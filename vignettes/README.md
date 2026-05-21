# debiasR Training Workshop

This folder contains the eight-part tutorial sequence for illustrating the
package workflow.

The running example is the empirical MSOA travel-to-work workflow from
`debiasRdata`. Vignettes load `msoa_OD_travel2work` as the observed
mobile-phone-derived OD matrix and `census_msoa_OD_travel2work` as the Census
benchmark OD matrix via `debiasR::debiasR_example_data()`.

The main method demonstrations request `complete_grid = TRUE` so the MPD and
benchmark OD matrices share strict square support. Adjustment is presented as a
menu of methods with different data requirements, assumptions, advantages, and
limitations. `adjust_multilevel_bayes()` is treated as the main methodological
innovation, with empirical rendering conditional on Bayesian dependencies and
real OD distance being available.

## Structure

1. `01-landing-page.qmd`
2. `02-why-this-matters.qmd`
3. `03-getting-set-up.qmd`
4. `04-measuring-coverage-bias.qmd`
5. `05-identifying-and-explaining-bias.qmd`
6. `06-adjusting-biases.qmd`
7. `07-validation.qmd`
8. `08-data.qmd`

Supporting materials belong in:

- `data/README.md`
- `figures/README.md`
- `exercises/README.md`

Longer method-testing notebooks live in `testing/`, including
`testing/empirical-methods-walkthrough.qmd`.
