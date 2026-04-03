# Task Board

Last updated: 2026-04-02

This board turns the current roadmap into a short execution plan. Estimated effort is in rough person-hours.

## Now

1. Lock down testing and CI - `4-6h` - `initial scaffolding implemented`
- Added a fast deterministic test runner script.
- Added a required PR workflow for the fast tier.
- Added an optional/manual workflow for Bayesian checks.
- Updated the documented test command to match the workflow.

2. Finish migration cleanup - `3-5h` - `partially implemented`
- Swept for remaining user-facing `method*`, `validate_flows`, or `toy_*` references.
- Cleaned stale scaffold leftovers in docs and vignettes.
- Updated the migration map to reflect the current package surface.
- Remaining step: validate the new workflows in GitHub Actions and fold any last migration follow-ups back into the docs.

## Next

1. Clarify Bayesian scope - `2-3h`
- Keep `adjust_multilevel_bayes()` explicitly marked as a stage-1 prototype.
- Document the supported backends and the stage-2 imputation gap.
- Make sure the status notes and project brief say the same thing.

2. Close the documentation loop - `2-4h`
- Update README/NEWS only if a final wording mismatch remains.
- Tighten any issue notes that are now stale after the migration.
- Make the task/status docs the single source of truth for current work.

## Later

1. Harden the Bayesian path - `1-2 days`
- Decide whether the prototype should be promoted beyond stage 1.
- Add stronger validation and dependency handling if that happens.
- Split the Bayesian tests into a clear optional CI lane if the scope expands.

2. Prepare a release-ready maintenance pass - `1-2 days`
- Re-run the full package check after the CI and migration work settle.
- Review examples and vignettes for remaining dependency friction.
- Decide whether a tagged pre-release makes sense after stabilization.
