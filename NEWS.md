# debiasR 0.0.0.9000

### Public documentation and governance

- Recorded that the `debiasR` repository is public on GitHub as of 2026-06-04
  and updated project context for public-repository hygiene.
- Added GitHub Pages pkgdown deployment support for the public vignette site.
- Added repository code ownership for Francisco Rowe and Carmen Cabrera.
- Updated contribution guidance so all changes to `main` go through pull
  requests with code-owner review.
- Documented public GitHub installation commands for `debiasR` and the
  empirical companion package `debiasRdata`.
- Made vignette setup chunks robust to interactive execution from RStudio by
  falling back to the package root or `vignettes/` folder when the current
  knitted input file is unavailable.
- Rewrote the validation workflow vignette to clarify how users can compare
  raw, adjusted, and benchmark OD flows with the current `validate_flow_*`
  diagnostics.
- Refined the validation vignette interpretation and recommendation text for
  the three-level validation workflow.

### Multilevel scenario development

- Added split `mobility_formula` and `bias_formula` support to
  `adjust_multilevel_bayes()` so users can distinguish conceptual Level-2
  true-flow predictors from Level-1 MPD observation-bias terms while retaining
  the current reduced-form fitting implementation.
- Opened enhancement issue #18 for the planned genuinely latent two-level
  Bayesian model where `F_true_ij` is estimated explicitly.
- Added an S1-S4 scenario contract for `adjust_multilevel_bayes()` covering single/multiple mobile-phone-derived data sources crossed with single/multiple observation periods.
- Added `scenario`, `source_col`, `time_col`, `repeated_observation`, and `model_engine` parameters so the multilevel path can validate and carry source/time metadata without introducing separate user-facing functions.
- Added a primary `formula` interface for `adjust_multilevel_bayes()`, with arbitrary area covariates available as `{covariate}_o` and `{covariate}_d`, formula-specified random effects and slopes, and legacy `custom_formula` / `income_col` compatibility retained.
- Added a frequentist development engine for fast testing of the shared multilevel data contract, complete-grid semantics, and bias-removal algebra; new S1-S4 model development should use this engine before Bayesian sampling is promoted.
- Added `model_terms` metadata to the multilevel result contract so the resolved default fixed-effect and random-effect structure can be inspected directly.
- Kept S2-S4 Bayesian scenario fitting explicitly deferred by returning a clear error under `model_engine = "bayesian"` when a repeated source/time scenario is resolved; use `model_engine = "frequentist"` for current S1-S4 development.
- Expanded fast tests with MSOA-like S1-S4 fixtures that exercise the default frequentist formula contract and complete-grid prediction metadata.
- Updated workshop/testing vignettes to show an S1 `model_engine = "frequentist"` placeholder example with one source and one time unit, plus parameter guidance for S2-S4 repeated source/time structures.

### Empirical LAD travel-to-work examples

- Added `debiasR_example_data()` to load and normalise `debiasRdata` LAD travel-to-work inputs into the package `origin`, `destination`, `flow` schema.
- Added optional complete-grid output to `debiasR_example_data()`, including zero-filled absent OD pairs, source row-status indicators, and an OD audit for strict square support.
- Added Census 2021 `ODWP01EW` workplace-flow extraction scripts for the benchmark travel-to-work OD matrices.
- Updated examples to use the optional companion package `de-bias/debiasRdata`, with `lad_OD_travel2work` as the default observed OD matrix and `census_lad_OD_travel2work` as the Census benchmark, while retaining MSOA access through `geography = "msoa"` and `simulated_*` datasets as lightweight test fixtures.
- Added selected-area LAD distance derivation from real `debiasRdata::lad_centroids`, avoiding a packaged full OD distance matrix.
- Removed legacy raw calibration CSVs from the main repository so public data
  assets are served through the audited `debiasRdata` package and lightweight
  simulated fixtures remain prebuilt in `debiasR`.

### Bayesian complete-grid prediction

- Extended `adjust_multilevel_bayes()` with `prediction_scope = "complete_grid"` for supplied square OD matrices.
- Complete-grid mode validates OD support, fits on originally observed MPD rows when `mpd_observed` is available, predicts across the supplied grid, and returns row-status and runtime metadata.
- Refreshed the training vignettes to centre the Bayesian multilevel adjustment path while keeping deterministic methods as transparent baselines.

### Stage 3 measure-bias diagnostics

- Added `validate_bias_residual_structure()` for active-user coverage residual diagnostics linked to `measure_bias()`.
- The helper returns coverage-score, count-scale, standardized count, and population-only linear-model residuals, with optional Moran's I, benchmark origin/destination flow correlations, covariate correlations, map-ready area data, and optional `ggplot2` diagnostics.
- Added a Stage 3 design note and review notebook for inspecting the implemented residual definitions and diagnostics on deterministic fixture data.

### Stage 2 validation layer

- Added richer residual comparison outputs to `validate_flow_residuals()`, including method labels, the Stage 2 signed residual-movement indicator, absolute residual reduction, raw-versus-adjusted residual outlier shares, and direction-of-benchmark movement flags.
- Added `validate_flow_residual_structure()` for residual randomness diagnostics, including benchmark-flow correlation, optional Moran's I from user-supplied neighbour links, optional covariate correlation, map-ready area residuals, and optional `ggplot2` diagnostic plots.
- Added `validate_flow_distribution()` for origin-conditioned destination-share fidelity using `KL(benchmark || adjusted)` and Jensen-Shannon divergence.

### Validation naming update

- The primary validation API now uses `validate_flow_overall()` for summary metrics and `validate_flow_pairs()` for row-level comparisons.
- The older names `validate_flow_benchmark()` and `validate_flow_all()` remain available as backwards-compatible aliases for one release cycle.
- The legacy `validate_flows()` helper has been removed.

### Migration notes

- Package documentation and onboarding now refer to `adjust_*` functions and the current example-data workflow consistently.
- `adjust_multilevel_bayes()` is the main methodological innovation and now has observed and complete-grid prediction scopes; empirical Bayesian rendering still requires explicit dependency, runtime, and real-distance validation.
