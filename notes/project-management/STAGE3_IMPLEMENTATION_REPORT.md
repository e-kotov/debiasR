# Stage 3 Implementation Report

Last updated: 2026-04-26

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
- `vignettes/simulated-methods-walkthrough.qmd`
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
- Moran's I with deterministic neighbour links,
- benchmark origin and destination flow correlations,
- covariate correlation,
- optional plot output,
- input validation.

## Verification

Verified on 2026-04-26.

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

Package check:

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
- 1 portable-file-name warning for long note and rendered-notebook asset paths.
- 2 existing notes about non-standard top-level files and Bayesian NSE globals.

## Remaining Review Questions

1. Should `validate_bias_residual_structure()` be treated as stable public API immediately, or marked as an early Stage 3 diagnostic until it is used in an empirical workflow?
2. Should a future release add a model-based residual option once an active-user sampling model is agreed?
3. Should optional plot generation stay inside diagnostics helpers, or move later into separate plotting helpers if the plotting surface grows?
