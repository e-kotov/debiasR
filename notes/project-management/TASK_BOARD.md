# Task Board

Last updated: 2026-05-18

This board turns the current roadmap into a short execution plan. Estimated effort is in rough person-hours.

The staged track below is intended to be implemented one stage per chat window. Do not start the next stage until the current stage deliverables and decision notes have been reviewed.

## Now

1. Validate optional Bayesian CI workflow and empirical distance readiness - `1-2h`
- Fast deterministic GitHub Actions validation passed on merged PR #11.
- Current branch fast deterministic tests pass locally.
- Local optional Bayesian test-file run passes with `rstanarm`; the remaining workflow check is the manual/optional GitHub Actions lane.
- Confirm the optional/manual Bayesian lane on GitHub Actions when Bayesian-lane validation is required.
- Real OD distance is still not included in `debiasRdata`; keep final empirical
  Bayesian rendering gated until that asset is added.

## Recently Completed

1. Review Stage 2 validation deliverables - `complete`
- Maintainer review completed on 2026-05-08.
- `validate_flow_residual_structure()` is stable public API.
- Optional validation plots remain inside helpers for now.
- `debiasRdata` is the implemented empirical MSOA data route:
  <https://github.com/de-bias/debiasRdata>.

2. Close remaining package-readiness warnings - `complete`
- Long generated paths and non-standard project folders are excluded from package builds through `.Rbuildignore`.
- Bayesian NSE warnings were removed by tightening tidyselect/tidy-evaluation expressions.
- The Bayesian draw-summary names mismatch in the optional test file was fixed.
- Package-readiness check with tests/vignettes/manual skipped now has 0 errors and 0 warnings.

3. Keep Bayesian scope aligned - `complete`
- `adjust_multilevel_bayes()` is documented as the main methodological innovation.
- Observed-flow mode remains backward compatible.
- Complete-grid prediction mode is available for strict square OD matrices and preserves row-status metadata.
- Full empirical Bayesian rendering remains gated by Bayesian dependencies, runtime, and real OD distance from `debiasRdata`.

4. Create `debiasRdata` companion package - `complete`
- Repository: <https://github.com/de-bias/debiasRdata>.
- Included data objects: `msoa_OD_travel2work` and
  `census_msoa_OD_travel2work`.
- License and source metadata live in the companion package.
- `debiasR::debiasR_example_data(n_areas = 5)` was smoke-tested against the
  local sibling `debiasRdata` checkout on 2026-05-18.
- `msoa_OD_distance` remains planned.

## Later

1. Harden the Bayesian path further - `1-2 days`
- Validate complete-grid Bayesian prediction on real `debiasRdata` OD inputs.
- Add or connect real MSOA OD distance in `debiasRdata` before final empirical
  Bayesian rendering.
- Record feasible empirical grid sizes and runtime expectations.
- Split the Bayesian tests into a clear optional CI lane if the scope expands.

2. Prepare a release-ready maintenance pass - `1-2 days`
- Re-run the full package check after the CI and migration work settle.
- Review examples and vignettes for remaining dependency friction.
- Decide whether a tagged pre-release makes sense after stabilization.

## Staged Implementation Track

This section is the working implementation plan for the next feature stages. Each stage is scoped so it can be handled in a separate chat window.

### Stage 2: Validation

Goal: extend validation beyond overall fit so we can compare methods on residual reduction, outlier behavior, and residual structure.

Estimated effort: `2-4 days`

Status: `complete; maintainer reviewed`

Tasks:

1. Define the core validation targets.
- Implemented geographic benchmark-adjusted flow correlation through `validate_flow_overall()`.
- Implemented residual-reduction diagnostics in `validate_flow_residuals()`, including the exact signed Stage 2 movement indicator and an absolute residual-reduction metric where positive values mean less benchmark error.
- Implemented MPD and adjusted residual outlier shares above 1, 2, and 3 standard deviations.
- Implemented distributional allocation fidelity in `validate_flow_distribution()` using origin-conditioned KL divergence and Jensen-Shannon divergence.

2. Implement a residual-reduction indicator for method comparison.
- Implemented the OD-level signed movement indicator as:
  `(benchmark_od_flow - observed_mpd_od_flow) - (benchmark_od_flow - adjusted_mpd_od_flow)`.
- Decision: this algebraic indicator equals `adjusted - observed_mpd`, so positive means upward adjustment. The package also returns `abs_residual_reduction`, where positive means reduced benchmark error, for method comparison.
- Method identifiers are carried in residual summaries, OD-level residual data, and top-worst residual rows.
- Summaries include mean, median, share improved/worsened/unchanged, direction-of-benchmark movement share, and optional distribution plots.

3. Add residual outlier diagnostics.
- Implemented residual shares above 1, 2, and 3 standard deviations.
- Decision: report both raw MPD residuals and adjusted residuals.
- Added outlier-reduction summaries, including reduction in the share above 2 standard deviations.

