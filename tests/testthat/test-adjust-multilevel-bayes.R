source(testthat::test_path("helper-multilevel-scenarios.R"))

test_that("adjust_multilevel_bayes errors clearly when rstanarm is unavailable", {
  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)

  if (!requireNamespace("rstanarm", quietly = TRUE)) {
    expect_error(
      suppressWarnings(
        adjust_multilevel_bayes(
          mpd_od_df = simulated_mpd.od,
          coverage_df = simulated_coverage,
          covariates_df = simulated_covariates,
          iter = 100,
          chains = 2,
          seed = 1
        )
      ),
      "Backend 'rstanarm' requested, but package is not installed."
    )
  } else {
    skip("rstanarm is installed; fallback error path not applicable in this environment.")
  }
})

test_that("backend auto-selection resolves to the expected engine", {
  expect_equal(debiasR:::.resolve_multilevel_backend("poisson", "auto"), "rstanarm")
  expect_equal(debiasR:::.resolve_multilevel_backend("negbin", "auto"), "rstanarm")
  expect_equal(debiasR:::.resolve_multilevel_backend("zip", "auto"), "brms")
  expect_equal(debiasR:::.resolve_multilevel_backend("zinb", "auto"), "brms")
  expect_equal(debiasR:::.resolve_multilevel_backend("poisson", "brms"), "brms")
  expect_equal(
    debiasR:::.resolve_multilevel_backend("poisson", "auto", "latent_two_level"),
    "stan_latent"
  )
})

test_that("formula builder reflects the requested random-intercept structure", {
  default_info <- list(formula = NULL, source = "default")
  f_origin <- debiasR:::.build_multilevel_formula("origin", default_info, "income_norm", TRUE)
  f_destination <- debiasR:::.build_multilevel_formula("destination", default_info, "income_norm", FALSE)
  f_od <- debiasR:::.build_multilevel_formula("od", default_info, "income_norm", FALSE)
  f_none <- debiasR:::.build_multilevel_formula("none", default_info, "income_norm", FALSE)
  f_formula <- debiasR:::.build_multilevel_formula(
    "origin",
    list(
      formula = flow ~ rural_pct_o + rural_pct_d + bias_e_origin + (1 + log_distance | origin),
      source = "formula"
    ),
    "income_norm",
    TRUE
  )

  txt_origin <- paste(format(f_origin), collapse = " ")
  txt_destination <- paste(format(f_destination), collapse = " ")
  txt_od <- paste(format(f_od), collapse = " ")
  txt_none <- paste(format(f_none), collapse = " ")

  expect_match(txt_origin, "\\(1 \\| origin\\)")
  expect_match(txt_destination, "\\(1 \\|\\s+destination\\)")
  expect_match(txt_od, "\\(1 \\|\\s+od_id\\)")
  expect_false(grepl("\\|", txt_none, fixed = TRUE))
  expect_match(txt_origin, "log_pop_o")
  expect_false(grepl("log_pop_o", txt_destination, fixed = TRUE))
  expect_match(paste(format(f_formula), collapse = " "), "rural_pct_o")
  expect_true(debiasR:::.formula_has_random_effects(f_formula))
  expect_equal(
    debiasR:::.formula_random_effect_terms(f_formula),
    "(1 + log_distance | origin)"
  )
})

test_that("formula resolver keeps custom_formula as a deprecated alias", {
  expect_warning(
    info <- debiasR:::.resolve_multilevel_user_formula(
      custom_formula = flow ~ bias_e_origin + log_distance
    ),
    "deprecated"
  )
  expect_equal(info$source, "custom_formula")
  expect_equal(all.vars(info$formula), c("flow", "bias_e_origin", "log_distance"))
  expect_error(
    debiasR:::.resolve_multilevel_user_formula(
      formula = flow ~ bias_e_origin,
      custom_formula = flow ~ log_distance
    ),
    "Use only one"
  )
})

