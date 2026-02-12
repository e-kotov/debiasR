# tests/testthat/test-measure_bias.R

test_that("measure_bias computes coverage bias and preserves rows/cols", {
  data("toy_coverage_df", package = "debiasR")  # <- replace yourpkg if needed
  df <- toy_coverage_df

  # Keep this test quiet (no warning) by ensuring user_count <= population
  df_sane <- df
  df_sane$user_count <- pmin(df_sane$user_count, df_sane$population)

  res <- measure_bias(df_sane)

  expect_true("bias" %in% names(res))
  expect_equal(nrow(res), nrow(df_sane))
  # preserves existing columns:
  expect_true(all(setdiff(names(df_sane), "bias") %in% names(res)))

  expect_equal(
    res$bias,
    with(df_sane, user_count / population),
    tolerance = 1e-12
  )
})

test_that("measure_bias warns when coverage bias > 1", {
  data("toy_coverage_df", package = "debiasR")
  df <- toy_coverage_df

  # Force an over-coverage in a single row
  i <- 1L
  df$user_count[i] <- df$population[i] * 1.1

  expect_warning(
    res <- measure_bias(df),
    regexp = "bias > 1"
  )
  expect_gt(res$bias[i], 1)
})

test_that("measure_bias errors on missing required columns", {
  data("toy_coverage_df", package = "debiasR")
  df <- toy_coverage_df

  df_missing_user <- df[, setdiff(names(df), "user_count")]
  expect_error(
    measure_bias(df_missing_user),
    regexp = "Missing required columns"
  )

  df_missing_pop <- df[, setdiff(names(df), "population")]
  expect_error(
    measure_bias(df_missing_pop),
    regexp = "Missing required columns"
  )
})

test_that("measure_bias errors on invalid values", {
  data("toy_coverage_df", package = "debiasR")
  df <- toy_coverage_df

  # population NA
  df_na <- df
  df_na$population[1] <- NA_real_
  expect_error(
    measure_bias(df_na),
    regexp = "population contains NA values"
  )

  # population <= 0
  df_zero <- df
  df_zero$population[1] <- 0
  expect_error(
    measure_bias(df_zero),
    regexp = "population must be positive"
  )

  # user_count < 0
  df_neg <- df
  df_neg$user_count[1] <- -1
  expect_error(
    measure_bias(df_neg),
    regexp = "user_count must be non-negative"
  )
})