4. Add residual randomness diagnostics.
- Implemented `validate_flow_residual_structure()` with optional global Moran's I from user-supplied neighbour links.
- Implemented area-level residual `map_data`; optional coordinate-based residual map plots are returned when coordinates and `ggplot2` are available.
- Implemented residual-versus-benchmark-flow Pearson correlation and optional scatter plot.
- Implemented residual-versus-user-selected-covariate Pearson correlation and optional scatter plot.
- Decision: covariates are passed as a plain area-level data frame plus explicit area and covariate column names.
- Maintainer review decision: treat `validate_flow_residual_structure()` as stable public API immediately.
- Maintainer review decision: keep optional diagnostic plots inside the helper for now because they are dependency-light and useful for review; split plotting into separate helpers later only if the plotting surface grows.
- Maintainer review decision: keep `sf`-aware cartographic support outside the package for now.

5. Add distributional allocation diagnostics.
- Implemented destination-share distributions by origin for benchmark and adjusted flows.
- Implemented dedicated helper `validate_flow_distribution()`.
- Implemented `KL(benchmark || adjusted)` as the directional allocation-fidelity metric.
- Implemented Jensen-Shannon divergence as the symmetric companion metric.
- Decision: use union support, configurable positive smoothing with default `epsilon = 1e-8`, origin-level metrics, and optional benchmark-origin-total weighted summaries.

6. Explore a method-assessment penalty indicator.
- Decision: keep this out of the package API for now.
- Rationale: a penalty for calibration inputs is a research-design judgement, not a validation property of an adjusted OD table. It belongs in method-comparison notes until a defensible scoring framework is agreed.

7. Resolve the data and redistribution gate.
- Documented in `DATA_REDISTRIBUTION_DECISION.md`.
- Confirmed the Zenodo record is licensed CC BY 4.0, which permits redistribution with attribution, but the full record is too large for the main package.
- Confirmed `msoa_OD_travel2work.csv.gz` is the preferred MPD empirical asset and should be paired with the extracted Census `census_msoa_OD_travel2work` benchmark.
- Recommended CRAN-safe option: a separate optional `debiasRdata` package licensed for the data, with `debiasR` using `Suggests`, `requireNamespace()`, `system.file()`, and conditional examples/tests/vignettes.
- Updated direction for `debiasR`: keep simulated/tiny data as lightweight test fixtures, but base user-facing examples and vignettes on the optional `debiasRdata` MSOA travel-to-work workflow.
- Maintainer review decision: accept the optional `debiasRdata` strategy and do not bundle the full Zenodo record in `debiasR`.
- Implementation update: `debiasRdata` now exists at
  <https://github.com/de-bias/debiasRdata> and supplies
  `msoa_OD_travel2work` plus `census_msoa_OD_travel2work`.

Deliverables:

- [x] a written validation design note
- [x] an implementation spec for `validate_flow_distribution()`
- [x] a method-comparison residual indicator with explicit interpretation
- [x] residual outlier summaries
- [x] residual randomness diagnostics and plots
- [x] origin-level and summary distributional allocation metrics based on KL divergence and Jensen-Shannon divergence
- [x] a written decision on data redistribution and CRAN suitability
- [x] a written recommendation on whether to use a separate `debiasRdata` package for `msoa_OD_travel2work.csv.gz`
- [x] a Stage 2 implementation report
- [x] a runnable Stage 2 validation review notebook

Decision gate:

- Do we have a validation layer that compares methods on fit, residual structure, and spatial allocation fidelity, and do we know whether the Zenodo-based data can be used in-package?
- Stage 2 answer: yes, maintainer reviewed on 2026-05-08. The implementation covers fit, residual behavior, residual structure, allocation fidelity, and the Zenodo redistribution/data-package decision. `validate_flow_residual_structure()` is stable public API; optional diagnostic plots remain inside validation helpers for now; `sf`-aware cartographic support is deferred; empirical MSOA examples use the optional `debiasRdata` package rather than bundling Zenodo data in `debiasR`.

### Stage 3: Measure Bias

Goal: extend the bias-measurement layer with residual randomness diagnostics linking benchmark population and active-user structure.

Estimated effort: `1-2 days`

Status: `complete; maintainer reviewed`

Tasks:

1. Write the Stage 3 design note before implementation.
- Implemented in `STAGE3_MEASURE_BIAS_DESIGN_NOTE.md`.
- Defined the active-user coverage residual as:
  - `global_coverage_score = sum(user_count) / sum(population)`
  - `expected_user_count = population * global_coverage_score`
  - `user_count_residual = user_count - expected_user_count`
  - `coverage_score_residual = coverage_score - global_coverage_score`
  - `standardized_user_count_residual = user_count_residual / sqrt(expected_user_count)`
  - `population_lm_residual = user_count - fitted(user_count ~ population)`
