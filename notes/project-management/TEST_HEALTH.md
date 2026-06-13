# Test Health

Last updated: 2026-06-13

## Summary

- Recommended fast-tier entry point:
  - `Rscript scripts/run_fast_tests.R`
- Recommended broad local development runner:
  - `Rscript scripts/run_dev_tests.R`
- Optional Bayesian runner:
  - `Rscript scripts/run_bayesian_tests.R` (defaults to `smoke`)
  - `Rscript scripts/run_bayesian_tests.R smoke`
  - `Rscript scripts/run_bayesian_tests.R rstanarm-smoke`
  - `Rscript scripts/run_bayesian_tests.R rstanarm`
  - `Rscript scripts/run_bayesian_tests.R latent-smoke`
  - `Rscript scripts/run_bayesian_tests.R latent-stress`
  - `Rscript scripts/run_bayesian_tests.R all`
- The runner loads the package with `devtools::load_all(".")` before executing targeted tests.
- Full suite still includes a slower Bayesian test file with MCMC runtime and optional `brms` coverage.
- Observed behavior today:
  - `Rscript scripts/run_fast_tests.R` passes, most recently on 2026-06-12 after adding `measure_bias_distribution()`, extended `validate_flow_distribution()` comparisons, and the custom latent two-level Stan data-contract checks.
  - merged PR #11 (`Codex/validation distribution`) passed the GitHub Actions fast deterministic workflow for commit `59705b376c26a4b33ecbbc9cd1063b037fd61572`.
  - the current working tree has been validated locally; the pushed head still needs remote GitHub Actions confirmation.
  - package-readiness check with tests/vignettes/manual skipped now completes with 0 errors, 0 warnings, and 1 note:
    `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes", "--no-tests"), error_on = "never")`.
  - the remaining package-readiness note is that the checker could not verify current time.
  - `debiasRdata` is now declared in `Suggests`, so conditional examples no longer trigger an unstated-dependency warning.
  - `debiasRdata` now exists at <https://github.com/de-bias/debiasRdata>; empirical integration should be validated with the installed companion package.
  - local integration smoke check on 2026-05-18 passed by loading `../debiasRdata` and calling `debiasR_example_data(n_areas = 5, complete_grid = TRUE)`. The helper returned default LAD objects and `distance_source = "debiasRdata_lad_centroids"`.
  - core workshop vignettes `vignettes/01-landing-page.qmd` through `vignettes/08-data.qmd` render against the installed `debiasRdata` route using bounded empirical examples.
  - `vignettes/v06-adjusting-biases.qmd`, `vignettes/v09-advanced-bayesian-adjustment.qmd`, `vignettes/testing/methods-conceptual-guide.qmd`, and `vignettes/testing/simulated-methods-walkthrough.qmd` render after replacing the Bayesian Method 6 example with a precomputed Bayesian coverage-offset example and splitting advanced Bayesian material into its own article.
  - `vignettes/testing/short-illustration.qmd` and `vignettes/testing/method-comparison.qmd` render to a temporary output directory after the same placeholder update.
  - `quarto render notes/project-management/STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.qmd` passes.
  - core workshop vignettes and updated testing notebooks render cleanly without `debiasRdata` installed by exiting early with an installation note.
  - targeted tests for `measure_bias`, `measure_bias_distribution()`, empirical example-data loading, Stage 3 bias residual diagnostics, deterministic adjustment helpers, Stage 2 validation helpers, and the raking smoke test pass under `load_all`.
  - targeted fast tests for `model_engine = "frequentist"` pass under `load_all`, covering S1-S4 scenario resolution, source/time metadata preparation, observed prediction, complete-grid prediction, MSOA-like default formula-contract fixtures, `model_terms` metadata, latent S1/S3 data-contract behavior, and the optional `lme4` mixed-model smoke path when installed.
  - `validate_bias_residual_structure()` now has a regression test for the documented `population_lm` residual option.
  - `test-adjust-coefficient.R` skips one optional `pscl`-dependent case when `pscl` is not installed.
  - the Bayesian draw-summary names mismatch has been fixed in the optional Bayesian test file.
  - local optional Bayesian smoke checks completed with `rstanarm` and `rstan` installed, including a tiny `stan_latent` repeated-source fit. The optional Bayesian runner is now split into `smoke`, `rstanarm-smoke`, full `rstanarm`, `latent-smoke`, and `latent-stress` scopes; no-argument runner calls default to `smoke`, while `all` includes the full rstanarm file and the latent S3/S4 stress scope. Smoke scopes should pass before opening a ready PR, and hosted/manual `latent-stress` results should be recorded before closing #18 or promoting the latent backend beyond experimental status.
  - local hardening checks on 2026-06-13 passed with `/Library/Frameworks/R.framework/Resources/bin/Rscript scripts/run_fast_tests.R`, `/Library/Frameworks/R.framework/Resources/bin/Rscript scripts/run_bayesian_tests.R latent-stress`, and no-argument `/Library/Frameworks/R.framework/Resources/bin/Rscript scripts/run_bayesian_tests.R`. The no-argument run selected the new `smoke` default; the latent-stress run completed in about 58 seconds with R 4.5.2, `testthat` 3.3.2, `rstanarm` 2.32.2, and `rstan` 2.32.7.
  - running `test_dir()` without loading package can produce false failures (`function not found`, data object not found).

## Test Tiers (Recommended)

### Tier 1: Fast deterministic (run on every commit)

- `tests/testthat/test-measure_bias.R`
- `tests/testthat/test-measure-bias-distribution.R`
- `tests/testthat/test-example-data.R`
- `tests/testthat/test-validate-bias-residual-structure.R`
- `tests/testthat/test-adjust_inverse_penetration.R`
- `tests/testthat/test-adjust-selection-rate.R`
- `tests/testthat/test-adjust-selection-rate2.R`
- `tests/testthat/test-adjust-raking-ratio.R`
- `tests/testthat/test-adjust-coefficient.R`
- `tests/testthat/test-adjust-multilevel-latent-contract.R`
- `tests/testthat/test-adjust-multilevel-frequentist-dev.R`
- `tests/testthat/test-validate-flow-overall.R`
- `tests/testthat/test-validate-flow-pairs.R`
- `tests/testthat/test-validate-flow-residuals.R`
- `tests/testthat/test-validate-flow-residual-structure.R`
- `tests/testthat/test-validate-flow-distribution.R`
- `tests/testthat/test-adjust_raking_ratio-smoke.R`

### Tier 2: Bayesian / slow / dependency-sensitive

- `tests/testthat/test-adjust-multilevel-bayes.R`
- `tests/testthat/test-adjust-multilevel-bayes-rstanarm-smoke.R`
- `tests/testthat/test-adjust-multilevel-bayes-latent.R`
- `tests/testthat/test-adjust-multilevel-bayes-latent-stress.R`
- Requires longer runtime; `rstanarm-smoke` and full `rstanarm` scopes require
  `rstanarm`, the `latent-smoke` and `latent-stress` scopes require `rstan`,
  and `brms` remains optional for extra model families.

## Current Known Test Issues

1. Direct `testthat::test_dir("tests/testthat")` without package load context may fail.
2. Bayesian tests are slower and environment-sensitive because of MCMC runtime, `rstanarm`, `rstan`, and optional `brms` support.
3. Full package checks that run the optional Bayesian lane may still be slow because `rstanarm` is now a default dependency and the latent backend compiles a custom Stan model.
4. Empirical tests that require `debiasRdata` should remain conditional because the companion package is optional.
5. Some warnings are locale-related (`LC_ALL='C.UTF-8'`) and mostly non-blocking.
6. The optional tiny-data `lme4` mixed-model smoke path may print a singular-fit message; this is expected for the deliberately small fixture.

## Recommended CI Strategy

1. Job A (required): fast deterministic tests only.
2. Job B (manual / optional): Bayesian tests using hard package dependencies plus explicit test runner packages.
3. Ensure CI runs from package root and loads package context before test execution.
4. Keep the fast lane lightweight by installing hard dependencies plus the explicit test runner packages rather than the full optional stack.

## Canonical Commands

```r
# Local fast tier
Rscript scripts/run_fast_tests.R
```

```r
# Local development tier, excluding optional Bayesian tests by default
Rscript scripts/run_dev_tests.R
```

```r
# Optional Bayesian tier
Rscript scripts/run_bayesian_tests.R smoke
Rscript scripts/run_bayesian_tests.R latent-stress
```

```bash
# Optional-data vignette smoke checks
quarto render vignettes/03-getting-set-up.qmd
quarto render vignettes/testing/empirical-methods-walkthrough.qmd
```

```r
# Local all-tests (dev context)
devtools::load_all(".", quiet = TRUE)
testthat::test_dir("tests/testthat", reporter = "summary")
```
