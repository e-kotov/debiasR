#' @title Measure Coverage Bias
#'
#' @description
#' Computes **coverage bias** by area: the ratio of mobile-phone–derived active users
#' to benchmark population, i.e. \code{user_count / population}.
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
#'   \item \code{bias} — Coverage bias (coverage ratio) defined as
#'         \code{user_count / population}. Values near 1 imply full coverage,
#'         < 1 imply under-coverage, and > 1 imply over-coverage relative to the benchmark.
#' }
#'
#' @details
#' This function treats "bias" as **coverage bias**. It does not rescale or cap values.
#' If \code{bias > 1}, a warning is issued, as this indicates user counts exceeding
#' benchmark population for that area (possible if benchmarks are not accurate, users are
#' overcounted or definitions differ).
#'
#' @examples
#' data(toy_coverage_df)
#' measure_bias(toy_coverage_df)
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

  # ---- Compute coverage bias ----
  coverage_df$bias <- coverage_df$user_count / coverage_df$population

  # Warn if coverage exceeds 100%
  if (any(coverage_df$bias > 1, na.rm = TRUE)) {
    warning("One or more areas have bias > 1 (user_count exceeds population). Check inputs or definitions.")
  }

  return(coverage_df)
}



