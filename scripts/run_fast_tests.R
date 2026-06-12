#!/usr/bin/env Rscript

fast_test_files <- c(
  "tests/testthat/test-measure_bias.R",
  "tests/testthat/test-measure-bias-distribution.R",
  "tests/testthat/test-example-data.R",
  "tests/testthat/test-validate-bias-residual-structure.R",
  "tests/testthat/test-adjust_inverse_penetration.R",
  "tests/testthat/test-adjust-selection-rate.R",
  "tests/testthat/test-adjust-selection-rate2.R",
  "tests/testthat/test-adjust-raking-ratio.R",
  "tests/testthat/test-adjust-coefficient.R",
  "tests/testthat/test-adjust-multilevel-latent-contract.R",
  "tests/testthat/test-adjust-multilevel-frequentist-dev.R",
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

count_test_failures <- function(results) {
  sum(vapply(
    results,
    function(test_result) {
      sum(vapply(
        test_result$results,
        function(expectation) {
          inherits(expectation, "expectation_failure") ||
            inherits(expectation, "expectation_error")
        },
        logical(1)
      ))
    },
    integer(1)
  ))
}

failure_count <- 0L
for (test_file in fast_test_files) {
  message("Running ", test_file)
  result <- testthat::test_file(test_file, reporter = "summary")
  failure_count <- failure_count + count_test_failures(result)
}

if (failure_count > 0L) {
  stop("Fast deterministic test tier failed with ", failure_count, " failure/error expectation(s).")
}

message("Fast deterministic test tier completed successfully.")
