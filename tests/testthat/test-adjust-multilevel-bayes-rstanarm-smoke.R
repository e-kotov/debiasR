source(testthat::test_path("helper-multilevel-scenarios.R"))

test_that("rstanarm Bayesian coverage-offset smoke fits repeated source/time data", {
  skip_if_not_installed("rstanarm")

  toy <- make_multilevel_scenario_toy(
    sources = c("src1", "src2"),
    periods = c("t1", "t2"),
    zero_filled = TRUE
  )

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "bayesian",
      scenario = "s4",
      random_intercept = "none",
      target_scale = "true_flow",
      observation_model = "coverage_offset",
      coverage_scale = "origin",
      model_family = "poisson",
      flow_adj_summary = "median",
      prediction_scope = "complete_grid",
      iter = 30,
      chains = 1,
      seed = 804,
      refresh = 0
    )
  )

  expect_equal(attr(res, "backend"), "rstanarm")
  expect_equal(attr(res, "scenario"), "s4")
  expect_equal(attr(res, "repeated_observation"), "source_time")
  expect_equal(attr(res, "observation_model"), "coverage_offset")
  expect_equal(as.numeric(res$flow_adj), as.numeric(res$flow_true_pred))
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(any(res$mpd_zero_filled))
})
