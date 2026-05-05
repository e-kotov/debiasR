#' @title Measure Coverage Bias
#'
#' @description
#' Computes area-level coverage quantities from active users and population.
#' The primary bias measure is defined as:
#' \deqn{coverage\_bias_i = 1 - \frac{U_i}{P_i}}
#' where \eqn{U_i} is user count and \eqn{P_i} is population in area \eqn{i}.
#' The function also returns:
#' \deqn{coverage\_score_i = \frac{U_i}{P_i}}
#'
#' @param coverage_df A data frame with one row per area, containing the following columns:
#'   \itemize{
#'     \item \code{population} — Benchmark population count for the area.
#'     \item \code{user_count} — Number of active users from mobile phone data.
#'   }
#'
#' @return
#' The input \code{coverage_df} with an added column:
#' \itemize{
#'   \item \code{coverage_bias} — Defined as \code{1 - user_count / population}.
#'   \item \code{coverage_score} — Defined as \code{user_count / population}
#'         (1 indicates full coverage, 0 indicates no coverage).
#'   \item \code{bias} — Backward-compatible alias of \code{coverage_bias}.
#' }
#'
#' @details
#' This function does not rescale or cap values.
#' If \code{coverage_score > 1}, a warning is issued, as this indicates user counts exceeding
#' benchmark population for that area (possible if benchmarks are not accurate, users are
#' overcounted or definitions differ).
#'
#' @examples
#' data(simulated_active.users)
#' data(simulated_pop)
#' coverage_df <- merge(
#'   simulated_pop,
#'   simulated_active.users[c("origin", "user_count")],
#'   by = "origin"
#' )
#' measure_bias(coverage_df)
#'
#' @export
measure_bias <- function(coverage_df) {
  # ---- Input validation ----
  required_cols <- c("population", "user_count")
  missing_cols <- setdiff(required_cols, names(coverage_df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  if (any(is.na(coverage_df$population))) {
    stop("population contains NA values; cannot compute coverage bias.")
  }
  if (any(coverage_df$population <= 0, na.rm = TRUE)) {
    stop("population must be positive to compute coverage bias.")
  }
  if (any(coverage_df$user_count < 0, na.rm = TRUE)) {
    stop("user_count must be non-negative.")
  }

  # ---- Compute coverage quantities ----
  coverage_df$coverage_score <- coverage_df$user_count / coverage_df$population
  coverage_df$coverage_bias <- 1 - coverage_df$coverage_score
  coverage_df$bias <- coverage_df$coverage_bias

  # Warn if coverage exceeds 100%
  if (any(coverage_df$coverage_score > 1, na.rm = TRUE)) {
    warning("One or more areas have coverage_score > 1 (user_count exceeds population). Check inputs or definitions.")
  }

  return(coverage_df)
}

.normalise_benchmark_flow_roles <- function(benchmark_flow_roles) {
  if (is.null(benchmark_flow_roles) || length(benchmark_flow_roles) == 0L) {
    return(character())
  }

  if (length(benchmark_flow_roles) == 1L && identical(benchmark_flow_roles, "both")) {
    return(c("origin", "destination"))
  }

  valid_roles <- c("origin", "destination")
  invalid_roles <- setdiff(benchmark_flow_roles, valid_roles)
  if (length(invalid_roles) > 0L) {
    stop("`benchmark_flow_roles` must contain only 'origin', 'destination', or 'both'.")
  }

  unique(benchmark_flow_roles)
}

.first_or_na_real <- function(x) {
  if (length(x) == 0L) {
    return(NA_real_)
  }
  x[1]
}

#' Validate Bias Residual Structure
#'
#' @description
#' Builds Stage 3 diagnostics for active-user coverage residuals. The helper
#' starts from the same coverage quantities as \code{measure_bias()}, computes a
#' global coverage score, and returns area-level residuals plus optional
#' spatial, benchmark-flow, covariate, and plotting diagnostics.
#'
#' The default residual is:
#' \deqn{coverage\_score\_residual_i =
#'       \frac{user\_count_i}{population_i} -
#'       \frac{\sum_i user\_count_i}{\sum_i population_i}}
#'
#' Positive values mean an area has higher active-user coverage than expected
#' under a constant global coverage rate. Negative values mean lower coverage
#' than expected under that global rate.
#'
#' @param coverage_df A data frame with one row per area and columns containing
#'   an area identifier, benchmark population, and active-user count.
#' @param coverage_area_col Column in \code{coverage_df} identifying the area.
#'   Default \code{"origin"}.
#' @param population_col Population column in \code{coverage_df}. Default
#'   \code{"population"}.
#' @param user_count_col Active-user count column in \code{coverage_df}. Default
#'   \code{"user_count"}.
#' @param residual_type Residual series to diagnose:
#'   \code{"coverage_score"} uses the coverage score minus the global coverage
#'   score, \code{"user_count"} uses observed minus expected user counts, and
#'   \code{"standardized_user_count"} uses the user-count residual divided by
#'   \code{sqrt(expected_user_count)}.
#' @param benchmark_od_df Optional benchmark OD data frame. When supplied,
#'   benchmark flows are collapsed to area-level origin and/or destination
#'   totals and correlated with the selected bias residual.
#' @param origin_col Origin column in \code{benchmark_od_df}. Default
#'   \code{"origin"}.
#' @param destination_col Destination column in \code{benchmark_od_df}. Default
#'   \code{"destination"}.
#' @param flow_col_bench Benchmark flow column in \code{benchmark_od_df}.
#'   Default \code{"flow"}.
#' @param benchmark_flow_roles Which benchmark area totals to compute:
#'   \code{"origin"}, \code{"destination"}, or \code{"both"}. The default
#'   \code{c("origin", "destination")} returns both separately.
#' @param area_neighbors Optional neighbour table for Moran's I.
#' @param area_col Column in \code{area_neighbors} identifying the focal area.
#'   Default \code{"area"}.
#' @param neighbor_col Column in \code{area_neighbors} identifying the
#'   neighbouring area. Default \code{"neighbor"}.
#' @param weight_col Optional positive numeric weight column in
#'   \code{area_neighbors}. If \code{NULL}, all neighbour links receive weight 1.
#' @param covariate_df Optional area-level covariate table.
#' @param covariate_col Optional covariate column to correlate with area-level
#'   bias residuals. Requires \code{covariate_df}.
#' @param covariate_area_col Area key in \code{covariate_df}. Default
#'   \code{"area"}.
#' @param geometry_df Optional area table with coordinates or geometry-like
#'   columns to join onto \code{map_data}.
#' @param geometry_area_col Area key in \code{geometry_df}. Default
#'   \code{"area"}.
#' @param x_col Optional x-coordinate column in \code{map_data}, used only when
#'   \code{make_plots = TRUE}.
#' @param y_col Optional y-coordinate column in \code{map_data}, used only when
#'   \code{make_plots = TRUE}.
#' @param make_plots Logical. If \code{TRUE}, return ggplot objects for the
#'   selected residual distribution, optional residual-versus-benchmark-flow
#'   scatter, optional residual-versus-covariate scatter, and optional
#'   coordinate residual map. Requires \pkg{ggplot2}.
#'
#' @return A list with:
#' \itemize{
#'   \item \code{summary}: one-row tibble with global coverage, residual spread,
#'     Moran's I, and benchmark-flow/covariate correlations when available,
#'   \item \code{residual_definitions}: definitions and sign interpretations,
#'   \item \code{moran_i}: Moran's I summary from the neighbour table, or
#'     \code{NA} when no neighbour table is supplied,
#'   \item \code{benchmark_flow_correlation}: Pearson correlations between the
#'     selected bias residual and benchmark origin/destination flow totals when
#'     benchmark OD data are supplied,
#'   \item \code{covariate_correlation}: optional Pearson correlation between
#'     selected bias residuals and the selected covariate,
#'   \item \code{area_level}: area-level residual table,
#'   \item \code{map_data}: area-level residual table joined to
#'     \code{geometry_df} when supplied,
#'   \item \code{benchmark_flow_data}, \code{covariate_data}, and
#'     \code{plots}: optional review-ready outputs when requested.
#' }
#'
#' @examples
#' data(simulated_coverage)
#' data(simulated_benchmark.od)
#' data(simulated_covariates)
#'
#' validate_bias_residual_structure(
#'   coverage_df = simulated_coverage,
#'   benchmark_od_df = simulated_benchmark.od,
#'   covariate_df = simulated_covariates,
#'   covariate_col = "internet_access"
#' )
#'
#' @export
validate_bias_residual_structure <- function(coverage_df,
                                             coverage_area_col = "origin",
                                             population_col = "population",
                                             user_count_col = "user_count",
                                             residual_type = c(
                                               "coverage_score",
                                               "user_count",
                                               "standardized_user_count"
                                             ),
                                             benchmark_od_df = NULL,
                                             origin_col = "origin",
                                             destination_col = "destination",
                                             flow_col_bench = "flow",
                                             benchmark_flow_roles = c("origin", "destination"),
                                             area_neighbors = NULL,
                                             area_col = "area",
                                             neighbor_col = "neighbor",
                                             weight_col = NULL,
                                             covariate_df = NULL,
                                             covariate_col = NULL,
                                             covariate_area_col = "area",
                                             geometry_df = NULL,
                                             geometry_area_col = "area",
                                             x_col = NULL,
                                             y_col = NULL,
                                             make_plots = FALSE) {

  residual_type <- match.arg(residual_type)
  residual_type_label <- residual_type
  benchmark_flow_roles <- .normalise_benchmark_flow_roles(benchmark_flow_roles)

  if (make_plots && !requireNamespace("ggplot2", quietly = TRUE)) {
    stop("`make_plots = TRUE` requires the ggplot2 package.")
  }
  if (!is.null(covariate_col) && is.null(covariate_df)) {
    stop("`covariate_df` is required when `covariate_col` is supplied.")
  }

  req_coverage <- c(coverage_area_col, population_col, user_count_col)
  if (!all(req_coverage %in% names(coverage_df))) {
    stop("`coverage_df` must contain: ", paste(req_coverage, collapse = ", "))
  }

  coverage_tbl <- coverage_df |>
    dplyr::select(
      area = dplyr::all_of(coverage_area_col),
      population = dplyr::all_of(population_col),
      user_count = dplyr::all_of(user_count_col)
    )

  if (any(is.na(coverage_tbl$area))) {
    stop("`coverage_area_col` contains NA values; areas must be identifiable.")
  }
  if (anyDuplicated(coverage_tbl$area) > 0L) {
    stop("`coverage_df` must contain one row per area for bias residual diagnostics.")
  }
  if (any(is.na(coverage_tbl$user_count))) {
    stop("`user_count_col` contains NA values; cannot compute coverage residuals.")
  }

  coverage_tbl <- measure_bias(coverage_tbl)

  total_population <- sum(coverage_tbl$population)
  total_user_count <- sum(coverage_tbl$user_count)
  global_coverage_score <- total_user_count / total_population

  area_level <- coverage_tbl |>
    dplyr::mutate(
      global_coverage_score = global_coverage_score,
      expected_user_count = .data$population * .data$global_coverage_score,
      user_count_residual = .data$user_count - .data$expected_user_count,
      coverage_score_residual = .data$coverage_score - .data$global_coverage_score,
      standardized_user_count_residual = dplyr::if_else(
        .data$expected_user_count > 0,
        .data$user_count_residual / sqrt(.data$expected_user_count),
        NA_real_
      )
    )

  selected_residual_col <- switch(
    residual_type_label,
    coverage_score = "coverage_score_residual",
    user_count = "user_count_residual",
    standardized_user_count = "standardized_user_count_residual"
  )

  area_level <- area_level |>
    dplyr::mutate(
      residual_type = residual_type_label,
      selected_residual = .data[[selected_residual_col]]
    )

  benchmark_flow_data <- NULL
  benchmark_flow_correlation <- tibble::tibble(
    residual_type = residual_type_label,
    benchmark_flow_role = character(),
    n = integer(),
    pearson_r = double()
  )

  if (!is.null(benchmark_od_df)) {
    req_benchmark <- c(origin_col, destination_col, flow_col_bench)
    if (!all(req_benchmark %in% names(benchmark_od_df))) {
      stop("`benchmark_od_df` must contain: ", paste(req_benchmark, collapse = ", "))
    }

    benchmark_tbl <- benchmark_od_df |>
      dplyr::select(
        origin = dplyr::all_of(origin_col),
        destination = dplyr::all_of(destination_col),
        benchmark_flow = dplyr::all_of(flow_col_bench)
      )

    benchmark_flow_tables <- list()

    if ("origin" %in% benchmark_flow_roles) {
      origin_totals <- benchmark_tbl |>
        dplyr::group_by(area = .data$origin) |>
        dplyr::summarise(
          benchmark_origin_flow_total = sum(.data$benchmark_flow, na.rm = TRUE),
          .groups = "drop"
        )

      area_level <- area_level |>
        dplyr::left_join(origin_totals, by = "area") |>
        dplyr::mutate(
          benchmark_origin_flow_total = dplyr::coalesce(.data$benchmark_origin_flow_total, 0)
        )

      benchmark_flow_tables$origin <- area_level |>
        dplyr::transmute(
          area = .data$area,
          residual_type = residual_type_label,
          benchmark_flow_role = "origin",
          selected_residual = .data$selected_residual,
          benchmark_flow_total = .data$benchmark_origin_flow_total,
          population = .data$population,
          user_count = .data$user_count,
          coverage_score = .data$coverage_score,
          coverage_score_residual = .data$coverage_score_residual
        )
    }

    if ("destination" %in% benchmark_flow_roles) {
      destination_totals <- benchmark_tbl |>
        dplyr::group_by(area = .data$destination) |>
        dplyr::summarise(
          benchmark_destination_flow_total = sum(.data$benchmark_flow, na.rm = TRUE),
          .groups = "drop"
        )

      area_level <- area_level |>
        dplyr::left_join(destination_totals, by = "area") |>
        dplyr::mutate(
          benchmark_destination_flow_total = dplyr::coalesce(.data$benchmark_destination_flow_total, 0)
        )

      benchmark_flow_tables$destination <- area_level |>
        dplyr::transmute(
          area = .data$area,
          residual_type = residual_type_label,
          benchmark_flow_role = "destination",
          selected_residual = .data$selected_residual,
          benchmark_flow_total = .data$benchmark_destination_flow_total,
          population = .data$population,
          user_count = .data$user_count,
          coverage_score = .data$coverage_score,
          coverage_score_residual = .data$coverage_score_residual
        )
    }

    if (length(benchmark_flow_tables) > 0L) {
      benchmark_flow_data <- dplyr::bind_rows(benchmark_flow_tables)
      benchmark_flow_correlation <- benchmark_flow_data |>
        dplyr::group_by(.data$benchmark_flow_role) |>
        dplyr::summarise(
          residual_type = residual_type_label,
          n = sum(is.finite(.data$selected_residual) & is.finite(.data$benchmark_flow_total)),
          pearson_r = .safe_pearson(.data$selected_residual, .data$benchmark_flow_total),
          .groups = "drop"
        ) |>
        dplyr::select(
          .data$residual_type,
          .data$benchmark_flow_role,
          .data$n,
          .data$pearson_r
        )
    }
  }

  moran_stats <- list(
    moran_i = NA_real_,
    n_areas_used = sum(is.finite(area_level$selected_residual)),
    n_links_used = NA_integer_,
    weight_sum = NA_real_
  )
  if (!is.null(area_neighbors)) {
    moran_stats <- .compute_moran_i(
      area_level = area_level,
      area_neighbors = area_neighbors,
      area_col = area_col,
      neighbor_col = neighbor_col,
      weight_col = weight_col
    )
  }

  moran_tbl <- tibble::tibble(
    residual_type = residual_type_label,
    n_areas_used = moran_stats$n_areas_used,
    n_links_used = moran_stats$n_links_used,
    weight_sum = moran_stats$weight_sum,
    moran_i = moran_stats$moran_i
  )

  covariate_data <- NULL
  covariate_correlation <- tibble::tibble(
    residual_type = residual_type_label,
    covariate = NA_character_,
    n = NA_integer_,
    pearson_r = NA_real_
  )

  if (!is.null(covariate_col)) {
    req_covariates <- c(covariate_area_col, covariate_col)
    if (!all(req_covariates %in% names(covariate_df))) {
      stop("`covariate_df` must contain: ", paste(req_covariates, collapse = ", "))
    }

    covariate_data <- covariate_df |>
      dplyr::select(
        area = dplyr::all_of(covariate_area_col),
        covariate_value = dplyr::all_of(covariate_col)
      ) |>
      dplyr::right_join(area_level, by = "area")

    covariate_correlation <- tibble::tibble(
      residual_type = residual_type_label,
      covariate = covariate_col,
      n = sum(is.finite(covariate_data$selected_residual) & is.finite(covariate_data$covariate_value)),
      pearson_r = .safe_pearson(covariate_data$selected_residual, covariate_data$covariate_value)
    )
  }

  map_data <- area_level
  if (!is.null(geometry_df)) {
    if (!geometry_area_col %in% names(geometry_df)) {
      stop("`geometry_area_col` must name a column in `geometry_df`.")
    }
    geometry_tbl <- geometry_df |>
      dplyr::rename(area = dplyr::all_of(geometry_area_col))
    map_data <- area_level |>
      dplyr::left_join(geometry_tbl, by = "area")
  }

  origin_flow_corr <- .first_or_na_real(
    benchmark_flow_correlation$pearson_r[
      benchmark_flow_correlation$benchmark_flow_role == "origin"
    ]
  )
  destination_flow_corr <- .first_or_na_real(
    benchmark_flow_correlation$pearson_r[
      benchmark_flow_correlation$benchmark_flow_role == "destination"
    ]
  )

  summary_tbl <- tibble::tibble(
    residual_type = residual_type_label,
    selected_residual_col = selected_residual_col,
    n_areas = nrow(area_level),
    total_population = total_population,
    total_user_count = total_user_count,
    global_coverage_score = global_coverage_score,
    mean_coverage_score = mean(area_level$coverage_score, na.rm = TRUE),
    sd_coverage_score = stats::sd(area_level$coverage_score, na.rm = TRUE),
    mean_selected_residual = mean(area_level$selected_residual, na.rm = TRUE),
    sd_selected_residual = stats::sd(area_level$selected_residual, na.rm = TRUE),
    moran_i = moran_tbl$moran_i,
    pearson_bias_benchmark_origin_flow = origin_flow_corr,
    pearson_bias_benchmark_destination_flow = destination_flow_corr,
    pearson_bias_covariate = covariate_correlation$pearson_r
  )

  residual_definitions <- tibble::tibble(
    residual = c(
      "coverage_score_residual",
      "user_count_residual",
      "standardized_user_count_residual"
    ),
    definition = c(
      "coverage_score - global_coverage_score",
      "user_count - expected_user_count",
      "user_count_residual / sqrt(expected_user_count)"
    ),
    interpretation = c(
      "Positive values mean higher active-user coverage than the global coverage score.",
      "Positive values mean more active users than expected under the global coverage score.",
      "Positive values mean more active users than expected after a Poisson-style count scaling."
    )
  )

  out <- list(
    summary = summary_tbl,
    residual_definitions = residual_definitions,
    moran_i = moran_tbl,
    benchmark_flow_correlation = benchmark_flow_correlation,
    covariate_correlation = covariate_correlation,
    area_level = area_level,
    map_data = map_data
  )

  if (!is.null(benchmark_flow_data)) {
    out$benchmark_flow_data <- benchmark_flow_data
  }
  if (!is.null(covariate_data)) {
    out$covariate_data <- covariate_data
  }

  if (make_plots) {
    plots <- list(
      bias_residual_distribution =
        ggplot2::ggplot(area_level, ggplot2::aes(x = .data$selected_residual)) +
        ggplot2::geom_histogram(bins = 30, fill = "#2B8CBE", color = "white", na.rm = TRUE) +
        ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#D95F0E") +
        ggplot2::labs(
          x = selected_residual_col,
          y = "Areas",
          title = "Bias residual distribution"
        )
    )

    if (!is.null(benchmark_flow_data)) {
      plots$bias_residual_vs_benchmark_flow <-
        ggplot2::ggplot(
          benchmark_flow_data,
          ggplot2::aes(x = .data$benchmark_flow_total, y = .data$selected_residual)
        ) +
        ggplot2::geom_point(alpha = 0.7, na.rm = TRUE) +
        ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "#D95F0E") +
        ggplot2::facet_wrap(ggplot2::vars(.data$benchmark_flow_role), scales = "free_x") +
        ggplot2::labs(
          x = "Benchmark area flow total",
          y = selected_residual_col,
          title = "Bias residuals versus benchmark flow totals"
        )
    }

    if (!is.null(covariate_data)) {
      plots$bias_residual_vs_covariate <-
        ggplot2::ggplot(
          covariate_data,
          ggplot2::aes(x = .data$covariate_value, y = .data$selected_residual)
        ) +
        ggplot2::geom_point(alpha = 0.7, na.rm = TRUE) +
        ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "#D95F0E") +
        ggplot2::labs(
          x = covariate_col,
          y = selected_residual_col,
          title = "Bias residuals versus covariate"
        )
    }

    if (!is.null(x_col) || !is.null(y_col)) {
      if (is.null(x_col) || is.null(y_col)) {
        stop("Both `x_col` and `y_col` are required for a bias residual map plot.")
      }
      if (!all(c(x_col, y_col) %in% names(map_data))) {
        stop("`x_col` and `y_col` must name columns in `map_data`.")
      }
      map_plot_data <- map_data |>
        dplyr::mutate(
          .map_x = .data[[x_col]],
          .map_y = .data[[y_col]]
        )
      plots$bias_residual_map <-
        ggplot2::ggplot(
          map_plot_data,
          ggplot2::aes(x = .data$.map_x, y = .data$.map_y, color = .data$selected_residual)
        ) +
        ggplot2::geom_point(size = 2.5, alpha = 0.9, na.rm = TRUE) +
        ggplot2::coord_equal() +
        ggplot2::labs(
          x = x_col,
          y = y_col,
          color = "Residual",
          title = "Area-level bias residual map"
        )
    }

    out$plots <- plots
  }

  out
}