test_that("formula resolver supports split mobility and bias formulas", {
  info <- debiasR:::.resolve_multilevel_user_formula(
    mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance + (1 | origin),
    bias_formula = ~ bias_e_origin
  )

  expect_equal(info$source, "split_formula")
  expect_equal(info$interface, "split")
  expect_equal(info$mobility_variables, c("rural_pct_o", "rural_pct_d", "log_distance"))
  expect_equal(info$bias_variables, "bias_e_origin")
  expect_equal(
    debiasR:::.formula_random_effect_terms(info$formula),
    "(1 | origin)"
  )
  expect_true(all(c(
    "flow",
    "rural_pct_o",
    "rural_pct_d",
    "log_distance",
    "bias_e_origin",
    "origin"
  ) %in% all.vars(info$formula)))

  expect_error(
    debiasR:::.resolve_multilevel_user_formula(
      formula = flow ~ bias_e_origin,
      mobility_formula = ~ log_distance,
      bias_formula = ~ bias_e_origin
    ),
    "not both"
  )
  expect_error(
    debiasR:::.resolve_multilevel_user_formula(
      mobility_formula = ~ log_distance
    ),
    "Supply both"
  )
  expect_error(
    debiasR:::.resolve_multilevel_user_formula(
      mobility_formula = flow ~ log_distance,
      bias_formula = ~ bias_e_origin
    ),
    "one-sided formula"
  )
})

test_that("complete-grid audit detects strict square OD support", {
  complete_od <- data.frame(
    origin = c("A", "A", "B", "B"),
    destination = c("A", "B", "A", "B"),
    mpd_observed = c(TRUE, TRUE, TRUE, FALSE),
    mpd_zero_filled = c(FALSE, FALSE, FALSE, TRUE),
    flow = c(10, 2, 3, 0)
  )

  audit <- debiasR:::.audit_multilevel_complete_grid(complete_od, "flow")

  expect_true(audit$strict_square_support)
  expect_true(audit$same_origin_destination_area_set)
  expect_equal(audit$n_areas, 2)
  expect_equal(audit$expected_od_rows, 4)
  expect_equal(audit$n_zero_filled, 1)
  expect_equal(audit$balance_diff, 0)

  incomplete_od <- complete_od[-4, ]
  audit_incomplete <- debiasR:::.audit_multilevel_complete_grid(incomplete_od, "flow")
  expect_false(audit_incomplete$strict_square_support)
})

test_that("diagnostic summarizer standardizes available convergence metrics", {
  diag_tbl <- data.frame(
    Rhat = c(1.01, 1.00, 1.03),
    Bulk_ESS = c(410, 260, 320),
    Tail_ESS = c(505, 280, 450),
    stringsAsFactors = FALSE
  )

  out <- debiasR:::.summarize_diagnostics_frame(diag_tbl)

  expect_equal(out$status, "available")
  expect_equal(out$rhat_max, 1.03)
  expect_equal(out$ess_bulk_min, 260)
  expect_equal(out$ess_tail_min, 280)
})

test_that("diagnostic collector falls back cleanly when summary metrics are unavailable", {
  fake_fit <- structure(list(), class = "debiasR_fake_fit")
  coefficients <- data.frame(term = c("(Intercept)", "bias_e_origin"))

  out <- debiasR:::.collect_multilevel_diagnostics(
    fit = fake_fit,
    backend = "rstanarm",
    coefficients = coefficients
  )

  expect_equal(out$backend, "rstanarm")
  expect_true(out$has_bias_term)
  expect_equal(out$convergence$status, "not_available")
})

test_that("prepare helper builds deterministic bias and synthetic distance columns", {
  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)

  prep1 <- suppressWarnings(
    debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = simulated_mpd.od,
      coverage_df = simulated_coverage,
      covariates_df = simulated_covariates,
      distance_df = NULL,
      flow_col = "flow",
      income_col = "income_norm",
      pop_col = "population",
      distance_col = "distance_km"
    )
  )

  prep2 <- suppressWarnings(
    debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = simulated_mpd.od,
      coverage_df = simulated_coverage,
      covariates_df = simulated_covariates,
      distance_df = NULL,
      flow_col = "flow",
      income_col = "income_norm",
      pop_col = "population",
      distance_col = "distance_km"
    )
  )

  expect_true(all(c("bias_e_origin", "log_dist_synth") %in% names(prep1$base_df)))
  expect_true(all(c("income_norm_o", "income_norm_d", "income_o", "income_d") %in% names(prep1$base_df)))
  expect_equal(prep1$default_covariate_col, "income_norm")
  expect_equal(prep1$base_df$log_dist_synth, prep2$base_df$log_dist_synth)
  expect_equal(prep1$base_df$bias_e_origin, prep2$base_df$bias_e_origin)
})

