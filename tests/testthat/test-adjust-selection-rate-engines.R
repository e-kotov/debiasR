# tests/testthat/test-adjust-selection-rate-engines.R
# Tests for optional adjust_selection_rate() calibration engines

test_that("adjust_selection_rate DuckDB matches dplyr with new coverage schema", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)
  data(simulated_benchmark.od)

  new_coverage <- simulated_coverage |>
    dplyr::transmute(
      origin = .data$origin,
      origin_population = .data$population,
      origin_user_count = .data$user_count,
      destination = .data$origin,
      destination_population = .data$population,
      destination_user_count = .data$user_count,
      mpd_source = .data$mpd_source
    )

  benchmark <- simulated_benchmark.od |>
    dplyr::rename(flow_bench = "flow")

  res_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = new_coverage,
    covariates_df = simulated_covariates,
    covariate_col = "income_norm",
    weight_by = "both",
    benchmark_od_df = benchmark,
    flow_col_bench = "flow_bench",
    r_grid = c(0, 0.1, 0.5, 1),
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "dplyr"
  )

  res_duckdb <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = new_coverage,
    covariates_df = simulated_covariates,
    covariate_col = "income_norm",
    weight_by = "both",
    benchmark_od_df = benchmark,
    flow_col_bench = "flow_bench",
    r_grid = c(0, 0.1, 0.5, 1),
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "duckdb"
  )

  expect_equal(attr(res_duckdb, "r_global"), attr(res_dplyr, "r_global"))
  expect_equal(
    attr(res_duckdb, "r_calibration"),
    attr(res_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(res_duckdb, res_dplyr, tolerance = 1e-8)
})

test_that("adjust_selection_rate DuckDB matches legacy destination weighting", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_benchmark.od)

  res_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "destination",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "dplyr"
  )

  res_duckdb <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "destination",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "duckdb"
  )

  expect_equal(attr(res_duckdb, "r_global"), attr(res_dplyr, "r_global"))
  expect_equal(
    attr(res_duckdb, "r_calibration"),
    attr(res_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(res_duckdb$flow_adj, res_dplyr$flow_adj, tolerance = 1e-8)
})

test_that("adjust_selection_rate DuckDB preserves r_grid order and missing weights", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_benchmark.od)

  incomplete_coverage <- simulated_coverage[-1, ]
  r_grid <- c(1, 0, 0.5, 0.1)

  res_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = incomplete_coverage,
    weight_by = "origin",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = r_grid,
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "dplyr"
  )

  res_duckdb <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = incomplete_coverage,
    weight_by = "origin",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = r_grid,
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "duckdb"
  )

  expect_equal(attr(res_duckdb, "r_calibration")$r, r_grid)
  expect_equal(
    attr(res_duckdb, "r_calibration"),
    attr(res_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(res_duckdb$weight_missing, res_dplyr$weight_missing)
  expect_equal(res_duckdb$flow_adj, res_dplyr$flow_adj, tolerance = 1e-8)
})

test_that("adjust_selection_rate data.table matches dplyr with new coverage schema", {
  skip_if_not_installed("data.table")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_covariates)
  data(simulated_benchmark.od)

  new_coverage <- simulated_coverage |>
    dplyr::transmute(
      origin = .data$origin,
      origin_population = .data$population,
      origin_user_count = .data$user_count,
      destination = .data$origin,
      destination_population = .data$population,
      destination_user_count = .data$user_count,
      mpd_source = .data$mpd_source
    )

  benchmark <- simulated_benchmark.od |>
    dplyr::rename(flow_bench = "flow")

  res_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = new_coverage,
    covariates_df = simulated_covariates,
    covariate_col = "income_norm",
    weight_by = "both",
    benchmark_od_df = benchmark,
    flow_col_bench = "flow_bench",
    r_grid = c(0, 0.1, 0.5, 1),
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "dplyr"
  )

  res_datatable <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = new_coverage,
    covariates_df = simulated_covariates,
    covariate_col = "income_norm",
    weight_by = "both",
    benchmark_od_df = benchmark,
    flow_col_bench = "flow_bench",
    r_grid = c(0, 0.1, 0.5, 1),
    calibration_aggregate = "origin",
    clip_min = 0.25,
    clip_max = 8,
    engine = "data.table"
  )

  expect_equal(attr(res_datatable, "r_global"), attr(res_dplyr, "r_global"))
  expect_equal(
    attr(res_datatable, "r_calibration"),
    attr(res_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(res_datatable, res_dplyr, tolerance = 1e-8)
})

test_that("adjust_selection_rate data.table matches legacy weighting modes", {
  skip_if_not_installed("data.table")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_benchmark.od)

  res_origin_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "origin",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "dplyr"
  )

  res_origin_datatable <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "origin",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "data.table"
  )

  res_destination_dplyr <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "destination",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "dplyr"
  )

  res_destination_datatable <- adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "destination",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5, 1),
    calibration_aggregate = "od",
    engine = "data.table"
  )

  expect_equal(
    attr(res_origin_datatable, "r_calibration"),
    attr(res_origin_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(
    res_origin_datatable$flow_adj,
    res_origin_dplyr$flow_adj,
    tolerance = 1e-8
  )
  expect_equal(
    attr(res_destination_datatable, "r_calibration"),
    attr(res_destination_dplyr, "r_calibration"),
    tolerance = 1e-8
  )
  expect_equal(
    res_destination_datatable$flow_adj,
    res_destination_dplyr$flow_adj,
    tolerance = 1e-8
  )
})

test_that("adjust_selection_rate data.table does not attach data.table", {
  skip_if_not_installed("data.table")

  data(simulated_mpd.od)
  data(simulated_coverage)
  data(simulated_benchmark.od)

  search_path <- search()

  adjust_selection_rate(
    mpd_od_df = simulated_mpd.od,
    coverage_df = simulated_coverage,
    weight_by = "both",
    benchmark_od_df = simulated_benchmark.od,
    r_grid = c(0.1, 0.5),
    engine = "data.table"
  )

  expect_identical(search(), search_path)
})
