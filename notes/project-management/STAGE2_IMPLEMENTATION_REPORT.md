# Stage 2 Implementation Report

Last updated: 2026-04-25

## Summary

Stage 2 has been implemented as a validation layer for comparing adjusted origin-destination flows against benchmark OD flows on more than overall fit.

The implemented layer now covers:

- method-level fit,
- OD-level residual reduction,
- raw-versus-adjusted residual outlier behavior,
- residual structure and randomness diagnostics,
- origin-conditioned destination allocation fidelity,
- data redistribution and CRAN suitability decisions.

## Code Implemented

### Residual Comparison

Updated `validate_flow_residuals()` in `R/validate_flows.R`.

Implemented outputs:

- `method` labels in summary, OD-level data, and `top_worst`.
- `benchmark_minus_mpd`.
- `benchmark_minus_adj`.
- `signed_residual_reduction`.
- `abs_residual_reduction`.
- raw MPD residual standard-deviation scores.
- adjusted residual standard-deviation scores.
- residual outlier flags above 1, 2, and 3 SDs for both raw MPD and adjusted residuals.
- `share_moved_in_benchmark_direction`.
- `reduction_share_residual_over_2sd`.

Interpretation decision:

- `signed_residual_reduction = (benchmark - observed_mpd) - (benchmark - adjusted)`.
- Algebraically, this equals `adjusted - observed_mpd`.
- Positive values mean the adjustment moved the OD flow upward relative to observed MPD.
- For method comparison where positive should mean reduced benchmark error, use `abs_residual_reduction`.

### Residual Structure

Added exported helper `validate_flow_residual_structure()`.

Implemented diagnostics:

- residual-versus-benchmark-flow Pearson correlation,
- area-level residual summaries by origin or destination,
- optional global Moran's I from a user-supplied neighbour-link table,
- optional residual-versus-covariate Pearson correlation,
- map-ready residual data,
- optional `ggplot2` diagnostics:
  - residual-reduction distribution,
  - residual-versus-benchmark-flow scatter,
  - residual-versus-covariate scatter,
  - coordinate-based residual map.

Design decision:

- Avoid adding `sf` or spatial-neighbour dependencies in Stage 2.
- Keep the interface transparent by requiring users to supply neighbour links and optional coordinate or geometry-like columns.

### Distributional Allocation

`validate_flow_distribution()` is implemented and exported.

Implemented diagnostics:

- benchmark and adjusted destination-share distributions by origin,
- union support across benchmark and adjusted OD pairs,
- configurable smoothing with default `epsilon = 1e-8`,
- `KL(benchmark || adjusted)`,
- Jensen-Shannon divergence,
- origin-level metrics,
- summary mean, median, and optional benchmark-origin-total weighted means.

Design note:

- Detailed specification is in `VALIDATION_DISTRIBUTIONAL_METRICS_NOTE.md`.

## Documentation Implemented

Updated user-facing and project-management documentation:

- `README.md`
- `NEWS.md`
- `vignettes/methods-conceptual-guide.qmd`
- `vignettes/simulated-methods-walkthrough.qmd`
- `vignettes/figures/package-workflow.svg`
- `notes/project-management/TASK_BOARD.md`
- `notes/project-management/STATUS.md`
- `notes/project-management/TEST_HEALTH.md`

Added Stage 2 notes:

- `VALIDATION_STAGE2_DESIGN_NOTE.md`
- `DATA_REDISTRIBUTION_DECISION.md`
- `STAGE2_IMPLEMENTATION_REPORT.md`
- `STAGE2_VALIDATION_REVIEW_NOTEBOOK.qmd`

Generated package documentation:

- `man/validate_flow_residuals.Rd`
- `man/validate_flow_residual_structure.Rd`
- refreshed alias docs for `validate_flow_overall.Rd` and `validate_flow_pairs.Rd`.

## Tests Implemented

Updated or added tests:

- `tests/testthat/test-validate-flow-residuals.R`
- `tests/testthat/test-validate-flow-residual-structure.R`
- `tests/testthat/test-validate-flow-distribution.R`

Updated the fast deterministic runner:

- `scripts/run_fast_tests.R`

## Verification

Verified on 2026-04-25.

Commands:

```r
Rscript scripts/run_fast_tests.R
```

Result:

- Pass.
- One optional `pscl`-dependent coefficient test skipped because `pscl` is not installed.

Additional package-level check:

```r
devtools::check(
  document = FALSE,
  build_args = "--no-build-vignettes",
  args = c("--no-manual", "--ignore-vignettes"),
  error_on = "never"
)
```

Result:

- 0 errors.
- 1 existing warning about non-portable long file paths.
- 2 existing notes about top-level project files and Bayesian NSE globals.

Full vignette rebuilding was not run because Pandoc is unavailable in the local environment.

## Data Redistribution Decision

Decision:

- Do not bundle the full Zenodo record in `debiasR`.
- Keep `debiasR` small with simulated/tiny examples.
- If empirical packaged data is needed, create a separate optional data package such as `debiasRdata`.

Rationale:

- The Zenodo record is licensed `CC BY 4.0`, so redistribution appears legally compatible with attribution.
- The full record is too large for the main package.
- `msoa_OD_travel2work.csv.gz` is the preferred candidate if a separate data package is created.

## Remaining Review Questions

1. Should `validate_flow_residual_structure()` be treated as stable public API immediately, or marked as early Stage 2 API until used in one empirical workflow?
2. Should optional plot generation stay inside the helper, or move later into separate plotting helpers if more diagnostics are added?
3. Should a future release add `sf`-aware map support, or keep cartographic rendering outside the package?

## Next Stage

Stage 3 should extend `measure_bias()`-related diagnostics.

Recommended next work:

1. Write a Stage 3 design note defining active-user coverage residuals.
2. Implement a focused helper, likely `validate_bias_residual_structure()` or `measure_bias_residuals()`, only after the residual definition is agreed.
3. Reuse Stage 2 residual-structure patterns where appropriate:
   - user-supplied neighbour links,
   - optional covariate table,
   - map-ready area data,
   - optional `ggplot2` diagnostics.
4. Add deterministic tests using simulated coverage, population, and covariate data.
5. Update README, NEWS, status notes, and vignettes only after the API name and residual definition settle.
