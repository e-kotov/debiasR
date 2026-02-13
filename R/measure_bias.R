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

