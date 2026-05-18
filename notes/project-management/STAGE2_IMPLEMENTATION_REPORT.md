# Stage 2 Implementation Report

Last updated: 2026-05-18

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
- `vignettes/testing/methods-conceptual-guide.qmd`
- `vignettes/testing/empirical-methods-walkthrough.qmd`
- `vignettes/testing/figures/package-workflow.svg`
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

Historical result on 2026-05-05 before the package-readiness cleanup:

- 1 error, 2 warnings, 3 notes.
- The error is in the optional Bayesian test file (`test-adjust-multilevel-bayes.R`) where draw-summary comparisons differ only by names on expected vectors; this is outside the deterministic Stage 2 validation path.
- The warnings and notes were package-readiness items rather than Stage 2 validation failures.

Follow-up on 2026-05-08:

- Package-readiness check with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 2 notes.
- Historical remaining notes were the then-missing optional companion data package and current time verification.
- The Bayesian draw-summary names mismatch was fixed in the optional Bayesian test file.

Vignette smoke checks were run with Quarto on 2026-05-05. The empirical
`debiasRdata` vignettes render cleanly in an environment without `debiasRdata`
by exiting early with an installation note.

## Data Redistribution Decision

Decision:

- Do not bundle the full Zenodo record in `debiasR`.
- Keep `debiasR` small with simulated/tiny test fixtures.
- Use the separate optional companion package `debiasRdata`
  (<https://github.com/de-bias/debiasRdata>) for empirical examples and
  vignettes.

Rationale:

- The Zenodo record is licensed `CC BY 4.0`, so redistribution appears legally compatible with attribution.
- The full record is too large for the main package.
- `debiasRdata` supplies `msoa_OD_travel2work` as the MPD empirical data object,
  paired with the extracted Census benchmark object
  `census_msoa_OD_travel2work`.

## Maintainer Review Decisions

Stage 2 maintainer review was completed on 2026-05-08.

Decisions:

1. Treat `validate_flow_residual_structure()` as stable public API immediately.
2. Keep optional plot generation inside the validation helper for now because the plots are dependency-light and useful during review. Split plotting into separate helpers later only if the plotting surface grows.
3. Keep `sf`-aware map support outside the package for now. The package should continue returning map-ready area data and user-supplied coordinate plots rather than owning full cartographic workflows.
4. Accept the data-redistribution decision: do not bundle the full Zenodo resource in `debiasR`; use the optional `debiasRdata` companion package for empirical MSOA travel-to-work examples.
5. Implementation update on 2026-05-18: `debiasRdata` now exists locally and remotely at <https://github.com/de-bias/debiasRdata>. It includes `msoa_OD_travel2work` and `census_msoa_OD_travel2work`; real MSOA OD distance remains planned.

## Subsequent Stage Status

Stage 3 has now extended `measure_bias()`-related diagnostics through
`validate_bias_residual_structure()`.

Implemented Stage 3 follow-up:

1. Wrote `STAGE3_MEASURE_BIAS_DESIGN_NOTE.md` defining active-user coverage
   residuals and the simple population-only linear-model residual.
2. Added exported helper `validate_bias_residual_structure()`.
3. Reused Stage 2 residual-structure patterns:
   - user-supplied neighbour links,
   - optional covariate table,
   - map-ready area data,
   - optional `ggplot2` diagnostics.
4. Added deterministic tests using simulated coverage, population, and
   covariate data.
5. Updated README, NEWS, status notes, vignettes, and diagrams to reflect the
   settled Stage 3 API and residual definitions.
