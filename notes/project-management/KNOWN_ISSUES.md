# Known Issues

Last updated: 2026-04-02

## High Priority

1. API/docs drift during migration
- Description: most user-facing docs are aligned, but the migration map still documents the legacy names for reference and a few older scaffold files remain in the repo.
- Impact: minor onboarding friction if contributors land on archival materials first.
- Suggested fix: keep top-level docs pointed at the current API and clearly label archival migration references.

2. Test execution context sensitivity
- Description: running tests without first loading package context can cause false negatives.
- Impact: unreliable signal in local and CI usage.
- Suggested fix: keep contributors and CI on `Rscript scripts/run_fast_tests.R` for the fast tier, and reserve raw `test_dir()` runs for explicit development/debugging.

3. Prototype Bayesian pathway not clearly bounded in all docs
- Description: `adjust_multilevel_bayes()` is stage-1 only; stage-2 imputation pending.
- Impact: users may over-interpret readiness/scope.
- Suggested fix: keep the README and status page explicit that the Bayesian path is experimental.

## Medium Priority

1. Bayesian CI lane is still unproven in GitHub Actions
- Description: a manual Bayesian workflow now exists, but it has not yet been validated on the hosted runner.
- Impact: dependency/runtime surprises may still show up the first time it is used remotely.
- Suggested fix: run the manual workflow once after merge and record any environment fixes that are needed.

2. Working tree transition volume
- Description: the large migration has landed, but archival notes and older scaffolds still need occasional cleanup.
- Impact: some review and onboarding friction remains.
- Suggested fix: keep follow-up cleanup small and focused, using the task board to prioritize only active work.

3. README structure section is not fully descriptive
- Description: top-level docs are much better aligned now, but they still need periodic checks against the exported API and workflow files.
- Impact: drift could reappear as new methods or notes are added.
- Suggested fix: review README/CONTRIBUTING/STATUS whenever exported functions or CI entry points change.

## Low Priority

1. Locale warnings in tests (`LC_ALL='C.UTF-8'`)
- Description: repeated non-fatal warnings appear during test runs.
- Impact: noisy logs.
- Suggested fix: normalize locale settings in CI or suppress non-essential locale changes in tests.

## Issue Tracking Template

Use this mini template for each issue:

- Issue:
- Owner:
- Priority:
- First observed:
- Affected files:
- Decision:
- Target resolution date:
- Status:
