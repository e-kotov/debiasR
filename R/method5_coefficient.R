#' Method 5: Global coefficient calibration with multiple model families
#'
#' Calibrate a multiplicative coefficient that links MPD-derived flows to
#' benchmark flows, following the "coefficient" approach in Chi et al.
#'
#' All supported families enforce a proportional structure
#' \deqn{E[F^{bench}_{ij}] = \beta F^{mpd}_{ij}}
#' but differ in the assumed distribution for counts:
#' \itemize{
#'   \item \code{"ols"}: linear regression (baseline).
#'   \item \code{"poisson"}: Poisson GLM with \code{offset(log(F^{mpd}))}.
#'   \item \code{"negbin"}: Negative Binomial GLM with \code{offset(log(F^{mpd}))}.
#'   \item \code{"zinb"}: Zero-inflated NB with \code{offset(log(F^{mpd}))}.
#' }
#'
#' For \code{"poisson"}, \code{"negbin"}, and \code{"zinb"}, we fit:
#' \deqn{\log(\mu_{ij}) = \alpha + \log(F^{mpd}_{ij})}
#' so that \eqn{\mu_{ij} = \exp(\alpha) F^{mpd}_{ij}} and
#' \eqn{\beta = \exp(\alpha)}.
#'
#' @param mpd_od_df Data frame of MPD flows with at least:
#'   \code{origin, destination} and \code{flow_col_mpd}. Optionally
#'   \code{mpd_source} for \code{by_source = TRUE}.
#'
#' @param benchmark_od_df Data frame of benchmark flows with at least:
#'   \code{origin, destination} and \code{flow_col_bench}.
#'
#' @param flow_col_mpd Name of MPD flow column. Default "flow".
#' @param flow_col_bench Name of benchmark flow column. Default "flow".
#'
#' @param model_family One of \code{"ols"}, \code{"poisson"},
#'   \code{"negbin"}, \code{"zinb"}. Default "ols".
#'
#' @param level Aggregation level for calibration:
#'   \itemize{
#'     \item \code{"od"} (default): use OD pairs.
#'     \item \code{"origin"}: use origin totals.
#'     \item \code{"destination"}: use destination totals.
#'   }
#'
#' @param fit_intercept For \code{model_family = "ols"} only:
#'   if \code{FALSE} (default), fit through the origin
#'   \eqn{F^{bench} = \beta F^{mpd}}.
#'   if \code{TRUE}, fit \eqn{F^{bench} = \alpha + \beta F^{mpd}} and derive a
#'   flow-specific correction factor \eqn{CF_{ij} = \hat{F}^{bench}_{ij}/F^{mpd}_{ij}}.
#'   Ignored for count models, where the functional form is fixed as above.
#'
#' @param by_source Logical; if \code{TRUE} and both inputs contain
#'   \code{mpd_source}, estimate separate coefficients per source.
#'
#' @param keep_cols Optional character vector of extra columns from
#'   \code{mpd_od_df} to retain.
#'
#' @return A tibble with:
#'   \itemize{
#'     \item \code{origin, destination,} (and \code{mpd_source} if present),
#'     \item \code{flow}: original MPD flow,
#'     \item \code{flow_adj}: adjusted flow,
#'     \item \code{coef_factor}: applied multiplicative factor.
#'   }
#'   Attributes:
#'   \itemize{
#'     \item \code{"coef"}: estimated coefficient(s)
#'     \item \code{"model"}: data frame summarising fits
#'   }
#'
#' @details
#' - Requires overlapping positive flows in MPD and benchmark after aggregation.
#' - For \code{"negbin"}, requires \pkg{MASS} (Suggested).
#' - For \code{"zinb"}, requires \pkg{pscl} (Suggested).
#' - If a required package is unavailable, an informative error is thrown.
#'
#' @export
method5_coefficient <- function(mpd_od_df,
                                benchmark_od_df,
                                flow_col_mpd   = "flow",
                                flow_col_bench = "flow",
                                model_family   = c("ols", "poisson", "negbin", "zinb"),
                                level          = c("od", "origin", "destination"),
                                fit_intercept  = FALSE,
                                by_source      = FALSE,
                                keep_cols      = character()) {

  model_family <- match.arg(model_family)
  level        <- match.arg(level)

  # ---- checks ----
  req_mpd   <- c("origin", "destination", flow_col_mpd)
  req_bench <- c("origin", "destination", flow_col_bench)

  if (!all(req_mpd %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req_mpd, collapse = ", "))
  }
  if (!all(req_bench %in% names(benchmark_od_df))) {
    stop("`benchmark_od_df` must contain: ", paste(req_bench, collapse = ", "))
  }

  has_source <- "mpd_source" %in% names(mpd_od_df) &&
    "mpd_source" %in% names(benchmark_od_df)
  if (by_source && !has_source) {
    stop("`by_source = TRUE` requires `mpd_source` in both inputs.")
  }

  if (model_family != "ols" && fit_intercept) {
    warning("`fit_intercept` is ignored for count model families; using offset(log(x)) with intercept only.")
  }

  # ---- build calibration xy by level & source ----

  build_xy <- function(mpd, bench, lvl) {
    if (lvl == "od") {
      dplyr::inner_join(
        mpd  %>% dplyr::select(origin, destination, x = !!rlang::sym(flow_col_mpd)),
        bench %>% dplyr::select(origin, destination, y = !!rlang::sym(flow_col_bench)),
        by = c("origin", "destination")
      )
    } else if (lvl == "origin") {
      dplyr::inner_join(
        mpd %>%
          dplyr::group_by(origin) %>%
          dplyr::summarise(x = sum(.data[[flow_col_mpd]], na.rm = TRUE), .groups = "drop"),
        bench %>%
          dplyr::group_by(origin) %>%
          dplyr::summarise(y = sum(.data[[flow_col_bench]], na.rm = TRUE), .groups = "drop"),
        by = "origin"
      )
    } else { # "destination"
      dplyr::inner_join(
        mpd %>%
          dplyr::group_by(destination) %>%
          dplyr::summarise(x = sum(.data[[flow_col_mpd]], na.rm = TRUE), .groups = "drop"),
        bench %>%
          dplyr::group_by(destination) %>%
          dplyr::summarise(y = sum(.data[[flow_col_bench]], na.rm = TRUE), .groups = "drop"),
        by = "destination"
      )
    }
  }

  # fit for one (optionally source-specific) subset
  fit_one <- function(mpd_sub, bench_sub, src_label = NA_character_) {
    xy <- build_xy(mpd_sub, bench_sub, level)
    xy <- xy %>%
      dplyr::filter(is.finite(x), is.finite(y), x > 0, y >= 0)

    if (nrow(xy) < 2L) {
      return(list(
        summary = data.frame(
          mpd_source = src_label,
          n          = nrow(xy),
          beta       = NA_real_,
          intercept  = NA_real_,
          r_squared  = NA_real_,
          family     = model_family,
          level      = level,
          stringsAsFactors = FALSE
        ),
        beta = NA_real_,
        alpha = NA_real_
      ))
    }

    if (model_family == "ols") {
      if (fit_intercept) {
        fit <- stats::lm(y ~ x, data = xy)
        co  <- stats::coef(fit)
        alpha <- unname(co[1])
        beta  <- unname(co[2])
        rsq   <- unname(summary(fit)$r.squared)
      } else {
        # through origin: beta = sum(xy)/sum(x^2)
        beta  <- sum(xy$x * xy$y) / sum(xy$x^2)
        alpha <- 0
        yhat  <- beta * xy$x
        rsq   <- suppressWarnings(stats::cor(xy$y, yhat))^2
      }

    } else if (model_family == "poisson") {
      # log(mu) = alpha + log(x)
      fit <- stats::glm(
        y ~ 1,
        data = xy,
        family = stats::poisson(link = "log"),
        offset = log(xy$x)
      )
      alpha <- unname(stats::coef(fit)[1])
      beta  <- exp(alpha)
      mu    <- beta * xy$x
      rsq   <- suppressWarnings(stats::cor(xy$y, mu))^2

    } else if (model_family == "negbin") {
      if (!requireNamespace("MASS", quietly = TRUE)) {
        stop("model_family = 'negbin' requires the 'MASS' package.")
      }
      fit <- MASS::glm.nb(
        y ~ 1 + offset(log(x)),
        data = xy
      )
      alpha <- unname(stats::coef(fit)[1])
      beta  <- exp(alpha)
      mu    <- beta * xy$x
      rsq   <- suppressWarnings(stats::cor(xy$y, mu))^2

    } else if (model_family == "zinb") {
      if (!requireNamespace("pscl", quietly = TRUE)) {
        stop("model_family = 'zinb' requires the 'pscl' package.")
      }
      # count model: log(mu) = alpha + log(x); zero model: intercept only
      fit <- pscl::zeroinfl(
        y ~ 1 | 1,
        dist   = "negbin",
        offset = log(x),
        data   = xy
      )

      # extract intercept from COUNT component
      alpha <- unname(stats::coef(fit, model = "count")[1])
      beta  <- exp(alpha)

      mu    <- beta * xy$x
      rsq   <- suppressWarnings(stats::cor(xy$y, mu))^2
    } else {
      stop("Unsupported model_family: ", model_family)
    }

    summary_row <- data.frame(
      mpd_source = src_label,
      n          = nrow(xy),
      beta       = beta,
      intercept  = alpha,
      r_squared  = rsq,
      family     = model_family,
      level      = level,
      stringsAsFactors = FALSE
    )

    list(summary = summary_row, beta = beta, alpha = alpha)
  }

  # --- estimate coefficients (global or by source) ---

  if (by_source) {
    sources <- intersect(
      unique(mpd_od_df$mpd_source),
      unique(benchmark_od_df$mpd_source)
    )
    if (length(sources) == 0L) {
      stop("No overlapping `mpd_source` values for by_source = TRUE.")
    }

    fits <- lapply(sources, function(s) {
      fit_one(
        mpd_sub   = dplyr::filter(mpd_od_df, .data$mpd_source == s),
        bench_sub = dplyr::filter(benchmark_od_df, .data$mpd_source == s),
        src_label = s
      )
    })

    coef_tbl <- do.call(rbind, lapply(fits, `[[`, "summary"))
    betas    <- setNames(coef_tbl$beta, coef_tbl$mpd_source)

  } else {
    fit <- fit_one(mpd_od_df, benchmark_od_df, src_label = NA_character_)
    coef_tbl <- fit$summary
    betas    <- fit$beta
  }

  # ---- apply coefficients ----

  out <- mpd_od_df

  # keep extra cols if exist
  if (length(keep_cols)) {
    keep_cols <- keep_cols[keep_cols %in% names(out)]
  } else {
    keep_cols <- character(0)
  }

  if (by_source) {
    out <- dplyr::left_join(
      out,
      coef_tbl %>% dplyr::select(mpd_source, beta),
      by = "mpd_source"
    )
    out$coef_factor <- out$beta
    out$beta <- NULL
  } else {
    out$coef_factor <- as.numeric(betas)
  }

  # invalid coefficients -> NA
  out$coef_factor[!is.finite(out$coef_factor) | out$coef_factor <= 0] <- NA_real_

  # compute adjusted flow
  x_vec <- out[[flow_col_mpd]]
  out$flow_adj <- ifelse(
    is.finite(out$coef_factor),
    x_vec * out$coef_factor,
    NA_real_
  )

  # final column order
  out <- out %>%
    dplyr::select(
      dplyr::any_of(c("origin", "destination",
                      if (has_source) "mpd_source")),
      dplyr::any_of(keep_cols),
      !!rlang::sym(flow_col_mpd),
      flow_adj,
      coef_factor
    ) %>%
    dplyr::rename(flow = !!rlang::sym(flow_col_mpd)) %>%
    tibble::as_tibble()

  attr(out, "coef")  <- if (by_source) coef_tbl else coef_tbl$beta[1]
  attr(out, "model") <- coef_tbl

  out
}
