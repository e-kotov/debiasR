# debiasR Project Brief (April 2, 2026)

## 1) Project Aim

`debiasR` is an R package that develops and operationalises methods to correct biases in mobile-phone-derived origin-destination (OD) mobility flows, so corrected flows are closer to benchmark population and migration/mobility statistics and can be used more reliably in research and policy settings.

## 2) Project Objectives

1. Provide a suite of transparent bias-adjustment methods for OD flow correction.
2. Offer a consistent validation framework to compare adjusted outputs against benchmark OD flows.
3. Supply simulated datasets and walkthrough vignettes so methods can be tested and compared reproducibly.
4. Advance from deterministic/statistical adjustment methods to a Bayesian multilevel framework (currently prototype stage).
5. Support reproducible package development with tests, documentation, and vignettes.

## 3) Current Workflow (Practical)

The package currently supports this working sequence:

1. Load data:
- MPD OD flows (`simulated_mpd.od` or user data),
- coverage inputs (`population`, `user_count`),
- optional covariates and distance,
- benchmark OD flows for calibration/validation.

2. Measure coverage bias:
- `measure_bias()` computes:
  - `coverage_score = user_count / population`
  - `coverage_bias = 1 - coverage_score`

3. Adjust flows with one or more methods:
- `adjust_inverse_penetration()`
- `adjust_selection_rate()`
- `adjust_selection_rate2()`
- `adjust_raking_ratio()`
- `adjust_coefficient()`
- `adjust_multilevel_bayes()` (stage-1 Bayesian prototype only)

4. Validate outputs:
- `validate_flow_overall()` for summary metrics (correlation/error/regression diagnostics),
- `validate_flow_pairs()` for row-level joined comparison table.

5. Compare methods and inspect fit:
- Use `vignettes/simulated-methods-walkthrough.qmd` and related vignette material to compare model behavior and benchmark alignment.

The deterministic methods above are the default support path. Bayesian work remains separate and experimental until stage-2 imputation and dependency/runtime expectations are clearly defined.

## 4) Summary of Latest Updates

Based on local code, changelog, and recent commits:

1. API transition is underway:
- Old `method*` function naming has been replaced with `adjust_*` names.
- Validation has moved from `validate_flows()` to:
  - `validate_flow_overall()`
  - `validate_flow_pairs()`
- `NEWS.md` documents this breaking change.

2. Bias definition update:
- Latest commit (`dc4401f`, 2026-02-13) redefines `measure_bias` to use:
  - `coverage_bias = 1 - user_count/population`
  - while retaining `coverage_score` and backward-compatible `bias`.

3. Dataset migration:
- Toy datasets and builders were replaced by simulated datasets and new build scripts:
  - `data-raw/build_simulated_data.R`
  - `data-raw/build_simulated_covariates.R`

4. Bayesian pathway expanded:
- `adjust_multilevel_bayes()` added as stage-1 prototype.
- Vignettes and notes explicitly state stage-2 missing-OD imputation is not yet implemented.

5. Documentation/testing actively evolving:
- New vignettes for method walkthrough/comparison added.
- Tests for new `adjust_*` and validation functions are present.
- Repository currently shows a large in-progress transition in the working tree (many renames/deletions/additions not yet consolidated).

## 5) Where We Are Right Now

Current project status appears to be:

1. **Method portfolio:** Strong and broad for deterministic/statistical corrections; Bayesian method available but still prototype.
2. **Architecture:** Mid-migration from old API/data naming to new naming and simulated data.
3. **Documentation quality:** Good conceptual depth in vignettes/notes, but some top-level docs are still lagging behind code changes.
4. **Testing maturity:** Partial; core tests exist, but suite reliability is mixed and includes environment-sensitive behavior (especially Bayesian dependencies and package-loading assumptions).
5. **Release readiness:** Not CRAN-ready yet (`Version: 0.0.0.9000`) and still in active development/refactoring mode.

## 6) Additional Information That Would Be Useful

### A) For future development and fast comprehensive onboarding

1. **Single source of truth for method catalog**
- A table mapping each method to:
  - assumptions,
  - required inputs,
  - calibration parameters,
  - outputs,
  - known limitations.

2. **Stability roadmap**
- Explicit milestones for:
  - API freeze (`adjust_*`, `validate_flow_*`),
  - data object naming freeze,
  - deprecation removal timing.

3. **Benchmarking protocol**
- Standard experiment design and reporting template:
  - train/validation splits (if relevant),
  - metrics,
  - acceptance thresholds,
  - reproducible seeds and scenarios.

4. **Dependency/compute profile**
- Clear guidance on heavy dependencies (`rstanarm`, `brms`) and expected runtime to aid users and CI setup.
- Current recommendation for the Bayesian stage-1 model:
  - prefer `rstanarm` as the default backend for standard Poisson / negative-binomial models because it is lighter, uses precompiled Stan code, and is usually simpler to fit and troubleshoot in a package workflow;
  - use `brms` when the model needs additional flexibility, especially zero-inflated families or more complex formula-based extensions.
- This keeps the current prototype practical while preserving an upgrade path for richer Bayesian specifications later.

5. **Decision log**
- Short ADR-style notes capturing why key modelling choices were made (e.g., bias definition change, calibration loss choices).

### B) For you to quickly understand current progress at any time

1. **Current status dashboard (lightweight markdown)**
- Last updated date,
- what is stable vs experimental,
- key blockers,
- immediate next tasks.

2. **Test health summary**
- Which tests are deterministic and should always pass,
- which are optional/slow/model-dependent,
- current pass/fail trend.

3. **Migration checklist**
- Old-to-new function mapping,
- old-to-new dataset mapping,
- docs/tests/vignettes updated vs pending.

4. **Known issues list**
- One page with current inconsistencies (README/NEWS/API/tests) and owner/target date for each fix.

## 7) Recommended Immediate Next Actions

1. Validate the new fast deterministic GitHub Actions workflow on the next PR.
2. Run the manual Bayesian workflow once in GitHub Actions and record any hosted-runner dependency issues.
3. Keep top-level docs synchronized with the exported API and the task board.
4. Use [notes/project-management/TASK_BOARD.md](notes/project-management/TASK_BOARD.md) as the execution order for remaining stabilization work.

## 8) Execution Board

The current work is organized as a small execution board:

### Now

- Lock down testing and CI.
- Finish migration cleanup.

### Next

- Clarify Bayesian scope.
- Close the documentation loop.

### Later

- Harden the Bayesian path.
- Prepare a release-ready maintenance pass.

See [notes/project-management/TASK_BOARD.md](notes/project-management/TASK_BOARD.md) for the effort estimates and concrete deliverables.
