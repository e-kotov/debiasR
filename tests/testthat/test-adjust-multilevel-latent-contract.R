source(testthat::test_path("helper-multilevel-scenarios.R"))

test_that("latent backend routing uses custom backend while standard modes keep existing routing", {
  expect_equal(
    debiasR:::.resolve_multilevel_backend("poisson", "auto", "reduced_form"),
    "rstanarm"
  )
  expect_equal(
    debiasR:::.resolve_multilevel_backend("negbin", "auto", "coverage_offset"),
    "rstanarm"
  )
  expect_equal(
    debiasR:::.resolve_multilevel_backend("zip", "auto", "reduced_form"),
    "brms"
  )
  expect_equal(
    debiasR:::.resolve_multilevel_backend("poisson", "auto", "latent_two_level"),
    "stan_latent"
  )
  expect_equal(
    debiasR:::.resolve_multilevel_backend("poisson", "stan_latent", "latent_two_level"),
    "stan_latent"
  )
  expect_error(
    debiasR:::.resolve_multilevel_backend("zip", "auto", "latent_two_level"),
    "currently supports"
  )
  expect_error(
    debiasR:::.resolve_multilevel_backend("poisson", "rstanarm", "latent_two_level"),
    "requires `backend = 'stan_latent'`"
  )
})

test_that("latent-state keys are source-invariant across S1-S4 scenarios", {
  scenarios <- list(
    s1 = list(sources = "src1", periods = "t1", expected_unit = "od", expected_n = 9L, weak = TRUE),
    s2 = list(sources = "src1", periods = c("t1", "t2"), expected_unit = "od_time", expected_n = 18L, weak = TRUE),
    s3 = list(sources = c("src1", "src2"), periods = "t1", expected_unit = "od", expected_n = 9L, weak = FALSE),
    s4 = list(sources = c("src1", "src2"), periods = c("t1", "t2"), expected_unit = "od_time", expected_n = 18L, weak = FALSE)
  )

  for (scenario in names(scenarios)) {
    spec <- scenarios[[scenario]]
    toy <- make_multilevel_scenario_toy(
      sources = spec$sources,
      periods = spec$periods
    )
    scenario_info <- debiasR:::.resolve_multilevel_scenario(
      toy$mpd_od,
      scenario = scenario
    )
    prep <- debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      flow_col = "flow",
      income_col = "income_norm",
      pop_col = "population",
      distance_col = "distance_km",
      scenario_info = scenario_info
    )
    latent <- suppressWarnings(
      debiasR:::.prepare_multilevel_latent_state(
        data = prep$model_df,
        scenario_info = scenario_info,
        latent_flow_unit = "auto"
      )
    )

    expect_equal(latent$latent_flow_unit, spec$expected_unit, info = scenario)
    expect_equal(latent$n_latent_flows, spec$expected_n, info = scenario)
    expect_equal(
      latent$identifiability$weak_identification_warning,
      spec$weak,
      info = scenario
    )

    if (scenario %in% c("s3", "s4")) {
      grouped <- split(latent$data$latent_flow_id, latent$data[c("origin", "destination", if (scenario == "s4") "mpd_time")], drop = TRUE)
      expect_true(
        all(vapply(grouped, function(x) length(unique(as.character(x))) == 1L, logical(1))),
        info = scenario
      )
    }
  }
})

