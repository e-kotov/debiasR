locate_debiasr_root <- function() {
  candidate_roots <- c(".", "..", "../..")
  candidate_roots[file.exists(file.path(candidate_roots, "DESCRIPTION"))][1]
}

load_debiasr_workshop <- function() {
  pkg_root <- locate_debiasr_root()
  if (is.na(pkg_root)) {
    stop("Could not locate the debiasR package root.")
  }

  if (!requireNamespace("debiasR", quietly = TRUE)) {
    if (!requireNamespace("devtools", quietly = TRUE)) {
      stop("Install either `debiasR` or `devtools` to load the local package.")
    }
    devtools::load_all(pkg_root, quiet = TRUE)
  }

  suppressPackageStartupMessages({
    library(debiasR)
    library(dplyr)
  })

  invisible(pkg_root)
}

load_workshop_example <- function(n_areas = 25,
                                  complete_grid = TRUE,
                                  geography = "lad") {
  load_debiasr_workshop()

  if (!requireNamespace("debiasRdata", quietly = TRUE)) {
    cat(
      "Install `debiasRdata` to run the empirical MSOA travel-to-work examples. ",
      "Use `remotes::install_github(\"de-bias/debiasRdata\")`.\n",
      sep = ""
    )
    knitr::knit_exit()
  }

  tryCatch(
    debiasR::debiasR_example_data(
      n_areas = n_areas,
      complete_grid = complete_grid,
      geography = geography
    ),
    error = function(e) {
      cat(
        conditionMessage(e),
        "\nThe empirical vignette will render fully once `debiasRdata` exposes the required inputs.\n",
        sep = ""
      )
      knitr::knit_exit()
    }
  )
}

choose_bayes_area_count <- function(default_max_od_rows = 1600) {
  max_od_rows <- suppressWarnings(as.integer(Sys.getenv(
    "DEBIASR_BAYES_MAX_OD_ROWS",
    unset = as.character(default_max_od_rows)
  )))
  if (!is.finite(max_od_rows) || max_od_rows < 4L) {
    max_od_rows <- default_max_od_rows
  }
  max(2L, floor(sqrt(max_od_rows)))
}

validation_row <- function(method_name, adj_df, benchmark_od_df) {
  v <- debiasR::validate_flow_overall(
    adj_df = adj_df,
    benchmark_od_df = benchmark_od_df,
    method_name = method_name,
    return_joined = FALSE
  )

  tibble::tibble(
    method = method_name,
    n = v$n,
    pearson_r = v$pearson_r,
    spearman_rho = v$spearman_rho,
    rmse = v$rmse,
    mae = v$mae,
    mape = v$mape,
    r_squared = v$r_squared
  )
}

fit_adjustment_methods <- function(example_data) {
  mpd_od <- example_data$mpd_od
  benchmark_od <- example_data$benchmark_od
  coverage <- example_data$coverage
  covariates <- example_data$covariates

  list(
    inverse_penetration = debiasR::adjust_inverse_penetration(
      mpd_od_df = mpd_od,
      coverage_df = coverage,
      weight_by = "both"
    ),
    selection_rate = debiasR::adjust_selection_rate(
      mpd_od_df = mpd_od,
      coverage_df = coverage,
      covariates_df = covariates,
      income_col = "income_norm",
      weight_by = "origin",
      benchmark_od_df = benchmark_od,
      calibration_aggregate = "origin"
    ),
    selection_rate2 = debiasR::adjust_selection_rate2(
      mpd_od_df = mpd_od,
      coverage_df = coverage,
      weight_by = "origin",
      benchmark_od_df = benchmark_od,
      calibration_aggregate = "origin"
    ),
    raking_ratio = debiasR::adjust_raking_ratio(
      mpd_od_df = mpd_od,
      benchmark_od_df = benchmark_od
    ),
    coefficient = debiasR::adjust_coefficient(
      mpd_od_df = mpd_od,
      benchmark_od_df = benchmark_od,
      model_family = "ols",
      level = "od"
    )
  )
}
