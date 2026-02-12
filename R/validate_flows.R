#' Validate adjusted OD flows against a benchmark
#'
#' Compares bias-adjusted MPD flows to benchmark (e.g., census) OD flows.
#' Uses adjusted flows as estimates (x) and benchmark as targets (y).
#'
#' @param adj_df Data frame with at least: origin, destination, and a column of adjusted flows
#'   (default name "flow_adj"). If present, an mpd_source column is carried through.
#' @param benchmark_od_df Data frame with at least: origin, destination, and a column of benchmark flows
#'   (default name "flow").
#' @param flow_col_adj Name of adjusted flow column in adj_df. Default "flow_adj".
#' @param flow_col_bench Name of benchmark flow column in benchmark_od_df. Default "flow".
#' @param drop_zeros Logical, drop rows where either x or y == 0 before metrics. Default TRUE.
#' @param na_rm Logical, remove non-finite rows before metrics. Default TRUE.
#' @param by_source Logical, if TRUE and mpd_source exists in both inputs (or in adj_df),
#'   compute metrics per mpd_source as well as overall. Default FALSE.
#' @param return_joined Logical, return the joined row-level data in the result list. Default TRUE.
#' @param method_name Optional label for the adjustment method (e.g. "method1_inverse_penetration",
#'   "method2_selection_rate"). Stored in the output for comparison workflows.
#'
#' @return A list with:
#'   \itemize{
#'     \item method (if provided)
#'     \item n, sum_adj, sum_bench
#'     \item pearson_r, spearman_rho
#'     \item rmse, mae, mape
#'     \item ols_intercept, ols_slope, r_squared (from lm(y ~ x))
#'     \item (optional) by_source: a tibble of per-source metrics when by_source = TRUE
#'     \item (optional) data: the joined tibble used for the calculations
#'   }
#' @export
validate_flows <- function(adj_df,
                           benchmark_od_df,
                           flow_col_adj   = "flow_adj",
                           flow_col_bench = "flow",
                           drop_zeros     = TRUE,
                           na_rm          = TRUE,
                           by_source      = FALSE,
                           return_joined  = TRUE,
                           method_name    = NA_character_) {

  # --- Required columns
  req_adj   <- c("origin", "destination", flow_col_adj)
  req_bench <- c("origin", "destination", flow_col_bench)
  if (!all(req_adj %in% names(adj_df))) {
    stop("`adj_df` must contain: ", paste(req_adj, collapse = ", "))
  }
  if (!all(req_bench %in% names(benchmark_od_df))) {
    stop("`benchmark_od_df` must contain: ", paste(req_bench, collapse = ", "))
  }

  # --- Prepare joined data
  joined <- adj_df |>
    dplyr::select(dplyr::any_of(c("mpd_source")), origin, destination, !!flow_col_adj) |>
    dplyr::rename(flow_adj = !!flow_col_adj) |>
    dplyr::inner_join(
      benchmark_od_df |>
        dplyr::select(origin, destination, !!flow_col_bench) |>
        dplyr::rename(flow_bench = !!flow_col_bench),
      by = c("origin", "destination")
    )

  # --- Clean rows
  if (na_rm) {
    joined <- dplyr::filter(joined,
                            is.finite(.data$flow_adj),
                            is.finite(.data$flow_bench))
  }
  if (drop_zeros) {
    joined <- dplyr::filter(joined,
                            .data$flow_adj > 0,
                            .data$flow_bench > 0)
  }

  # --- Empty guard
  if (nrow(joined) == 0L) {
    res <- list(
      method        = method_name,
      n             = 0L,
      sum_adj       = 0,
      sum_bench     = 0,
      pearson_r     = NA_real_,
      spearman_rho  = NA_real_,
      rmse          = NA_real_,
      mae           = NA_real_,
      mape          = NA_real_,
      ols_intercept = NA_real_,
      ols_slope     = NA_real_,
      r_squared     = NA_real_
    )
    if (by_source && "mpd_source" %in% names(joined)) {
      res$by_source <- dplyr::tibble()
    }
    if (return_joined) res$data <- joined
    return(res)
  }

  # --- Core metrics (x = adjusted; y = benchmark)
  x <- joined$flow_adj
  y <- joined$flow_bench

  sum_adj   <- sum(x, na.rm = TRUE)
  sum_bench <- sum(y, na.rm = TRUE)

  pearson_r    <- suppressWarnings(stats::cor(x, y, method = "pearson"))
  spearman_rho <- suppressWarnings(stats::cor(x, y, method = "spearman"))

  rmse  <- sqrt(mean((y - x)^2))
  mae   <- mean(abs(y - x))
  denom <- ifelse(y == 0, NA_real_, y)
  mape  <- mean(abs((y - x) / denom), na.rm = TRUE)

  fit <- stats::lm(y ~ x)
  coefs <- stats::coef(fit)
  ols_intercept <- unname(coefs[1])
  ols_slope     <- unname(coefs[2])
  r_squared     <- unname(summary(fit)$r.squared)

  # --- Package result
  out <- list(
    method        = method_name,
    n             = nrow(joined),
    sum_adj       = sum_adj,
    sum_bench     = sum_bench,
    pearson_r     = pearson_r,
    spearman_rho  = spearman_rho,
    rmse          = rmse,
    mae           = mae,
    mape          = mape,
    ols_intercept = ols_intercept,
    ols_slope     = ols_slope,
    r_squared     = r_squared
  )

  # --- Optional: per-source metrics
  if (by_source && "mpd_source" %in% names(joined)) {
    metrics_fun <- function(df) {
      xx <- df$flow_adj
      yy <- df$flow_bench
      data.frame(
        n = length(xx),
        sum_adj = sum(xx),
        sum_bench = sum(yy),
        pearson_r = suppressWarnings(stats::cor(xx, yy, method = "pearson")),
        spearman_rho = suppressWarnings(stats::cor(xx, yy, method = "spearman")),
        rmse = sqrt(mean((yy - xx)^2)),
        mae  = mean(abs(yy - xx)),
        mape = {
          dd <- ifelse(yy == 0, NA_real_, yy)
          mean(abs((yy - xx) / dd), na.rm = TRUE)
        },
        ols_intercept = {
          if (length(xx) >= 2 && all(is.finite(xx + yy))) {
            unname(stats::coef(stats::lm(yy ~ xx))[1])
          } else NA_real_
        },
        ols_slope = {
          if (length(xx) >= 2 && all(is.finite(xx + yy))) {
            unname(stats::coef(stats::lm(yy ~ xx))[2])
          } else NA_real_
        },
        r_squared = {
          if (length(xx) >= 2 && all(is.finite(xx + yy))) {
            unname(summary(stats::lm(yy ~ xx))$r.squared)
          } else NA_real_
        }
      )
    }

    by_src <- joined |>
      dplyr::group_by(mpd_source) |>
      dplyr::group_modify(~ tibble::as_tibble(metrics_fun(.x))) |>
      dplyr::ungroup()

    out$by_source <- by_src
  }

  if (return_joined) out$data <- joined
  out
}