test_that("prepare helper builds origin and destination coverage columns", {
  mpd <- data.frame(
    origin = c("A", "A", "B"),
    destination = c("A", "B", "A"),
    flow = c(2, 4, 3)
  )
  coverage <- data.frame(
    origin = c("A", "B"),
    population = c(100, 200),
    user_count = c(25, 20)
  )

  prep <- suppressWarnings(
    debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = mpd,
      coverage_df = coverage,
      covariates_df = NULL,
      distance_df = NULL,
      flow_col = "flow",
      income_col = NULL,
      pop_col = "population",
      distance_col = "distance_km"
    )
  )

  expect_equal(prep$base_df$coverage_rate_o, c(0.25, 0.25, 0.10))
  expect_equal(prep$base_df$coverage_rate_d, c(0.25, 0.10, 0.25))

  origin_offset <- debiasR:::.set_multilevel_observation_probability(
    prep$base_df,
    coverage_scale = "origin"
  )
  destination_offset <- debiasR:::.set_multilevel_observation_probability(
    prep$base_df,
    coverage_scale = "destination"
  )
  both_offset <- debiasR:::.set_multilevel_observation_probability(
    prep$base_df,
    coverage_scale = "both"
  )

  expect_equal(origin_offset$observation_probability, origin_offset$coverage_rate_o)
  expect_equal(destination_offset$observation_probability, destination_offset$coverage_rate_d)
  expect_equal(
    both_offset$observation_probability,
    sqrt(both_offset$coverage_rate_o * both_offset$coverage_rate_d)
  )
  expect_equal(
    both_offset$log_observation_probability,
    log(both_offset$observation_probability)
  )
})

test_that("coverage-offset validation rejects non-positive coverage", {
  bad <- data.frame(
    coverage_rate_o = c(0.1, 0),
    coverage_rate_d = c(0.2, 0.3)
  )

  expect_error(
    debiasR:::.validate_multilevel_coverage_offset_data(
      bad,
      coverage_scale = "origin"
    ),
    "positive finite coverage rates"
  )
  expect_error(
    debiasR:::.validate_multilevel_observation_contract(
      target_scale = "true_flow",
      observation_model = "reduced_form"
    ),
    "requires"
  )
})

test_that("prepare helper preserves complete-grid source row status", {
  complete_od <- data.frame(
    origin = c("A", "A", "B", "B"),
    destination = c("A", "B", "A", "B"),
    mpd_source = "toy",
    mpd_observed = c(TRUE, TRUE, TRUE, FALSE),
    mpd_zero_filled = c(FALSE, FALSE, FALSE, TRUE),
    mpd_row_status = c("observed", "observed", "observed", "zero_filled"),
    flow = c(10, 2, 3, 0)
  )
  coverage <- data.frame(
    origin = c("A", "B"),
    population = c(100, 80),
    user_count = c(12, 3),
    mpd_source = "toy"
  )
  covariates <- data.frame(
    area = c("A", "B"),
    income_norm = c(0.2, 0.8),
    rural_pct = c(0.7, 0.2),
    population = c(100, 80)
  )

  prep <- suppressWarnings(
    debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = complete_od,
      coverage_df = coverage,
      covariates_df = covariates,
      distance_df = NULL,
      flow_col = "flow",
      income_col = "income_norm",
      pop_col = "population",
      distance_col = "distance_km"
    )
  )

  expect_true(all(c(
    "mpd_observed", "mpd_zero_filled", "mpd_row_status",
    "rural_pct_o", "rural_pct_d"
  ) %in% names(prep$model_df)))
  expect_equal(sum(prep$model_df$mpd_observed), 3)
  expect_equal(sum(prep$model_df$mpd_zero_filled), 1)
  expect_equal(prep$model_df$mpd_row_status[prep$model_df$mpd_zero_filled], "zero_filled")
})

