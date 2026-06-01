make_multilevel_scenario_toy <- function(sources = "src1",
                                         periods = "t1",
                                         zero_filled = FALSE) {
  areas <- c("A", "B", "C")
  od <- expand.grid(
    origin = areas,
    destination = areas,
    mpd_source = sources,
    mpd_time = periods,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  origin_i <- match(od$origin, areas)
  dest_i <- match(od$destination, areas)
  source_i <- match(od$mpd_source, sources)
  time_i <- match(od$mpd_time, periods)
  od$flow <- as.integer(3 + origin_i + dest_i + source_i + time_i)
  od$mpd_observed <- TRUE
  od$mpd_zero_filled <- FALSE
  od$mpd_row_status <- "observed"

  if (isTRUE(zero_filled)) {
    od$mpd_observed[nrow(od)] <- FALSE
    od$mpd_zero_filled[nrow(od)] <- TRUE
    od$mpd_row_status[nrow(od)] <- "zero_filled"
    od$flow[nrow(od)] <- 0L
  }

  coverage <- expand.grid(
    origin = areas,
    mpd_source = sources,
    mpd_time = periods,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  coverage$population <- c(100, 120, 150)[match(coverage$origin, areas)]
  coverage$user_count <- pmax(
    2,
    round(coverage$population * (0.08 + 0.015 * match(coverage$mpd_source, sources)))
  )

  covariates <- data.frame(
    area = areas,
    income_norm = c(0.2, 0.5, 0.8),
    rural_pct = c(0.7, 0.4, 0.1),
    deprivation_score = c(3.0, 1.5, 2.2),
    population = c(100, 120, 150)
  )

  distance <- expand.grid(
    origin = areas,
    destination = areas,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  distance$distance_km <- abs(match(distance$origin, areas) - match(distance$destination, areas)) + 1

  list(
    mpd_od = od,
    coverage = coverage,
    covariates = covariates,
    distance = distance
  )
}

make_multilevel_msoa_like_scenario <- function(n_areas = 12,
                                               sources = "operator_a",
                                               periods = "2021_q1",
                                               zero_filled = FALSE) {
  areas <- sprintf("E020%05d", seq_len(n_areas))
  od <- expand.grid(
    origin = areas,
    destination = areas,
    provider_id = sources,
    period_id = periods,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  origin_i <- match(od$origin, areas)
  dest_i <- match(od$destination, areas)
  source_i <- match(od$provider_id, sources)
  time_i <- match(od$period_id, periods)
  od$flow <- as.integer(
    15 + (origin_i * 2) + dest_i + (source_i * 4) + (time_i * 3) +
      ifelse(od$origin == od$destination, 6, 0)
  )
  od$mpd_observed <- TRUE
  od$mpd_zero_filled <- FALSE
  od$mpd_row_status <- "observed"

  if (isTRUE(zero_filled)) {
    zero_idx <- nrow(od)
    od$mpd_observed[zero_idx] <- FALSE
    od$mpd_zero_filled[zero_idx] <- TRUE
    od$mpd_row_status[zero_idx] <- "zero_filled"
    od$flow[zero_idx] <- 0L
  }

  coverage <- expand.grid(
    origin = areas,
    provider_id = sources,
    period_id = periods,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  coverage_origin_i <- match(coverage$origin, areas)
  coverage_source_i <- match(coverage$provider_id, sources)
  coverage_time_i <- match(coverage$period_id, periods)
  coverage$population <- 1000 + (coverage_origin_i * 25)
  coverage$user_count <- pmax(
    10,
    round(coverage$population * (0.055 + 0.004 * coverage_source_i + 0.002 * coverage_time_i))
  )

  covariates <- data.frame(
    area = areas,
    income_norm = seq(0.15, 0.85, length.out = n_areas),
    rural_pct = seq(0.75, 0.25, length.out = n_areas),
    deprivation_score = seq(1.2, 3.6, length.out = n_areas),
    population = 1000 + (seq_len(n_areas) * 25)
  )

  distance <- expand.grid(
    origin = areas,
    destination = areas,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  distance$distance_km <- abs(match(distance$origin, areas) - match(distance$destination, areas)) + 1

  list(
    mpd_od = od,
    coverage = coverage,
    covariates = covariates,
    distance = distance
  )
}

test_that("multilevel scenario resolver maps S1 through S4", {
  s1 <- make_multilevel_scenario_toy()
  s2 <- make_multilevel_scenario_toy(periods = c("t1", "t2"))
  s3 <- make_multilevel_scenario_toy(sources = c("src1", "src2"))
  s4 <- make_multilevel_scenario_toy(sources = c("src1", "src2"), periods = c("t1", "t2"))

  expect_equal(debiasR:::.resolve_multilevel_scenario(s1$mpd_od)$scenario, "s1")
  expect_equal(debiasR:::.resolve_multilevel_scenario(s2$mpd_od)$scenario, "s2")
  expect_equal(debiasR:::.resolve_multilevel_scenario(s3$mpd_od)$scenario, "s3")
  expect_equal(debiasR:::.resolve_multilevel_scenario(s4$mpd_od)$scenario, "s4")

  expect_equal(
    debiasR:::.resolve_multilevel_scenario(s2$mpd_od, scenario = "s2")$repeated_observation,
    "time"
  )
  expect_error(
    debiasR:::.resolve_multilevel_scenario(s3$mpd_od, scenario = "s2"),
    "scenario = 's2'"
  )
})

test_that("prepare helper carries source and time metadata for repeated inputs", {
  toy <- make_multilevel_scenario_toy(periods = c("t1", "t2"))
  scenario_info <- debiasR:::.resolve_multilevel_scenario(
    toy$mpd_od,
    scenario = "s2"
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

  expect_equal(prep$scenario_info$scenario, "s2")
  expect_equal(prep$scenario_info$repeated_observation, "time")
  expect_true(all(c(
    "mpd_source", "mpd_time", "bias_e_origin",
    "rural_pct_o", "rural_pct_d", "deprivation_score_o", "deprivation_score_d"
  ) %in% names(prep$model_df)))
  expect_equal(length(unique(prep$model_df$mpd_time)), 2)
  expect_true(all(is.finite(prep$model_df$bias_e_origin)))
})

test_that("internal frequentist default formula contract scales across MSOA-like S1-S4 inputs", {
  scenarios <- list(
    s1 = list(
      sources = "operator_a",
      periods = "2021_q1",
      repeated = "none",
      scenario_terms = character()
    ),
    s2 = list(
      sources = "operator_a",
      periods = c("2021_q1", "2021_q2"),
      repeated = "time",
      scenario_terms = "mpd_time"
    ),
    s3 = list(
      sources = c("operator_a", "operator_b"),
      periods = "2021_q1",
      repeated = "source",
      scenario_terms = "mpd_source"
    ),
    s4 = list(
      sources = c("operator_a", "operator_b"),
      periods = c("2021_q1", "2021_q2"),
      repeated = "source_time",
      scenario_terms = c("mpd_source", "mpd_time")
    )
  )

  for (scenario_name in names(scenarios)) {
    spec <- scenarios[[scenario_name]]
    toy <- make_multilevel_msoa_like_scenario(
      sources = spec$sources,
      periods = spec$periods,
      zero_filled = identical(scenario_name, "s4")
    )

    res <- adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "frequentist",
      scenario = scenario_name,
      source_col = "provider_id",
      time_col = "period_id",
      random_intercept = "none",
      prediction_scope = if (identical(scenario_name, "s4")) "complete_grid" else "observed"
    )

    metadata <- attr(res, "result_metadata")
    model_terms <- attr(res, "model_terms")

    expect_equal(attr(res, "scenario"), scenario_name)
    expect_equal(attr(res, "repeated_observation"), spec$repeated)
    expect_equal(attr(res, "source_col"), "provider_id")
    expect_equal(attr(res, "time_col"), "period_id")
    expect_equal(metadata$model_terms$scenario_fixed_effects, spec$scenario_terms)
    expect_equal(model_terms$scenario_fixed_effects, spec$scenario_terms)
    expect_false(model_terms$custom_formula)
    expect_true(all(
      c("income_o", "income_d", "log_distance", "bias_e_origin", "log_pop_o", "log_pop_d") %in%
        model_terms$default_fixed_effects
    ))
    expect_equal(model_terms$requested_random_intercept, "none")
    expect_equal(metadata$n_prediction_rows, nrow(toy$mpd_od))
    expect_true(all(is.finite(res$flow_adj)))
    expect_true(all(res$flow_adj >= 0))
  }
})

test_that("internal frequentist scaffold returns adjusted observed flows", {
  toy <- make_multilevel_scenario_toy()

  res <- adjust_multilevel_bayes(
    mpd_od_df = toy$mpd_od,
    coverage_df = toy$coverage,
    covariates_df = toy$covariates,
    distance_df = toy$distance,
    model_engine = "frequentist",
    scenario = "s1",
    random_intercept = "none",
    formula = flow ~ rural_pct_o + rural_pct_d + bias_e_origin + log_distance,
    include_flow_adj_draws = TRUE
  )

  expect_s3_class(res, "tbl_df")
  expect_equal(attr(res, "backend"), "frequentist_dev")
  expect_equal(attr(res, "model_engine"), "frequentist")
  expect_equal(attr(res, "scenario"), "s1")
  expect_equal(attr(res, "repeated_observation"), "none")
  expect_true(all(is.finite(res$flow_adj)))
  expect_true(all(res$flow_adj >= 0))
  expect_equal(dim(attr(res, "flow_adj_draws")), c(1L, nrow(res)))
  expect_true("bias_e_origin" %in% attr(res, "coefficients")$term)
  expect_equal(attr(res, "model_terms")$formula_source, "formula")
  expect_true(all(c("rural_pct_o", "rural_pct_d") %in% attr(res, "model_terms")$formula_variables))
})

test_that("internal frequentist scaffold supports S4 complete-grid prediction", {
  toy <- make_multilevel_scenario_toy(
    sources = c("src1", "src2"),
    periods = c("t1", "t2"),
    zero_filled = TRUE
  )

  res <- adjust_multilevel_bayes(
    mpd_od_df = toy$mpd_od,
    coverage_df = toy$coverage,
    covariates_df = toy$covariates,
    distance_df = toy$distance,
    model_engine = "frequentist",
    scenario = "s4",
    random_intercept = "none",
    formula = flow ~ rural_pct_o + rural_pct_d + bias_e_origin + log_distance + mpd_source + mpd_time,
    prediction_scope = "complete_grid"
  )

  metadata <- attr(res, "result_metadata")

  expect_equal(attr(res, "scenario"), "s4")
  expect_equal(attr(res, "repeated_observation"), "source_time")
  expect_equal(nrow(res), nrow(toy$mpd_od))
  expect_equal(metadata$n_fit_rows, nrow(toy$mpd_od) - 1L)
  expect_equal(metadata$n_prediction_rows, nrow(toy$mpd_od))
  expect_equal(metadata$n_zero_filled_prediction_rows, 1L)
  expect_equal(attr(res, "od_audit")$n_scenarios, 4)
  expect_equal(res$model_fit_status[res$mpd_zero_filled], "predicted")
  expect_true(all(is.finite(res$flow_adj)))
})

test_that("internal frequentist scaffold can use lme4 for a mixed model when available", {
  testthat::skip_if_not_installed("lme4")
  toy <- make_multilevel_scenario_toy(periods = c("t1", "t2"))

  res <- suppressWarnings(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "frequentist",
      scenario = "s2",
      random_intercept = "origin",
      formula = flow ~ bias_e_origin + log_distance + mpd_time + (1 + log_distance | origin)
    )
  )

  expect_equal(attr(res, "backend"), "frequentist_dev")
  expect_equal(attr(res, "model_engine"), "frequentist")
  expect_equal(attr(res, "random_intercept"), "origin")
  expect_true("(1 + log_distance | origin)" %in% attr(res, "model_terms")$formula_random_effects)
  expect_true(all(is.finite(res$flow_adj)))
})

test_that("formula validation reports missing prepared covariates", {
  toy <- make_multilevel_scenario_toy()

  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "frequentist",
      scenario = "s1",
      random_intercept = "none",
      formula = flow ~ missing_covariate_o + bias_e_origin
    ),
    "missing_covariate_o"
  )
})

test_that("Bayesian engine explicitly defers repeated source/time scenarios", {
  toy <- make_multilevel_scenario_toy(periods = c("t1", "t2"))

  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "bayesian",
      scenario = "s2",
      random_intercept = "none"
    ),
    "currently supports the existing Stage-1 S1 path only"
  )
})

test_that("internal frequentist scaffold rejects unsupported zero-inflated families", {
  toy <- make_multilevel_scenario_toy()

  expect_error(
    adjust_multilevel_bayes(
      mpd_od_df = toy$mpd_od,
      coverage_df = toy$coverage,
      covariates_df = toy$covariates,
      distance_df = toy$distance,
      model_engine = "frequentist",
      scenario = "s1",
      random_intercept = "none",
      model_family = "zip"
    ),
    "supports only Poisson and negative-binomial"
  )
})
