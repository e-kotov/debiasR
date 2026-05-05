# Validation Design Note: Distributional Metrics

Last updated: 2026-04-25

## Purpose

This note defines a distributional validation layer for mobility redistribution tasks where the key question is not only whether adjusted estimates are close in magnitude to a benchmark, but whether they preserve a plausible **spatial allocation** of mobility across areas.

The immediate focus is on two related metrics:

1. Kullback-Leibler divergence (`KL`)
2. Jensen-Shannon divergence (`JSD`)

These should be treated as **distribution-preservation metrics**, not as replacements for scale-sensitive fit metrics.

## Core Validation Question

For a fixed origin, do the model-adjusted mobility estimates reproduce the benchmark spatial distribution of mobility across destination areas?

This matters especially when:

- a total flow is known or constrained
- the substantive task is to **redistribute** mobility across subnational units
- the main modelling risk is not just wrong totals, but implausible allocation of mass across space

## Evaluation Setup

For each origin area `i`, let:

- `b_ij` be the benchmark mobility flow from origin `i` to destination `j`
- `m_ij` be the model-adjusted mobility flow from origin `i` to destination `j`

Define origin-normalized benchmark and model shares:

- `P_ij = b_ij / sum_j b_ij`
- `Q_ij = m_ij / sum_j m_ij`

where the sum is taken over all candidate destination areas `j` for a given origin `i`.

Interpretation:

- `P_i` is the benchmark destination distribution for origin `i`
- `Q_i` is the model-implied destination distribution for origin `i`

These are probability distributions over destinations, conditional on origin.

## Metric 1: Kullback-Leibler Divergence

Use the benchmark distribution as the reference:

`KL(P_i || Q_i) = sum_j P_ij * log(P_ij / Q_ij)`

Interpretation:

- `0` means the model and benchmark distributions are identical for origin `i`
- larger values mean the model allocation diverges more from the benchmark allocation
- this metric is directional: it measures information loss when the model distribution is used in place of the benchmark distribution

Why it is useful here:

- it directly evaluates whether the benchmark allocation is preserved
- it penalizes misplaced mass across destinations
- it is well matched to redistribution problems where the spatial share pattern is the object of interest

Important caveats:

1. It is not symmetric.
2. It is undefined if `Q_ij = 0` where `P_ij > 0`.
3. It is sensitive to tail probabilities and sparse allocation patterns.
4. It does not capture geographic proximity between destinations.

Recommended implementation choice:

- use `KL(benchmark || model)` only
- document explicitly that the benchmark distribution is the reference distribution

## Metric 2: Jensen-Shannon Divergence

Define the midpoint distribution:

- `M_i = 0.5 * (P_i + Q_i)`

Then define:

`JSD(P_i, Q_i) = 0.5 * KL(P_i || M_i) + 0.5 * KL(Q_i || M_i)`

Interpretation:

- `0` means the two distributions are identical
- larger values mean greater distributional disagreement
- unlike KL, this metric is symmetric

Why include it:

- more stable than raw KL
- easier to compare across models
- handles asymmetry concerns cleanly
- often easier to communicate in validation summaries

Recommended role:

- include `JSD` alongside `KL`
- use `KL` as the benchmark-referenced directional metric
- use `JSD` as the symmetric robustness check and more communication-friendly summary

## Zero Handling And Smoothing

Both metrics require care when some destination shares are zero.

Recommended implementation:

1. Construct the full destination support for each origin before normalization.
2. Add a small smoothing constant `epsilon > 0` to both benchmark and model destination counts before converting to shares.
3. Renormalize after smoothing.

Suggested default:

- `epsilon = 1e-8`

Rationale:

- prevents undefined log terms
- keeps the smoothing negligible relative to meaningful flows
- makes implementation deterministic and reproducible

Implementation note:

- the value of `epsilon` should be user-configurable but defaulted
- the chosen default should be documented clearly

## Aggregation Strategy

These metrics should first be computed at the **origin level**.

For each origin `i`, return:

- `kl_origin`
- `jsd_origin`
- `n_destinations`
- optional total benchmark and model flow for context

Then summarize across origins by method using:

- mean
- median
- weighted mean, with optional weights based on benchmark origin totals
- distribution plots or quantile summaries

Recommended default reporting:

1. unweighted median by method
2. unweighted mean by method
3. weighted mean by benchmark origin total

Rationale:

- median is robust to extreme origins
- mean captures overall distortion
- weighted mean reflects the importance of large-origin mobility systems

## Interpretation Guidance

These metrics should be framed as:

- **distributional allocation metrics**
- not total-error metrics
- not direct spatial autocorrelation metrics

Suggested interpretation:

- lower `KL` and lower `JSD` indicate better preservation of benchmark spatial allocation
- a method may score well on correlation or RMSE while still performing poorly on `KL`/`JSD` if it gets the broad scale right but allocates mass implausibly across destinations

## What These Metrics Do Not Capture

1. Total scale mismatch after normalization
- once distributions are normalized to shares, total flow magnitude is removed

2. Geographic closeness
- reallocating mass to a neighboring destination and to a far-away destination can be penalized similarly if only shares are used

3. Residual spatial structure
- Moran's I or related diagnostics are still needed for residual randomness analysis

Therefore, `KL` and `JSD` should be used together with:

- scale-sensitive fit metrics
- residual diagnostics
- spatial randomness diagnostics