test_that("adjust_multilevel_bayes validates required schema", {
  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)

  bad_cov <- simulated_coverage
  bad_cov$population <- NULL
  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = simulated_mpd.od,
      coverage_df = bad_cov,
      covariates_df = simulated_covariates
    ),
    "coverage_df"
  )

  bad_covars <- simulated_covariates
  bad_covars$income_norm <- NULL
  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = simulated_mpd.od,
      coverage_df = simulated_coverage,
      covariates_df = bad_covars,
      income_col = "income_norm"
    ),
    "covariates_df"
  )

  bad_mpd <- simulated_mpd.od
  bad_mpd$flow <- NULL
  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = bad_mpd,
      coverage_df = simulated_coverage,
      covariates_df = simulated_covariates
    ),
    "mpd_od_df"
  )
})

test_that("adjust_multilevel_bayes returns adjusted flows when rstanarm is available", {
  skip_if_not_installed("rstanarm")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)

  res <- adjust_multilevel_bayes(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    covariates_df = simulated_covariates,
    iter = 100,
    chains = 1,
    seed = 123,
    refresh = 0
  )

  expect_s3_class(res, "tbl_df")
  expect_true(all(c("origin", "destination", "flow", "flow_adj") %in% names(res)))
  expect_true(all(c("bias_e_origin", "log_dist_synth") %in% names(res)))

  modeled <- res[is.finite(res$flow_adj), , drop = FALSE]
  expect_gt(nrow(modeled), 0)
  expect_true(all(is.finite(modeled$flow_adj)))
  expect_true(all(modeled$flow_adj >= 0))
  expect_true(any(abs(modeled$flow_adj - modeled$flow) > 1e-8))

  coef_tbl <- attr(res, "coefficients")
  expect_true(is.data.frame(coef_tbl))
  expect_true("term" %in% names(coef_tbl))
  expect_true("bias_e_origin" %in% coef_tbl$term)

  expect_equal(attr(res, "backend"), "rstanarm")
  expect_equal(attr(res, "stage"), "stage_1")
  expect_equal(attr(res, "stage_scope"), "observed_od_only")
  expect_equal(attr(res, "flow_adj_summary"), "mean")
  expect_equal(attr(res, "random_intercept"), "origin")
  expect_match(attr(res, "prototype_notes"), "Stage-1 observed mode")
  expect_match(attr(res, "prototype_notes"), "prediction_scope = 'complete_grid'")
  expect_match(attr(res, "prototype_notes"), "removes the fixed-effect contribution")

  result_metadata <- attr(res, "result_metadata")
  expect_type(result_metadata, "list")
  expect_equal(result_metadata$backend, "rstanarm")
  expect_equal(result_metadata$model_family, "poisson")
  expect_equal(result_metadata$stage, "stage_1")
  expect_equal(result_metadata$stage_scope, "observed_od_only")
  expect_equal(result_metadata$flow_adj_summary, "mean")
  expect_equal(result_metadata$random_intercept, "origin")
  expect_equal(result_metadata$distance_source, "synthetic")
  expect_equal(result_metadata$bias_terms, "bias_e_origin")

  diagnostics <- attr(res, "diagnostics")
  expect_type(diagnostics, "list")
  expect_equal(diagnostics$backend, "rstanarm")
  expect_true(isTRUE(diagnostics$has_bias_term))
  expect_true(diagnostics$convergence$status %in% c(
    "available",
    "available_no_standard_metrics",
    "not_available"
  ))
})

