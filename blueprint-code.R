
# 1. Create the package skeleton
library(usethis)

# Create package
create_package("debiasR")

# Move into it
setwd("debiasR")

# Initialize Git and link to GitHub
use_git()
use_github()  # optional but recommended for collaboration

# 2. Edit DESCRIPTION
read.dcf("DESCRIPTION")  # should parse without error
usethis::use_mit_license("Francisco Rowe & Carmen Cabrera")

# 3. Add supporting folders
usethis::use_package_doc()      # will create man/
usethis::use_testthat()         # creates tests/
usethis::use_vignette("debias-method1")  # creates vignettes/
usethis::use_data_raw()         # creates data-raw/

# 4. Create a toy data set
file.remove("data-raw/DATASET.R") # first remove existing suggestion
source("data-raw/build_toy_data.R") # run once to create .rda files in data/
# Check that they load properly
devtools::load_all()
data(package = "debiasR")

# 5 Implement Method 1 function: create a R file in R/ and then run
devtools::document()
devtools::load_all()
data(toy_mpd_od); data(toy_coverage_df)
adj <- method1_inverse_penetration(toy_mpd_od, toy_coverage_df, clip_max = 200)
head(adj)

devtools::test()     # if you already added a test
# If this returns: `Error in `test_dir()`:`, run:
# 1) Ensure testthat is wired up (safe to run again)
usethis::use_testthat()

# 2) Create a test file for Method 1
usethis::use_test("method1_inverse_penetration")
devtools::test()
devtools::check()

# quick sanity using your realistic toy data
adj_o <- debiasR::method1_inverse_penetration(toy_mpd_od, toy_coverage_df, weight_by = "origin")
adj_d <- debiasR::method1_inverse_penetration(toy_mpd_od, toy_coverage_df, weight_by = "destination")
adj_b <- debiasR::method1_inverse_penetration(toy_mpd_od, toy_coverage_df, weight_by = "both")

# 3) Test validate flows
devtools::document()
devtools::load_all()

# After computing adjusted flows:
adj_o <- method1_inverse_penetration(toy_mpd_od, toy_coverage_df, weight_by = "origin")
adj_both <- method1_inverse_penetration(toy_mpd_od, toy_coverage_df, weight_by = "both")

# Validate against benchmark:
val_o <- validate_flows(adj_o, toy_benchmark_od, by_source = TRUE)
val_d <- validate_flows(adj_d, toy_benchmark_od, by_source = TRUE)
val_b <- validate_flows(adj_both, toy_benchmark_od, by_source = TRUE)
str(val_o)


# 6 Implement Method 2 function: create a R file in R/ and then run
devtools::document()
devtools::load_all()

data(toy_mpd_od)
data(toy_coverage_df)
data(toy_covariates_df)
data(toy_benchmark_od)

res <- method2_selection_rate(
  toy_mpd_od,
  toy_coverage_df,
  covariates_df = toy_covariates_df,
  income_col = "income_norm",
  r_global = NULL,
  weight_by = "origin",
  benchmark_od_df = toy_benchmark_od,
  calibration_aggregate = "origin"
)

attr(res, "r_global")        # calibrated r_t*
attr(res, "r_calibration")   # grid search diagnostics


# 7 Implement Method 3 function: create a R file in R/ and then run
devtools::document()
devtools::load_all()

data(toy_mpd_od)
data(toy_coverage_df)
data(toy_covariates_df)
data(toy_benchmark_od)

# Case (1) location only:
adj_m3.1 <- method3_selection_rateII(
  toy_mpd_od,
  toy_coverage_df,
  weight_by = "origin",
  benchmark_od_df = toy_benchmark_od,  # if available
  k_grid = seq(0.1, 3, 0.05)
)
attr(adj_m3.1, "k")

val_m3.1 <- validate_flows(adj_m3.1, toy_benchmark_od, by_source = TRUE)

# Case (2) age/sex

adj_m3.2 <- method3_selection_rateII(
  mpd_od_df,
  coverage_df,
  weight_by = "origin",
  group_cols = c("age_group", "sex"),
  benchmark_od_df = bench_od_df,
  k_grid = seq(0.1, 5, 0.1)
)


# 8 Implement Method 4 function (raking_ratio): create a R file in R/ and then run
devtools::document()
devtools::load_all()

data(toy_mpd_od)
data(toy_benchmark_od)

res_rake_loc <- method4_raking_ratio(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,  # derives origin/dest margins
  flow_col_bench  = "flow",
  max_iter        = 500,
  tol             = 1e-8
)

attr(res_rake_loc, "ipf_converged")

val_m4.1 <- validate_flows(res_rake_loc, toy_benchmark_od, by_source = TRUE)

res_rake_strata <- method4_raking_ratio(
  mpd_od_df         = mpd_od_by_age_sex,
  origin_targets    = origin_margins_by_age_sex,
  destination_targets = dest_margins_by_age_sex,
  group_cols        = c("age_group", "sex"),
  max_iter          = 500,
  tol               = 1e-7
)

# Users can inspect two attributes that method4_raking_ratio() automatically attaches to its output tibble:
attr(res_rake_loc, "ipf_converged")
attr(res_rake_loc, "ipf_iterations")


# 9 Implement Method 5 function (regression coefficient): create a R file in R/ and then run
  # implementing four options (ols, poisson, negbin, zinb)
devtools::document()
devtools::load_all()

data(toy_mpd_od)
data(toy_benchmark_od)

# OLS coefficient (Chi-style baseline)
res_ols <- method5_coefficient(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,
  model_family    = "ols",
  level           = "od",      # regress on OD pairs
  fit_intercept   = FALSE,     # y = beta * x
  by_source       = FALSE
)

head(res_ols)
attr(res_ols, "coef")
attr(res_ols, "model")

# Global Poisson calibration

res_pois <- method5_coefficient(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,
  model_family    = "poisson",
  level           = "od",
  by_source       = FALSE
)

attr(res_pois, "coef")   # beta = exp(intercept)
attr(res_pois, "model")  # summary row with n, beta, r^2, etc.

# Negative Binomial calibration
res_nb <- method5_coefficient(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,
  model_family    = "negbin",
  level           = "od"
)

head(res_nb )
attr(res_nb , "coef")
attr(res_nb , "model")

# Zero-inflated Negative Binomial calibration
res_zinb <- method5_coefficient(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,
  model_family    = "zinb",
  level           = "od"
)

head(res_zinb)
attr(res_zinb, "coef")
attr(res_zinb, "model")

# Coefficient by MPD source
res_by_source <- method5_coefficient(
  mpd_od_df       = toy_mpd_od,
  benchmark_od_df = toy_benchmark_od,
  model_family    = "ols",
  level           = "od",
  by_source       = FALSE
)

attr(res_by_source, "coef")   # tibble of beta per mpd_source
attr(res_by_source, "model")  # same, with n and r_squared

# Inspecting the fitted relation

mod_info <- attr(res_nb, "model")
mod_info
# columns: mpd_source, n, beta, intercept, r_squared, family, level

summary_beta <- attr(res_nb, "coef")
summary_beta


# Run any test function in `testthat`
devtools::test(filter = "method2-selection-rate")
devtools::test(filter = "method4-raking-ratio")
devtools::test(filter = "method5_coefficient")
