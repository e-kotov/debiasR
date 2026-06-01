# Multilevel Model Scenario Plan

Last updated: 2026-05-21

## Purpose

This note defines the planned scenario support for mobile-phone-derived inputs
in `adjust_multilevel_bayes()`. The aim is to handle variation in data source
and observation time through one transparent Bayesian modelling path.

The Bayesian model remains the end goal. During S1-S4 model development, use
the faster frequentist engine first through `model_engine = "frequentist"` so we
can skip sampler work until the complete data contract, formula structure, and
output contract are stable. Move the completed structure into
`model_engine = "bayesian"` only after that contract has been reviewed.

## Scenario Definitions

S1: single source, single time.

- One mobile-phone-derived OD matrix for one observation period.
- This is the current baseline scenario for observed-flow correction and
  complete-grid prediction.
- Source and time identifiers may be absent or constant.

S2: single source, multiple times.

- One mobile-phone-derived source observed across repeated periods.
- A time identifier is required.
- The model should support temporal variation while preserving the OD structure.

S3: multiple sources, single time.

- Two or more mobile-phone-derived OD matrices for the same observation period.
- A source identifier is required.
- The model should support source-level variation in coverage or reporting
  intensity.

S4: multiple sources, multiple times.

- Multiple mobile-phone-derived sources observed across repeated periods.
- Source and time identifiers are required.
- The model should support source effects, time effects, and a later decision on
  whether a source-time interaction is needed.

## API Direction

Scenario support should be added through parameters in `adjust_multilevel_bayes()`.

Initial design questions:

- Should users pass `scenario`, `source_col`, and `time_col`, or should
  `scenario` be inferred when source and time columns are supplied?
- Should S1 be represented by missing source/time columns, constant source/time
  columns, or both?
- Which random-effect structures should be available for each scenario while
  keeping the function transparent?

Working recommendation:

- Accept explicit source and time column arguments.
- Allow a scenario argument for clarity and validation.
- Use `model_engine = "frequentist"` as the active development path until S1-S4
  behaviour is complete; keep `model_engine = "bayesian"` for the existing
  Stage-1 path and final transfer.
- Infer the simplest valid scenario only when `scenario = "auto"`.
- Return scenario metadata so downstream validation and teaching examples can
  show what was fit.
- Keep existing observed-flow and complete-grid prediction behavior unchanged
  for S1.

## Current Frequentist Formula Contract

The primary user-facing model interface is now `formula`, for example:

`flow ~ rural_pct_o + rural_pct_d + log_distance + bias_e_origin + (1 + log_distance | origin)`

Area-level covariates are joined twice using origin and destination suffixes.
Formula random-effect terms are treated as the source of truth when supplied.
`custom_formula` is retained as a deprecated alias, and `income_col` is retained
only as a legacy helper for the default formula.

Under `model_engine = "frequentist"` and no `formula`, the default formula
starts from:

`flow ~ income_o + income_d + log_distance + bias_e_origin`

When finite population terms are available, the default also includes
`log_pop_o + log_pop_d`.

Scenario-specific fixed effects are:

- S1: no additional source/time term.
- S2: add `mpd_time`.
- S3: add `mpd_source`.
- S4: add `mpd_source + mpd_time`.

Current random-intercept options are `origin`, `destination`, `od`, `source`,
`time`, `source_time`, and `none`, subject to the relevant grouping column
having at least two levels. If a source or time grouping is requested as the
random intercept, the same source or time fixed effect is omitted from the
default formula to avoid duplicating that structure.

The S4 fixed source-time interaction remains deferred until empirical runtime
and identifiability are reviewed. Users can request `random_intercept =
"source_time"` during development to test source-time pooling without adding a
default fixed interaction.

`model_engine = "bayesian"` currently remains the existing Stage-1 S1 path. It
now errors clearly for resolved S2-S4 inputs so the package does not imply that
full Bayesian scenario transfer has already happened.

## Development Data Policy

Use MSOA data for software development and internal testing.

- MSOA inputs are better for stress testing because they expose larger grids,
  repeated observations, and stricter runtime constraints.
- Internal tests should cover scenario detection, missing required columns,
  source/time metadata, and compatibility with the existing prediction scopes.

Use LAD data for vignettes and teaching materials.

- LAD examples are easier to explain and render.
- LAD should remain the default empirical teaching route because it is the
  current user-facing path through `debiasRdata`.

## Workstreams

### Software Development

1. Define the S1-S4 data contract.
- Required columns: origin, destination, flow, benchmark or comparison fields,
  and optional source/time identifiers depending on scenario.
- Confirm how complete-grid row-status metadata interacts with source and time
  identifiers.

2. Build the frequentist scaffold.
- Use a fast internal GLM or GLMM prototype to check formula construction,
  scenario-specific terms, and output shape.
- Use the scaffold to identify runtime and identifiability problems before
  running Bayesian fits.
- Expose it only as a development engine option on `adjust_multilevel_bayes()`;
  do not introduce a separate exported frequentist adjustment function.

3. Implement Bayesian scenario support.
- Defer Bayesian scenario implementation until the frequentist S1-S4 contract is
  complete.
- Then map each reviewed scenario to a transparent Bayesian model formula.
- Preserve current backend policy: `rstanarm` for the practical standard path
  and `brms` only when extra model flexibility is required.
- Return scenario metadata, model terms, and prediction-scope metadata.

4. Add internal MSOA tests.
- Test S1 backward compatibility.
- Test S2 time-column validation and time-level metadata.
- Test S3 source-column validation and source-level metadata.
- Test S4 combined source/time validation and metadata.

### Vignettes and Teaching Materials

1. Build LAD-scale examples.
- Keep examples small and explicit.
- Avoid forcing Bayesian dependencies during routine vignette rendering when
  the optional backend is unavailable.

2. Teach scenarios in order.
- S1: baseline OD correction.
- S2: temporal variation.
- S3: source variation.
- S4: combined source and temporal variation.

3. Explain the modelling status.
- State that `model_engine = "frequentist"` is a development device for faster
  model-contract iteration.
- Present the Bayesian model as the intended package method.
- Keep prototype and runtime caveats visible until empirical Bayesian runtime is
  validated.

## Decision Gate

Proceed to implementation only if the S1-S4 contract can be expressed with
clear parameters, stable metadata, and focused tests. Defer any general formula
interface until the scenario-specific path is stable.
