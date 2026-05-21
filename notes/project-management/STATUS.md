# Project Status

Last updated: 2026-05-21

## Snapshot

- Project stage: active development (`0.0.0.9000`)
- Package scope: OD mobility bias correction methods + Stage 2 validation toolkit + Stage 3 bias residual diagnostics
- API direction: stable adjustment methods use `adjust_*`; validation helpers use `validate_flow_*`
- Bayesian component: `adjust_multilevel_bayes()` is the main methodological innovation and now has observed and complete-grid prediction scopes; empirical use remains dependency- and runtime-sensitive
- Current execution board: see [TASK_BOARD.md](TASK_BOARD.md)

## Stable vs Experimental

### Stable adjustment and validation API

- `measure_bias()`
- `validate_bias_residual_structure()`
- `adjust_inverse_penetration()`
- `adjust_selection_rate()`
- `adjust_selection_rate2()`
- `adjust_raking_ratio()`
- `adjust_coefficient()`
- `validate_flow_overall()`
- `validate_flow_pairs()`
- `validate_flow_residuals()`
- `validate_flow_residual_structure()`
- `validate_flow_distribution()`
  - legacy aliases retained temporarily: `validate_flow_benchmark()`, `validate_flow_all()`

### Bayesian multilevel path

- `adjust_multilevel_bayes()`
  - observed-flow correction remains backward compatible
  - complete-grid prediction mode is available for strict square OD matrices
  - row-status metadata distinguishes observed MPD rows from zero-filled source-missing cells
  - scenario metadata now distinguishes S1 single-source/single-time, S2 single-source/multiple-time, S3 multiple-source/single-time, and S4 multiple-source/multiple-time inputs
  - S1-S4 development should use `model_engine = "frequentist"` first; Bayesian scenario implementation is deferred until the complete model contract is stable
  - `model_terms` metadata records the resolved default fixed-effect and random-effect structure for the frequentist-first scenario contract
  - `model_engine = "bayesian"` now errors clearly for resolved S2-S4 inputs so repeated source/time Bayesian fitting is not implied before the transfer step
  - performance and dependency footprint are heavy relative to fixed-rule adjustment methods
  - backend guidance: prefer `rstanarm` for standard Poisson / negative-binomial models because it is lighter and easier to fit in a package workflow; use `brms` when you need extra flexibility, especially zero-inflated or more complex Bayesian specifications

## What Changed Recently

- Function naming migrated from `method*` to `adjust_*`
- Validation API migrated from `validate_flows()` to `validate_flow_overall()` and `validate_flow_pairs()`, with legacy aliases retained temporarily for compatibility
- Data assets migrated from toy datasets to simulated test fixtures, while user-facing examples now default to the optional companion package `debiasRdata` (<https://github.com/de-bias/debiasRdata>) for the empirical LAD travel-to-work workflow.
- Adjustment methods are documented as a menu of coverage-based, margin-constrained, benchmark-calibrated, and multilevel modelling options; the Bayesian multilevel path is the central innovation but requires separate runtime and dependency validation.
- CI scaffolding now includes a fast core workflow plus a separate manual Bayesian workflow
- Bias metric updated to:
  - `coverage_bias = 1 - user_count/population`
  - `coverage_score = user_count/population`
- Top-level docs were refreshed to reflect the exported API, the implemented `debiasRdata` companion package, simulated test fixtures, and current repository structure
- User-facing docs now name the default empirical OD matrices explicitly: `lad_OD_travel2work` for observed MPD travel-to-work flows and `census_lad_OD_travel2work` for the Census benchmark. MSOA assets remain available through `geography = "msoa"` when needed.
- `debiasR_example_data()` now supports optional complete-grid OD output with zero-filled absent pairs, row-status indicators, an OD audit for strict square support, and selected-area LAD distances computed from `debiasRdata::lad_centroids`.
- `adjust_multilevel_bayes()` now supports `prediction_scope = "complete_grid"` for supplied square OD matrices; it fits on originally observed source rows when `mpd_observed` is available and predicts across the grid.
- `adjust_multilevel_bayes()` now has explicit scenario/source/time parameters for the planned S1-S4 multilevel path, plus `model_engine = "frequentist"` for fast design and test iteration while the Bayesian method remains the goal.
- The default frequentist S1-S4 formula contract is documented: S1 uses the base OD/covariate/bias terms, S2 adds `mpd_time`, S3 adds `mpd_source`, and S4 adds `mpd_source + mpd_time`; S4 source-time interaction remains deferred.
- Fast core tests passed after replacing the placeholder raking smoke test and removing selection-rate deprecation warnings
- Stage 2 maintainer review is complete: `validate_flow_residual_structure()` is stable public API; optional diagnostic plots remain inside the validation helpers for now; `sf`-aware mapping remains outside the package; the optional `debiasRdata` companion package is the empirical data source.
- Stage 3 measure-bias diagnostics now include active-user coverage residuals, optional Moran's I, benchmark origin/destination flow correlations, covariate correlations, map-ready data, and optional plots through `validate_bias_residual_structure()`.
- Stage 3 maintainer review is complete: `validate_bias_residual_structure()` is stable public API; optional diagnostic plots remain inside the helper for now; a simple population-only linear-regression residual is included as a descriptive diagnostic.
- The Zenodo data gate is documented in `DATA_REDISTRIBUTION_DECISION.md`: do not bundle the full record in `debiasR`; use the separate optional `debiasRdata` package for empirical travel-to-work examples and keep simulated data as lightweight test fixtures.
- `debiasRdata` now exists locally and remotely at <https://github.com/de-bias/debiasRdata>. It supplies MSOA and LAD OD-flow assets, with the LAD route (`lad_OD_travel2work`, `census_lad_OD_travel2work`) now the default for `debiasR`, plus `lad_centroids` for selected-area distance derivation.
- Cleanup pass removed tracked rendered notebook HTML/assets from project-management notes while keeping the Quarto sources, and declared `debiasRdata` in `Suggests` for conditional examples.

## Verification

- Verified on 2026-05-05 with `Rscript scripts/run_fast_tests.R`
- Result: pass
- Notes:
  - adjustment, Stage 2 validation, and Stage 3 bias residual diagnostics tests passed
  - core workshop vignettes and updated testing notebooks render cleanly when `debiasRdata` is absent by exiting early with an installation note
  - `quarto render notes/project-management/STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.qmd` completed successfully
  - `test-adjust-coefficient.R` skipped one optional `pscl`-dependent case because `pscl` is not installed
  - full `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes"), error_on = "never")` was also run on 2026-05-05; it completed with 1 error, 2 warnings, and 3 notes before the 2026-05-08 package-readiness cleanup
- GitHub Actions on merged PR #11 (`Codex/validation distribution`) completed the fast core workflow successfully for commit `59705b376c26a4b33ecbbc9cd1063b037fd61572`.
- The current working tree has been validated locally; the pushed head still needs remote GitHub Actions confirmation.
- Verified on 2026-05-08 with `Rscript scripts/run_fast_tests.R`.
- Result: pass.
- Package-readiness check on 2026-05-08 with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 2 notes:
  - `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes", "--no-tests"), error_on = "never")`
  - historical remaining notes: the then-missing optional companion data package and current time verification
- A local optional Bayesian test-file run completed on 2026-05-08 with `rstanarm` installed. Result: no failures, one expected skip for the unavailable-backend fallback path, and expected warnings from locale handling, synthetic-distance fallback, and intentionally low-iteration MCMC convergence diagnostics.
- Verified on 2026-05-18 by loading the sibling `../debiasRdata` checkout and calling `debiasR_example_data(n_areas = 5, complete_grid = TRUE)`.
- Result: pass. The helper returned both `lad_OD_travel2work` and `census_lad_OD_travel2work`; `metadata$geography` was `lad`, and `distance_source` was `debiasRdata_lad_centroids`.
- Package-readiness cleanup check on 2026-05-18 with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 1 note:
  - `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes", "--no-tests"), error_on = "never")`
  - remaining note: the checker could not verify current time
- Documentation validation on 2026-05-18 rendered the core workshop vignettes `vignettes/01-landing-page.qmd` through `vignettes/08-data.qmd` against the installed `debiasRdata` route using bounded empirical examples.
- `validate_bias_residual_structure()` now supports and tests the documented `population_lm` residual option.
- Verified on 2026-05-21 with targeted
  `Rscript -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-adjust-multilevel-frequentist-dev.R', reporter = 'summary')"`.
- Result: pass. The targeted file now covers S1-S4 scenario resolution, source/time metadata, observed prediction, complete-grid prediction, MSOA-like default frequentist formula-contract fixtures, `model_terms` metadata, and the explicit Bayesian S2-S4 deferral guard.
- Verified on 2026-05-21 with `Rscript scripts/run_fast_tests.R`.
- Result: pass. Existing locale warnings remained, and the optional `lme4` tiny-data smoke path can still print a singular-fit message.
- Package-readiness check on 2026-05-21 with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 1 note:
  - `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes", "--no-tests"), error_on = "never")`
  - remaining note: the checker could not verify current time

## Current Risks / Blockers

1. Documentation mismatch risk now mainly sits in archival migration materials and older review notebook sources that intentionally use fixed test fixtures.
2. Test suite reliability still depends on using the curated runner rather than raw `test_dir()` calls.
3. Bayesian tests are slower and environment-sensitive due to optional dependencies; run them manually when Bayesian-lane validation is needed.
4. CI has been scaffolded and the fast core workflow passed on merged PR #11; the current branch head still needs live validation on the next PR or push.
5. Full cartographic residual maps remain user-supplied because the package deliberately avoids adding an `sf` dependency at this stage.
6. The default LAD empirical route now has selected-area distance support through `lad_centroids`; MSOA distance-aware examples still require a future `msoa_OD_distance` or `msoa_centroids` asset if `geography = "msoa"` is needed.

## Immediate Priorities

1. Validate the current branch head with local tests and the next GitHub Actions run.
2. Validate the optional/manual Bayesian workflow behavior on GitHub Actions when Bayesian-lane validation is needed; the local optional Bayesian test file now passes.
3. Keep top-level docs synchronized with exported API (`NAMESPACE`).
4. Record feasible LAD empirical grid sizes and runtime expectations before promoting Bayesian examples beyond prototype guidance.
5. Use MSOA-scale inputs for software/runtime stress tests and LAD-scale inputs for vignettes and teaching material as the S1-S4 scenario work develops.
