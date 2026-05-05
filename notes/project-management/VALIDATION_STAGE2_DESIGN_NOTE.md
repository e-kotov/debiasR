# Stage 2 Validation Design Note

Last updated: 2026-04-25

## Purpose

Stage 2 extends validation beyond overall benchmark fit. The validation layer now compares adjustment methods on:

- overall benchmark alignment,
- OD-level residual reduction,
- residual outlier behavior,
- residual structure across areas, benchmark flow size, and user-selected covariates,
- origin-conditioned destination allocation fidelity.

## Implemented API

The Stage 2 validation layer is split across focused helpers:

- `validate_flow_overall()` for method-level correlation, error, and regression summaries.
- `validate_flow_pairs()` for the minimal joined OD audit table.
- `validate_flow_residuals()` for signed movement, absolute residual reduction, raw-versus-adjusted outlier shares, improvement flags, and top-worst OD pairs.
- `validate_flow_residual_structure()` for residual randomness and structure diagnostics.
- `validate_flow_distribution()` for origin-conditioned KL divergence and Jensen-Shannon divergence.

## Residual Reduction

The task-board formula is implemented as:

`signed_residual_reduction = (benchmark - observed_mpd) - (benchmark - adjusted)`

This simplifies to:

`signed_residual_reduction = adjusted - observed_mpd`

Decision:

- Keep this exact signed movement indicator because it is useful for auditing the direction and magnitude of the adjustment.
- Do not use it alone as the "positive means better" metric, because positive only means the adjusted flow moved upward relative to observed MPD.
- Use `abs_residual_reduction = abs(mpd - benchmark) - abs(adjusted - benchmark)` when a positive value must mean reduced benchmark error.

`validate_flow_residuals()` therefore returns both:

- `signed_residual_reduction` for directional movement,
- `abs_residual_reduction` and `improvement_flag` for method comparison.

## Residual Outliers

Decision:

- Report outlier shares for both raw MPD residuals and adjusted residuals.
- Use standard-deviation thresholds at 1, 2, and 3 SDs.
- Use the reduction in share above 2 SDs as the main outlier-reduction summary.

This keeps the original residual structure visible, and avoids making adjusted residuals look isolated from the starting MPD error distribution.

## Residual Structure

`validate_flow_residual_structure()` implements the Stage 2 residual randomness diagnostics with deliberately light dependencies.

It returns:

- Pearson correlation between selected OD residuals and benchmark OD flows.
- Area-level residual summaries by origin or destination.
- Optional global Moran's I when the user supplies a plain neighbour-link table.
- Optional Pearson correlation between area-level residuals and a user-selected covariate.
- Map-ready area residual data, optionally joined to user-supplied coordinates or geometry-like fields.
- Optional `ggplot2` plots for residual reduction, residual-versus-flow, residual-versus-covariate, and coordinate residual maps.

Decision:

- Do not import `sf` or spatial-neighbour packages for Stage 2.
- Require users to pass neighbour links explicitly for Moran's I.
- Return map-ready data rather than attempting to own full cartographic workflows.

This keeps the validation API deterministic, transparent, and CRAN-light.

## Distributional Allocation

`validate_flow_distribution()` is specified in detail in `VALIDATION_DISTRIBUTIONAL_METRICS_NOTE.md`.

The implemented choices are:

- compare benchmark and adjusted destination-share distributions within each origin,
- build support from the union of benchmark and adjusted destinations,
- smooth with configurable `epsilon`, default `1e-8`,
- return `KL(benchmark || adjusted)` as the directional metric,
- return Jensen-Shannon divergence as the symmetric companion metric,
- summarize by mean, median, and optionally benchmark-origin-total weighted mean.

These metrics assess allocation fidelity, not total flow scale.

## Method-Assessment Penalty

Decision:

- Do not add a package metric that penalizes methods for using MPD flows or benchmark calibration inputs.

Rationale:

- This is a research-design and fairness-of-comparison judgement, not a property of the adjusted OD table.
- A defensible penalty would require an explicit scoring framework for information use, calibration burden, and deployment constraints.
- Until that framework exists, the penalty belongs in method-comparison notes rather than the package API.

## Validation Gate

Stage 2 now has a validation layer that compares methods on:

- fit: `validate_flow_overall()`,
- OD residual behavior: `validate_flow_residuals()`,
- residual structure and randomness: `validate_flow_residual_structure()`,
- spatial allocation fidelity: `validate_flow_distribution()`.

The remaining review question is not implementation completeness, but whether these helpers should be considered stable enough for the next public API milestone.
