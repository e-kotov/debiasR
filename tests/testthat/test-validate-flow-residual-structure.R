test_that("validate_flow_residual_structure returns correlations and Morans I", {
  adj_df <- data.frame(
    origin = c("A", "B", "C", "D", "A", "B", "C", "D"),
    destination = c("X", "X", "X", "X", "Y", "Y", "Y", "Y"),
    flow = c(9, 21, 31, 41, 10, 20, 30, 40),
    flow_adj = c(11, 21, 29, 39, 10, 20, 30, 40)
  )

  benchmark_od_df <- data.frame(
    origin = c("A", "B", "C", "D", "A", "B", "C", "D"),
    destination = c("X", "X", "X", "X", "Y", "Y", "Y", "Y"),
    flow = c(10, 20, 30, 40, 10, 20, 30, 40)
  )

  area_neighbors <- data.frame(
    area = c("A", "B", "C", "D"),
    neighbor = c("B", "A", "D", "C")
  )

  covariates <- data.frame(
    area = c("A", "B", "C", "D"),
    cov = c(1, 2, 3, 4)
  )

  res <- validate_flow_residual_structure(
    adj_df = adj_df,
    benchmark_od_df = benchmark_od_df,
    method_name = "demo_method",
    area_neighbors = area_neighbors,
    covariate_df = covariates,
    covariate_col = "cov"
  )

  expect_true(all(c(
    "summary",
    "flow_correlation",
    "moran_i",
    "covariate_correlation",
    "od_level",
    "area_level",
    "map_data",
    "covariate_data"
  ) %in% names(res)))

  expect_equal(res$summary$method, "demo_method")
  expect_equal(res$summary$n_od_pairs, 8)
  expect_equal(res$summary$n_areas, 4)
  expect_equal(res$area_level$n_od_pairs, c(2, 2, 2, 2))
  expect_equal(res$area_level$selected_residual, c(0.5, 0.5, -0.5, -0.5))
  expect_equal(res$moran_i$moran_i, 1)
  expect_equal(round(res$flow_correlation$pearson_r, 4), -0.6325)
  expect_equal(round(res$covariate_correlation$pearson_r, 4), -0.8944)
})

test_that("validate_flow_residual_structure can return ggplot diagnostics", {
  testthat::skip_if_not_installed("ggplot2")

  adj_df <- data.frame(
    origin = c("A", "B", "C", "D"),
    destination = "X",
    flow = c(9, 21, 31, 41),
    flow_adj = c(11, 21, 29, 39)
  )

  benchmark_od_df <- data.frame(
    origin = c("A", "B", "C", "D"),
    destination = "X",
    flow = c(10, 20, 30, 40)
  )

  coordinates <- data.frame(
    area = c("A", "B", "C", "D"),
    x = c(0, 1, 0, 1),
    y = c(1, 1, 0, 0)
  )

  res <- validate_flow_residual_structure(
    adj_df = adj_df,
    benchmark_od_df = benchmark_od_df,
    geometry_df = coordinates,
    x_col = "x",
    y_col = "y",
    make_plots = TRUE
  )

  expect_s3_class(res$plots$residual_reduction_distribution, "ggplot")
  expect_s3_class(res$plots$residual_vs_benchmark, "ggplot")
  expect_s3_class(res$plots$residual_map, "ggplot")
})

test_that("validate_flow_residual_structure validates optional inputs", {
  adj_df <- data.frame(
    origin = "A",
    destination = "B",
    flow = 10,
    flow_adj = 12
  )

  benchmark_od_df <- data.frame(
    origin = "A",
    destination = "B",
    flow = 11
  )

  expect_error(
    validate_flow_residual_structure(
      adj_df,
      benchmark_od_df,
      covariate_col = "income"
    ),
    "`covariate_df` is required"
  )

  expect_error(
    validate_flow_residual_structure(
      adj_df,
      benchmark_od_df,
      area_neighbors = data.frame(area = "A")
    ),
    "`area_neighbors` must contain"
  )
})