test_that("adjust_multilevel_bayes supports complete-grid prediction when rstanarm is available", {
  skip_if_not_installed("rstanarm")

  complete_od <- data.frame(
    origin = c("A", "A", "B", "B"),
    destination = c("A", "B", "A", "B"),
    mpd_source = "toy",
    mpd_observed = c(TRUE, TRUE, TRUE, FALSE),
    mpd_zero_filled = c(FALSE, FALSE, FALSE, TRUE),
    mpd_row_status = c("observed", "observed", "observed", "zero_filled"),
    flow = c(10, 2, 3, 0)
  )
  coverage <- data.frame(
    origin = c("A", "B"),
    population = c(100, 80),
    user_count = c(12, 3),
    mpd_source = "toy"
  )
  covariates <- data.frame(
    area = c("A", "B"),
    income_norm = c(0.2, 0.8),
    population = c(100, 80)
  )

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = complete_od,
      coverage_df = coverage,
      covariates_df = covariates,
      prediction_scope = "complete_grid",
      random_intercept = "origin",
      formula = flow ~ bias_e_origin + (1 | origin),
      iter = 100,
      chains = 1,
      seed = 321,
      refresh = 0
    )
  )

  expect_equal(nrow(res), 4)
  expect_equal(attr(res, "prediction_scope"), "complete_grid")
  expect_equal(attr(res, "stage_scope"), "complete_grid_prediction")
  expect_true(all(c("mpd_observed", "mpd_zero_filled", "mpd_row_status") %in% names(res)))
  expect_true(any(res$mpd_zero_filled))
  expect_true(all(is.finite(res$flow_adj)))

  metadata <- attr(res, "result_metadata")
  expect_equal(metadata$n_fit_rows, 3)
  expect_equal(metadata$n_prediction_rows, 4)
  expect_equal(metadata$n_zero_filled_prediction_rows, 1)
  expect_true(metadata$runtime_seconds >= 0)
})

test_that("Bayesian coverage-offset predictions separate MPD and true-flow scales", {
  skip_if_not_installed("rstanarm")

  areas <- c("A", "B", "C")
  mpd <- expand.grid(
    origin = areas,
    destination = areas,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  mpd$flow <- c(18, 4, 5, 6, 15, 7, 3, 5, 14)

  coverage <- data.frame(
    origin = areas,
    population = c(100, 120, 90),
    user_count = c(20, 30, 18)
  )
  covariates <- data.frame(
    area = areas,
    rural_pct = c(0.2, 0.5, 0.8),
    population = c(100, 120, 90)
  )
  distance <- expand.grid(
    origin = areas,
    destination = areas,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  distance$distance_km <- abs(
    match(distance$origin, areas) - match(distance$destination, areas)
  ) + 1

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = mpd,
      coverage_df = coverage,
      covariates_df = covariates,
      distance_df = distance,
      mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance,
      bias_formula = ~ bias_e_origin,
      target_scale = "true_flow",
      observation_model = "coverage_offset",
      coverage_scale = "origin",
      model_engine = "bayesian",
      prediction_scope = "complete_grid",
      random_intercept = "none",
      model_family = "poisson",
      flow_adj_summary = "median",
      iter = 100,
      chains = 1,
      seed = 99,
      refresh = 0
    )
  )

  expect_equal(attr(res, "backend"), "rstanarm")
  expect_equal(attr(res, "target_scale"), "true_flow")
  expect_equal(attr(res, "observation_model"), "coverage_offset")
  expect_equal(as.numeric(res$flow_adj), as.numeric(res$flow_true_pred))
  expect_equal(
    as.numeric(res$flow_mpd_pred),
    as.numeric(res$flow_true_pred * res$observation_probability),
    tolerance = 1e-6
  )
  expect_true(all(res$flow_true_pred > res$flow_mpd_pred))
})

test_that("Bayesian formula contract resolves S2-S4 repeated source/time terms", {
  scenarios <- list(
    s2 = list(
      sources = "src1",
      periods = c("t1", "t2"),
      repeated = "time",
      terms = "mpd_time"
    ),
    s3 = list(
      sources = c("src1", "src2"),
      periods = "t1",
      repeated = "source",
      terms = "mpd_source"
    ),
    s4 = list(
      sources = c("src1", "src2"),
      periods = c("t1", "t2"),
      repeated = "source_time",
      terms = c("mpd_source", "mpd_time")
    )
  )

  for (scenario_name in names(scenarios)) {
    spec <- scenarios[[scenario_name]]
    toy <- make_multilevel_scenario_toy(
      sources = spec$sources,
      periods = spec$periods
    )
    scenario_info <- debiasR:::.resolve_multilevel_scenario(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      scenario = scenario_name,
      repeated_observation = "auto"
    )
    prep <- debiasR:::.prepare_multilevel_bayes_data(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      flow_col = "flow",
      income_col = NULL,
      pop_col = "population",
      distance_col = "distance_km",
      scenario_info = scenario_info
    )
    scenario_terms <- debiasR:::.resolve_multilevel_formula_terms(
      data = prep$model_df,
      repeated_observation = scenario_info$repeated_observation,
      random_intercept = "none"
    )
    fit_formula <- debiasR:::.build_multilevel_formula(
      random_intercept = "none",
      formula_info = list(formula = NULL, source = "default", interface = "default"),
      default_covariate_col = prep$default_covariate_col,
      include_pop_terms = prep$has_pop_terms,
      scenario_terms = scenario_terms,
      target_scale = "true_flow"
    )

    expect_equal(scenario_info$scenario, scenario_name)
    expect_equal(scenario_info$repeated_observation, spec$repeated)
    expect_equal(scenario_terms, spec$terms)
    expect_true(all(spec$terms %in% all.vars(fit_formula)))
  }
})

