# Migration Map

Last updated: 2026-04-02

## Purpose

This file tracks migration from legacy function/data naming to current package naming.

The tables below are archival references for contributors and reviewers. User-facing docs should prefer the current names only.

## Function Mapping

| Legacy | Current | Status | Notes |
|---|---|---|---|
| `method1_inverse_penetration()` | `adjust_inverse_penetration()` | migrated | same conceptual method |
| `method2_selection_rate()` | `adjust_selection_rate()` | migrated | same conceptual method |
| `method3_selection_rateII()` | `adjust_selection_rate2()` | migrated | suffix simplified |
| `method4_raking_ratio()` | `adjust_raking_ratio()` | migrated | same conceptual method |
| `method5_coefficient()` | `adjust_coefficient()` | migrated | same conceptual method |
| `validate_flows()` | `validate_flow_overall()` | migrated | summary metrics validator |
| `validate_flows()` | `validate_flow_pairs()` | new split | row-level comparison helper |
| `validate_flow_benchmark()` | `validate_flow_overall()` | alias retained | temporary compatibility alias |
| `validate_flow_all()` | `validate_flow_pairs()` | alias retained | temporary compatibility alias |

## Data Object Mapping

| Legacy data object | Current data object | Status |
|---|---|---|
| `toy_mpd_od` | `simulated_mpd.od` | migrated |
| `toy_benchmark_od` | `simulated_benchmark.od` | migrated |
| `toy_coverage_df` | `simulated_coverage` | migrated |
| `toy_covariates_df` | `simulated_covariates` | migrated |
| `toy_aup_df` | `simulated_active.users` | migrated |
| `toy_pop_df` | `simulated_pop` | migrated |
| (none) | `simulated_distance` | added |

## Script and Builder Mapping

| Legacy builder | Current builder | Status |
|---|---|---|
| `data-raw/build_toy_data.R` | `data-raw/build_simulated_data.R` | migrated |
| `data-raw/build_toy_covariates.R` | `data-raw/build_simulated_covariates.R` | migrated |

## Documentation Migration Checklist

- [x] `NAMESPACE` exports new API names.
- [x] New roxygen docs in `man/` exist for `adjust_*` and `validate_flow_*`.
- [x] `README.md` aligned with new API and simulated data naming.
- [x] Non-archival docs now avoid deleted `method*` names.
- [x] Vignettes use current names or clearly label legacy scaffolding.

## Suggested Deprecation Policy

1. Keep migration aliases through the next release cycle to avoid abrupt API churn.
2. Add soft deprecation messaging only after the new names have settled across docs and examples.
3. Remove aliases only after `README.md`, `NEWS.md`, and vignettes have used the new names for a full cycle.
