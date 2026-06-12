# debiasR package vignettes

This folder contains the package-facing Quarto vignettes for `debiasR`.
They are intended to be built and installed with the package, and should stay
focused on stable user workflows rather than workshop planning, exploratory
method testing, or rendered preview artifacts.

The running examples use the optional `debiasRdata` package at LAD scale by
default. Vignettes call `debiasR::debiasR_example_data()` through `_common.R`
so examples can render with bounded empirical inputs and exit cleanly when the
optional data package is not installed.

## Structure

1. `v02-why-this-matters.qmd`
2. `v03-getting-set-up.qmd`
3. `v04-measuring-coverage-bias.qmd`
4. `v05-identifying-and-explaining-bias.qmd`
5. `v06-adjusting-biases.qmd`
6. `v07-validation.qmd`
7. `v08-data.qmd`
8. `v09-advanced-bayesian-adjustment.qmd`

Supporting package-vignette assets belong in:

- `figures/`
- `data/`
- `exercises/`

Longer workshop, teaching, and method-testing notebooks live outside the
package vignette tree in `notes/workshop/`.

Generated render artifacts such as `.html`, extracted `.R`, `.knit.md`,
`.rmarkdown`, `.quarto/`, `*_files/`, and `.quarto_ipynb` files should not be
committed from this folder.
