# Project Status

Last updated: 2026-04-26

## Snapshot

- Project stage: active development (`0.0.0.9000`)
- Package scope: OD mobility bias correction methods + Stage 2 validation toolkit + Stage 3 bias residual diagnostics
- API direction: stable deterministic methods use `adjust_*` and `validate_flow_*`
- Bayesian component: `adjust_multilevel_bayes()` remains a stage-1 prototype only
- Current execution board: see [TASK_BOARD.md](TASK_BOARD.md)

## Stable vs Experimental

### Stable deterministic API

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

### Experimental Bayesian prototype

- `adjust_multilevel_bayes()`
  - stage-1 correction implemented
  - stage-2 missing-OD imputation not implemented yet
  - performance and dependency footprint are heavy relative to deterministic methods
  - backend guidance: prefer `rstanarm` for standard Poisson / negative-binomial models because it is lighter and easier to fit in a package workflow; use `brms` when you need extra flexibility, especially zero-inflated or more complex Bayesian specifications

## What Changed Recently

- Function naming migrated from `method*` to `adjust_*`
- Validation API migrated from `validate_flows()` to `validate_flow_overall()` and `validate_flow_pairs()`, with legacy aliases retained temporarily for compatibility
- Data assets migrated from toy datasets to simulated datasets
- Stable deterministic work is the default support path; Bayesian work is explicitly prototype-only
- CI scaffolding now includes a fast deterministic workflow plus a separate manual Bayesian workflow
- Bias metric updated to:
  - `coverage_bias = 1 - user_count/population`
  - `coverage_score = user_count/population`
- Top-level docs were refreshed to reflect the exported API, simulated datasets, and current repository structure
- Fast deterministic tests passed after replacing the placeholder raking smoke test and removing selection-rate deprecation warnings
- Stage 2 validation now includes residual reduction and outlier summaries, residual-structure diagnostics, optional residual plots, and distributional allocation metrics based on KL divergence and Jensen-Shannon divergence.
- Stage 3 measure-bias diagnostics now include active-user coverage residuals, optional Moran's I, benchmark origin/destination flow correlations, covariate correlations, map-ready data, and optional plots through `validate_bias_residual_structure()`.
- The Zenodo data gate is documented in `DATA_REDISTRIBUTION_DECISION.md`: do not bundle the full record in `debiasR`; use a tiny packaged example plus external download, or a separate optional `debiasRdata` package if empirical packaged data is needed.

## Verification

- Verified on 2026-04-26 with `Rscript scripts/run_fast_tests.R`
- Result: pass
- Notes:
  - deterministic adjustment, Stage 2 validation, and Stage 3 bias residual diagnostics tests passed
  - `test-adjust-coefficient.R` skipped one optional `pscl`-dependent case because `pscl` is not installed
  - Bayesian tests remain outside the fast deterministic tier
  - `devtools::check(document = FALSE, build_args = "--no-build-vignettes", args = c("--no-manual", "--ignore-vignettes"), error_on = "never")` completed with 0 errors, 1 portable-file-name warning for long note/rendered-notebook asset paths, and 2 existing notes about top-level files and Bayesian NSE globals

## Current Risks / Blockers

1. Documentation mismatch risk persists in archival migration materials and older scaffolds.
2. Test suite reliability still depends on using the curated runner rather than raw `test_dir()` calls.
3. Bayesian tests are slower and environment-sensitive due to optional dependencies.
4. CI has been scaffolded but still needs live validation in GitHub Actions after merge.
5. Full cartographic residual maps remain user-supplied because the package deliberately avoids adding an `sf` dependency at this stage.

## Immediate Priorities

1. Review Stage 3 measure-bias design and notebook outputs.
2. Review the Stage 2 validation design and data redistribution decisions.
3. Validate the new GitHub Actions workflows on the next PR.
4. Keep top-level docs synchronized with exported API (`NAMESPACE`).
5. Keep the Bayesian path explicitly scoped as prototype-only until a hardening plan is approved.