- Decision: use `coverage_score_residual` as the default diagnostic residual because it is scale-free and has a direct active-user coverage interpretation.
- Decision: implement a separate helper, `validate_bias_residual_structure()`, rather than expanding `measure_bias()`.
- Maintainer review decision: treat `validate_bias_residual_structure()` as stable public API immediately.
- Maintainer review decision: add a simple population-only linear-regression residual option. It fits `user_count ~ population` using the benchmark population column and active-user counts in `coverage_df`, then reports observed minus fitted active-user counts. This is a descriptive diagnostic, not a validated active-user sampling model.
- Maintainer review decision: keep optional `ggplot2` plots inside the diagnostics helper for now because they are optional, dependency-light, and useful for review. Split plotting into separate helpers later only if the plotting surface grows.

2. Add spatial randomness diagnostics.
- Implemented optional global Moran's I from a user-supplied neighbour-link table.
- Reused the Stage 2 neighbour-link interface.
- Returned area-level and map-ready residual data.
- Kept cartographic rendering optional and dependency-light with coordinate-based `ggplot2` output only when requested.

3. Relate bias residuals to benchmark OD flows.
- Implemented benchmark origin-total and destination-total diagnostics as separate outputs.
- Computed Pearson correlations between the selected bias residual and each requested benchmark area-flow total.
- Returned scatter-plot-ready data and optional `ggplot2` scatter plots.

4. Relate bias residuals to a user-selected covariate.
- Mirrored the Stage 2 covariate interface.
- Accepted an area-level covariate table plus explicit area and covariate column names.
- Computed Pearson correlation between the selected bias residual and covariate.
- Returned scatter-plot-ready data and optional `ggplot2` scatter plots.

5. Add tests and documentation.
- Added deterministic tests in `tests/testthat/test-validate-bias-residual-structure.R`.
- Updated `scripts/run_fast_tests.R`.
- Generated `man/validate_bias_residual_structure.Rd` and updated `NAMESPACE`.
- Updated README, NEWS, status notes, test health notes, vignettes, and workflow diagrams.
- Added `STAGE3_IMPLEMENTATION_REPORT.md`.
- Added and rendered `STAGE3_MEASURE_BIAS_REVIEW_NOTEBOOK.qmd`.

Deliverables:

- [x] a Stage 3 design note with a clear residual definition for `measure_bias()`-related diagnostics
- [x] a deterministic bias residual diagnostics helper or a documented extension to `measure_bias()`
- [x] spatial randomness summary and map-ready area data
- [x] benchmark-flow and covariate correlation diagnostics
- [x] focused tests and generated documentation
- [x] a Stage 3 implementation report
- [x] a runnable Stage 3 measure-bias review notebook

Decision gate:

- Are the new bias diagnostics interpretable enough to keep in the main package API rather than only in analysis notes?
- Stage 3 answer: yes, maintainer reviewed on 2026-05-05. The implementation uses deterministic coverage residuals directly linked to `measure_bias()`, includes a simple population-only linear-model residual for diagnostics, reuses the Stage 2 diagnostic interfaces, and keeps optional plotting dependency-light.

### Stage 4: Validation Modelling Extension

Goal: extend the modelling strategy to origin-destination random effects under repeated-observation settings.

Estimated effort: `3-5 days`

Status: `planned`

Working recommendation:

- Start with two separate example datasets, not one unified dataset.
- Reason: this is clearer for users, keeps the two repeated-observation assumptions explicit, makes examples easier to explain, and reduces the risk of one overloaded schema trying to cover two conceptually different designs.
- Revisit a unified internal representation only later if duplication becomes a real maintenance burden.

Tasks:

1. Write a short design note before implementation.
- Compare a two-dataset versus one-dataset approach explicitly.
- Record why the default choice is two datasets unless a strong reason emerges to unify them.
- Keep transparency and user-friendliness as the primary criteria, with computational efficiency secondary.
- Before implementation, explicitly ask which datasets should be used for Stage 4 examples and modelling tests.
- Confirm whether Stage 4 should use simulated data, empirical data, or one of each for the two formulations.

2. Formulation A: repeated observations for an OD pair from a single data source.
- Create a dataset to support this formulation.
- Add level-1 variables needed to control temporal variation.
- Decide what the minimum reproducible example should look like.

3. Formulation B: repeated observations for an OD pair from multiple data sources.
- Create a dataset to support this formulation.
- Add level-1 variables needed to control data-source variation.
- Decide what the minimum reproducible example should look like.

4. Improve modelling flexibility.
- Explore an interface that lets users define the model they want to estimate.
- Keep the modelling API transparent enough that users can see what is being fit.
- Decide how much formula freedom is realistic without making the function too opaque or fragile.

5. Validate the user-facing design.
- Compare whether two separate datasets really do improve transparency and onboarding.
- Check whether a single internal helper could still support both examples without exposing unnecessary complexity.

Deliverables:

- a written modelling design note
- one example dataset for single-source repeated OD observations
- one example dataset for multi-source repeated OD observations
- a recommendation on flexible model specification

Decision gate:

- Do two separate datasets remain the clearest path for users after we draft the examples, or is there a strong enough maintenance case to justify a unified structure?
