test_that("validate_flow_pairs returns requested columns and differences", {
  adj_df <- data.frame(
    origin = c("A", "A", "B"),
    destination = c("B", "C", "C"),
    flow = c(100, 80, 40),
    flow_adj = c(90, 75, 50),
    mpd_source = c("src1", "src1", "src2")
  )

  benchmark_od_df <- data.frame(
    origin = c("A", "A", "B"),
    destination = c("B", "C", "C"),
    flow = c(95, 70, 55)
  )

  res <- validate_flow_pairs(adj_df, benchmark_od_df)

  expect_true(all(c(
    "origin",
    "destination",
    "mpd_source",
    "mpd_flow",
    "benchmark_flow",
    "adj_flow",
    "diff_mpd_benchmark",
    "diff_mpd_adj",
    "diff_adj_benchmark"
  ) %in% names(res)))

  expect_equal(res$mpd_flow, c(100, 80, 40))
  expect_equal(res$adj_flow, c(90, 75, 50))
  expect_equal(res$benchmark_flow, c(95, 70, 55))
  expect_equal(res$diff_mpd_benchmark, c(5, 10, -15))
  expect_equal(res$diff_mpd_adj, c(10, 5, -10))
  expect_equal(res$diff_adj_benchmark, c(-5, 5, -5))
})

test_that("validate_flow_pairs supports custom flow column names", {
  adj_df <- data.frame(
    origin = c("A"),
    destination = c("B"),
    mpd = c(10),
    adjusted = c(12)
  )
  benchmark_od_df <- data.frame(
    origin = c("A"),
    destination = c("B"),
    bench = c(11)
  )

  res <- validate_flow_pairs(
    adj_df = adj_df,
    benchmark_od_df = benchmark_od_df,
    flow_col_mpd = "mpd",
    flow_col_adj = "adjusted",
    flow_col_bench = "bench"
  )

  expect_equal(res$mpd_flow, 10)
  expect_equal(res$adj_flow, 12)
  expect_equal(res$benchmark_flow, 11)
  expect_equal(res$diff_mpd_benchmark, -1)
  expect_equal(res$diff_mpd_adj, -2)
  expect_equal(res$diff_adj_benchmark, 1)
})

test_that("validate_flow_pairs errors on missing required columns", {
  adj_df <- data.frame(
    origin = "A",
    destination = "B",
    flow = 10
  )
  benchmark_od_df <- data.frame(
    origin = "A",
    destination = "B",
    flow = 11
  )

  expect_error(
    validate_flow_pairs(adj_df, benchmark_od_df),
    regexp = "`adj_df` must contain"
  )

  adj_df$flow_adj <- 12
  benchmark_bad <- benchmark_od_df[, c("origin", "flow")]

  expect_error(
    validate_flow_pairs(adj_df, benchmark_bad),
    regexp = "`benchmark_od_df` must contain"
  )
})

test_that("validate_flow_all remains an alias for validate_flow_pairs", {
  adj_df <- data.frame(
    origin = c("A"),
    destination = c("B"),
    flow = c(10),
    flow_adj = c(12)
  )

  benchmark_od_df <- data.frame(
    origin = c("A"),
    destination = c("B"),
    flow = c(11)
  )

  expect_equal(
    validate_flow_all(adj_df, benchmark_od_df),
    validate_flow_pairs(adj_df, benchmark_od_df)
  )
})
