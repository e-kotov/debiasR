#!/usr/bin/env Rscript

fast_test_files <- c(
  "tests/testthat/test-measure_bias.R",
  "tests/testthat/test-validate-bias-residual-structure.R",
  "tests/testthat/test-adjust_inverse_penetration.R",
  "tests/testthat/test-adjust-selection-rate.R",
  "tests/testthat/test-adjust-selection-rate2.R",
  "tests/testthat/test-adjust-raking-ratio.R",
  "tests/testthat/test-adjust-coefficient.R",
  "tests/testthat/test-validate-flow-overall.R",
  "tests/testthat/test-validate-flow-pairs.R",
  "tests/testthat/test-validate-flow-residuals.R",
  "tests/testthat/test-validate-flow-residual-structure.R",
  "tests/testthat/test-validate-flow-distribution.R",
  "tests/testthat/test-adjust_raking_ratio-smoke.R"
)

if (!file.exists("DESCRIPTION")) {
  stop("Run this script from the package root so DESCRIPTION is available.")
}

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("The fast test runner requires the 'devtools' package.")
}

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("The fast test runner requires the 'testthat' package.")
}

devtools::load_all(".", quiet = TRUE)

for (test_file in fast_test_files) {
  message("Running ", test_file)
  testthat::test_file(test_file, reporter = "summary")
}

message("Fast deterministic test tier completed successfully.")
