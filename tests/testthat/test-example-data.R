test_that("debiasR_example_data normalises empirical travel-to-work files", {
  mpd_path <- tempfile(fileext = ".csv")
  census_path <- tempfile(fileext = ".csv")

  utils::write.csv(
    data.frame(
      origin = c("E06000001", "E06000001", "E06000002", "E06000003"),
      destination = c("E06000001", "E06000002", "E06000001", "E06000003"),
      flow = c(10, 4, 5, 1)
    ),
    mpd_path,
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      `Lower tier local authorities code` = c(
        "E06000001", "E06000001", "E06000002", "E06000003", "E06000001"
      ),
      `Lower tier local authorities label` = "area",
      `LTLA of workplace code` = c(
        "E06000001", "E06000002", "E06000001", "E06000003", "999999999"
      ),
      `LTLA of workplace label` = "work",
      `Place of work indicator (4 categories) code` = c(3, 3, 3, 1, 2),
      `Place of work indicator (4 categories) label` = "label",
      Count = c(100, 25, 50, 200, 999),
      check.names = FALSE
    ),
    census_path,
    row.names = FALSE
  )

  ex <- debiasR_example_data(
    n_areas = Inf,
    mpd_path = mpd_path,
    census_path = census_path
  )

  expect_named(
    ex,
    c(
      "mpd_od",
      "benchmark_od",
      "coverage",
      "active_users",
      "population",
      "covariates",
      "distance",
      "od_audit",
      "metadata",
      "lad_OD_travel2work",
      "census_lad_OD_travel2work"
    )
  )
  expect_equal(nrow(ex$mpd_od), 3)
  expect_equal(nrow(ex$benchmark_od), 3)
  expect_true(all(c("origin", "destination", "flow") %in% names(ex$benchmark_od)))
  expect_false("999999999" %in% ex$benchmark_od$destination)

  coverage_1 <- ex$coverage[ex$coverage$origin == "E06000001", ]
  expect_equal(coverage_1$population, 125)
  expect_equal(coverage_1$user_count, 14)
  expect_equal(coverage_1$mpd_source, "locomizer_travel_to_work_lad")
  expect_equal(ex$metadata$geography, "lad")
})

test_that("debiasR_example_data returns real debiasRdata covariates when available", {
  testthat::skip_if_not_installed("debiasRdata")

  ex <- debiasR_example_data(
    n_areas = 5,
    complete_grid = TRUE,
    geography = "lad"
  )

  expect_equal(ex$metadata$covariate_source, "debiasRdata::lad_covariates")
  expect_identical(sort(ex$covariates$area), sort(ex$coverage$origin))
  expect_equal(anyDuplicated(ex$covariates$area), 0L)
  expect_true(all(c(
    "name",
    "year",
    "per_age_20.29",
    "per_age_70plus",
    "per_level4",
    "rural_pct"
  ) %in% names(ex$covariates)))
  expect_false("income_norm" %in% names(ex$covariates))
})

