# Stage 3 Measure Bias Design Note

Last updated: 2026-04-26

## Purpose

Stage 3 extends the bias-measurement layer from area-level coverage scores to diagnostics that test whether active-user coverage residuals look spatially random or systematically related to benchmark mobility structure and selected covariates.

The goal is not to adjust flows directly. The goal is to expose interpretable residual structure before adjustment, so users can see where active-user coverage is unusually high or low relative to benchmark population.

## Implemented API

Stage 3 uses a separate exported helper:

- `validate_bias_residual_structure()`

Decision:

- Keep `measure_bias()` as the simple area-level coverage calculator.
- Put residual randomness, benchmark-flow, covariate, and optional plot outputs in a separate helper.

This keeps the existing stable `measure_bias()` output compact while giving the richer diagnostics a list output similar to `validate_flow_residual_structure()`.

## Coverage Residual Definition

The helper starts from the package coverage definitions:

```text
coverage_score_i = user_count_i / population_i
coverage_bias_i = 1 - coverage_score_i
```

It then computes a global active-user coverage score:

```text
global_coverage_score = sum(user_count) / sum(population)
```

The primary Stage 3 residual is:

```text
coverage_score_residual_i = coverage_score_i - global_coverage_score
```

Interpretation:

- positive values mean the area has higher active-user coverage than expected under a constant global coverage rate,
- negative values mean the area has lower active-user coverage than expected under a constant global coverage rate,
- zero means the area matches the global active-user coverage rate.

The helper also returns two companion residuals:

```text
expected_user_count_i = population_i * global_coverage_score
user_count_residual_i = user_count_i - expected_user_count_i
standardized_user_count_residual_i = user_count_residual_i / sqrt(expected_user_count_i)
```

Decision:

- Use `coverage_score_residual` as the default diagnostic residual because it is scale-free and has a direct coverage-rate interpretation.
- Return `user_count_residual` for count-scale interpretation.
- Return `standardized_user_count_residual` as a deterministic Poisson-style scale check, not as a full statistical model.
- Do not add a model-based residual in Stage 3; that would require assumptions about active-user sampling that are not yet part of the package API.

## Spatial Randomness

The helper reuses the Stage 2 neighbour-link interface:

- users may pass a plain area-neighbour table,
- links can be unweighted or use a positive numeric weight column,
- the output reports global Moran's I for the selected bias residual,
- no `sf` or spatial-neighbour dependency is added.

Decision:

- Keep cartographic dependencies outside the package.
- Return map-ready area data and optional coordinate-based `ggplot2` plots when users supply coordinates.

## Benchmark OD Flow Correlation

Benchmark OD flows are collapsed to area level in two ways:

- origin totals: total benchmark outflow from each area,
- destination totals: total benchmark inflow to each area.

The helper reports Pearson correlations between the selected bias residual and each requested benchmark-flow total.

Decision:

- Return origin and destination diagnostics separately by default.
- Treat missing area-flow totals as zero after joining to the coverage areas.

This avoids hiding different interpretations of high-activity origins and high-activity destinations in one combined number.

## Covariate Correlation

The helper mirrors the Stage 2 covariate interface:

- users pass an area-level covariate table,
- the area key and covariate column are explicit arguments,
- the output reports Pearson correlation between the selected bias residual and the selected covariate.

Decision:

- Keep the interface plain-data-frame based.
- Return the joined scatter-plot-ready data so users can inspect leverage and outliers.

## Validation Gate

Stage 3 diagnostics are interpretable enough to keep in the main package API because:

- the residual definition is deterministic and directly linked to `measure_bias()`,
- positive and negative residual signs have clear coverage-rate interpretations,
- the spatial, benchmark-flow, and covariate diagnostics mirror Stage 2 validation patterns,
- optional plotting remains dependency-light and can be ignored in programmatic workflows.

Remaining review question:

- Should future releases add a small model-based residual option once an empirical active-user sampling model is agreed?
