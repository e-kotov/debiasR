# Latent Two-Level Bayesian Design Note

Last updated: 2026-06-12

## Purpose

This note scopes enhancement issue #18: a genuinely latent two-level Bayesian
model for `adjust_multilevel_bayes()`. It records both the first package
prototype added on 2026-06-12 and the follow-up experimental custom Stan
backend. The backend estimates explicit latent true-flow intensities, but it
should remain experimental until prior sensitivity, diagnostics, and larger
S3/S4 empirical workflows are hardened.

The current implementation can separate `mobility_formula` and `bias_formula`,
and `target_scale = "true_flow"` with `observation_model = "coverage_offset"`
uses coverage as a fixed observation offset. Issue #18 should go one step
further: estimate a latent true-flow state explicitly, then model each
mobile-phone-derived observation as a biased and noisy measurement of that
state.

## Current Prototype Status

The current development branch includes:

- `observation_model = "latent_two_level"` in `adjust_multilevel_bayes()`;
- `latent_flow_unit = "auto"`, `"od"`, or `"od_time"` to define the latent
  state key;
- internal `latent_flow_id` and `latent_flow_unit` columns in the returned
  result;
- an experimental `backend = "stan_latent"` custom Stan path selected by
  `backend = "auto"` for latent models;
- source-invariant OD or OD-time latent true-flow intensities estimated
  directly by the custom backend;
- coverage-offset true-flow prediction with `flow_true_pred`, `flow_mpd_pred`,
  and `flow_adj`;
- metadata for the number of latent states and weak-identification warnings;
- fast tests for argument/data-contract behavior and an optional tiny Bayesian
  smoke test for repeated-source observations.

This is intentionally experimental. The custom backend now represents the
latent state explicitly, but the fuller target model below still needs stronger
prior controls, observation-layer source/time effects, posterior predictive
checks, and richer diagnostics. Issue #18 should therefore remain open until
those hardening tasks are resolved or deliberately split into follow-up issues.

## Model Target

For origin `i`, destination `j`, source `s`, and time `t`, define:

- `Y_ijst`: observed MPD flow.
- `F_ijt`: latent true flow or latent true-flow intensity for OD pair `(i, j)`
  at time `t`. It is source-invariant.
- `q_ijst`: known or derived observation probability from active-user coverage.
- `x_ijt`: true-mobility predictors, such as distance and area covariates.
- `z_ijst`: observation-bias predictors, such as coverage residuals, source
  indicators, or source-time terms.

The recommended first implementation should model the latent true-flow
intensity, not a discrete latent count, because it is easier to fit and diagnose:

```text
log(lambda_true_ijt) =
  alpha + x_ijt beta + u_i_origin + v_j_destination + w_ij_od + tau_t

Y_ijst ~ NegBin(mu_obs_ijst, phi_obs)
log(mu_obs_ijst) =
  log(lambda_true_ijt) + log(q_ijst) + z_ijst gamma +
  a_s_source + b_st_source_time
```

`flow_adj` should summarize `lambda_true_ijt` on the count scale. A later
extension can sample a discrete `F_ijt` from the posterior predictive true-flow
distribution, but the first implementation should avoid adding discrete latent
parameters unless a clear validation need appears.

## Priors

The latent model needs stronger default priors than the reduced-form path
because true-flow and observation-bias components can otherwise trade off.

Recommended defaults:

- Standardize continuous predictors before fitting or document that priors
  assume approximately standardized inputs.
- Use weakly regularizing normal priors for true-flow fixed effects, for
  example `normal(0, 1)` on standardized slopes and a wider intercept prior
  centered near the log median observed flow after coverage adjustment.
- Use half-normal or half-Student-t priors on origin, destination, OD, time,
  source, and source-time standard deviations.
- Use tighter normal priors for observation-bias coefficients, for example
  `normal(0, 0.5)` or `normal(0, 1)` on the log scale, unless empirical
  validation justifies broader bias variation.
- Keep the coverage offset coefficient fixed at 1 in the first implementation.
  Estimating it should be a later sensitivity option because it weakens
  identifiability.