test_that("debiasR_example_data can return strict complete square OD support", {
  mpd_path <- tempfile(fileext = ".csv")
  census_path <- tempfile(fileext = ".csv")

  utils::write.csv(
    data.frame(
      origin = c("E06000001", "E06000001", "E06000002", "E06000003"),
      destination = c("E06000001", "E06000002", "E06000001", "E06000003"),
      count = c(10, 4, 5, 1)
    ),
    mpd_path,
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      `Lower tier local authorities code` = c(
        "E06000001", "E06000001", "E06000002", "E06000003"
      ),
      `LTLA of workplace code` = c(
        "E06000001", "E06000002", "E06000001", "E06000003"
      ),
      `Place of work indicator (4 categories) code` = c(3, 3, 3, 1),
      Count = c(100, 25, 50, 200),
      check.names = FALSE
    ),
    census_path,
    row.names = FALSE
  )

  ex <- debiasR_example_data(
    n_areas = Inf,
    mpd_path = mpd_path,
    census_path = census_path,
    complete_grid = TRUE
  )

  areas_mpd_o <- sort(unique(ex$mpd_od$origin))
  areas_mpd_d <- sort(unique(ex$mpd_od$destination))
  areas_bench_o <- sort(unique(ex$benchmark_od$origin))
  areas_bench_d <- sort(unique(ex$benchmark_od$destination))

  expect_identical(areas_mpd_o, areas_mpd_d)
  expect_identical(areas_mpd_o, areas_bench_o)
  expect_identical(areas_mpd_o, areas_bench_d)
  expect_equal(nrow(ex$mpd_od), length(areas_mpd_o)^2)
  expect_equal(nrow(ex$benchmark_od), length(areas_mpd_o)^2)
  expect_false(any(duplicated(ex$mpd_od[c("origin", "destination")])))
  expect_false(any(duplicated(ex$benchmark_od[c("origin", "destination")])))
  expect_true(all(is.finite(ex$mpd_od$flow) & ex$mpd_od$flow >= 0))
  expect_true(all(is.finite(ex$benchmark_od$flow) & ex$benchmark_od$flow >= 0))
  expect_true(any(ex$mpd_od$mpd_zero_filled))
  expect_true(any(ex$benchmark_od$benchmark_zero_filled))
  expect_true(ex$od_audit$strict_square_support)
  expect_equal(ex$metadata$n_mpd_zero_filled, sum(ex$mpd_od$mpd_zero_filled))
  expect_equal(ex$metadata$mpd_total_flow, sum(ex$mpd_od$flow))
  expect_equal(ex$metadata$benchmark_total_flow, sum(ex$benchmark_od$flow))
  expect_equal(ex$metadata$mpd_balance_diff, 0)
  expect_equal(ex$metadata$benchmark_balance_diff, 0)
})

test_that("optional example distances can be derived from real centroids", {
  centroids <- data.frame(
    lad21cd = c("E06000001", "E06000002", "E06000003"),
    longitude = c(-1.27018, -1.21099, -1.00608),
    latitude = c(54.67614, 54.54467, 54.56752)
  )

  out <- .build_example_centroid_distance(
    .normalise_example_centroids(
      centroids,
      areas = c("E06000001", "E06000002", "E06000003")
    ),
    areas = c("E06000001", "E06000002", "E06000003"),
    include_self_flows = TRUE,
    distance_source = "debiasRdata_lad_centroids"
  )

  expect_named(out, c("origin", "destination", "distance_km", "distance_source"))
  expect_equal(nrow(out), 9)
  expect_true(all(out$distance_km >= 0))
  expect_equal(out$distance_source, rep("debiasRdata_lad_centroids", 9))
  expect_equal(
    out$distance_km[out$origin == out$destination],
    rep(0, 3),
    tolerance = 1e-8
  )
})

test_that("optional example distance objects convert metre columns to kilometres", {
  out <- .normalise_example_distance(
    data.frame(
      origin = "E02000001",
      destination = "E02000002",
      distance_m = 2500
    ),
    areas = c("E02000001", "E02000002"),
    include_self_flows = TRUE
  )

  expect_equal(out$distance_km, 2.5)
  expect_equal(out$distance_source, "debiasRdata")
})

test_that("default LAD geography rejects MSOA-shaped explicit inputs", {
  mpd_path <- tempfile(fileext = ".csv")
  census_path <- tempfile(fileext = ".csv")

  utils::write.csv(
    data.frame(
      origin = c("E02000001", "E02000001"),
      destination = c("E02000001", "E02000002"),
      flow = c(10, 4)
    ),
    mpd_path,
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      origin = c("E02000001", "E02000001"),
      destination = c("E02000001", "E02000002"),
      flow = c(100, 25)
    ),
    census_path,
    row.names = FALSE
  )

  expect_error(
    debiasR_example_data(
      n_areas = Inf,
      mpd_path = mpd_path,
      census_path = census_path
    ),
    "No overlapping LAD/LTLA codes"
  )
})
