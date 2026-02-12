# tests/testthat/test-method2-selection-rate.R
# ------------------------------------------------------------------------------
# Tests for method2_selection_rate()
# ------------------------------------------------------------------------------

# tests/testthat/test-method2-selection-rate.R
# Tests for method2_selection_rate()

test_that("method2_selection_rate basic origin weighting works", {

  data(toy_mpd_od)
  data(toy_coverage_df)
  data(toy_covariates_df)

  res_o <- method2_selection_rate(
    mpd_od_df      = toy_mpd_od,
    coverage_df    = toy_coverage_df,
    covariates_df  = toy_covariates_df,
    income_col     = "income_norm",
    weight_by      = "origin"
  )

  # structure
  expect_s3_class(res_o, "tbl_df")
  expect_true(all(c("origin", "destination", "flow", "flow_adj") %in% names(res_o)))
  expect_true("weight_origin" %in% names(res_o))
  expect_true(all(res_o$flow_adj >= 0 | is.na(res_o$flow_adj)))
})

test_that("method2_selection_rate destination and both-side weighting work", {

  data(toy_mpd_od)
  data(toy_coverage_df)
  data(toy_covariates_df)

  # destination-only
  res_d <- method2_selection_rate(
    mpd_od_df      = toy_mpd_od,
    coverage_df    = toy_coverage_df,
    covariates_df  = toy_covariates_df,
    income_col     = "income_norm",
    weight_by      = "destination"
  )

  expect_s3_class(res_d, "tbl_df")
  expect_true("weight_destination" %in% names(res_d))
  expect_true(all(res_d$flow_adj >= 0 | is.na(res_d$flow_adj)))

  # both origin and destination
  res_b <- method2_selection_rate(
    mpd_od_df      = toy_mpd_od,
    coverage_df    = toy_coverage_df,
    covariates_df  = toy_covariates_df,
    income_col     = "income_norm",
    weight_by      = "both"
  )

  expect_s3_class(res_b, "tbl_df")
  expect_true(all(c("weight_origin", "weight_destination") %in% names(res_b)))
  expect_true(all(res_b$flow_adj >= 0 | is.na(res_b$flow_adj)))
})

test_that("method2_selection_rate calibration with benchmark chooses minimizing r_t", {

  data(toy_mpd_od)
  data(toy_coverage_df)
  data(toy_covariates_df)
  data(toy_benchmark_od)

  # use a compact grid for speed; behaviour is what matters
  r_grid <- seq(0, 1, by = 0.1)

  res_cal <- method2_selection_rate(
    mpd_od_df           = toy_mpd_od,
    coverage_df         = toy_coverage_df,
    covariates_df       = toy_covariates_df,
    income_col          = "income_norm",
    weight_by           = "origin",
    benchmark_od_df     = toy_benchmark_od,
    calibration_aggregate = "origin",
    r_grid              = r_grid
  )

  # basic structure
  expect_s3_class(res_cal, "tbl_df")
  expect_true("flow_adj" %in% names(res_cal))

  # attributes present
  rt <- attr(res_cal, "r_global")
  cal_diag <- attr(res_cal, "r_calibration")

  expect_false(is.null(rt))
  expect_true(is.numeric(rt))
  expect_false(is.null(cal_diag))
  expect_true(all(c("r", "loss") %in% names(cal_diag)))

  # r_global is within grid bounds (allowing numerical tolerance)
  expect_true(rt >= min(cal_diag$r) - 1e-12)
  expect_true(rt <= max(cal_diag$r) + 1e-12)

  # r_global corresponds to (one of) the minimal loss values
  best_idx <- which.min(cal_diag$loss)
  expect_equal(rt, cal_diag$r[best_idx])

  # Using r_global directly should reproduce the same adjusted flows
  res_fixed <- method2_selection_rate(
    mpd_od_df      = toy_mpd_od,
    coverage_df    = toy_coverage_df,
    covariates_df  = toy_covariates_df,
    income_col     = "income_norm",
    weight_by      = "origin",
    r_global       = rt
  )

  # Compare flow_adj vectors (order should match; if not, join then compare)
  expect_equal(
    res_fixed$flow_adj,
    res_cal$flow_adj,
    tolerance = 1e-8
  )
})

test_that("method2_selection_rate errors cleanly with bad inputs", {

  data(toy_mpd_od)
  data(toy_coverage_df)
  data(toy_covariates_df)

  # missing required columns in mpd_od_df
  bad_mpd <- toy_mpd_od
  bad_mpd$origin <- NULL

  expect_error(
    method2_selection_rate(
      mpd_od_df     = bad_mpd,
      coverage_df   = toy_coverage_df,
      covariates_df = toy_covariates_df,
      income_col    = "income_norm",
      weight_by     = "origin"
    ),
    "mpd_od_df"
  )

  # invalid income column name
  expect_error(
    method2_selection_rate(
      mpd_od_df     = toy_mpd_od,
      coverage_df   = toy_coverage_df,
      covariates_df = toy_covariates_df,
      income_col    = "not_a_col",
      weight_by     = "origin"
    ),
    "income_col"
  )
})
