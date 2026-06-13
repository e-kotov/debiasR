#!/usr/bin/env Rscript

if (!file.exists("DESCRIPTION")) {
  stop("Run this script from the package root so DESCRIPTION is available.")
}

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("The Bayesian test runner requires the 'devtools' package.")
}

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("The Bayesian test runner requires the 'testthat' package.")
}

options(mc.cores = 1)
Sys.setenv(RSTAN_NUM_THREADS = "1")

args <- commandArgs(trailingOnly = TRUE)
scope <- Sys.getenv("DEBIASR_BAYESIAN_SCOPE", unset = NA_character_)
if (is.na(scope) || !nzchar(scope)) {
  scope <- Sys.getenv("DEBIASR_BAYESIAN_TEST_MODE", unset = NA_character_)
}
if (is.na(scope) || !nzchar(scope)) {
  scope <- if (length(args) >= 1L) args[[1]] else "smoke"
}
scope <- match.arg(
  scope,
  choices = c(
    "smoke",
    "rstanarm-smoke",
    "rstanarm",
    "latent-smoke",
    "latent-stress",
    "standard",
    "latent",
    "all"
  )
)
scope <- switch(
  scope,
  standard = "rstanarm-smoke",
  latent = "latent-smoke",
  smoke = "smoke",
  scope
)

if (scope %in% c("smoke", "rstanarm-smoke", "rstanarm", "all") &&
    !requireNamespace("rstanarm", quietly = TRUE)) {
  stop("The rstanarm Bayesian test scope requires the optional 'rstanarm' package.")
}

if (scope %in% c("smoke", "latent-smoke", "latent-stress", "all") &&
    !requireNamespace("rstan", quietly = TRUE)) {
  stop("The latent Bayesian test scope requires the optional 'rstan' package.")
}

start_time <- Sys.time()
message("Bayesian test run started at ", format(start_time, "%Y-%m-%d %H:%M:%S %Z"))
message("R version: ", getRversion())
message("testthat version: ", as.character(utils::packageVersion("testthat")))
if (requireNamespace("rstanarm", quietly = TRUE)) {
  message("rstanarm version: ", as.character(utils::packageVersion("rstanarm")))
}
if (requireNamespace("rstan", quietly = TRUE)) {
  message("rstan version: ", as.character(utils::packageVersion("rstan")))
}
message("Bayesian test scope: ", scope)
message("Loading debiasR package context with devtools::load_all().")

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

test_files <- switch(
  scope,
  smoke = file.path(
    "tests",
    "testthat",
    c(
      "test-adjust-multilevel-bayes-rstanarm-smoke.R",
      "test-adjust-multilevel-bayes-latent.R"
    )
  ),
  `rstanarm-smoke` = file.path("tests", "testthat", "test-adjust-multilevel-bayes-rstanarm-smoke.R"),
  rstanarm = file.path("tests", "testthat", "test-adjust-multilevel-bayes.R"),
  `latent-smoke` = file.path("tests", "testthat", "test-adjust-multilevel-bayes-latent.R"),
  `latent-stress` = file.path("tests", "testthat", "test-adjust-multilevel-bayes-latent-stress.R"),
  all = file.path(
    "tests",
    "testthat",
    c(
      "test-adjust-multilevel-bayes-rstanarm-smoke.R",
      "test-adjust-multilevel-bayes.R",
      "test-adjust-multilevel-bayes-latent.R",
      "test-adjust-multilevel-bayes-latent-stress.R"
    )
  )
)

failure_count <- 0L
for (test_file in test_files) {
  message("Running ", test_file)
  result <- testthat::test_file(test_file, reporter = "summary")
  failure_count <- failure_count + count_test_failures(result)
}

if (failure_count > 0L) {
  stop("Bayesian test scope failed with ", failure_count, " failure/error expectation(s).")
}

end_time <- Sys.time()
message("Bayesian test run finished at ", format(end_time, "%Y-%m-%d %H:%M:%S %Z"))
message(
  "Elapsed time: ",
  round(as.numeric(difftime(end_time, start_time, units = "secs")), 1),
  " seconds"
)
