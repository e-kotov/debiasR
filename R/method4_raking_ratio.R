#' Method 4: Raking ratio / IPF adjustment of OD flows
#'
#' Adjusts observed OD flows so that their margins match given benchmark
#' totals using iterative proportional fitting (IPF), also known as raking.
#'
#' This is a generic implementation that covers:
#' \enumerate{
#'   \item \strong{Location-only case} (most users):
#'         raking on origin and/or destination totals derived from benchmark
#'         flows or population.
#'   \item \strong{Stratified case} (age, sex, etc.):
#'         raking within each combination of \code{group_cols}, using
#'         group-specific origin and destination margins.
#' }
#'
#' The method operates on aggregated flows (no microdata) and is deliberately
#' transparent:
#'
#' \deqn{F_{ij}^{adj} = F_{ij}^{obs} \times w_{ij}}
#'
#' where the cell weights \eqn{w_{ij}} are determined so that:
#'
#' \itemize{
#'   \item \eqn{\sum_j F_{ij}^{adj} = T_i^{(O)}} for all origins with supplied
#'         origin targets, and/or
#'   \item \eqn{\sum_i F_{ij}^{adj} = T_j^{(D)}} for all destinations with
#'         supplied destination targets,
#' }
#'
#' with \eqn{T_i^{(O)}} and \eqn{T_j^{(D)}} provided by the user, typically
#' from census or high-quality benchmark flows or populations.
#'
#' @section Inputs:
#'
#' @param mpd_od_df Data frame with at least:
#'   \code{origin, destination, flow}; an \code{mpd_source} column is carried
#'   through if present. May include stratification variables named in
#'   \code{group_cols}.
#'
#' @param origin_targets Optional data frame of origin margin targets with:
#'   \code{origin, target}, and, if using \code{group_cols},
#'   also those columns. Targets are interpreted within each
#'   (group_cols) subset.
#'
#' @param destination_targets Optional data frame of destination margin targets
#'   with: \code{destination, target}, and, if using \code{group_cols},
#'   also those columns.
#'
#' @param benchmark_od_df Optional benchmark OD with columns:
#'   \code{origin, destination} and a benchmark flow column (see
#'   \code{flow_col_bench}). If supplied and \code{origin_targets} and/or
#'   \code{destination_targets} are NULL, margins are derived from this
#'   benchmark (by origin / destination, optionally stratified).
#'
#' @param flow_col_bench Name of benchmark flow column in
#'   \code{benchmark_od_df}. Default "flow".
#'
#' @param group_cols Optional character vector of stratification variables
#'   (e.g. \code{c("age_group","sex")}). If provided, these must exist in
#'   \code{mpd_od_df} and the corresponding target tables; raking is performed
#'   independently within each group combination.
#'
#' @param max_iter Maximum IPF iterations. Default 200.
#' @param tol Convergence tolerance on relative margin differences. Default 1e-6.
#' @param clip_min,clip_max Clamp resulting cell weights into
#'   \code{[clip_min, clip_max]} to avoid extreme corrections. Defaults 0, Inf.
#' @param keep_cols Optional character vector of extra columns from
#'   \code{mpd_od_df} to keep in the output.
#'
#' @return A tibble with:
#'   \itemize{
#'     \item origin, destination, (mpd_source), (group_cols)
#'     \item flow: original observed flow
#'     \item flow_adj: raked flow
#'     \item weight_ipf: multiplicative weight = flow_adj / flow
#'   }
#'   Attributes:
#'     \item \code{"ipf_converged"}: logical
#'     \item \code{"ipf_iterations"}: iterations used
#'
#' @details
#' - If only \code{origin_targets} is supplied, raking enforces origin margins.
#' - If only \code{destination_targets} is supplied, raking enforces destination margins.
#' - If both are supplied (or derived from \code{benchmark_od_df}), standard
#'   bi-proportional IPF is performed.
#' - Cells with zero initial flow cannot be created by this implementation;
#'   if benchmark margins suggest mass in structurally zero cells, margins
#'   will not be matched exactly. This is by design and should be inspected.
#'
#' @export
method4_raking_ratio <- function(mpd_od_df,
                                 origin_targets = NULL,
                                 destination_targets = NULL,
                                 benchmark_od_df = NULL,
                                 flow_col_bench = "flow",
                                 group_cols = NULL,
                                 max_iter = 200,
                                 tol = 1e-6,
                                 clip_min = 0,
                                 clip_max = Inf,
                                 keep_cols = character()) {

  # ---- basic checks ----
  req <- c("origin", "destination", "flow")
  if (!all(req %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req, collapse = ", "))
  }

  if (is.null(origin_targets) && is.null(destination_targets) &&
      !is.null(benchmark_od_df)) {
    if (!all(c("origin", "destination", flow_col_bench) %in% names(benchmark_od_df))) {
      stop("`benchmark_od_df` must contain origin, destination, and `flow_col_bench`.")
    }
  }

  # group_cols
  if (!is.null(group_cols) && length(group_cols) > 0) {
    missing_mpd <- setdiff(group_cols, names(mpd_od_df))
    if (length(missing_mpd)) {
      stop("`group_cols` missing in mpd_od_df: ",
           paste(missing_mpd, collapse = ", "))
    }
  } else {
    group_cols <- character(0)
  }
  group_syms <- rlang::syms(group_cols)

  # ---- derive margins from benchmark if needed ----
  if (!is.null(benchmark_od_df)) {
    bench <- benchmark_od_df |>
      dplyr::transmute(
        origin      = as.character(.data$origin),
        destination = as.character(.data$destination),
        flow_bench  = as.numeric(.data[[flow_col_bench]])
      )

    if (length(group_cols)) {
      # assume benchmark has same group_cols if used
      missing_bench <- setdiff(group_cols, names(benchmark_od_df))
      if (length(missing_bench)) {
        stop("`group_cols` missing in benchmark_od_df: ",
             paste(missing_bench, collapse = ", "))
      }
      bench <- bench |>
        dplyr::bind_cols(
          benchmark_od_df[, group_cols, drop = FALSE]
        )
    }

    if (is.null(origin_targets)) {
      origin_targets <- bench |>
        dplyr::group_by(origin, !!!group_syms) |>
        dplyr::summarise(target = sum(flow_bench, na.rm = TRUE),
                         .groups = "drop")
    }

    if (is.null(destination_targets)) {
      destination_targets <- bench |>
        dplyr::group_by(destination, !!!group_syms) |>
        dplyr::summarise(target = sum(flow_bench, na.rm = TRUE),
                         .groups = "drop")
    }
  }

  # validate targets if provided
  if (!is.null(origin_targets)) {
    if (!all(c("origin", "target") %in% names(origin_targets))) {
      stop("`origin_targets` must contain columns: origin, target.")
    }
    missing_gc <- setdiff(group_cols, names(origin_targets))
    if (length(missing_gc)) {
      stop("`origin_targets` missing group_cols: ",
           paste(missing_gc, collapse = ", "))
    }
  }
  if (!is.null(destination_targets)) {
    if (!all(c("destination", "target") %in% names(destination_targets))) {
      stop("`destination_targets` must contain columns: destination, target.")
    }
    missing_gc <- setdiff(group_cols, names(destination_targets))
    if (length(missing_gc)) {
      stop("`destination_targets` missing group_cols: ",
           paste(missing_gc, collapse = ", "))
    }
  }

  if (is.null(origin_targets) && is.null(destination_targets)) {
    stop("Provide at least one of `origin_targets`, `destination_targets`, or `benchmark_od_df`.")
  }

  # ---- helper: IPF on one (group_cols) subset ----
  ipf_subset <- function(df_sub,
                         ot_sub = NULL,
                         dt_sub = NULL,
                         max_iter, tol) {

    # df_sub: origin, destination, flow (positive)
    # ot_sub: origin, target
    # dt_sub: destination, target

    # initialize with observed flows
    mat <- df_sub$flow
    origin <- df_sub$origin
    destination <- df_sub$destination

    # indices
    o_levels <- unique(origin)
    d_levels <- unique(destination)
    o_index <- match(origin, o_levels)
    d_index <- match(destination, d_levels)

    # precompute lists of cell indices per origin/dest
    rows_by_o <- split(seq_along(mat), o_index)
    rows_by_d <- split(seq_along(mat), d_index)

    # origin targets vector (if any)
    if (!is.null(ot_sub)) {
      ot_vec <- ot_sub$target[match(o_levels, ot_sub$origin)]
    } else {
      ot_vec <- rep(NA_real_, length(o_levels))
    }

    # destination targets vector (if any)
    if (!is.null(dt_sub)) {
      dt_vec <- dt_sub$target[match(d_levels, dt_sub$destination)]
    } else {
      dt_vec <- rep(NA_real_, length(d_levels))
    }

    # IPF iterations
    converged <- FALSE
    it <- 0L

    while (it < max_iter) {
      it <- it + 1L
      max_rel_dev <- 0

      # scale rows
      if (any(is.finite(ot_vec))) {
        for (i in seq_along(o_levels)) {
          target_i <- ot_vec[i]
          if (!is.finite(target_i)) next
          idx <- rows_by_o[[i]]
          current_sum <- sum(mat[idx])
          if (current_sum > 0) {
            f <- target_i / current_sum
            mat[idx] <- mat[idx] * f
            max_rel_dev <- max(max_rel_dev, abs(f - 1))
          }
        }
      }

      # scale columns
      if (any(is.finite(dt_vec))) {
        for (j in seq_along(d_levels)) {
          target_j <- dt_vec[j]
          if (!is.finite(target_j)) next
          idx <- rows_by_d[[j]]
          current_sum <- sum(mat[idx])
          if (current_sum > 0) {
            f <- target_j / current_sum
            mat[idx] <- mat[idx] * f
            max_rel_dev <- max(max_rel_dev, abs(f - 1))
          }
        }
      }

      if (max_rel_dev < tol) {
        converged <- TRUE
        break
      }
    }

    weight <- mat / df_sub$flow
    weight[!is.finite(weight)] <- NA_real_

    list(
      flow_adj = mat,
      weight_ipf = pmax(clip_min,
                        pmin(weight, clip_max,
                             na.rm = FALSE)),
      converged = converged,
      iterations = it
    )
  }

  # ---- run IPF by group_cols ----

  out_list <- list()
  conv_vec <- logical(0)
  iter_vec <- integer(0)

  # split mpd_od_df by group_cols (or single chunk if none)
  mpd_split <- if (length(group_cols)) {
    split(mpd_od_df, mpd_od_df[group_cols], drop = TRUE)
  } else {
    list(all = mpd_od_df)
  }

  for (nm in names(mpd_split)) {
    df_sub <- mpd_split[[nm]]

    # subset origin/dest targets if present
    ot_sub <- NULL
    dt_sub <- NULL

    if (!is.null(origin_targets)) {
      if (length(group_cols)) {
        key_vals <- df_sub[1, group_cols, drop = FALSE]
        ot_sub <- origin_targets
        for (gc in group_cols) {
          ot_sub <- ot_sub[ot_sub[[gc]] == key_vals[[gc]], , drop = FALSE]
        }
      } else {
        ot_sub <- origin_targets
      }
      ot_sub <- ot_sub[ot_sub$origin %in% df_sub$origin, , drop = FALSE]
      if (nrow(ot_sub) == 0) ot_sub <- NULL
    }

    if (!is.null(destination_targets)) {
      if (length(group_cols)) {
        key_vals <- df_sub[1, group_cols, drop = FALSE]
        dt_sub <- destination_targets
        for (gc in group_cols) {
          dt_sub <- dt_sub[dt_sub[[gc]] == key_vals[[gc]], , drop = FALSE]
        }
      } else {
        dt_sub <- destination_targets
      }
      dt_sub <- dt_sub[dt_sub$destination %in% df_sub$destination, , drop = FALSE]
      if (nrow(dt_sub) == 0) dt_sub <- NULL
    }

    adj <- ipf_subset(df_sub, ot_sub, dt_sub, max_iter, tol)

    df_sub$flow_adj  <- adj$flow_adj
    df_sub$weight_ipf <- adj$weight_ipf

    out_list[[nm]] <- df_sub
    conv_vec <- c(conv_vec, adj$converged)
    iter_vec <- c(iter_vec, adj$iterations)
  }

  out <- dplyr::bind_rows(out_list)

  # keep selected columns
  if (length(keep_cols)) {
    keep_cols <- keep_cols[keep_cols %in% names(out)]
  } else {
    keep_cols <- character(0)
  }

  out <- out %>%
    dplyr::select(
      dplyr::any_of(c("origin", "destination",
                      "mpd_source",
                      group_cols)),
      dplyr::any_of(keep_cols),
      flow,
      flow_adj,
      weight_ipf
    ) %>%
    tibble::as_tibble()

  attr(out, "ipf_converged")  <- all(conv_vec)
  attr(out, "ipf_iterations") <- max(iter_vec)

  out
}
