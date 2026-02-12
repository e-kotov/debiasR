# tests/testthat/test-method1_inverse_penetration.R
# Updated to match the new coverage_df schema:
#   origin_population, origin_user_count,
#   destination_population, destination_user_count

test_that("origin weighting applies correct origin weights on toy data", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  # Run method
  res <- method1_inverse_penetration(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "origin"
  )

  expect_s3_class(res, "tbl_df")
  expect_true(all(c("origin", "destination", "flow_adj", "weight_origin") %in% names(res)))

  # Compute expected weight = origin_population / origin_user_count
  cov <- toy_coverage_df
  cov$w <- cov$origin_population / cov$origin_user_count

  # Join weights
  chk <- res |>
    dplyr::left_join(cov |> dplyr::select(origin, w), by = "origin")

  # Verify the applied weights equal expected
  expect_equal(chk$weight_origin, chk$w, tolerance = 1e-6)

  # flow_adj must equal flow * weight_origin
  expect_equal(chk$flow_adj, chk$flow * chk$weight_origin, tolerance = 1e-6)
})


test_that("destination weighting applies correct destination weights", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  res <- method1_inverse_penetration(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "destination"
  )

  expect_s3_class(res, "tbl_df")
  expect_true(all(c("destination", "flow_adj", "weight_destination") %in% names(res)))

  # Expected destination weight
  cov <- toy_coverage_df
  cov$w <- cov$destination_population / cov$destination_user_count

  chk <- res |>
    dplyr::left_join(cov |> dplyr::select(destination, w), by = "destination")

  expect_equal(chk$weight_destination, chk$w, tolerance = 1e-6)

  expect_equal(chk$flow_adj, chk$flow * chk$weight_destination, tolerance = 1e-6)
})


test_that("both-sides weighting uses geometric mean of origin and destination weights", {

  data(toy_mpd_od)
  data(toy_coverage_df)

  res <- method1_inverse_penetration(
    mpd_od_df   = toy_mpd_od,
    coverage_df = toy_coverage_df,
    weight_by   = "both"
  )

  expect_s3_class(res, "tbl_df")
  expect_true(all(c("flow_adj", "weight_origin", "weight_destination", "weight_both") %in% names(res)))

  cov <- toy_coverage_df |>
    dplyr::mutate(
      w_o = origin_population / origin_user_count,
      w_d = destination_population / destination_user_count,
      w_b = sqrt(w_o * w_d)
    )

  chk <- res |>
    dplyr::left_join(cov |> dplyr::select(origin, w_o), by = "origin") |>
    dplyr::left_join(cov |> dplyr::select(destination, w_d), by = "destination") |>
    dplyr::mutate(w_b = sqrt(w_o * w_d))

  # ensure both-side weights are correct
  expect_equal(chk$weight_both, chk$w_b, tolerance = 1e-6)

  # flow_adj must equal flow * weight_both
  expect_equal(chk$flow_adj, chk$flow * chk$weight_both, tolerance = 1e-6)
})
