#' Selection-rate weighting (Chi et al. with r_t calibration)
#'
#' Implements Chi et al.-style selection weights.
#'
#' Notation used throughout:
#' \itemize{
#'   \item \eqn{P_i^{(O)}, P_j^{(D)}}: population at origin \eqn{i} and destination \eqn{j}
#'   \item \eqn{U_i^{(O)}, U_j^{(D)}}: active users at origin \eqn{i} and destination \eqn{j}
#'   \item \eqn{p_i^{(O)} = U_i^{(O)}/P_i^{(O)}} and \eqn{p_j^{(D)} = U_j^{(D)}/P_j^{(D)}}: penetration
#'   \item \eqn{I_i, I_j \in [0,1]}: normalized selected covariate
#'   \item \eqn{r_t > 0}: global selection parameter
#'   \item \eqn{F_{ij}^{mpd}} and \eqn{F_{ij}^{adj}}: observed and adjusted flows
#' }
#'
#' Origin-side weight:
#' \deqn{w_i^{(O)}(r_t) = \frac{1}{I_i p_i^{(O)} + (1 - I_i) r_t}}
#'
#' Destination-side weight:
#' \deqn{w_j^{(D)}(r_t) = \frac{1}{I_j p_j^{(D)} + (1 - I_j) r_t}}
#'
#' Flow adjustment:
#' \deqn{F_{ij}^{adj} = F_{ij}^{mpd} \times w_{ij}}
#' with \eqn{w_{ij} = w_i^{(O)}} for \code{weight_by = "origin"},
#' \eqn{w_{ij} = w_j^{(D)}} for \code{weight_by = "destination"}, and
#' \eqn{w_{ij} = \sqrt{w_i^{(O)} w_j^{(D)}}} for \code{weight_by = "both"}.
#'
#' with flexible area-level covariates and optional calibration of r_t
#' against benchmark OD flows.
#'
#' Coverage formats:
#'   NEW:
#'     origin, origin_population, origin_user_count,
#'     destination, destination_population, destination_user_count, mpd_source
#'   LEGACY:
#'     origin, population, user_count, mpd_source
#'
#' Optional covariates:
#'   covariates_df with:
#'     area,
#'     a numeric area-level covariate column (specified via `covariate_col`),
#'     optional mpd_source.
#'
#' r_t handling:
#'   - If `r_global` is provided: use it directly.
#'   - Else if `benchmark_od_df` is provided: calibrate r_t by grid search
#'     to minimize the sum of absolute errors, reproducing Chi et al.'s idea.
#'     By default aggregates by origin:
#'       \deqn{r_t^\ast = \arg\min_{r \in \mathcal{R}} \sum_i
#'       \left|\hat{M}_i(r) - M_i^{bench}\right|}
#'   - Else: fall back to descriptive r_t = sum(U) / sum(P) (transparent).
#'
#' @param mpd_od_df Data frame with: origin, destination, flow, mpd_source.
#' @param coverage_df Data frame in NEW or LEGACY schema.
#' @param covariates_df Optional data frame with columns:
#'   - area
#'   - a numeric area-level covariate column
#'   - optional mpd_source
#' @param covariate_col Optional name of the numeric area-level covariate column
#'   in `covariates_df`. The selected covariate is normalized to the 0-1 range
#'   internally before weights are computed. If NULL, auto-detect among legacy
#'   income-like names:
#'   `income_norm, gni_pc, income, inc, gni, income_2000, income_2010`.
#' @param weight_by "origin", "destination", or "both".
#' @param r_global Optional scalar r_t. Overrides calibration if given.
#' @param benchmark_od_df Optional OD benchmark for calibrating r_t.
#'   Must contain: origin, destination, and a flow column.
#' @param flow_col_bench Name of benchmark flow column in `benchmark_od_df`.
#'   Default "flow".
#' @param r_grid Numeric vector of candidate r_t values for calibration.
#'   Default `seq(0, 3, by = 0.01)` as in Chi et al.
#' @param calibration_aggregate "origin" (default, Chi et al. style) or "od".
#' @param clip_min Lower bound used to clamp weights. Default 0.
#' @param clip_max Upper bound used to clamp weights. Default Inf.
#' @param keep_cols Extra columns from `mpd_od_df` to keep.
#' @param engine One of `"dplyr"` (default), `"duckdb"`, or `"data.table"`.
#'   The optional backends accelerate calibration grid searches on large inputs.
#' @param ... Deprecated arguments. `income_col` is accepted here as a legacy
#'   alias for `covariate_col`.
#'
#' @return Tibble with:
#'   origin, destination, mpd_source, flow,
#'   weight_origin, weight_destination, weight_missing, flow_adj.
#'   Attributes:
#'     - "r_global": numeric r_t used.
#'     - "r_calibration": data.frame of (r, loss) if calibration was run.
#' @export
adjust_selection_rate <- function(mpd_od_df,
                                   coverage_df,
                                   covariates_df = NULL,
                                   covariate_col = NULL,
                                   weight_by = c("origin", "destination", "both"),
                                   r_global = NULL,
                                   benchmark_od_df = NULL,
                                   flow_col_bench = "flow",
                                   r_grid = seq(0, 3, by = 0.01),
                                   calibration_aggregate = c("origin", "od"),
                                   clip_min = 0,
                                   clip_max = Inf,
                                   keep_cols = character(),
                                   engine = c("dplyr", "duckdb", "data.table"),
                                   ...) {
  weight_by <- match.arg(weight_by)
  calibration_aggregate <- match.arg(calibration_aggregate)
  engine <- match.arg(engine)

  dots <- list(...)
  legacy_income_col <- dots$income_col
  dots$income_col <- NULL
  if (length(dots) > 0L) {
    stop("Unused argument(s): ", paste(names(dots), collapse = ", "))
  }
  if (!is.null(covariate_col) && !is.null(legacy_income_col) &&
      !identical(covariate_col, legacy_income_col)) {
    stop("Use only one of `covariate_col` or legacy `income_col`.")
  }
  if (is.null(covariate_col) && !is.null(legacy_income_col)) {
    covariate_col <- legacy_income_col
  }

  # -------- basic checks --------
  req_mpd <- c("origin", "destination", "flow", "mpd_source")
  if (!all(req_mpd %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req_mpd, collapse = ", "))
  }

  nms_cov <- names(coverage_df)
  has_new <- all(c(
    "origin",
    "origin_population", "origin_user_count",
    "destination", "destination_population", "destination_user_count",
    "mpd_source"
  ) %in% nms_cov)
  has_legacy <- all(c("origin", "population", "user_count", "mpd_source") %in% nms_cov)

  if (!has_new && !has_legacy) {
    stop(
      "`coverage_df` does not match a supported schema.\n",
      "New:    {origin, origin_population, origin_user_count, ",
      "destination, destination_population, destination_user_count, mpd_source}\n",
      "Legacy: {origin, population, user_count, mpd_source}\n",
      "Got: {", paste(nms_cov, collapse = ", "), "}"
    )
  }

  # -------- small helpers --------
  clamp_weight <- function(w) {
    w <- suppressWarnings(as.numeric(w))
    w[!(is.finite(w) & w > 0)] <- NA_real_
    w <- pmax(clip_min, pmin(w, clip_max), na.rm = FALSE)
    w
  }

  normalize01 <- function(v) {
    v <- suppressWarnings(as.numeric(v))
    v[!is.finite(v)] <- NA_real_
    if (!any(is.finite(v))) return(rep(NA_real_, length(v)))
    v_min <- min(v, na.rm = TRUE)
    v_max <- max(v, na.rm = TRUE)
    if (v_min >= 0 && v_max <= 1) return(v)
    if (v_max > v_min) (v - v_min) / (v_max - v_min) else rep(NA_real_, length(v))
  }

  infer_covariate_from_coverage <- function(df, prefix = NULL) {
    cand <- c(
      if (!is.null(prefix)) paste0(prefix, c("income", "gni_pc", "gni")),
      "income", "gni_pc", "gni"
    )
    cand <- cand[cand %in% names(df)]
    if (length(cand) == 0) return(rep(1, nrow(df)))
    inc <- normalize01(df[[cand[1]]])
    ifelse(is.finite(inc), inc, 1)
  }

  # -------- build normalized selected covariate (if provided) --------
  covariate_values <- NULL
  if (!is.null(covariates_df)) {
    if (!"area" %in% names(covariates_df)) {
      stop("`covariates_df` must contain column `area`.")
    }

    if (!is.null(covariate_col)) {
      if (!covariate_col %in% names(covariates_df)) {
        stop("`covariate_col` = '", covariate_col, "' not found in `covariates_df`.")
      }
      covariate_col_use <- covariate_col
    } else {
      cand_auto <- c("income_norm", "gni_pc", "income", "inc", "gni",
                     "income_2000", "income_2010")
      covariate_col_use <- cand_auto[cand_auto %in% names(covariates_df)][1]
      if (is.na(covariate_col_use)) covariate_col_use <- NULL
    }

    if (!is.null(covariate_col_use)) {
      covariate_norm <- normalize01(covariates_df[[covariate_col_use]])
      covariate_values <- covariates_df %>%
        dplyr::transmute(
          area = as.character(.data$area),
          covariate_norm = covariate_norm
        )
      if ("mpd_source" %in% names(covariates_df)) {
        covariate_values$mpd_source <- covariates_df$mpd_source
      }
    }
  }

  # =====================================================================
  # Precompute side-specific quantities that do not depend on r_t
  # =====================================================================

  if (has_new) {
    # ORIGIN side
    cov_o_pre <- coverage_df %>%
      dplyr::transmute(
        origin     = as.character(.data$origin),
        mpd_source = .data$mpd_source,
        P_o        = as.numeric(.data$origin_population),
        U_o        = as.numeric(.data$origin_user_count)
      ) %>%
      dplyr::filter(is.finite(P_o), P_o > 0, is.finite(U_o), U_o > 0)

    if (!is.null(covariate_values)) {
      if ("mpd_source" %in% names(covariate_values)) {
        cov_o_pre <- cov_o_pre %>%
          dplyr::left_join(covariate_values,
                           by = c("origin" = "area", "mpd_source"))
      } else {
        cov_o_pre <- cov_o_pre %>%
          dplyr::left_join(covariate_values, by = c("origin" = "area"))
      }
      Income_o <- ifelse(is.finite(cov_o_pre$covariate_norm),
                         cov_o_pre$covariate_norm, NA_real_)
    } else {
      Income_o <- infer_covariate_from_coverage(cov_o_pre, prefix = "origin_")
    }
    Income_o[!is.finite(Income_o)] <- 1
    cov_o_pre$Income_o <- Income_o
    cov_o_pre$pen_o <- cov_o_pre$U_o / cov_o_pre$P_o

    # DESTINATION side
    cov_d_pre <- coverage_df %>%
      dplyr::transmute(
        destination = as.character(.data$destination),
        mpd_source  = .data$mpd_source,
        P_d         = as.numeric(.data$destination_population),
        U_d         = as.numeric(.data$destination_user_count)
      ) %>%
      dplyr::filter(is.finite(P_d), P_d > 0, is.finite(U_d), U_d > 0)

    if (!is.null(covariate_values)) {
      if ("mpd_source" %in% names(covariate_values)) {
        cov_d_pre <- cov_d_pre %>%
          dplyr::left_join(covariate_values,
                           by = c("destination" = "area", "mpd_source"))
      } else {
        cov_d_pre <- cov_d_pre %>%
          dplyr::left_join(covariate_values, by = c("destination" = "area"))
      }
      Income_d <- ifelse(is.finite(cov_d_pre$covariate_norm),
                         cov_d_pre$covariate_norm, NA_real_)
    } else {
      Income_d <- infer_covariate_from_coverage(cov_d_pre, prefix = "destination_")
    }
    Income_d[!is.finite(Income_d)] <- 1
    cov_d_pre$Income_d <- Income_d
    cov_d_pre$pen_d <- cov_d_pre$U_d / cov_d_pre$P_d

  } else {
    # LEGACY schema
    cov_base_pre <- coverage_df %>%
      dplyr::transmute(
        area       = as.character(.data$origin),
        mpd_source = .data$mpd_source,
        P          = as.numeric(.data$population),
        U          = as.numeric(.data$user_count)
      ) %>%
      dplyr::filter(is.finite(P), P > 0, is.finite(U), U > 0)

    if (!is.null(covariate_values)) {
      if ("mpd_source" %in% names(covariate_values)) {
        cov_base_pre <- cov_base_pre %>%
          dplyr::left_join(covariate_values, by = c("area", "mpd_source"))
      } else {
        cov_base_pre <- cov_base_pre %>%
          dplyr::left_join(covariate_values, by = "area")
      }
      Income <- ifelse(is.finite(cov_base_pre$covariate_norm),
                       cov_base_pre$covariate_norm, NA_real_)
    } else {
      Income <- infer_covariate_from_coverage(cov_base_pre, prefix = NULL)
    }
    Income[!is.finite(Income)] <- 1
    cov_base_pre$Income <- Income
    cov_base_pre$pen <- cov_base_pre$U / cov_base_pre$P
  }

  # =====================================================================
  # Internal helper to compute adjusted flows for a given r_t
  # =====================================================================

  compute_with_r <- function(r_val) {
    r_val <- as.numeric(r_val)[1]

    if (has_new) {
      cov_o <- NULL
      cov_d <- NULL

      if (weight_by %in% c("origin", "both")) {
        cov_o <- cov_o_pre %>%
          dplyr::mutate(
            weight_origin = clamp_weight(
              1 / (Income_o * pen_o + (1 - Income_o) * r_val)
            )
          ) %>%
          dplyr::select(origin, mpd_source, weight_origin)
      }

      if (weight_by %in% c("destination", "both")) {
        cov_d <- cov_d_pre %>%
          dplyr::mutate(
            weight_destination = clamp_weight(
              1 / (Income_d * pen_d + (1 - Income_d) * r_val)
            )
          ) %>%
          dplyr::select(destination, mpd_source, weight_destination)
      }

    } else {
      # legacy: same weights for origin/destination from cov_base_pre
      cov_o <- NULL
      cov_d <- NULL

      if (weight_by %in% c("origin", "both", "destination")) {
        cov_w <- cov_base_pre %>%
          dplyr::mutate(
            w_sel = clamp_weight(
              1 / (Income * pen + (1 - Income) * r_val)
            )
          )
      }

      if (weight_by %in% c("origin", "both")) {
        cov_o <- cov_w %>%
          dplyr::transmute(
            origin = area,
            mpd_source,
            weight_origin = w_sel
          ) %>%
          dplyr::distinct(origin, mpd_source, .keep_all = TRUE)
      }

      if (weight_by %in% c("destination", "both")) {
        cov_d <- cov_w %>%
          dplyr::transmute(
            destination = area,
            mpd_source,
            weight_destination = w_sel
          ) %>%
          dplyr::distinct(destination, mpd_source, .keep_all = TRUE)
      }
    }

    out <- mpd_od_df
    if (length(keep_cols)) {
      keep_cols_local <- keep_cols[keep_cols %in% names(out)]
    } else keep_cols_local <- character()

    if (!is.null(cov_o)) {
      out <- dplyr::left_join(out, cov_o, by = c("origin", "mpd_source"))
    } else {
      out$weight_origin <- NA_real_
    }

    if (!is.null(cov_d)) {
      out <- dplyr::left_join(out, cov_d, by = c("destination", "mpd_source"))
    } else {
      out$weight_destination <- NA_real_
    }

    if (weight_by == "origin") {
      final_w <- out$weight_origin
    } else if (weight_by == "destination") {
      final_w <- out$weight_destination
    } else {
      final_w <- suppressWarnings(
        sqrt(out$weight_origin * out$weight_destination)
      )
    }
    if (weight_by == "both") {
      final_w[!is.finite(out$weight_origin) |
                !is.finite(out$weight_destination)] <- NA_real_
    }

    out$weight_missing <- !is.finite(final_w)
    out$flow_adj <- ifelse(is.finite(final_w), out$flow * final_w, NA_real_)

    dplyr::select(
      out,
      dplyr::any_of(c("origin", "destination", "mpd_source")),
      dplyr::any_of(keep_cols_local),
      flow,
      weight_origin,
      weight_destination,
      weight_missing,
      flow_adj
    ) %>%
      tibble::as_tibble()
  }

  # =====================================================================
  # Calibrate or set r_t
  # =====================================================================

  r_used <- NULL
  calib_diag <- NULL

  # Case 1: user supplies r_global directly
  if (!is.null(r_global)) {
    r_used <- as.numeric(r_global[1])

  } else if (!is.null(benchmark_od_df)) {
    # Case 2: Chi-style calibration using benchmark flows

    if (!all(c("origin", "destination", flow_col_bench) %in% names(benchmark_od_df))) {
      stop("`benchmark_od_df` must contain origin, destination, and `flow_col_bench`.")
    }

    bench_df <- benchmark_od_df %>%
      dplyr::transmute(
        origin      = as.character(.data$origin),
        destination = as.character(.data$destination),
        flow_bench  = as.numeric(.data[[flow_col_bench]])
      ) %>%
      dplyr::filter(is.finite(flow_bench))

    if (nrow(bench_df) == 0L) {
      stop("`benchmark_od_df` has no valid benchmark flows for calibration.")
    }

    if (length(r_grid) == 0L) {
      stop("`r_grid` is empty; provide candidate values for r_t.")
    }

    if (engine == "duckdb") {
      calib_diag <- .calibrate_selection_rate_duckdb(
        mpd_od_df = mpd_od_df,
        bench_df = bench_df,
        r_grid = r_grid,
        weight_by = weight_by,
        calibration_aggregate = calibration_aggregate,
        has_new = has_new,
        cov_o_pre = if (has_new) cov_o_pre else NULL,
        cov_d_pre = if (has_new) cov_d_pre else NULL,
        cov_base_pre = if (!has_new) cov_base_pre else NULL,
        clip_min = clip_min,
        clip_max = clip_max
      )
      rs <- calib_diag$r
      losses <- calib_diag$loss
    } else if (engine == "data.table") {
      calib_diag <- .calibrate_selection_rate_data_table(
        mpd_od_df = mpd_od_df,
        bench_df = bench_df,
        r_grid = r_grid,
        weight_by = weight_by,
        calibration_aggregate = calibration_aggregate,
        has_new = has_new,
        cov_o_pre = if (has_new) cov_o_pre else NULL,
        cov_d_pre = if (has_new) cov_d_pre else NULL,
        cov_base_pre = if (!has_new) cov_base_pre else NULL,
        clip_min = clip_min,
        clip_max = clip_max
      )
      rs <- calib_diag$r
      losses <- calib_diag$loss
    } else {
      losses <- numeric(0)
      rs     <- numeric(0)

      for (r in r_grid) {
        adj_r <- compute_with_r(r) %>%
          dplyr::select(origin, destination, flow_adj)

        joined <- dplyr::inner_join(adj_r, bench_df,
                                    by = c("origin", "destination"))
        if (nrow(joined) == 0L) next

        if (calibration_aggregate == "origin") {
          agg <- joined %>%
            dplyr::group_by(origin) %>%
            dplyr::summarise(
              adj   = sum(flow_adj, na.rm = TRUE),
              bench = sum(flow_bench, na.rm = TRUE),
              .groups = "drop"
            )
          loss <- sum(abs(agg$adj - agg$bench), na.rm = TRUE)
        } else { # "od"
          loss <- sum(abs(joined$flow_adj - joined$flow_bench), na.rm = TRUE)
        }

        rs     <- c(rs, r)
        losses <- c(losses, loss)
      }
    }

    if (length(rs) == 0L) {
      stop("Calibration failed: no overlap between adjusted and benchmark ODs.")
    }

    idx_best <- which.min(losses)
    r_used <- rs[idx_best]

    calib_diag <- data.frame(
      r = rs,
      loss = losses
    )
  } else {
    # Case 3: fallback descriptive r_t (transparent)
    if (has_new) {
      if (weight_by == "origin") {
        r_used <- sum(cov_o_pre$U_o, na.rm = TRUE) /
          sum(cov_o_pre$P_o, na.rm = TRUE)
      } else if (weight_by == "destination") {
        r_used <- sum(cov_d_pre$U_d, na.rm = TRUE) /
          sum(cov_d_pre$P_d, na.rm = TRUE)
      } else { # both
        r_used <- (sum(cov_o_pre$U_o, na.rm = TRUE) +
                     sum(cov_d_pre$U_d, na.rm = TRUE)) /
          (sum(cov_o_pre$P_o, na.rm = TRUE) +
             sum(cov_d_pre$P_d, na.rm = TRUE))
      }
    } else {
      r_used <- sum(cov_base_pre$U, na.rm = TRUE) /
        sum(cov_base_pre$P, na.rm = TRUE)
    }
  }

  # =====================================================================
  # Final run with chosen r_t
  # =====================================================================

  out_final <- compute_with_r(r_used)
  attr(out_final, "r_global") <- r_used
  if (!is.null(calib_diag)) {
    attr(out_final, "r_calibration") <- calib_diag
  }

  out_final
}