test_that("Bayesian engine fits an S4 repeated source/time scenario", {
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
      iter = 50,
      chains = 1,
      seed = 804,
      refresh = 0
    )
  )

  metadata <- attr(res, "result_metadata")
  model_terms <- attr(res, "model_terms")

  expect_equal(attr(res, "model_engine"), "bayesian")
  expect_equal(attr(res, "backend"), "rstanarm")
  expect_equal(attr(res, "scenario"), "s4")
  expect_equal(attr(res, "repeated_observation"), "source_time")
  expect_equal(metadata$model_terms$scenario_fixed_effects, c("mpd_source", "mpd_time"))
  expect_equal(model_terms$scenario_fixed_effects, c("mpd_source", "mpd_time"))
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(all(res$flow_adj >= 0))
  expect_equal(as.numeric(res$flow_adj), as.numeric(res$flow_true_pred))
  expect_equal(
    as.numeric(res$flow_mpd_pred),
    as.numeric(res$flow_true_pred * res$observation_probability),
    tolerance = 1e-6
  )

  coverage_lookup <- toy$coverage
  coverage_lookup$expected_observation_probability <-
    coverage_lookup$user_count / coverage_lookup$population
  coverage_check <- merge(
    as.data.frame(res[c(
      "origin",
      "mpd_source",
      "mpd_time",
      "observation_probability"
    )]),
    coverage_lookup[c(
      "origin",
      "mpd_source",
      "mpd_time",
      "expected_observation_probability"
    )],
    by = c("origin", "mpd_source", "mpd_time"),
    sort = FALSE
  )
  expect_equal(
    coverage_check$observation_probability,
    coverage_check$expected_observation_probability
  )

  expect_equal(metadata$n_fit_rows, nrow(toy$mpd_od) - 1L)
  expect_equal(metadata$n_zero_filled_prediction_rows, 1L)
  expect_equal(res$model_fit_status[res$mpd_zero_filled], "predicted")
})

test_that("adjust_multilevel_bayes can attach draw-level summaries when requested", {
  skip_if_not_installed("rstanarm")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)

  res_mean <- adjust_multilevel_bayes(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    covariates_df = simulated_covariates,
    iter = 100,
    chains = 1,
    seed = 456,
    refresh = 0,
    include_flow_adj_draws = TRUE,
    flow_adj_summary = "mean"
  )

  res_median <- adjust_multilevel_bayes(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    covariates_df = simulated_covariates,
    iter = 100,
    chains = 1,
    seed = 456,
    refresh = 0,
    include_flow_adj_draws = TRUE,
    flow_adj_summary = "median"
  )

  draws_mean <- attr(res_mean, "flow_adj_draws")
  draws_median <- attr(res_median, "flow_adj_draws")

  expect_true(is.matrix(draws_mean))
  expect_true(is.matrix(draws_median))
  expect_equal(dim(draws_mean), dim(draws_median))
  expect_equal(ncol(draws_mean), nrow(res_mean))
  expect_equal(attr(res_median, "flow_adj_summary"), "median")
  expect_false(is.null(attr(res_mean, "formula")))
  expect_false(is.null(attr(res_mean, "model_family")))
  expect_equal(as.numeric(res_mean$flow_adj), unname(colMeans(draws_mean)))
  expect_equal(
    as.numeric(res_median$flow_adj),
    unname(apply(draws_median, 2, stats::median))
  )
  expect_true(any(abs(res_mean$flow_adj - res_median$flow_adj) > 0))
})
