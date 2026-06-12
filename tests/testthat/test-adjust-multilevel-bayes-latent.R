source(testthat::test_path("helper-multilevel-scenarios.R"))

test_that("Bayesian latent two-level backend fits repeated source observations", {
  skip_if_not_installed("rstan")

  toy <- make_multilevel_scenario_toy(
    sources = c("src1", "src2"),
    periods = "t1"
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
      iter = 50,
      chains = 1,
      seed = 918,
      refresh = 0
    )
  )

  metadata <- attr(res, "result_metadata")
  diagnostics <- attr(res, "diagnostics")

  expect_equal(attr(res, "observation_model"), "latent_two_level")
  expect_equal(attr(res, "backend"), "stan_latent")
  expect_equal(attr(res, "stage"), "latent_two_level_experimental")
  expect_equal(attr(res, "latent_flow_unit"), "od")
  expect_true(all(c("latent_flow_id", "latent_flow_unit") %in% names(res)))
  expect_equal(as.numeric(res$flow_adj), as.numeric(res$flow_true_pred))
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(all(is.finite(res$flow_mpd_pred)))
  expect_equal(metadata$n_latent_flows, length(unique(res$latent_flow_id)))
  expect_false(metadata$latent_identifiability$weak_identification_warning)
  expect_equal(metadata$latent_backend_contract, "custom_stan_latent_v0.1")
  expect_equal(metadata$latent_source_effect_layer, "observation")
  expect_equal(metadata$latent_time_effect_layer, "none")
  expect_equal(metadata$latent_controls$latent_coef_prior_scale, 0.8)
  expect_equal(metadata$latent_controls$latent_intercept_prior_scale, 2)
  expect_equal(metadata$latent_controls$latent_phi_prior_rate, 1.1)
  expect_equal(metadata$latent_controls$latent_max_treedepth, 10L)
  expect_equal(diagnostics$convergence$max_treedepth, 10L)
  expect_equal(diagnostics$convergence$adapt_delta, 0.9)
  expect_true(all(c(
    "n_post_warmup_draws",
    "divergence_rate",
    "treedepth_hit_rate",
    "accept_stat_mean",
    "accept_stat_min",
    "ebfmi_min",
    "rhat_max",
    "n_eff_min"
  ) %in% names(diagnostics$convergence)))
  expect_gt(diagnostics$convergence$n_post_warmup_draws, 0)
  expect_equal(diagnostics$posterior_predictive$rng_eta_max, 18)
  expect_match(attr(res, "prototype_notes"), "Latent two-level experimental backend")
})
