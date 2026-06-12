# Project Status

Last updated: 2026-06-12

## Snapshot

- Project stage: active development (`0.0.0.9002`)
- Repository visibility: public on GitHub since 2026-06-04
- Package scope: OD mobility bias correction methods + Stage 2 validation toolkit + Stage 3 bias residual diagnostics + distributional bias diagnostics
- API direction: stable adjustment methods use `adjust_*`; validation helpers use `validate_flow_*`
- Bayesian component: `adjust_multilevel_bayes()` is the main methodological innovation and now has observed and complete-grid prediction scopes; S1-S4 source/time scenarios are supported by both Bayesian and frequentist engines, while empirical use remains dependency- and runtime-sensitive
- Current execution board: see [TASK_BOARD.md](TASK_BOARD.md)

## Stable vs Experimental

### Stable adjustment and validation API

- `measure_bias()`
- `measure_bias_distribution()`
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
  - S1-S4 repeated source/time scenarios can now be fitted with `model_engine = "bayesian"` or `model_engine = "frequentist"`
  - `observation_model = "latent_two_level"` is available as an experimental Bayesian backend for repeated source/time structures; it creates `latent_flow_id` states, estimates latent true-flow intensities with a custom Stan backend, and records latent-state metadata and identifiability notes
  - `model_terms` metadata records the resolved default fixed-effect and random-effect structure for the shared S1-S4 scenario contract
  - `model_engine = "frequentist"` remains useful for fast testing, experimentation, and method comparison before committing to Bayesian runtime
  - performance and dependency footprint are heavy relative to fixed-rule adjustment methods
  - backend guidance: `rstanarm` is the default package dependency for standard Poisson / negative-binomial models because it is lighter and easier to fit in a package workflow; use optional `brms` when you need extra flexibility, especially zero-inflated or more complex Bayesian specifications

## What Changed Recently

- The `debiasR` repository was made public on GitHub on 2026-06-04. Treat
  repository docs, vignettes, workflows, issues, pull requests, and tracked
  assets as public-facing by default.
