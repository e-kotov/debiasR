test_that("validate_bias_residual_structure returns deterministic diagnostics", {
  coverage_df <- data.frame(
    area_id = c("A", "B", "C", "D"),
    population = c(100, 100, 100, 100),
    user_count = c(5, 15, 25, 35)
  )

  benchmark_od_df <- data.frame(
    origin = c("A", "B", "C", "D"),
    destination = c("D", "C", "B", "A"),
    flow = c(10, 20, 30, 40)
  )

  area_neighbors <- data.frame(
    area = c("A", "B", "C", "D"),
    neighbor = c("B", "A", "D", "C")
  )

  covariates <- data.frame(
    area = c("A", "B", "C", "D"),
    cov = c(4, 3, 2, 1)
  )

  res <- validate_bias_residual_structure(
    coverage_df = coverage_df,
    coverage_area_col = "area_id",
    benchmark_od_df = benchmark_od_df,
    area_neighbors = area_neighbors,
    covariate_df = covariates,
    covariate_col = "cov"
  )

  expect_true(all(c(
    "summary",
    "residual_definitions",
    "moran_i",
    "benchmark_flow_correlation",
    "covariate_correlation",
    "area_level",
    "map_data",
    "benchmark_flow_data",
    "covariate_data"
  ) %in% names(res)))

  expect_equal(res$summary$residual_type, "coverage_score")
  expect_equal(res$summary$global_coverage_score, 0.2)
  expect_equal(res$area_level$expected_user_count, rep(20, 4))
  expect_equal(res$area_level$user_count_residual, c(-15, -5, 5, 15))
  expect_equal(
    res$area_level$coverage_score_residual,
    c(-0.15, -0.05, 0.05, 0.15),
    tolerance = 1e-12
  )
  expect_equal(
    res$area_level$selected_residual,
    res$area_level$coverage_score_residual,
    tolerance = 1e-12
  )

  expect_equal(res$moran_i$moran_i, 0.6, tolerance = 1e-12)

  origin_cor <- res$benchmark_flow_correlation$pearson_r[
    res$benchmark_flow_correlation$benchmark_flow_role == "origin"
  ]
  destination_cor <- res$benchmark_flow_correlation$pearson_r[
    res$benchmark_flow_correlation$benchmark_flow_role == "destination"
  ]

  expect_equal(origin_cor, 1, tolerance = 1e-12)
  expect_equal(destination_cor, -1, tolerance = 1e-12)
  expect_equal(res$covariate_correlation$pearson_r, -1, tolerance = 1e-12)
})

test_that("validate_bias_residual_structure can select standardized count residuals", {
  coverage_df <- data.frame(
    area_id = c("A", "B", "C", "D"),
    population = c(100, 100, 100, 100),
    user_count = c(5, 15, 25, 35)
  )

  res <- validate_bias_residual_structure(
    coverage_df = coverage_df,
    coverage_area_col = "area_id",
    residual_type = "standardized_user_count"
  )

  expect_equal(res$summary$selected_residual_col, "standardized_user_count_residual")
  expect_equal(
    res$area_level$selected_residual,
    c(-15, -5, 5, 15) / sqrt(20),
    tolerance = 1e-12
  )
})

test_that("validate_bias_residual_structure can return ggplot diagnostics", {
  testthat::skip_if_not_installed("ggplot2")

  coverage_df <- data.frame(
    area_id = c("A", "B", "C", "D"),
    population = c(100, 100, 100, 100),
    user_count = c(5, 15, 25, 35)
  )

  benchmark_od_df <- data.frame(
    origin = c("A", "B", "C", "D"),
    destination = c("D", "C", "B", "A"),
    flow = c(10, 20, 30, 40)
  )

  coordinates <- data.frame(
    area = c("A", "B", "C", "D"),
    x = c(0, 1, 0, 1),
    y = c(1, 1, 0, 0)
  )

  res <- validate_bias_residual_structure(
    coverage_df = coverage_df,
    coverage_area_col = "area_id",
    benchmark_od_df = benchmark_od_df,
    geometry_df = coordinates,
    x_col = "x",
    y_col = "y",
    make_plots = TRUE
  )

  expect_s3_class(res$plots$bias_residual_distribution, "ggplot")
  expect_s3_class(res$plots$bias_residual_vs_benchmark_flow, "ggplot")
  expect_s3_class(res$plots$bias_residual_map, "ggplot")
})

test_that("validate_bias_residual_structure validates optional inputs", {
  coverage_df <- data.frame(
    area_id = c("A", "A"),
    population = c(100, 100),
    user_count = c(5, 15)
  )

  expect_error(
    validate_bias_residual_structure(
      coverage_df = coverage_df,
      coverage_area_col = "area_id"
    ),
    "one row per area"
  )

  coverage_df <- data.frame(
    area_id = "A",
    population = 100,
    user_count = 5
  )

  expect_error(
    validate_bias_residual_structure(
      coverage_df = coverage_df,
      coverage_area_col = "area_id",
      covariate_col = "income"
    ),
    "`covariate_df` is required"
  )

  expect_error(
    validate_bias_residual_structure(
      coverage_df = coverage_df,
      coverage_area_col = "area_id",
      benchmark_od_df = data.frame(origin = "A", flow = 10)
    ),
    "`benchmark_od_df` must contain"
  )
})