.calibrate_selection_rate_duckdb <- function(mpd_od_df,
                                              bench_df,
                                              r_grid,
                                              weight_by,
                                              calibration_aggregate,
                                              has_new,
                                              cov_o_pre = NULL,
                                              cov_d_pre = NULL,
                                              cov_base_pre = NULL,
                                              clip_min = 0,
                                              clip_max = Inf) {
  if (!requireNamespace("duckdb", quietly = TRUE) ||
      !requireNamespace("DBI", quietly = TRUE)) {
    stop("Packages 'duckdb' and 'DBI' are required for the duckdb engine.")
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbWriteTable(con, "mpd_od", mpd_od_df)
  DBI::dbWriteTable(con, "bench", bench_df)
  DBI::dbWriteTable(
    con,
    "r_grid",
    data.frame(r_order = seq_along(r_grid), r = r_grid)
  )

  if (has_new) {
    if (weight_by %in% c("origin", "both")) {
      DBI::dbWriteTable(con, "cov_o", cov_o_pre)
    }
    if (weight_by %in% c("destination", "both")) {
      DBI::dbWriteTable(con, "cov_d", cov_d_pre)
    }
  } else {
    DBI::dbWriteTable(con, "cov_base", cov_base_pre)
  }

  weight_expr_o <- if (has_new) {
    "1.0 / (Income_o * pen_o + (1.0 - Income_o) * r)"
  } else {
    "1.0 / (Income * pen + (1.0 - Income) * r)"
  }

  weight_expr_d <- "1.0 / (Income_d * pen_d + (1.0 - Income_d) * r)"

  origin_join <- if (weight_by %in% c("origin", "both")) {
    "LEFT JOIN cov_o co
     ON m.origin = co.origin AND m.mpd_source = co.mpd_source"
  } else {
    ""
  }
  destination_join <- if (weight_by %in% c("destination", "both")) {
    "LEFT JOIN cov_d cd
     ON m.destination = cd.destination AND m.mpd_source = cd.mpd_source"
  } else {
    ""
  }

  clamp_sql <- function(expr) {
    out <- expr
    if (is.finite(clip_min)) {
      out <- sprintf(
        "GREATEST(%s, %s)",
        format(clip_min, scientific = FALSE),
        out
      )
    }
    if (is.finite(clip_max)) {
      out <- sprintf(
        "LEAST(%s, %s)",
        format(clip_max, scientific = FALSE),
        out
      )
    }
    sprintf(
      "CASE WHEN isfinite(%1$s) AND (%1$s) > 0 THEN %2$s ELSE NULL END",
      expr,
      out
    )
  }

  weight_final_sql <- if (weight_by == "origin") {
    clamp_sql(weight_expr_o)
  } else if (weight_by == "destination") {
    clamp_sql(weight_expr_d)
  } else {
    sprintf("sqrt(%s * %s)", clamp_sql(weight_expr_o), clamp_sql(weight_expr_d))
  }

  sql_base <- if (has_new) {
    sprintf("
      SELECT
        m.origin, m.destination, m.mpd_source, m.flow,
        %s as pen_o, %s as Income_o,
        %s as pen_d, %s as Income_d,
        b.flow_bench
      FROM mpd_od m
      %s
      %s
      JOIN bench b ON m.origin = b.origin AND m.destination = b.destination
    ",
    if (weight_by %in% c("origin", "both")) "co.pen_o" else "0",
    if (weight_by %in% c("origin", "both")) "co.Income_o" else "1",
    if (weight_by %in% c("destination", "both")) "cd.pen_d" else "0",
    if (weight_by %in% c("destination", "both")) "cd.Income_d" else "1",
    origin_join,
    destination_join
    )
  } else {
    "
      SELECT
        m.origin, m.destination, m.mpd_source, m.flow,
        co.pen as pen, co.Income as Income,
        cd.pen as pen_d, cd.Income as Income_d,
        b.flow_bench
      FROM mpd_od m
      LEFT JOIN cov_base co ON m.origin = co.area AND m.mpd_source = co.mpd_source
      LEFT JOIN cov_base cd ON m.destination = cd.area AND m.mpd_source = cd.mpd_source
      JOIN bench b ON m.origin = b.origin AND m.destination = b.destination
    "
  }

  sql <- sprintf("
    WITH base AS (%s),
    grid AS (SELECT b.*, g.r_order, g.r FROM base b CROSS JOIN r_grid g),
    adjusted AS (
      SELECT
        r_order, r, origin, destination,
        flow * %s as flow_adj,
        flow_bench
      FROM grid
    ),
    losses AS (
      %s
    )
    SELECT r, loss FROM losses ORDER BY r_order
  ",
  sql_base,
  weight_final_sql,
  if (calibration_aggregate == "origin") {
    "SELECT r_order, r, sum(abs(adj_total - bench_total)) as loss
     FROM (
       SELECT r_order, r, origin,
         coalesce(sum(flow_adj), 0) as adj_total,
         sum(flow_bench) as bench_total
       FROM adjusted
       GROUP BY r_order, r, origin
     )
     GROUP BY r_order, r"
  } else {
    "SELECT r_order, r, coalesce(sum(abs(flow_adj - flow_bench)), 0) as loss
     FROM adjusted
     GROUP BY r_order, r"
  }
  )

  res <- DBI::dbGetQuery(con, sql)
  res
}

.calibrate_selection_rate_data_table <- function(mpd_od_df,
                                                  bench_df,
                                                  r_grid,
                                                  weight_by,
                                                  calibration_aggregate,
                                                  has_new,
                                                  cov_o_pre = NULL,
                                                  cov_d_pre = NULL,
                                                  cov_base_pre = NULL,
                                                  clip_min = 0,
                                                  clip_max = Inf) {
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package 'data.table' is required for the data.table engine.")
  }

  dt_mpd <- data.table::as.data.table(mpd_od_df)
  dt_bench <- data.table::as.data.table(bench_df)

  if (has_new) {
    if (weight_by %in% c("origin", "both")) {
      dt_cov_o <- data.table::as.data.table(cov_o_pre)
      dt_mpd <- merge(dt_mpd, dt_cov_o, by = c("origin", "mpd_source"), all.x = TRUE)
    }
    if (weight_by %in% c("destination", "both")) {
      dt_cov_d <- data.table::as.data.table(cov_d_pre)
      dt_mpd <- merge(dt_mpd, dt_cov_d, by = c("destination", "mpd_source"), all.x = TRUE)
    }
  } else {
    dt_cov <- data.table::as.data.table(cov_base_pre)

    if (weight_by %in% c("origin", "both")) {
      dt_mpd <- merge(
        dt_mpd,
        dt_cov,
        by.x = c("origin", "mpd_source"),
        by.y = c("area", "mpd_source"),
        all.x = TRUE
      )
      data.table::setnames(
        dt_mpd,
        c("pen", "Income"),
        c("pen_o", "Income_o"),
        skip_absent = TRUE
      )
    }
    if (weight_by %in% c("destination", "both")) {
      dt_mpd <- merge(
        dt_mpd,
        dt_cov,
        by.x = c("destination", "mpd_source"),
        by.y = c("area", "mpd_source"),
        all.x = TRUE
      )
      data.table::setnames(
        dt_mpd,
        c("pen", "Income"),
        c("pen_d", "Income_d"),
        skip_absent = TRUE
      )
    }
  }

  dt_base <- merge(dt_mpd, dt_bench, by = c("origin", "destination"))

  clamp_v <- function(x) {
    x[!(is.finite(x) & x > 0)] <- NA_real_
    pmax(clip_min, pmin(clip_max, x), na.rm = FALSE)
  }

  losses <- numeric(length(r_grid))

  for (i in seq_along(r_grid)) {
    r <- r_grid[i]

    w_o <- if (weight_by %in% c("origin", "both")) {
      1 / (dt_base[["Income_o"]] * dt_base[["pen_o"]] +
        (1 - dt_base[["Income_o"]]) * r)
    } else {
      NULL
    }
    w_d <- if (weight_by %in% c("destination", "both")) {
      1 / (dt_base[["Income_d"]] * dt_base[["pen_d"]] +
        (1 - dt_base[["Income_d"]]) * r)
    } else {
      NULL
    }

    w_final <- if (weight_by == "origin") {
      clamp_v(w_o)
    } else if (weight_by == "destination") {
      clamp_v(w_d)
    } else {
      sqrt(clamp_v(w_o) * clamp_v(w_d))
    }

    f_adj <- dt_base[["flow"]] * w_final

    if (calibration_aggregate == "origin") {
      adj_sums <- base::rowsum(f_adj, dt_base[["origin"]], na.rm = TRUE)
      bench_sums <- base::rowsum(
        dt_base[["flow_bench"]],
        dt_base[["origin"]],
        na.rm = TRUE
      )
      losses[i] <- sum(abs(adj_sums - bench_sums), na.rm = TRUE)
    } else {
      losses[i] <- sum(abs(f_adj - dt_base[["flow_bench"]]), na.rm = TRUE)
    }
  }

  data.frame(r = r_grid, loss = losses)
}