## Recommended Package Role

Add both metrics to the validation stage as origin-conditioned distributional diagnostics.

Recommended naming:

- `validate_flow_distribution()` if implemented as a dedicated helper
- or as a component inside a broader residual/distribution validation function

Recommended outputs by method:

- origin-level `KL`
- origin-level `JSD`
- summary table by method
- optional density or boxplot-ready output

## Implementation Spec: `validate_flow_distribution()`

### Purpose

`validate_flow_distribution()` should evaluate whether adjusted OD flows preserve the benchmark **destination-share distribution by origin**.

It should answer:

- for each origin, how different is the model-implied allocation across destinations from the benchmark allocation?
- across methods, which adjustments best preserve plausible spatial allocation?

### Proposed Function Signature

```r
validate_flow_distribution <- function(
  adj_df,
  benchmark_od_df,
  flow_col_adj = "flow_adj",
  flow_col_bench = "flow",
  epsilon = 1e-8,
  method_name = NA_character_,
  weight_by = c("none", "benchmark_origin_total"),
  return_origin_level = TRUE
)
```

### Required Inputs

`adj_df` must contain:

- `origin`
- `destination`
- adjusted flow column, default `flow_adj`

`benchmark_od_df` must contain:

- `origin`
- `destination`
- benchmark flow column, default `flow`

Optional:

- `mpd_source` may be carried through if useful for grouped comparisons later, but it does not need to be required in the first implementation.

### Preprocessing Steps

For each origin:

1. Join adjusted and benchmark flows on `origin` and `destination`.
2. Build the full destination support for that origin from the union of:
- destinations present in benchmark
- destinations present in adjusted output
3. Replace missing flows with `0`.
4. Add `epsilon` to both benchmark and adjusted flows.
5. Renormalize to produce:
- `p_share_bench`
- `q_share_adj`

### Origin-Level Metrics

For each origin `i`, compute:

1. `kl_origin`
- `sum_j p_ij * log(p_ij / q_ij)`

2. `jsd_origin`
- with midpoint `m_ij = 0.5 * (p_ij + q_ij)`
- `0.5 * sum_j p_ij * log(p_ij / m_ij) + 0.5 * sum_j q_ij * log(q_ij / m_ij)`

3. Context fields:
- `n_destinations`
- `bench_origin_total`
- `adj_origin_total`
- `method`

### Summary Outputs

The function should return a list with:

1. `summary`
- one-row tibble (or one row per method if batched later) with:
  - `method`
  - `n_origins`
  - `kl_mean`
  - `kl_median`
  - `kl_weighted_mean`
  - `jsd_mean`
  - `jsd_median`
  - `jsd_weighted_mean`

2. `origin_level`
- tibble with one row per origin if `return_origin_level = TRUE`

Recommended weights for weighted means:

- benchmark origin total

### Interpretation Rules

The function docs should state clearly:

- lower `KL` means the adjusted destination distribution is closer to the benchmark distribution
- lower `JSD` means the two distributions are more similar
- these metrics assess allocation fidelity, not total-scale accuracy

### First-Version Scope

The first implementation should:

- work for one adjusted method at a time
- operate at the origin-conditioned distribution level
- return tidy summary and origin-level outputs
- avoid plotting inside the function

Plotting can come later in a companion helper or vignette workflow.

### Edge Cases To Handle

1. Origins with zero benchmark totals
- either drop with a clear rule
- or return `NA` and exclude from summary

2. Origins with zero adjusted totals
- smoothing should prevent undefined logs, but these origins should still be flagged in the origin-level output

3. Single-destination origins
- still valid, but interpret with care

4. Missing overlap in support
- handled by union-of-destinations plus zero fill before smoothing

### Test Plan

Minimum tests for a first implementation:

1. identical benchmark and adjusted distributions give `KL = 0` and `JSD = 0`
2. origin-level support union works when one side has missing destinations
3. zero flows do not break the function because of smoothing
4. weighted summaries use benchmark origin totals correctly
5. summary output contains the expected columns

### Relationship To Other Validation Helpers

This helper should complement, not replace:

- `validate_flow_overall()` / global fit summaries
- residual-based diagnostics
- spatial randomness diagnostics

Recommended role in the validation stack:

- `validate_flow_overall()` for aggregate fit
- `validate_flow_pairs()` or residual helper for OD-level fit structure
- `validate_flow_distribution()` for origin-conditioned spatial allocation fidelity
- residual randomness helper for spatial residual structure

## Suggested Task Board Wording

To add this to the Stage 2 validation work:

1. Add a distributional allocation diagnostic.
- Compute benchmark-versus-model destination shares by origin.
- Add `KL(benchmark || model)` as a directional allocation-fidelity metric.
- Add Jensen-Shannon divergence as a symmetric and more stable companion metric.
- Decide on smoothing, support definition, and weighted versus unweighted summaries.

2. Add interpretation guidance.
- Document that these metrics assess preservation of spatial allocation rather than total scale.
- Keep them alongside residual, correlation, and spatial-randomness diagnostics.

## Recommendation

Yes, these metrics are worth adding.

Recommended final position:

- use `KL(benchmark || model)` as the benchmark-referenced distributional metric
- also include `JSD` as the symmetric robustness metric
- do not use either as the sole validation criterion
- embed both in a broader Stage 2 validation layer that also includes magnitude and residual diagnostics
