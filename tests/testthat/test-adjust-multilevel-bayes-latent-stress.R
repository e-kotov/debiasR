source(testthat::test_path("helper-multilevel-scenarios.R"))

expect_latent_stress_diagnostics <- function(res,
                                             max_divergence_rate = 0.10,
                                             max_treedepth_hit_rate = 0.10) {
  diagnostics <- attr(res, "diagnostics")
  expect_equal(diagnostics$backend, "stan_latent")
  expect_equal(diagnostics$convergence$status, "available")
  expect_gt(diagnostics$convergence$n_post_warmup_draws, 0)
  expect_true(is.finite(diagnostics$convergence$divergence_rate))
  expect_true(is.finite(diagnostics$convergence$treedepth_hit_rate))
  expect_lte(diagnostics$convergence$divergence_rate, max_divergence_rate)
  expect_lte(diagnostics$convergence$treedepth_hit_rate, max_treedepth_hit_rate)
  expect_true(is.na(diagnostics$convergence$ebfmi_min) ||
    is.finite(diagnostics$convergence$ebfmi_min))
  expect_equal(diagnostics$posterior_predictive$status, "available")
}

expect_source_invariant_latent_true_flow <- function(res, group_cols) {
  grouped <- split(
    res$flow_true_pred,
    res[group_cols],
    drop = TRUE
  )
  within_group_range <- vapply(
    grouped,
    function(x) max(x, na.rm = TRUE) - min(x, na.rm = TRUE),
    numeric(1)
  )
  scale <- max(abs(res$flow_true_pred), 1, na.rm = TRUE)
  expect_lt(max(within_group_range, na.rm = TRUE), scale * 1e-8)
}

expect_observation_scale_varies <- function(res, group_cols) {
  grouped <- split(
    res$flow_mpd_pred,
    res[group_cols],
    drop = TRUE
  )
  within_group_range <- vapply(
    grouped,
    function(x) max(x, na.rm = TRUE) - min(x, na.rm = TRUE),
    numeric(1)
  )
  expect_gt(max(within_group_range, na.rm = TRUE), 0)
}

test_that("latent Stan stress scope fits a larger S3 repeated-source fixture", {
  skip_if_not_installed("rstan")

  toy <- make_multilevel_msoa_like_scenario(
    n_areas = 4,
    sources = c("operator_a", "operator_b"),
    periods = "2021_q1"
  )

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance,
      bias_formula = ~ bias_e_origin,
      model_engine = "bayesian",
      scenario = "s3",
      source_col = "provider_id",
      time_col = "period_id",
      target_scale = "true_flow",
      observation_model = "latent_two_level",
      coverage_scale = "origin",
      latent_flow_unit = "auto",
      latent_coef_prior_scale = 0.8,
      latent_bias_prior_scale = 0.4,
      latent_intercept_prior_scale = 2,
      latent_state_prior_scale = 0.7,
      latent_source_prior_scale = 0.4,
      latent_time_prior_scale = 0.4,
      latent_phi_prior_rate = 1.1,
      latent_adapt_delta = 0.9,
      latent_max_treedepth = 10,
      latent_rng_eta_max = 18,
      model_family = "poisson",
      flow_adj_summary = "median",
      iter = 80,
      chains = 2,
      seed = 118,
      refresh = 0
    )
  )

  metadata <- attr(res, "result_metadata")

  expect_equal(attr(res, "backend"), "stan_latent")
  expect_equal(attr(res, "stage"), "latent_two_level_experimental")
  expect_equal(attr(res, "latent_flow_unit"), "od")
  expect_equal(metadata$scenario, "s3")
  expect_equal(metadata$n_sources, 2L)
  expect_equal(metadata$n_time_periods, 1L)
  expect_equal(metadata$n_latent_flows, 16L)
  expect_equal(metadata$latent_identifiability$min_observations_per_latent_flow, 2L)
  expect_false(metadata$latent_identifiability$weak_identification_warning)
  expect_equal(metadata$latent_source_effect_layer, "observation")
  expect_equal(metadata$latent_time_effect_layer, "none")
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(all(is.finite(res$flow_true_pred)))
  expect_true(all(is.finite(res$flow_mpd_pred)))
  expect_equal(as.numeric(res$flow_adj), as.numeric(res$flow_true_pred))
  expect_source_invariant_latent_true_flow(res, c("origin", "destination"))
  expect_observation_scale_varies(res, c("origin", "destination"))
  expect_latent_stress_diagnostics(res)
})

test_that("latent Stan stress scope fits S4 source-time complete-grid predictions", {
  skip_if_not_installed("rstan")

  toy <- make_multilevel_msoa_like_scenario(
    n_areas = 4,
    sources = c("operator_a", "operator_b"),
    periods = c("2021_q1", "2021_q2"),
    zero_filled = TRUE
  )

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance,
      bias_formula = ~ bias_e_origin,
      model_engine = "bayesian",
      scenario = "s4",
      source_col = "provider_id",
      time_col = "period_id",
      target_scale = "true_flow",
      observation_model = "latent_two_level",
      coverage_scale = "origin",
      latent_flow_unit = "auto",
      latent_coef_prior_scale = 0.8,
      latent_bias_prior_scale = 0.4,
      latent_intercept_prior_scale = 2,
      latent_state_prior_scale = 0.7,
      latent_source_prior_scale = 0.4,
      latent_time_prior_scale = 0.4,
      latent_phi_prior_rate = 1.1,
      latent_adapt_delta = 0.9,
      latent_max_treedepth = 10,
      latent_rng_eta_max = 18,
      model_family = "poisson",
      flow_adj_summary = "median",
      prediction_scope = "complete_grid",
      iter = 80,
      chains = 2,
      seed = 119,
      refresh = 0
    )
  )

  metadata <- attr(res, "result_metadata")
  zero_filled <- res$mpd_zero_filled %in% TRUE

  expect_equal(attr(res, "backend"), "stan_latent")
  expect_equal(attr(res, "stage"), "latent_two_level_experimental")
  expect_equal(attr(res, "latent_flow_unit"), "od_time")
  expect_equal(metadata$scenario, "s4")
  expect_equal(metadata$n_sources, 2L)
  expect_equal(metadata$n_time_periods, 2L)
  expect_equal(metadata$n_latent_flows, 32L)
  expect_equal(metadata$n_zero_filled_prediction_rows, 1L)
  expect_equal(metadata$latent_identifiability$n_unobserved_latent_flows, 0L)
  expect_equal(metadata$latent_identifiability$min_observations_per_latent_flow, 1L)
  expect_false(metadata$latent_identifiability$weak_identification_warning)
  expect_equal(metadata$latent_source_effect_layer, "observation")
  expect_equal(metadata$latent_time_effect_layer, "observation")
  expect_equal(sum(zero_filled), 1L)
  expect_equal(unique(res$model_fit_status[zero_filled]), "predicted")
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(all(is.finite(res$flow_true_pred)))
  expect_true(all(is.finite(res$flow_mpd_pred)))
  expect_true(all(is.finite(res$flow_adj[zero_filled])))
  expect_true(all(is.finite(res$flow_mpd_pred[zero_filled])))
  expect_source_invariant_latent_true_flow(res, c("origin", "destination", "mpd_time"))
  expect_observation_scale_varies(res, c("origin", "destination", "mpd_time"))
  expect_latent_stress_diagnostics(res)
})
