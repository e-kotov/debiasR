#' Selection Rate II weighting (Zagheni & Weber 2012) with k calibration
#'
#' Implements the "Selection Rate II" correction:
#'   CF(p; k) = p (e^{-k} - 1) / (e^{-k p} - 1)
#'
#' where p is a penetration rate in [0,1] (e.g. Internet or platform
#' penetration), and k > 0 controls how strongly selection bias increases
#' as p decreases.
#'
#' For OD flows:
#'   - weight_by = "origin":    p = U_o / P_o, weight = CF(p; k)
#'   - weight_by = "destination": p = U_d / P_d, weight = CF(p; k)
#'   - weight_by = "both":      weight = sqrt(CF_origin * CF_destination)
#'
#' Supports:
#'   1) Location-only OD (default).
#'   2) Stratified OD (e.g. age/sex) via group_cols; then p and CF are
#'      computed by (area, group_cols).
#'
#' Calibration of k:
#'   - If k is provided (numeric scalar): use it.
#'   - Else if benchmark_od_df is provided:
#'       search k_grid, pick k* minimising sum of absolute errors between
#'       adjusted and benchmark flows (origin-aggregated or OD-level).
#'   - Else: default k = 1.
#'
#' @param mpd_od_df Data frame with at least:
#'   origin, destination, flow, mpd_source; plus group_cols if used.
#' @param coverage_df Data frame with:
#'   NEW: origin, origin_population, origin_user_count,
#'        destination, destination_population, destination_user_count, mpd_source
#'   or LEGACY: origin, population, user_count, mpd_source.
#'   Must contain group_cols if used.
#' @param weight_by "origin", "destination", or "both".
#' @param group_cols Optional character vector of stratification variables
#'   present in both mpd_od_df and coverage_df (e.g. c("age_group","sex")).
#' @param k Optional positive scalar. If NULL and benchmark_od_df supplied,
#'   k is calibrated by grid search. If NULL and no benchmark, k = 1.
#' @param k_grid Grid of candidate k values for calibration when k is NULL.
#'   Default seq(0.1, 5, by = 0.1).
#' @param benchmark_od_df Optional benchmark OD for calibrating k.
#'   Must contain origin, destination, and a flow column.
#' @param flow_col_bench Name of benchmark flow column. Default "flow".
#' @param calibration_aggregate "origin" (default, compare origin totals)
#'   or "od" (compare OD flows directly).
#' @param clip_min,clip_max Clamp weights into [clip_min, clip_max].
#' @param keep_cols Extra columns from mpd_od_df to retain.
#'
#' @return Tibble with:
#'   origin, destination, mpd_source, (group_cols), flow,
#'   weight_origin, weight_destination, weight_missing, flow_adj.
#'   Attributes:
#'     - "k" : numeric k used.
#'     - "k_calibration" : data.frame of k vs loss (if calibrated).
#' @export
method3_selection_rateII <- function(mpd_od_df,
                                     coverage_df,
                                     weight_by = c("origin", "destination", "both"),
                                     group_cols = NULL,
                                     k = NULL,
                                     k_grid = seq(0.1, 5, by = 0.1),
                                     benchmark_od_df = NULL,
                                     flow_col_bench = "flow",
                                     calibration_aggregate = c("origin", "od"),
                                     clip_min = 0,
                                     clip_max = Inf,
                                     keep_cols = character()) {

  weight_by <- match.arg(weight_by)
  calibration_aggregate <- match.arg(calibration_aggregate)

  # ---- basic checks ----
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

  # handle group_cols
  if (!is.null(group_cols) && length(group_cols) > 0) {
    miss_mpd <- setdiff(group_cols, names(mpd_od_df))
    miss_cov <- setdiff(group_cols, names(coverage_df))
    if (length(miss_mpd)) {
      stop("`group_cols` missing in mpd_od_df: ", paste(miss_mpd, collapse = ", "))
    }
    if (length(miss_cov)) {
      stop("`group_cols` missing in coverage_df: ", paste(miss_cov, collapse = ", "))
    }
  } else {
    group_cols <- character(0)
  }
  group_syms <- rlang::syms(group_cols)

  # ---- helpers ----

  clamp_weight <- function(w) {
    w <- suppressWarnings(as.numeric(w))
    w[!(is.finite(w) & w > 0)] <- NA_real_
    w <- pmax(clip_min, pmin(w, clip_max), na.rm = FALSE)
    w
  }

  cf_fun <- function(p, k_val) {
    p <- suppressWarnings(as.numeric(p))
    p[p < 0] <- 0
    p[p > 1] <- 1

    eps <- 1e-8
    p_safe <- p
    p_safe[p_safe < eps] <- eps
    p_safe[p_safe > 1 - eps] <- 1 - eps

    num <- p_safe * (exp(-k_val) - 1)
    den <- (exp(-k_val * p_safe) - 1)

    cf <- num / den
    cf[p == 1] <- 1
    cf[p == 0] <- 0
    cf
  }

  # ---- precompute penetrations p_o, p_d that do not depend on k ----

  if (has_new) {
    cov_o_pre <- coverage_df %>%
      dplyr::transmute(
        origin     = as.character(.data$origin),
        mpd_source = .data$mpd_source,
        !!!group_syms,
        P_o        = as.numeric(.data$origin_population),
        U_o        = as.numeric(.data$origin_user_count)
      ) %>%
      dplyr::filter(is.finite(P_o), P_o > 0, is.finite(U_o), U_o >= 0) %>%
      dplyr::group_by(origin, mpd_source, !!!group_syms) %>%
      dplyr::summarise(
        P_o = sum(P_o, na.rm = TRUE),
        U_o = sum(U_o, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(p_o = pmin(pmax(U_o / P_o, 0), 1))

    cov_d_pre <- coverage_df %>%
      dplyr::transmute(
        destination = as.character(.data$destination),
        mpd_source  = .data$mpd_source,
        !!!group_syms,
        P_d         = as.numeric(.data$destination_population),
        U_d         = as.numeric(.data$destination_user_count)
      ) %>%
      dplyr::filter(is.finite(P_d), P_d > 0, is.finite(U_d), U_d >= 0) %>%
      dplyr::group_by(destination, mpd_source, !!!group_syms) %>%
      dplyr::summarise(
        P_d = sum(P_d, na.rm = TRUE),
        U_d = sum(U_d, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(p_d = pmin(pmax(U_d / P_d, 0), 1))

  } else {
    cov_base_pre <- coverage_df %>%
      dplyr::transmute(
        area       = as.character(.data$origin),
        mpd_source = .data$mpd_source,
        !!!group_syms,
        P          = as.numeric(.data$population),
        U          = as.numeric(.data$user_count)
      ) %>%
      dplyr::filter(is.finite(P), P > 0, is.finite(U), U >= 0) %>%
      dplyr::group_by(area, mpd_source, !!!group_syms) %>%
      dplyr::summarise(
        P = sum(P, na.rm = TRUE),
        U = sum(U, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(p = pmin(pmax(U / P, 0), 1))

    cov_o_pre <- cov_base_pre %>%
      dplyr::rename(origin = area, p_o = p)

    cov_d_pre <- cov_base_pre %>%
      dplyr::rename(destination = area, p_d = p)
  }

  # ---- internal: compute adjusted flows for a given k ----

  compute_with_k <- function(k_val) {
    if (!is.finite(k_val) || k_val <= 0) return(NULL)

    cov_o <- NULL
    cov_d <- NULL

    if (weight_by %in% c("origin", "both")) {
      cov_o <- cov_o_pre %>%
        dplyr::mutate(
          weight_origin = clamp_weight(cf_fun(p_o, k_val))
        ) %>%
        dplyr::select(origin, mpd_source, !!!group_syms, weight_origin)
    }

    if (weight_by %in% c("destination", "both")) {
      cov_d <- cov_d_pre %>%
        dplyr::mutate(
          weight_destination = clamp_weight(cf_fun(p_d, k_val))
        ) %>%
        dplyr::select(destination, mpd_source, !!!group_syms, weight_destination)
    }

    out <- mpd_od_df
    if (length(keep_cols)) {
      keep_local <- keep_cols[keep_cols %in% names(out)]
    } else keep_local <- character(0)

    join_by_o <- c("origin", "mpd_source", group_cols)
    join_by_d <- c("destination", "mpd_source", group_cols)

    if (!is.null(cov_o)) {
      out <- dplyr::left_join(out, cov_o, by = join_by_o)
    } else {
      out$weight_origin <- NA_real_
    }

    if (!is.null(cov_d)) {
      out <- dplyr::left_join(out, cov_d, by = join_by_d)
    } else {
      out$weight_destination <- NA_real_
    }

    final_w <- dplyr::case_when(
      weight_by == "origin"      ~ out$weight_origin,
      weight_by == "destination" ~ out$weight_destination,
      weight_by == "both"        ~ suppressWarnings(
        sqrt(out$weight_origin * out$weight_destination)
      )
    )

    if (weight_by == "both") {
      final_w[!is.finite(out$weight_origin) |
                !is.finite(out$weight_destination)] <- NA_real_
    }

    out$weight_missing <- !is.finite(final_w)
    out$flow_adj <- ifelse(is.finite(final_w), out$flow * final_w, NA_real_)

    dplyr::select(
      out,
      dplyr::any_of(c("origin", "destination", "mpd_source", group_cols)),
      dplyr::any_of(keep_local),
      flow,
      weight_origin,
      weight_destination,
      weight_missing,
      flow_adj
    ) %>%
      tibble::as_tibble()
  }

  # ---- choose k: fixed, calibrated, or default ----

  k_used <- NULL
  k_diag <- NULL

  if (!is.null(k)) {
    if (!is.numeric(k) || length(k) != 1 || k <= 0) {
      stop("`k` must be a positive scalar.")
    }
    k_used <- as.numeric(k)

  } else if (!is.null(benchmark_od_df)) {
    # calibration mode

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

    if (length(k_grid) == 0L) {
      stop("`k_grid` is empty; provide candidate k values.")
    }

    ks <- numeric(0)
    losses <- numeric(0)

    for (k_val in k_grid) {
      adj <- compute_with_k(k_val)
      if (is.null(adj)) next

      joined <- dplyr::inner_join(
        adj %>% dplyr::select(origin, destination, flow_adj),
        bench_df,
        by = c("origin", "destination")
      )
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
      } else {
        loss <- sum(abs(joined$flow_adj - joined$flow_bench), na.rm = TRUE)
      }

      ks <- c(ks, k_val)
      losses <- c(losses, loss)
    }

    if (!length(ks)) {
      stop("Calibration failed: no overlap between adjusted and benchmark flows.")
    }

    best <- which.min(losses)
    k_used <- ks[best]
    k_diag <- data.frame(k = ks, loss = losses)

  } else {
    # no k given, no benchmark: default
    k_used <- 1
  }

  # ---- final run with chosen k ----

  out_final <- compute_with_k(k_used)
  attr(out_final, "k") <- k_used
  if (!is.null(k_diag)) {
    attr(out_final, "k_calibration") <- k_diag
  }

  out_final
}
