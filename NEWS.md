# debiasR NEWS

## 0.0.0.9000

### Stage 3 measure-bias diagnostics

- Added `validate_bias_residual_structure()` for active-user coverage residual diagnostics linked to `measure_bias()`.
- The helper returns coverage-score, count-scale, and standardized count residuals, with optional Moran's I, benchmark origin/destination flow correlations, covariate correlations, map-ready area data, and optional `ggplot2` diagnostics.
- Added a Stage 3 design note and review notebook for inspecting the implemented residual definitions and diagnostics on simulated data.

### Stage 2 validation layer

- Added richer residual comparison outputs to `validate_flow_residuals()`, including method labels, the Stage 2 signed residual-movement indicator, absolute residual reduction, raw-versus-adjusted residual outlier shares, and direction-of-benchmark movement flags.
- Added `validate_flow_residual_structure()` for residual randomness diagnostics, including benchmark-flow correlation, optional Moran's I from user-supplied neighbour links, optional covariate correlation, map-ready area residuals, and optional `ggplot2` diagnostic plots.
- Added `validate_flow_distribution()` for origin-conditioned destination-share fidelity using `KL(benchmark || adjusted)` and Jensen-Shannon divergence.

### Validation naming update

- The primary validation API now uses `validate_flow_overall()` for summary metrics and `validate_flow_pairs()` for row-level comparisons.
- The older names `validate_flow_benchmark()` and `validate_flow_all()` remain available as backwards-compatible aliases for one release cycle.
- The legacy `validate_flows()` helper has been removed.

### Migration notes

- Package documentation and onboarding now refer to `adjust_*` functions and `simulated_*` datasets consistently.