- Use regularizing priors on overdispersion, with prior predictive checks to
  ensure plausible MPD count variation.

## Identifiability

The latent true-flow scale is not identified by one observed MPD matrix alone.
The first implementation should state this directly and rely on external
coverage, repeated measurements, and regularizing priors.

Main constraints:

- `F_ijt` is source-invariant. Source effects belong in the observation layer.
- Time effects can belong in the true-flow layer because mobility can change
  over time. Source-time interactions should initially belong in the
  observation layer and remain optional.
- Source and source-time effects should be centered so they cannot absorb the
  global true-flow intercept.
- Coverage scores must be positive exposure ratios, not arbitrary indices.
- Rich origin or destination random effects can absorb area-level coverage
  patterns, so diagnostics must check whether the latent and observation layers
  are weakly separated.
- Complete-grid rows marked as source-missing predictions are not observed
  zeros unless the input explicitly marks them as observed zero flows.

S3 and S4 provide the strongest identification because multiple sources observe
the same latent OD-time state. S1 should be supported only with clear warnings:
without repeated observations or strong external coverage information, the
latent split is mostly prior- and offset-driven.

## S1-S4 Structures

The latent model should reuse the existing scenario contract.

S1: single source, single time.

- Latent state: `F_ij`.
- Observation: one `Y_ij`.
- Identification: weakest; useful mainly as a compatibility and simulation
  case.

S2: single source, multiple times.

- Latent state: `F_ijt`.
- Observation: one source observes each OD-time cell.
- True-flow time effects and OD-level temporal pooling are allowed, but source
  bias is not separately learned from replication.

S3: multiple sources, single time.

- Latent state: one `F_ij` shared across sources.
- Observation: each source has its own source bias and coverage exposure.
- This is the cleanest setting for separating source reporting intensity from
  true OD structure.

S4: multiple sources, multiple times.

- Latent state: `F_ijt`, shared across sources within each time.
- Observation: source effects and optional source-time effects capture
  reporting differences.
- Default source-time fixed interactions should remain deferred. A source-time
  random effect can be tested after S3 and simpler S4 models behave well.

## Proposed API

Keep the public surface close to the existing function:

```r
adjust_multilevel_bayes(
  mpd_od_df = mpd,
  coverage_df = coverage,
  covariates_df = covariates,
  distance_df = distance,
  mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance +
    (1 | origin) + (1 | destination),
  bias_formula = ~ bias_e_origin + (1 | mpd_source),
  target_scale = "true_flow",
  observation_model = "latent_two_level",
  coverage_scale = "origin",
  model_engine = "bayesian",
  backend = "auto",
  scenario = "s4",
  source_col = "mpd_source",
  time_col = "mpd_time",
  prediction_scope = "complete_grid"
)
```

Design decisions:

- Add `observation_model = "latent_two_level"` without changing the meaning of
  `"reduced_form"` or `"coverage_offset"`.
- Reuse `mobility_formula` for the true-flow layer and `bias_formula` for the
  observation layer.
- Keep `target_scale = "true_flow"` required for the latent model.
- Keep `coverage_scale` as the default source of `q_ijst`.
- Keep `scenario`, `source_col`, `time_col`, `repeated_observation`, and
  `prediction_scope` unchanged.
- Add optional draw controls only if needed, for example
  `include_latent_draws = FALSE`; otherwise extend `include_flow_adj_draws` to
  return true-flow draws for the latent model.

Default formula routing should be conservative: true-flow terms get distance,
area covariates, population terms, origin/destination/OD pooling, and time
effects; observation terms get coverage residuals, source effects, and optional
source-time pooling.

## Backend Strategy

`rstanarm` should remain the default backend for existing reduced-form and
coverage-offset models, but it is not expressive enough for the latent
two-level model. `observation_model = "latent_two_level"` should therefore
route to a backend that can fit a custom joint model.

Recommended policy:

- `backend = "auto"` chooses the current `rstanarm` path for existing models
  and `backend = "stan_latent"` for `latent_two_level`.
- The latent path should error clearly if the custom backend is unavailable.
- `brms` can remain an exploratory backend only if the model can be expressed
  transparently without hiding the shared latent state.