test_that("latent formula partitioning separates true-flow and observation layers", {
  info <- debiasR:::.resolve_multilevel_user_formula(
    mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance + (1 | origin),
    bias_formula = ~ bias_e_origin + (1 | mpd_source)
  )
  expect_warning(
    latent_formula <- debiasR:::.build_multilevel_latent_formula_info(
      formula_info = info,
      default_covariate_col = NULL,
      include_pop_terms = FALSE
    ),
    "Random-effect terms"
  )

  expect_equal(
    paste(deparse(latent_formula$true_formula), collapse = " "),
    "~rural_pct_o + rural_pct_d + log_distance"
  )
  expect_equal(
    paste(deparse(latent_formula$observation_formula), collapse = " "),
    "~bias_e_origin - 1"
  )
  expect_equal(
    latent_formula$mobility_variables,
    c("rural_pct_o", "rural_pct_d", "log_distance")
  )
  expect_equal(latent_formula$bias_variables, "bias_e_origin")
  expect_equal(
    latent_formula$ignored_random_effect_terms,
    c("(1 | origin)", "(1 | mpd_source)")
  )

  combined <- debiasR:::.resolve_multilevel_user_formula(
    formula = flow ~ rural_pct_o + bias_e_origin
  )
  expect_error(
    debiasR:::.build_multilevel_latent_formula_info(combined, NULL, FALSE),
    "needs separate true-flow and observation-bias formulas"
  )
})

test_that("latent Stan data contract records state, formula, and prediction dimensions", {
  toy <- make_multilevel_scenario_toy(
    sources = c("src1", "src2"),
    periods = c("t1", "t2"),
    zero_filled = TRUE
  )
  scenario_info <- debiasR:::.resolve_multilevel_scenario(
    toy$mpd_od,
    scenario = "s4"
  )
  prep <- debiasR:::.prepare_multilevel_bayes_data(
    mpd_od_df = toy$mpd_od,
    coverage_df = toy$coverage,
    covariates_df = toy$covariates,
    distance_df = toy$distance,
    flow_col = "flow",
    income_col = "income_norm",
    pop_col = "population",
    distance_col = "distance_km",
    scenario_info = scenario_info
  )
  latent <- debiasR:::.prepare_multilevel_latent_state(
    data = prep$model_df,
    scenario_info = scenario_info,
    latent_flow_unit = "auto"
  )
  prediction_df <- debiasR:::.set_multilevel_observation_probability(
    latent$data,
    coverage_scale = "origin"
  )
  fit_df <- prediction_df[prediction_df$mpd_observed, , drop = FALSE]
  formula_info <- debiasR:::.resolve_multilevel_user_formula(
    mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance,
    bias_formula = ~ bias_e_origin
  )
  latent_formula <- debiasR:::.build_multilevel_latent_formula_info(
    formula_info,
    prep$default_covariate_col,
    prep$has_pop_terms
  )
  stan_data <- debiasR:::.build_multilevel_latent_stan_data(
    fit_df = fit_df,
    prediction_df = prediction_df,
    latent_formula_info = latent_formula,
    scenario_info = scenario_info,
    model_family = "poisson",
    latent_controls = debiasR:::.validate_multilevel_latent_controls(
      latent_coef_prior_scale = 1,
      latent_bias_prior_scale = 0.5,
      latent_intercept_prior_scale = 2.5,
      latent_state_prior_scale = 0.75,
      latent_source_prior_scale = 0.5,
      latent_time_prior_scale = 0.5,
      latent_phi_prior_rate = 1,
      latent_adapt_delta = 0.95,
      latent_max_treedepth = 12,
      latent_rng_eta_max = 20
    )
  )

  expect_equal(stan_data$data$N_obs, 35L)
  expect_equal(stan_data$data$N_pred, 36L)
  expect_equal(stan_data$data$L, 18L)
  expect_equal(stan_data$data$S, 2L)
  expect_equal(stan_data$data$T, 2L)
  expect_equal(stan_data$data$use_time_effect, 1L)
  expect_equal(stan_data$data$prior_coef_scale, 1)
  expect_equal(stan_data$data$prior_bias_scale, 0.5)
  expect_equal(stan_data$data$intercept_scale, 2.5)
  expect_equal(stan_data$data$prior_latent_state_scale, 0.75)
  expect_equal(stan_data$data$prior_source_scale, 0.5)
  expect_equal(stan_data$data$prior_time_scale, 0.5)
  expect_equal(stan_data$data$phi_prior_rate, 1)
  expect_equal(stan_data$data$max_rng_eta, 20)
  expect_equal(stan_data$summary$latent_controls$latent_adapt_delta, 0.95)
  expect_equal(stan_data$summary$n_unobserved_latent_flows, 0L)
  expect_equal(stan_data$summary$true_formula, "~rural_pct_o + rural_pct_d + log_distance")
  expect_equal(stan_data$summary$observation_formula, "~bias_e_origin - 1")
  expect_equal(stan_data$summary$source_effect_layer, "observation")
  expect_equal(stan_data$summary$time_effect_layer, "observation")
  expect_true(all(stan_data$data$latent_id_obs %in% seq_len(stan_data$data$L)))
  expect_true(all(stan_data$data$source_id_pred %in% seq_len(stan_data$data$S)))
})

