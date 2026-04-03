# debiasR NEWS

## 0.0.0.9000

### Breaking changes

- The validation API now uses `validate_flow_benchmark()` for summary metrics and `validate_flow_all()` for row-level comparisons.
- The legacy `validate_flows()` helper has been removed.

### Migration notes

- Package documentation and onboarding now refer to `adjust_*` functions and `simulated_*` datasets consistently.