- The internal frequentist scaffold should continue to validate data shape,
  formula construction, and S1-S4 metadata, but it should not pretend to fit the
  latent Bayesian model.
- The first latent implementation should use small simulated data and optional
  Bayesian CI only; it should not enter the fast deterministic test tier except
  through preprocessing and metadata tests.

## Output Contract

Return the existing tibble shape where possible. Required row-level fields:

- identifiers: `origin`, `destination`, optional `mpd_source`, optional
  `mpd_time`, and complete-grid row-status fields;
- `flow`: observed MPD flow;
- `flow_adj`: posterior summary of the latent true-flow intensity;
- `flow_true_pred`: same scale as `flow_adj`;
- `flow_mpd_pred`: posterior summary of the source/time-specific MPD
  observation mean;
- `observation_probability` and `log_observation_probability`;
- `coverage_rate_o` and `coverage_rate_d` when available;
- uncertainty columns or attributes for true-flow and MPD-scale intervals.

Required metadata:

- `observation_model = "latent_two_level"`;
- backend, model family, priors, and sampler settings;
- resolved true-flow and observation formulas;
- S1-S4 scenario metadata;
- latent-state key, usually OD-time rather than OD-source-time;
- number of latent states, observed rows, fit rows, prediction rows, and
  zero-filled prediction rows;
- diagnostics and prototype notes explaining identifiability limits.

Draw-level outputs should be optional because S4 complete-grid models can become
large quickly.

## Diagnostics

Minimum diagnostics:

- sampler diagnostics: divergences, maximum R-hat, minimum effective sample
  size, treedepth warnings, and runtime;
- posterior predictive checks for `Y_ijst` overall and by source, time, origin,
  destination, and row status;
- summaries of `flow_mpd_pred / flow_true_pred` and adjusted-to-observed ratios;
- source-effect and source-time-effect summaries with shrinkage diagnostics;
- correlation between coverage exposure and residual MPD-scale error;
- comparison of latent true-flow totals by origin and destination against any
  supplied benchmark, using existing `validate_flow_*` helpers outside fitting;
- flags for weak identification, such as very wide true-flow intervals, source
  effects that absorb most variation, or high posterior correlation between
  true-flow and observation-bias parameters.

## Test Plan

Fast deterministic tests:

- validate `observation_model = "latent_two_level"` argument handling;
- validate that `target_scale = "true_flow"` is required;
- validate S1-S4 latent-state keys and source/time metadata;
- validate formula partitioning between true-flow and observation layers;
- validate complete-grid row-status handling;
- validate clear errors for unavailable latent backend, missing coverage, zero
  coverage, duplicate OD-source-time keys, and invalid scenarios.

Optional Bayesian tests:

- recover known latent flows on tiny simulated S3 and S4 data within broad
  tolerances;
- recover source bias direction on simulated repeated-source data;
- confirm `flow_mpd_pred` is source/time-specific while `flow_true_pred` is
  source-invariant within OD-time cells;
- confirm draw output dimensions and metadata;
- smoke-test posterior diagnostics with intentionally low iterations.

Empirical validation should remain outside the first PR. Use MSOA-scale inputs
for runtime stress tests and LAD-scale inputs only after the simulated contract
is stable.

## Staged Implementation

1. Add the API gate and data-preparation contract without fitting the latent
   model.
2. Add true-flow and observation formula partitioning, latent-state indexing,
   and metadata tests.
3. Implement the custom Bayesian backend on tiny simulated S3 data.
4. Extend to S4 with source/time metadata and complete-grid prediction.
5. Add diagnostics and optional draw outputs.
6. Compare latent, coverage-offset, and reduced-form modes on simulated data
   with known true flows.
7. Update user-facing documentation only after the latent path has stable
   simulation evidence and an acceptable runtime envelope.

## Decision Gate

Proceed to implementation only if the first PR can preserve existing behavior,
make the latent state explicit in metadata and output, and fail clearly when
the required Bayesian backend is unavailable. The latent model should remain
experimental until S3-S4 simulations show that it separates true-flow structure
from source-specific observation bias better than the current coverage-offset
path.
