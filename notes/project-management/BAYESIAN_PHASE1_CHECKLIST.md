# Bayesian Phase 1 Checklist

Last updated: 2026-05-18

This checklist records the completed Phase 1 stabilization work for the
observed-flow Bayesian prototype. Complete-grid prediction now exists as a
separate prototype mode, but empirical runtime guidance remains pending.

Reference note:

- [BAYESIAN_DEVELOPMENT_PLAN.md](BAYESIAN_DEVELOPMENT_PLAN.md)

## Stage 1 Contract

- [x] Clarify in the function docs that Stage 1 adjusts observed OD flows only.
- [x] Clarify that `flow_adj` is derived by removing the estimated coverage-bias contribution from posterior fixed-effect predictors.
- [x] Clarify how `flow_adj_summary` changes the returned adjusted flow.
- [x] Make the returned object expose enough metadata to understand backend, family, summary choice, and stage.

## Test Coverage

- [x] Test backend auto-selection logic without requiring a full fit.
- [x] Test formula construction for `origin`, `destination`, `od`, and `none`.
- [x] Test result metadata for successful Stage 1 fits.
- [x] Test `include_flow_adj_draws = TRUE` behavior when the active backend is available.
- [x] Test `flow_adj_summary = "mean"` versus `"median"` when the active backend is available.

## Diagnostics And Usability

- [x] Review whether the output should carry a dedicated Stage 1 scope attribute.
- [x] Review whether prototype notes should mention observed-only support more explicitly.
- [x] Decide whether lightweight convergence metadata should be attached now or deferred.

## Exit Criteria For Phase 1

- [x] Stage 1 behavior is documented clearly enough that a contributor can explain what `flow_adj` means.
- [x] Core Stage 1 helper logic is covered by tests that do not depend on heavy Bayesian backends.
- [x] Successful fits expose enough attributes to debug and interpret the result object.
- [x] The next unresolved step is empirical complete-grid/runtime hardening, not uncertainty about observed-flow behavior.
