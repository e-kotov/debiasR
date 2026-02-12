# tests/testthat/test-method3-selection-rateII.R
# Tests for method3_selection_rateII()

test_that("method3_selection_rateII basic origin weighting works", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  res_o <- method3_selection_rateII(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "origin",
    k           = 1
  )

  expect_s3_class(res_o, "tbl_df")
  expect_true(all(c("origin", "destination", "flow", "flow_adj") %in% names(res_o)))
  expect_true("weight_origin" %in% names(res_o))
  expect_true(all(res_o$flow_adj >= 0 | is.na(res_o$flow_adj)))
})

test_that("method3_selection_rateII destination and both-side weighting work", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  # destination-only
  res_d <- method3_selection_rateII(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "destination",
    k           = 1
  )

  expect_s3_class(res_d, "tbl_df")
  expect_true("weight_destination" %in% names(res_d))
  expect_true(all(res_d$flow_adj >= 0 | is.na(res_d$flow_adj)))

  # both origin and destination
  res_b <- method3_selection_rateII(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "both",
    k           = 1
  )

  expect_s3_class(res_b, "tbl_df")
  expect_true(all(c("weight_origin", "weight_destination") %in% names(res_b)))
  expect_true(all(res_b$flow_adj >= 0 | is.na(res_b$flow_adj)))
})

test_that("method3_selection_rateII calibrates k when benchmark provided", {

  data(toy_mpd_od)
  data(toy_coverage_df)
  data(toy_benchmark_od)

  k_grid <- seq(0.5, 2, by = 0.5)

  res_cal <- method3_selection_rateII(
    mpd_od_df           = toy_mpd_od,
    coverage_df         = toy_coverage_df,
    weight_by           = "origin",
    k                   = NULL,
    k_grid              = k_grid,
    benchmark_od_df     = toy_benchmark_od,
    flow_col_bench      = "flow",
    calibration_aggregate = "origin"
  )

  # structure
  expect_s3_class(res_cal, "tbl_df")
  expect_true("flow_adj" %in% names(res_cal))

  # calibration attributes
  k_used  <- attr(res_cal, "k")
  k_diag  <- attr(res_cal, "k_calibration")

  expect_false(is.null(k_used))
  expect_true(is.numeric(k_used))
  expect_false(is.null(k_diag))
  expect_true(all(c("k", "loss") %in% names(k_diag)))

  # k_used is within grid range
  expect_true(k_used >= min(k_diag$k) - 1e-12)
  expect_true(k_used <= max(k_diag$k) + 1e-12)

  # k_used corresponds to minimum loss
  best_idx <- which.min(k_diag$loss)
  expect_equal(k_used, k_diag$k[best_idx])

  # Using fixed k_used reproduces same adjusted flows
  res_fixed <- method3_selection_rateII(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "origin",
    k           = k_used
  )

  expect_equal(
    res_fixed$flow_adj,
    res_cal$flow_adj,
    tolerance = 1e-8
  )
})

test_that("method3_selection_rateII handles group_cols when present (synthetic check)", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  # Create a simple synthetic grouping to test plumbing
  toy_mpd_g <- toy_mpd_od
  toy_mpd_g$age_group <- ifelse(as.integer(factor(toy_mpd_g$origin)) %% 2 == 0, "young", "old")

  toy_cov_g <- toy_coverage_df
  toy_cov_g$age_group <- ifelse(as.integer(factor(toy_cov_g$origin)) %% 2 == 0, "young", "old")

  res_g <- method3_selection_rateII(
    mpd_od_df   = toy_mpd_g,
    coverage_df = toy_cov_g,
    weight_by   = "origin",
    group_cols  = "age_group",
    k           = 1
  )

  expect_s3_class(res_g, "tbl_df")
  expect_true("age_group" %in% names(res_g))
  expect_true("weight_origin" %in% names(res_g))
})

test_that("method3_selection_rateII errors cleanly with bad inputs", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  # Missing required columns in mpd_od_df
  bad_mpd <- toy_mpd_od
  bad_mpd$origin <- NULL

  expect_error(
    method3_selection_rateII(
      mpd_od_df   = bad_mpd,
      coverage_df = toy_coverage_df,
      weight_by   = "origin",
      k           = 1
    ),
    "mpd_od_df"
  )

  # Invalid k
  expect_error(
    method3_selection_rateII(
      mpd_od_df   = toy_mpd_od,
      coverage_df = toy_coverage_df,
      weight_by   = "origin",
      k           = -1
    ),
    "positive scalar"
  )

  # group_cols not found
  expect_error(
    method3_selection_rateII(
      mpd_od_df   = toy_mpd_od,
      coverage_df = toy_coverage_df,
      weight_by   = "origin",
      group_cols  = "age_group",
      k           = 1
    ),
    "group_cols"
  )
})
