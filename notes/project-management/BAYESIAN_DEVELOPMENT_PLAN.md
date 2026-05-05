# Bayesian Development Plan

Last updated: 2026-04-03

## Purpose

This note captures the next development steps for the Bayesian path in `debiasR`, centered on [`adjust_multilevel_bayes()`](/Users/franciscorowe/Library/CloudStorage/Dropbox/Francisco/Research/grants/2023/digital-footprint-accelerator/debias/github/debiasR/R/adjust_multilevel_bayes.R).

The current state is:

- Stage 1 implemented: bias-adjusted observed OD flows
- Stage 2 not implemented: missing-OD imputation
- Backends supported in principle: `rstanarm`, `brms`
- Current support level: prototype / experimental

## Current Progress Snapshot

As of 2026-04-20, Phase 1 is no longer just conceptual. The working tree now shows substantive progress on the main stabilization items:

1. Stage-1 scope is being clarified more explicitly in the function docs.
2. Result attributes are being expanded so successful fits carry clearer metadata and lightweight diagnostics.
3. The Bayesian test file has been extended to cover backend auto-selection, formula construction, metadata, and draw-summary behavior.
4. Stage 2 design and imputation work still remain untouched.

This plan is meant to help us continue development deliberately rather than expanding the prototype in an ad hoc way.

## Current Baseline

What already exists:

1. Data preparation helpers for coverage, covariates, and optional distance.
2. Formula construction and backend dispatch.
3. Posterior fixed-effect adjustment for observed OD pairs.
4. Basic tests covering:
- required schema validation
- deterministic preprocessing behavior
- backend-unavailable error handling
- a minimal successful `rstanarm` path when installed

What is still missing:

1. A formal definition of the Stage 2 imputation target.
2. Validation strategy for imputed unseen OD flows.
3. Clear runtime and dependency expectations for users.
4. A documented decision on whether the default backend should remain `rstanarm` for the practical path.

## Recommended Next Steps

## Phase 1: Stabilize Stage 1

Goal: make the current observed-OD Bayesian correction reliable and interpretable before adding missing-flow imputation.

Estimated effort: `1-2 days`

Tasks:

1. Define the exact Stage 1 contract.
- Clarify in docs what `flow_adj` means.
- Clarify that only observed OD pairs are adjusted.
- Clarify what is removed from the posterior linear predictor and why.

2. Tighten test coverage for Stage 1.
- Add tests for each supported `random_intercept` mode where feasible.
- Add tests for backend auto-selection behavior.
- Add tests for `flow_adj_summary = "mean"` vs `"median"`.
- Add tests for optional `include_flow_adj_draws`.

3. Improve diagnostics attached to the result object.
- Ensure the returned object carries enough metadata to interpret model behavior.
- Consider attaching convergence summaries or flags when available.

Deliverables:

- clearer Stage 1 documentation
- stronger tests for the current behavior
- a more explicit prototype contract for users and contributors

Decision gate:

- Do we trust Stage 1 as a stable experimental tool for observed OD correction?

If no, stay in Phase 1 until the answer is yes.

## Phase 2: Design Stage 2 Missing-OD Imputation

Goal: decide exactly how missing OD flows should be generated and how they connect to the existing Stage 1 model.

Estimated effort: `1-2 days`

Tasks:

1. Define the target population of missing OD pairs.
- All structurally possible OD pairs?
- Only within observed area sets?
- Do we exclude self-flows or impossible links?

2. Define the prediction mechanism.
- Predict from posterior fixed effects only?
- Include random effects for unseen combinations?
- Decide how origin/destination random effects are used for unobserved OD pairs.

3. Define output behavior.
- Should Stage 2 return only imputed missing flows?
- Or a full OD table containing observed adjusted flows plus imputed missing flows?
- How should uncertainty be summarized?

4. Define validation criteria.
- What evidence will count as improvement?
- Compare against simulated benchmarks where true full OD tables are known.
- Decide which summary metrics matter most for imputed flows.

Deliverables:

- a written Stage 2 design note
- a precise output contract
- evaluation criteria for imputation quality

Decision gate:

- Is the Stage 2 design identifiable, interpretable, and testable with current data assets?

## Phase 3: Implement Stage 2 on Simulated Data First

Goal: add missing-OD imputation only after the design is explicit and testable in a controlled setting.

Estimated effort: `2-4 days`

Tasks:

1. Build the candidate missing OD set.
2. Generate posterior predictions for missing pairs.
3. Decide whether to return draw-level predictions optionally.
4. Integrate Stage 2 output with existing Stage 1 adjusted observed flows.
5. Add simulated-data validation tests against known benchmark OD structure.

Deliverables:

- first implementation of Stage 2
- tests on simulated data
- clear examples showing what is observed, adjusted, and imputed

Decision gate:

- Does Stage 2 improve reconstruction of full OD structure enough to justify keeping it in-package?

## Phase 4: Harden the Bayesian Path for Broader Use

Goal: decide whether the Bayesian method remains prototype-only or is promoted to a more supported package feature.

Estimated effort: `2-3 days`

Tasks:

1. Revisit backend strategy.
- Keep `rstanarm` as the practical default for Poisson / NegBin?
- Keep `brms` as the only path for zero-inflated families?
- Decide whether both backends are worth maintaining.

2. Review runtime and CI strategy.
- Keep Bayesian checks manual only?
- Add a scheduled workflow?
- Add lighter smoke tests plus optional heavier model tests?

3. Improve user-facing ergonomics.
- clearer examples
- warnings around runtime and dependency footprint
- more explicit prototype/stability messaging if still experimental

Deliverables:

- backend policy
- CI/testing policy for Bayesian code
- updated README / STATUS / vignettes if scope changes

## Proposed Work Order

Recommended sequence:

1. Finish Phase 1 first.
2. Write the Stage 2 design note before implementing any imputation.
3. Implement Stage 2 only on simulated data first.
4. Decide on hardening only after Stage 2 performance is understood.

## Suggested Immediate Action List

If we pick this up in the next session, the most useful concrete starting tasks are:

1. Write a short Stage 1 contract section in the function docs and/or a dedicated note.
2. Add tests for:
- backend auto-selection
- `random_intercept`
- `flow_adj_summary`
- `include_flow_adj_draws`
3. Record a minimal benchmark for runtime and output shape using the simulated data.
4. Draft the Stage 2 design note before writing any imputation code.

## What Success Looks Like

The Bayesian method will be in a good place when:

1. Stage 1 is clearly bounded and well-tested.
2. Stage 2 has a written design before implementation.
3. Simulated-data validation shows whether imputation is actually helping.
4. The package can state plainly whether the Bayesian path is:
- experimental,
- supported for observed-flow correction only,
- or ready for fuller OD reconstruction workflows.
