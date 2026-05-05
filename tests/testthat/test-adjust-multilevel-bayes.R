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
})

test_that("formula builder reflects the requested random-intercept structure", {
  f_origin <- debiasR:::.build_multilevel_formula("origin", NULL, TRUE)
  f_destination <- debiasR:::.build_multilevel_formula("destination", NULL, FALSE)
  f_od <- debiasR:::.build_multilevel_formula("od", NULL, FALSE)
  f_none <- debiasR:::.build_multilevel_formula("none", NULL, FALSE)

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
  expect_equal(prep1$base_df$log_dist_synth, prep2$base_df$log_dist_synth)
  expect_equal(prep1$base_df$bias_e_origin, prep2$base_df$bias_e_origin)
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
  expect_match(attr(res, "prototype_notes"), "No missing OD pairs are created or imputed.")
  expect_match(attr(res, "prototype_notes"), "removes the estimated coverage-bias contribution")

  result_metadata <- attr(res, "result_metadata")
  expect_type(result_metadata, "list")
  expect_equal(result_metadata$backend, "rstanarm")
  expect_equal(result_metadata$model_family, "poisson")
  expect_equal(result_metadata$stage, "stage_1")
  expect_equal(result_metadata$stage_scope, "observed_od_only")
  expect_equal(result_metadata$flow_adj_summary, "mean")
  expect_equal(result_metadata$random_intercept, "origin")
  expect_equal(result_metadata$distance_source, "synthetic")

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
  expect_equal(as.numeric(res_mean$flow_adj), colMeans(draws_mean))
  expect_equal(
    as.numeric(res_median$flow_adj),
    apply(draws_median, 2, stats::median)
  )
  expect_true(any(abs(res_mean$flow_adj - res_median$flow_adj) > 0))
})
