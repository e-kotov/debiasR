locate_debiasr_root <- function() {
  if (exists("debiasr_pkg_root", inherits = TRUE)) {
    candidate_root <- get("debiasr_pkg_root", inherits = TRUE)
    if (file.exists(file.path(candidate_root, "DESCRIPTION"))) {
      return(candidate_root)
    }
  }

  candidate_roots <- c(".", "..", "../..")
  candidate_roots[file.exists(file.path(candidate_roots, "DESCRIPTION"))][1]
}

load_debiasr_workshop <- function() {
  pkg_root <- locate_debiasr_root()
  if (is.na(pkg_root)) {
    stop("Could not locate the debiasR package root.")
  }

  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(pkg_root, quiet = TRUE)
  } else if (!requireNamespace("debiasR", quietly = TRUE)) {
    stop("Install either `debiasR` or `devtools` to load the local package.")
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

fit_adjustment_methods <- function(example_data,
                                   include_multilevel = FALSE,
                                   multilevel_engine = "frequentist",
                                   covariate_col = "rural_pct") {
  mpd_od <- example_data$mpd_od
  benchmark_od <- example_data$benchmark_od
  coverage <- example_data$coverage
  covariates <- example_data$covariates

  method_results <- list(
    inverse_penetration = debiasR::adjust_inverse_penetration(
      mpd_od_df = mpd_od,
      coverage_df = coverage,
      weight_by = "both"
    ),
    selection_rate = debiasR::adjust_selection_rate(
      mpd_od_df = mpd_od,
      coverage_df = coverage,
      covariates_df = covariates,
      covariate_col = covariate_col,
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

  if (isTRUE(include_multilevel)) {
    if (!"distance" %in% names(example_data) || nrow(example_data$distance) == 0L) {
      stop("`include_multilevel = TRUE` requires OD distance inputs.")
    }

    mpd_s1 <- mpd_od
    if (!"mpd_source" %in% names(mpd_s1)) {
      mpd_s1$mpd_source <- "operator_a"
    }
    mpd_s1$mpd_time <- "2021_q1"

    coverage_s1 <- coverage
    if (!"mpd_source" %in% names(coverage_s1)) {
      coverage_s1$mpd_source <- "operator_a"
    }
    coverage_s1$mpd_time <- "2021_q1"

    method_results$multilevel_bayes <- debiasR::adjust_multilevel_bayes(
      mpd_od_df = mpd_s1,
      coverage_df = coverage_s1,
      covariates_df = covariates,
      distance_df = example_data$distance,
      income_col = covariate_col,
      model_engine = multilevel_engine,
      scenario = "s1",
      source_col = "mpd_source",
      time_col = "mpd_time",
      repeated_observation = "none",
      prediction_scope = "complete_grid",
      random_intercept = "none",
      model_family = "poisson",
      flow_adj_summary = "median"
    )
  }

  method_results
}