test_that("latent Stan controls validate scalar inputs", {
  controls <- debiasR:::.validate_multilevel_latent_controls(
    latent_coef_prior_scale = 2,
    latent_bias_prior_scale = 0.75,
    latent_intercept_prior_scale = 2.25,
    latent_state_prior_scale = 1,
    latent_source_prior_scale = 0.6,
    latent_time_prior_scale = 0.4,
    latent_phi_prior_rate = 1.2,
    latent_adapt_delta = 0.9,
    latent_max_treedepth = 11,
    latent_rng_eta_max = 18
  )

  expect_equal(controls$latent_coef_prior_scale, 2)
  expect_equal(controls$latent_intercept_prior_scale, 2.25)
  expect_equal(controls$latent_phi_prior_rate, 1.2)
  expect_equal(controls$latent_max_treedepth, 11L)
  expect_error(
    debiasR:::.validate_multilevel_latent_controls(
      latent_coef_prior_scale = 0,
      latent_bias_prior_scale = 0.75,
      latent_intercept_prior_scale = 2.25,
      latent_state_prior_scale = 1,
      latent_source_prior_scale = 0.6,
      latent_time_prior_scale = 0.4,
      latent_phi_prior_rate = 1.2,
      latent_adapt_delta = 0.9,
      latent_max_treedepth = 11,
      latent_rng_eta_max = 18
    ),
    "latent_coef_prior_scale"
  )
  expect_error(
    debiasR:::.validate_multilevel_latent_controls(
      latent_coef_prior_scale = 2,
      latent_bias_prior_scale = 0.75,
      latent_intercept_prior_scale = 2.25,
      latent_state_prior_scale = 1,
      latent_source_prior_scale = 0.6,
      latent_time_prior_scale = 0.4,
      latent_phi_prior_rate = 1.2,
      latent_adapt_delta = 1,
      latent_max_treedepth = 11,
      latent_rng_eta_max = 18
    ),
    "latent_adapt_delta"
  )
  expect_error(
    debiasR:::.validate_multilevel_latent_controls(
      latent_coef_prior_scale = 2,
      latent_bias_prior_scale = 0.75,
      latent_intercept_prior_scale = 2.25,
      latent_state_prior_scale = 1,
      latent_source_prior_scale = 0.6,
      latent_time_prior_scale = 0.4,
      latent_phi_prior_rate = 1.2,
      latent_adapt_delta = 0.9,
      latent_max_treedepth = 11.5,
      latent_rng_eta_max = 18
    ),
    "latent_max_treedepth"
  )
})

test_that("latent Stan controls are ignored outside the latent Stan backend", {
  toy <- make_multilevel_scenario_toy(
    sources = "src1",
    periods = "t1"
  )

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "frequentist",
      scenario = "s1",
      target_scale = "true_flow",
      observation_model = "coverage_offset",
      random_intercept = "none",
      model_family = "poisson",
      latent_coef_prior_scale = 0
    )
  )

  expect_equal(attr(res, "model_engine"), "frequentist")
  expect_equal(attr(res, "observation_model"), "coverage_offset")
})

test_that("latent backend availability errors before model fitting", {
  if (requireNamespace("rstan", quietly = TRUE)) {
    skip("rstan is installed; unavailable-backend path is not active in this environment.")
  }

  expect_error(
    debiasR:::.check_latent_stan_backend_available(),
    "Backend 'stan_latent' requested, but package 'rstan' is not installed"
  )
})
