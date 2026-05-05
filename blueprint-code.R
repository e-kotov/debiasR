
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
usethis::use_vignette("adjust-inverse-penetration")  # creates vignettes/
usethis::use_data_raw()         # creates data-raw/

# 4. Create simulated package data
file.remove("data-raw/DATASET.R") # first remove existing suggestion
source("data-raw/build_simulated_data.R") # run once to create .rda files in data/
# Check that they load properly
devtools::load_all()
data(package = "debiasR")
devtools::document()
devtools::test()     # if you already added a test

# 5 Implement the inverse-penetration adjustment: create an R file in R/ and then run

adj <- adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, clip_max = 200)
head(adj)


# If this returns `Error in test_dir():`, run:
# 1) Ensure testthat is wired up (safe to run again)
usethis::use_testthat()

# 2) Create a test file for the inverse-penetration adjustment
usethis::use_test("adjust_inverse_penetration")
devtools::test()
devtools::check()

# quick sanity using the simulated package data
adj_o <- debiasR::adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, weight_by = "origin")
adj_d <- debiasR::adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, weight_by = "destination")
adj_b <- debiasR::adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, weight_by = "both")

# 3) Test validation functions
devtools::document()
devtools::load_all()

# After computing adjusted flows:
adj_o <- adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, weight_by = "origin")
adj_both <- adjust_inverse_penetration(simulated_mpd.od, simulated_coverage, weight_by = "both")

# Validate against benchmark:
val_o <- validate_flow_overall(adj_o, simulated_benchmark.od, by_source = TRUE)
val_d <- validate_flow_overall(adj_d, simulated_benchmark.od, by_source = TRUE)
val_b <- validate_flow_overall(adj_both, simulated_benchmark.od, by_source = TRUE)
str(val_o)


# 6 Implement selection-rate adjustment: create an R file in R/ and then run
devtools::document()
devtools::load_all()

data(simulated_mpd.od)
data(simulated_coverage)
data(simulated_covariates)
data(simulated_benchmark.od)

res <- adjust_selection_rate(
  simulated_mpd.od,
  simulated_coverage,
  covariates_df = simulated_covariates,
  income_col = "income_norm",
  r_global = NULL,
  weight_by = "origin",
  benchmark_od_df = simulated_benchmark.od,
  calibration_aggregate = "origin"
)

attr(res, "r_global")        # calibrated r_t*
attr(res, "r_calibration")   # grid search diagnostics


# 7 Implement the second selection-rate variant: create an R file in R/ and then run
devtools::document()
devtools::load_all()

data(simulated_mpd.od)
data(simulated_coverage)
data(simulated_covariates)
data(simulated_benchmark.od)

# Case (1) location only:
adj_m3.1 <- adjust_selection_rate2(
  simulated_mpd.od,
  simulated_coverage,
  weight_by = "origin",
  benchmark_od_df = simulated_benchmark.od,  # if available
  k_grid = seq(0.1, 3, 0.05)
)
attr(adj_m3.1, "k")

val_m3.1 <- validate_flow_overall(adj_m3.1, simulated_benchmark.od, by_source = TRUE)

# Case (2) age/sex

# adj_m3.2 <- adjust_selection_rate2(
#   mpd_od_df = simulated_mpd.od,
#   coverage_df = simulated_mpd.od,
#   weight_by = "origin",
#   group_cols = c("age_group", "sex"),
#   benchmark_od_df = bench_od_df,
#   k_grid = seq(0.1, 5, 0.1)
# )


# 8 Implement the raking-ratio adjustment: create an R file in R/ and then run
devtools::document()
devtools::load_all()

data(simulated_mpd.od)
data(simulated_benchmark.od)

res_rake_loc <- adjust_raking_ratio(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,  # derives origin/dest margins
  flow_col_bench  = "flow",
  max_iter        = 500,
  tol             = 1e-8
)

attr(res_rake_loc, "ipf_converged")

val_m4.1 <- validate_flow_overall(res_rake_loc, simulated_benchmark.od, by_source = TRUE)

# res_rake_strata <- adjust_raking_ratio(
#   mpd_od_df         = mpd_od_by_age_sex,
#   origin_targets    = origin_margins_by_age_sex,
#   destination_targets = dest_margins_by_age_sex,
#   group_cols        = c("age_group", "sex"),
#   max_iter          = 500,
#   tol               = 1e-7
# )

# Users can inspect two attributes that adjust_raking_ratio() automatically attaches to its output tibble:
attr(res_rake_loc, "ipf_converged")
attr(res_rake_loc, "ipf_iterations")


# 9 Implement the coefficient adjustment: create an R file in R/ and then run
  # implementing four options (ols, poisson, negbin, zinb)
devtools::document()
devtools::load_all()

data(simulated_mpd.od)
data(simulated_benchmark.od)

# OLS coefficient (Chi-style baseline)
res_ols <- adjust_coefficient(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,
  model_family    = "ols",
  level           = "od",      # regress on OD pairs
  fit_intercept   = FALSE,     # y = beta * x
  by_source       = FALSE
)

head(res_ols)
attr(res_ols, "coef")
attr(res_ols, "model")

# Global Poisson calibration

res_pois <- adjust_coefficient(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,
  model_family    = "poisson",
  level           = "od",
  by_source       = FALSE
)

attr(res_pois, "coef")   # beta = exp(intercept)
attr(res_pois, "model")  # summary row with n, beta, r^2, etc.

# Negative Binomial calibration
res_nb <- adjust_coefficient(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,
  model_family    = "negbin",
  level           = "od"
)

head(res_nb )
attr(res_nb , "coef")
attr(res_nb , "model")

# Zero-inflated Negative Binomial calibration
res_zinb <- adjust_coefficient(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,
  model_family    = "zinb",
  level           = "od"
)

head(res_zinb)
attr(res_zinb, "coef")
attr(res_zinb, "model")

# Coefficient by MPD source
res_by_source <- adjust_coefficient(
  mpd_od_df       = simulated_mpd.od,
  benchmark_od_df = simulated_benchmark.od,
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
devtools::test(filter = "adjust-selection-rate")
devtools::test(filter = "adjust-raking-ratio")
devtools::test(filter = "adjust_coefficient")
