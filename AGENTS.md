# debiasR Codex Instructions

Purpose:
- keep project-specific guidance close to the repository
- reduce repeated setup and task-board discovery work
- protect in-progress migration and documentation edits

Project scope:
- `debiasR` is an R package for origin-destination mobility bias correction and validation.
- Stable deterministic helpers use the `adjust_*` and `validate_flow_*` naming pattern.
- `adjust_multilevel_bayes()` is an experimental stage-1 prototype unless the task board says otherwise.

Before substantial work:
- Read `notes/project-management/TASK_BOARD.md` and `notes/project-management/STATUS.md`.
- Check `git status --short` and avoid overwriting unrelated modified or untracked files.
- If the task touches validation, also check relevant notes in `notes/project-management/`.

Coding defaults:
- Prefer existing package patterns in `R/`, `tests/testthat/`, and roxygen documentation.
- Keep patches narrow and traceable.
- Add or update focused tests for new exported behavior.
- Update `NAMESPACE` and generated `man/` docs when exports or roxygen docs change.

Validation:
- Use the existing `validate_flow_*` API style.
- Keep validation functions deterministic and tidy-output friendly.
- Document metric interpretation clearly, especially sign conventions and scale.

Testing:
- Prefer the curated fast deterministic test runner when validating broad changes:
  `Rscript scripts/run_fast_tests.R`
- For narrow validation changes, targeted `testthat` runs are acceptable before the full fast tier.

Documentation:
- Keep README, NEWS, status notes, and task board synchronized when user-facing scope changes.
- Do not treat older migration notes as the current source of truth when `STATUS.md` or `TASK_BOARD.md` disagree.