- Function naming migrated from `method*` to `adjust_*`
- Validation API migrated from `validate_flows()` to `validate_flow_overall()` and `validate_flow_pairs()`, with legacy aliases retained temporarily for compatibility
- Data assets migrated from toy datasets to simulated test fixtures, while user-facing examples now default to the optional companion package `debiasRdata` (<https://github.com/de-bias/debiasRdata>) for the empirical LAD travel-to-work workflow.
- Adjustment methods are documented as a menu of coverage-based, margin-constrained, benchmark-calibrated, and multilevel modelling options; the Bayesian multilevel path is the central innovation but requires separate runtime and dependency validation.
- CI scaffolding now includes a fast core workflow plus a separate manual Bayesian workflow
- Bias metric updated to:
  - `coverage_bias = 1 - user_count/population`
  - `coverage_score = user_count/population`
- `measure_bias_distribution()` now compares benchmark-population and
  active-user spatial distributions using KL divergence, Jensen-Shannon
  divergence, share differences, and area-level contribution outputs.
- Top-level docs were refreshed to reflect the exported API, the implemented `debiasRdata` companion package, simulated test fixtures, and current repository structure
- User-facing docs now name the default empirical OD matrices explicitly: `lad_OD_travel2work` for observed MPD travel-to-work flows and `census_lad_OD_travel2work` for the Census benchmark. MSOA assets remain available through `geography = "msoa"` when needed.
- `debiasR_example_data()` now supports optional complete-grid OD output with zero-filled absent pairs, row-status indicators, an OD audit for strict square support, and selected-area LAD distances computed from `debiasRdata::lad_centroids`.
- `adjust_multilevel_bayes()` now supports `prediction_scope = "complete_grid"` for supplied square OD matrices; it fits on originally observed source rows when `mpd_observed` is available and predicts across the grid.
- `adjust_multilevel_bayes()` now has explicit scenario/source/time parameters for the S1-S4 multilevel path, with `model_engine = "bayesian"` for posterior fitting and `model_engine = "frequentist"` for fast design, test iteration, and method comparison.
- `adjust_multilevel_bayes()` now accepts a primary R formula interface. Area covariates are prepared with origin/destination suffixes, formula random-effect terms drive model dispatch, and `income_col` remains only as a legacy default-formula helper.
- `adjust_multilevel_bayes()` now also accepts split `mobility_formula` and
  `bias_formula` inputs. The package combines them internally for the current
  reduced-form fit, while metadata records the conceptual true-flow and
  observation-bias components separately.
- Enhancement issue #18 records the genuinely latent two-level Bayesian model,
  where `F_true_ij` is estimated explicitly rather than recovered only through
  a zero-bias counterfactual prediction. The current branch includes a first
  experimental custom Stan `latent_two_level` backend that estimates OD or
  OD-time latent true-flow intensities. The backend now exposes latent prior
  and sampler controls, records richer diagnostics, and splits optional
  Bayesian tests into `rstanarm-smoke`, full `rstanarm`, and latent-Stan
  scopes; empirical stress tests remain future hardening work.
- `validate_flow_distribution()` now supports `comparisons = "all"` so raw
  MPD, adjusted MPD-derived, and benchmark OD-flow allocation distributions can
  be compared through the same KL/JSD contract.
- The validation vignette now classifies this destination-share diagnostic as
  Level 4 distributional allocation validation, keeping Level 3 focused on
  individual origin-destination pair magnitudes, residuals, and outliers.
- A post-public repository hygiene pass reviewed public docs, pkgdown exposure,
  repository metadata, workflow deployment controls, tracked assets, and
  sensitive-content patterns. It removed a tracked workshop `.docx` with
  embedded Word metadata/comments, cleaned absolute local-path links, updated
  GitHub-owned Actions pins, restricted manual pkgdown deployments to `main`,
  clarified conduct-reporting and non-code licensing text, and removed stale
  public docs scaffolding.
- The default S1-S4 formula contract is documented for both engines: S1 uses the base OD/covariate/bias terms, S2 adds `mpd_time`, S3 adds `mpd_source`, and S4 adds `mpd_source + mpd_time`; S4 source-time interaction remains deferred.
- The adjustment vignette now keeps the Bayesian walkthrough focused on the
  default coverage-offset example with constant source/time columns and
  raw/adjusted/benchmark comparison columns.
- The advanced Bayesian adjustment vignette now explains S1-S4 source/time
  structures, the experimental `latent_two_level` backend, reduced-form
  compatibility mode, and Bayesian diagnostics.
- The adjustment vignette now reads its compact Bayesian example output from a
  precomputed package artifact reporting posterior median and mean summaries;
  maintainers can regenerate it explicitly with
  `Rscript scripts/precompute_v06_bayesian_example.R` when the model or data
  change.
- Fast core tests passed after replacing the placeholder raking smoke test and removing selection-rate deprecation warnings
- Stage 2 maintainer review is complete: `validate_flow_residual_structure()` is stable public API; optional diagnostic plots remain inside the validation helpers for now; `sf`-aware mapping remains outside the package; the optional `debiasRdata` companion package is the empirical data source.
- Stage 3 measure-bias diagnostics now include active-user coverage residuals, optional Moran's I, benchmark origin/destination flow correlations, covariate correlations, map-ready data, and optional plots through `validate_bias_residual_structure()`.
- Stage 3 maintainer review is complete: `validate_bias_residual_structure()` is stable public API; optional diagnostic plots remain inside the helper for now; a simple population-only linear-regression residual is included as a descriptive diagnostic.
- The Zenodo data gate is documented in `DATA_REDISTRIBUTION_DECISION.md`: do not bundle the full record in `debiasR`; use the separate optional `debiasRdata` package for empirical travel-to-work examples and keep simulated data as lightweight test fixtures.
- `debiasRdata` now exists locally and remotely at <https://github.com/de-bias/debiasRdata>. It supplies MSOA and LAD OD-flow assets, with the LAD route (`lad_OD_travel2work`, `census_lad_OD_travel2work`) now the default for `debiasR`, plus `lad_centroids` for selected-area distance derivation.
- Cleanup pass removed tracked rendered notebook HTML/assets from project-management notes while keeping the Quarto sources, and declared `debiasRdata` in `Suggests` for conditional examples.
- Public-release cleanup removed legacy raw calibration CSVs from `debiasR`.
  Public empirical examples now route through the audited `debiasRdata`
  package; `debiasR` keeps the prebuilt `simulated_*` fixtures for tests and
  lightweight examples.

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
- Result: pass. The targeted file covers S1-S4 scenario resolution, source/time metadata, observed prediction, complete-grid prediction, MSOA-like default frequentist formula-contract fixtures, and `model_terms` metadata.
- Verified on 2026-05-21 with `Rscript scripts/run_fast_tests.R`.
- Result: pass. Existing locale warnings remained, and the optional `lme4` tiny-data smoke path can still print a singular-fit message.
- Package-readiness check on 2026-05-21 with tests, vignettes, and manual skipped completed with 0 errors, 0 warnings, and 1 note:
  - `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes", "--no-tests"), error_on = "never")`
  - remaining note: the checker could not verify current time
- Vignette validation on 2026-05-21 rendered:
  - `vignettes/06-adjusting-biases.qmd`
  - `vignettes/testing/methods-conceptual-guide.qmd`
  - `vignettes/testing/simulated-methods-walkthrough.qmd`
  - `vignettes/testing/short-illustration.qmd` to a temporary output directory
  - `vignettes/testing/method-comparison.qmd` to a temporary output directory
- Verified on 2026-06-12 with `Rscript scripts/run_fast_tests.R`.
- Result: pass. The fast deterministic tier covers the frequentist S1-S4
  scenario contract, complete-grid metadata, and the unchanged deterministic
  adjustment/validation API.
- Bayesian S2-S4 validation on 2026-06-12 used a targeted `rstanarm` smoke
  check for S4 repeated source/time fitting because the full optional Bayesian
  test file remains slow. The targeted check verifies scenario metadata,
  source/time-specific coverage offsets, and MPD-scale versus true-flow-scale
  prediction algebra.
- Fast deterministic validation on 2026-06-12 passed with
  `Rscript scripts/run_fast_tests.R`. The tier now covers
  `measure_bias_distribution()`, extended `validate_flow_distribution()`
  comparisons, and the latent two-level backend metadata/data-contract path.
  The `0.0.0.9002` latent backend work adds a custom Stan contract and split
  smoke scopes that should pass before opening a ready PR; full optional
  Bayesian scopes should run before closing #18.

## Current Risks / Blockers

1. Public repository visibility raises the bar for repository hygiene: avoid committing confidential material, credentials, restricted raw data, or development-only artifacts that are not intended for public release.
2. Documentation mismatch risk now mainly sits in archival migration materials and older review notebook sources that intentionally use fixed test fixtures.
3. Test suite reliability still depends on using the curated runner rather than raw `test_dir()` calls.
4. Bayesian tests are slower and environment-sensitive due to MCMC runtime and optional `brms` support; run them manually when Bayesian-lane validation is needed.
5. CI has been scaffolded and the fast core workflow passed on merged PR #11; the current branch head still needs live validation on the next PR or push.
6. Full cartographic residual maps remain user-supplied because the package deliberately avoids adding an `sf` dependency at this stage.
7. The default LAD empirical route now has selected-area distance support through `lad_centroids`; MSOA distance-aware examples still require a future `msoa_OD_distance` or `msoa_centroids` asset if `geography = "msoa"` is needed.

## Immediate Priorities

1. Review public-facing docs, pkgdown pages, repository metadata, and tracked assets after the 2026-06-04 visibility change.
2. Validate the current branch head with local tests and the next GitHub Actions run.
3. Validate the optional/manual Bayesian workflow behavior on GitHub Actions
   when Bayesian-lane validation is needed; the runner now supports separate
   `rstanarm-smoke`, full `rstanarm`, and `latent-smoke` scopes.
4. Keep top-level docs synchronized with exported API (`NAMESPACE`).
5. Record feasible LAD empirical grid sizes and runtime expectations before promoting Bayesian examples beyond prototype guidance.
6. Harden enhancement issue #18 beyond the current experimental
   `latent_two_level` backend with S3/S4 empirical stress tests and prior
   sensitivity runs.
7. Use MSOA-scale inputs for software/runtime stress tests and LAD-scale inputs for vignettes and teaching material as the S1-S4 scenario work develops.
