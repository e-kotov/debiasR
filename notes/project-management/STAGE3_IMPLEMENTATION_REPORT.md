# Stage 3 Implementation Report

Last updated: 2026-05-05

## Summary

Stage 3 has been implemented as a measure-bias diagnostic layer for active-user coverage residuals.

The implemented layer now covers:

- deterministic coverage residual definitions linked to `measure_bias()`,
- optional residual spatial randomness diagnostics,
- benchmark origin-flow and destination-flow correlation diagnostics,
- selected covariate correlation diagnostics,
- map-ready and plot-ready review outputs,
- a runnable computational review notebook.

## Code Implemented

Added exported helper `validate_bias_residual_structure()` in `R/measure_bias.R`.

Implemented residuals:

- `global_coverage_score = sum(user_count) / sum(population)`.
- `expected_user_count = population * global_coverage_score`.
- `user_count_residual = user_count - expected_user_count`.
- `coverage_score_residual = coverage_score - global_coverage_score`.
- `standardized_user_count_residual = user_count_residual / sqrt(expected_user_count)`.
- `population_lm_expected_user_count = fitted(user_count ~ population)`.
- `population_lm_residual = user_count - population_lm_expected_user_count`.

Primary default:

- `residual_type = "coverage_score"`.

Interpretation:

- positive `coverage_score_residual` means higher active-user coverage than expected under the global coverage score,
- negative `coverage_score_residual` means lower active-user coverage than expected under the global coverage score.

## Diagnostics Implemented

`validate_bias_residual_structure()` returns:

- one-row summary table,
- residual definition table,
- area-level residual data,
- optional global Moran's I from a user-supplied neighbour-link table,
- population-only linear-model diagnostic summary,
- optional benchmark origin-flow and destination-flow Pearson correlations,
- optional covariate Pearson correlation,
- map-ready data optionally joined to user-supplied coordinates or geometry-like fields,
- optional `ggplot2` plots.

Design decisions:

- Keep `measure_bias()` compact and unchanged.
- Use a separate public helper rather than expanding `measure_bias()`.
- Reuse the Stage 2 plain-data-frame interfaces for neighbour links, covariates, and optional coordinate plots.
- Avoid adding `sf` or spatial-neighbour dependencies.

## Documentation Implemented

Updated user-facing and project-management documentation:

- `README.md`
- `NEWS.md`
- `vignettes/testing/empirical-methods-walkthrough.qmd`
- `notes/project-management/TASK_BOARD.md`
- `notes/project-management/STATUS.md`
- `notes/project-management/TEST_HEALTH.md`

Added Stage 3 notes:

- `STAGE3_MEASURE_BIAS_DESIGN_NOTE.md`
- `STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.qmd`
- rendered review output: `STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.html`

Generated package documentation:

- `man/validate_bias_residual_structure.Rd`

## Tests Implemented

Added deterministic tests:

- `tests/testthat/test-validate-bias-residual-structure.R`

Updated the fast deterministic runner:

- `scripts/run_fast_tests.R`

The tests cover:

- residual definitions,
- selected residual behavior,
- population-only linear-model residual behavior,
- Moran's I with deterministic neighbour links,
- benchmark origin and destination flow correlations,
- covariate correlation,
- optional plot output,
- input validation.

## Verification

Fast deterministic tests and notebook render verified on 2026-05-05.

Commands:

```r
Rscript scripts/run_fast_tests.R
```

Result:

- Pass.
- One optional `pscl`-dependent coefficient test skipped because `pscl` is not installed.

Notebook render:

```bash
quarto render notes/project-management/STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.qmd
```

Result:

- Pass.
- HTML output created at `notes/project-management/STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.html`.

Full package check attempted on 2026-05-05 before the package-readiness cleanup:

```r
devtools::check(
  document = FALSE,
  build_args = "--no-build-vignettes",
  args = c("--no-manual", "--ignore-vignettes"),
  error_on = "never"
)
```

Result:

- 1 error, 2 warnings, 3 notes.
- The error is in the optional Bayesian test file (`test-adjust-multilevel-bayes.R`) where draw-summary comparisons differ only by names on expected vectors; this is outside the Stage 3 deterministic diagnostics path.
- The warnings and notes were package-readiness items rather than Stage 3 diagnostics failures.

Follow-up on 2026-05-08:

- Package-readiness check with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 2 notes.
- Historical remaining notes were the then-missing optional companion data package and current time verification. `debiasRdata` now exists at <https://github.com/de-bias/debiasRdata>, but empirical tests should remain conditional because the companion package is optional.
- The Bayesian draw-summary names mismatch was fixed in the optional Bayesian test file.

## Maintainer Review Decisions

Reviewed on 2026-05-05.

1. Treat `validate_bias_residual_structure()` as stable public API immediately.
   - Rationale: the helper is deterministic, documented, tested, and directly tied to the existing `measure_bias()` coverage definitions.
2. Add a simple population-only linear-regression residual as a diagnostic option.
   - Clarification: this model residual is intentionally lightweight. It fits `user_count ~ population` using the benchmark population column and active-user counts in `coverage_df`, then reports observed minus fitted active-user counts as `population_lm_residual`. It is a descriptive diagnostic for areas that sit above or below a simple population trend, not a validated active-user sampling model and not a replacement for a future empirical sampling design.
3. Keep optional plot generation inside the diagnostics helper for now.
   - Rationale: the plots are optional, require only `ggplot2`, and make the review workflow easier. Revisit separate plotting helpers only if future diagnostics make the plotting surface larger or harder to maintain.
