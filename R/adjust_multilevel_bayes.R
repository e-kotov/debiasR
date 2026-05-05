#' Bayesian Multilevel Bias Adjustment for OD Flows (v0.2 Stage 1)
#'
#' Estimates bias-adjusted OD flows from MPD counts using a flexible Bayesian
#' multilevel count model. Stage 1 focuses on correcting observed OD flows
#' (no missing-OD imputation yet).
#'
#' Core idea:
#' \deqn{\log(\mu^{obs}_{ij}) = f(X_i, X_j, d_{ij}, e_i, u)}
#' where \eqn{e_i} is origin bias from coverage and \eqn{u} is an optional
#' random-intercept term (origin, destination, or OD).
#'
#' The adjusted flow removes the estimated bias contribution from posterior
#' linear predictors for observed OD pairs only, then summarizes draw-level
#' adjusted flows by mean or median.
#'
#' @param mpd_od_df Data frame with at least \code{origin}, \code{destination},
#'   and \code{flow_col}. Optional \code{mpd_source} is carried through.
#' @param coverage_df Data frame with at least \code{origin},
#'   \code{population}, \code{user_count}. Optional \code{destination} and
#'   \code{mpd_source} enable destination/source-specific joins.
#' @param covariates_df Area-level covariates with at least \code{area} and
#'   \code{income_col}. If \code{pop_col} exists, it is used for population
#'   covariates; otherwise populations are derived from \code{coverage_df}.
#' @param distance_df Optional OD distance data frame with
#'   \code{origin}, \code{destination}, and \code{distance_col}.
#' @param flow_col Name of MPD flow column in \code{mpd_od_df}. Default \code{"flow"}.
#' @param income_col Name of income-like covariate in \code{covariates_df}.
#'   Default \code{"income_norm"}.
#' @param pop_col Optional population column in \code{covariates_df}. Default
#'   \code{"population"}. If missing, a population proxy is built from
#'   \code{coverage_df}.
#' @param distance_col Name of distance column in \code{distance_df} (or in
#'   \code{mpd_od_df} if \code{distance_df = NULL}). Default \code{"distance_km"}.
#' @param random_intercept Random-intercept structure: \code{"origin"},
#'   \code{"destination"}, \code{"od"}, or \code{"none"}.
#' @param custom_formula Optional model formula override (character or formula).
#'   If provided, it supersedes auto-formula construction.
#' @param model_family Count family: \code{"poisson"}, \code{"negbin"},
#'   \code{"zip"}, or \code{"zinb"}.
#' @param backend Bayesian backend: \code{"auto"}, \code{"rstanarm"}, or
#'   \code{"brms"}. \code{"auto"} chooses \pkg{rstanarm} for Poisson/NegBin and
#'   \pkg{brms} for zero-inflated families.
#' @param flow_adj_summary Summary for posterior draw-level adjusted flows:
#'   \code{"mean"} or \code{"median"}. This controls how the draw-level
#'   Stage-1 adjusted flows are collapsed into the returned \code{flow_adj}
#'   column after removing the estimated coverage-bias contribution.
#' @param iter Number of sampling iterations. Default \code{1000}.
#' @param chains Number of MCMC chains. Default \code{2}.
#' @param seed Random seed. Default \code{123}.
#' @param refresh Sampler progress refresh. Default \code{0}.
#' @param include_flow_adj_draws Logical; if \code{TRUE}, attach posterior draw
#'   matrix as attribute \code{"flow_adj_draws"}. These are the draw-level
#'   adjusted observed flows underlying the returned \code{flow_adj} summary.
#'   Default \code{FALSE}.
#' @param keep_cols Optional extra columns from \code{mpd_od_df} to keep.
#'
#' @return A tibble with identifiers, original \code{flow}, adjusted
#'   \code{flow_adj}, \code{bias_e_origin}, and log-distance helper. In this
#'   Stage-1 prototype, \code{flow_adj} is only returned for observed OD rows in
#'   \code{mpd_od_df}; missing OD pairs are not imputed.
#'   Attributes:
#'   \itemize{
#'     \item \code{"model"}: fitted model object
#'     \item \code{"formula"}: fitted formula
#'     \item \code{"coefficients"}: fixed-effect summary table
#'     \item \code{"backend"}: backend used
#'     \item \code{"model_family"}: fitted family
#'     \item \code{"stage"}: development stage label
#'     \item \code{"stage_scope"}: short statement of scope
#'     \item \code{"result_metadata"}: compact Stage-1 metadata bundle
#'     \item \code{"random_intercept"}: grouping structure used
#'     \item \code{"flow_adj_summary"}: posterior summary used for \code{flow_adj}
#'     \item \code{"distance_source"}: where distance came from
#'     \item \code{"diagnostics"}: lightweight fit/convergence metadata when available
#'     \item \code{"prototype_notes"}: stage notes
#'   }
#' @export
adjust_multilevel_bayes <- function(mpd_od_df,
                                    coverage_df,
                                    covariates_df,
                                    distance_df = NULL,
                                    flow_col = "flow",
                                    income_col = "income_norm",
                                    pop_col = "population",
                                    distance_col = "distance_km",
                                    random_intercept = c("origin", "destination", "od", "none"),
                                    custom_formula = NULL,
                                    model_family = c("poisson", "negbin", "zip", "zinb"),
                                    backend = c("auto", "rstanarm", "brms"),
                                    flow_adj_summary = c("mean", "median"),
                                    iter = 1000,
                                    chains = 2,
                                    seed = 123,
                                    refresh = 0,
                                    include_flow_adj_draws = FALSE,
                                    keep_cols = character()) {

  random_intercept <- match.arg(random_intercept)
  model_family <- match.arg(model_family)
  backend <- .resolve_multilevel_backend(
    model_family = model_family,
    backend = backend
  )
  flow_adj_summary <- match.arg(flow_adj_summary)

  prep <- .prepare_multilevel_bayes_data(
    mpd_od_df = mpd_od_df,
    coverage_df = coverage_df,
    covariates_df = covariates_df,
    distance_df = distance_df,
    flow_col = flow_col,
    income_col = income_col,
    pop_col = pop_col,
    distance_col = distance_col
  )

  model_df <- prep$model_df
  if (nrow(model_df) < 2L) {
    stop("Insufficient rows for fitting after preprocessing. Need at least 2 complete rows.")
  }

  if (random_intercept == "origin" && length(unique(model_df$origin)) < 2L) {
    stop("`random_intercept = 'origin'` requires at least 2 distinct origins.")
  }
  if (random_intercept == "destination" && length(unique(model_df$destination)) < 2L) {
    stop("`random_intercept = 'destination'` requires at least 2 distinct destinations.")
  }

  if (random_intercept == "od") {
    warning(
      "OD random intercepts may be weakly identified when each OD pair appears once. ",
      "Use with caution."
    )
  }

  fit_formula <- .build_multilevel_formula(
    random_intercept = random_intercept,
    custom_formula = custom_formula,
    include_pop_terms = prep$has_pop_terms
  )

  fit <- .fit_multilevel_bayes(
    backend = backend,
    model_family = model_family,
    formula = fit_formula,
    data = model_df,
    iter = iter,
    chains = chains,
    seed = seed,
    refresh = refresh
  )

  lin_fix <- .posterior_linpred_fixef(
    fit = fit,
    backend = backend,
    newdata = model_df
  )

  omega_draw <- .extract_omega_draw(
    fit = fit,
    backend = backend,
    n_draw = nrow(lin_fix)
  )

  e_vec <- as.numeric(model_df$bias_e_origin)
  e_mat <- matrix(e_vec, nrow = nrow(lin_fix), ncol = ncol(lin_fix), byrow = TRUE)
  omega_mat <- matrix(omega_draw, nrow = nrow(lin_fix), ncol = ncol(lin_fix))

  # Remove estimated bias term from fixed-effect predictor draw-by-draw.
  lin_true <- lin_fix - omega_mat * e_mat
  flow_adj_draws <- exp(lin_true)

  flow_adj <- if (flow_adj_summary == "median") {
    apply(flow_adj_draws, 2, stats::median)
  } else {
    colMeans(flow_adj_draws)
  }

  modeled_out <- model_df |>
    dplyr::mutate(flow_adj = as.numeric(flow_adj))

  base_out <- prep$base_df |>
    dplyr::left_join(
      dplyr::select(modeled_out, row_id, flow_adj),
      by = "row_id"
    )

  keep_cols <- keep_cols[keep_cols %in% names(base_out)]
  select_cols <- c(
    "origin", "destination",
    if ("mpd_source" %in% names(base_out)) "mpd_source",
    keep_cols,
    "flow",
    "flow_adj",
    "distance_km",
    "log_distance",
    "bias_e_origin",
    "log_dist_synth"
  )

  out <- dplyr::select(base_out, dplyr::any_of(select_cols)) |>
    tibble::as_tibble()

  coef_tbl <- .coef_summary_compat(
    fit = fit,
    backend = backend,
    probs = c(0.025, 0.975)
  )

  result_metadata <- list(
    backend = backend,
    model_family = model_family,
    stage = "stage_1",
    stage_scope = "observed_od_only",
    random_intercept = random_intercept,
    flow_adj_summary = flow_adj_summary,
    distance_source = prep$distance_source
  )

  diagnostics <- .collect_multilevel_diagnostics(
    fit = fit,
    backend = backend,
    coefficients = coef_tbl
  )

  attr(out, "model") <- fit
  attr(out, "formula") <- deparse(fit_formula)
  attr(out, "coefficients") <- coef_tbl
  attr(out, "backend") <- backend
  attr(out, "model_family") <- model_family
  attr(out, "stage") <- "stage_1"
  attr(out, "stage_scope") <- "observed_od_only"
  attr(out, "result_metadata") <- result_metadata
  attr(out, "random_intercept") <- random_intercept
  attr(out, "flow_adj_summary") <- flow_adj_summary
  attr(out, "distance_source") <- prep$distance_source
  attr(out, "diagnostics") <- diagnostics
  attr(out, "prototype_notes") <- paste(
    "Stage-1 only: bias-adjusted observed OD flows.",
    "No missing OD pairs are created or imputed.",
    "No Stage-2 missing OD imputation yet.",
    "flow_adj removes the estimated coverage-bias contribution from posterior fixed-effect linear predictor draws and is summarized by", flow_adj_summary
  )

  if (isTRUE(include_flow_adj_draws)) {
    attr(out, "flow_adj_draws") <- flow_adj_draws
  }

  out
}

.collect_multilevel_diagnostics <- function(fit, backend, coefficients) {
  diagnostics <- list(
    backend = backend,
    has_bias_term = "bias_e_origin" %in% coefficients$term,
    convergence = list(status = "not_available")
  )

  diag_tbl <- .fit_summary_diagnostics_frame(fit = fit, backend = backend)
  if (is.null(diag_tbl) || nrow(diag_tbl) == 0L) {
    return(diagnostics)
  }

  diagnostics$convergence <- .summarize_diagnostics_frame(diag_tbl)
  diagnostics
}

.fit_summary_diagnostics_frame <- function(fit, backend) {
  fit_summary <- suppressWarnings(
    tryCatch(summary(fit), error = function(e) NULL)
  )

  if (is.null(fit_summary)) {
    return(NULL)
  }

  if (backend == "rstanarm") {
    coef_obj <- if (is.list(fit_summary) && !is.null(fit_summary$coefficients)) {
      fit_summary$coefficients
    } else {
      fit_summary
    }

    if (is.null(dim(coef_obj))) {
      return(NULL)
    }

    return(as.data.frame(coef_obj))
  }

  for (slot in c("fixed", "coefficients")) {
    coef_obj <- fit_summary[[slot]]
    if (!is.null(coef_obj) && !is.null(dim(coef_obj))) {
      return(as.data.frame(coef_obj))
    }
  }

  NULL
}

.summarize_diagnostics_frame <- function(diag_tbl) {
  nm_norm <- gsub("[^a-z0-9]+", "", tolower(names(diag_tbl)))
  find_metric_col <- function(patterns) {
    idx <- which(vapply(
      patterns,
      function(pattern) any(grepl(pattern, nm_norm)),
      logical(1)
    ))
    if (length(idx) == 0L) {
      return(NA_integer_)
    }

    matches <- which(grepl(patterns[idx[1]], nm_norm))
    if (length(matches) == 0L) NA_integer_ else matches[1]
  }

  rhat_idx <- find_metric_col(c("^rhat$", "rhat"))
  bulk_ess_idx <- find_metric_col(c("^bulkess$", "bulkess", "essbulk"))
  tail_ess_idx <- find_metric_col(c("^tailess$", "tailess", "esstail"))
  neff_idx <- find_metric_col(c("^neff$", "neff", "effn", "effective"))
  se_mean_idx <- find_metric_col(c("^semean$", "semean", "mcse"))

  out <- list(status = "available")

  if (!is.na(rhat_idx)) {
    rhat_vals <- suppressWarnings(as.numeric(diag_tbl[[rhat_idx]]))
    if (any(is.finite(rhat_vals))) {
      out$rhat_max <- max(rhat_vals[is.finite(rhat_vals)])
    }
  }

  if (!is.na(bulk_ess_idx)) {
    ess_bulk_vals <- suppressWarnings(as.numeric(diag_tbl[[bulk_ess_idx]]))
    if (any(is.finite(ess_bulk_vals))) {
      out$ess_bulk_min <- min(ess_bulk_vals[is.finite(ess_bulk_vals)])
    }
  }

  if (!is.na(tail_ess_idx)) {
    ess_tail_vals <- suppressWarnings(as.numeric(diag_tbl[[tail_ess_idx]]))
    if (any(is.finite(ess_tail_vals))) {
      out$ess_tail_min <- min(ess_tail_vals[is.finite(ess_tail_vals)])
    }
  }

  if (!is.na(neff_idx)) {
    neff_vals <- suppressWarnings(as.numeric(diag_tbl[[neff_idx]]))
    if (any(is.finite(neff_vals))) {
      out$n_eff_min <- min(neff_vals[is.finite(neff_vals)])
    }
  }

  if (!is.na(se_mean_idx)) {
    se_mean_vals <- suppressWarnings(as.numeric(diag_tbl[[se_mean_idx]]))
    if (any(is.finite(se_mean_vals))) {
      out$se_mean_max <- max(se_mean_vals[is.finite(se_mean_vals)])
    }
  }

  if (length(out) == 1L) {
    out$status <- "available_no_standard_metrics"
  }

  out
}

.resolve_multilevel_backend <- function(model_family, backend) {
  backend <- match.arg(backend, choices = c("auto", "rstanarm", "brms"))

  if (backend == "auto") {
    return(if (model_family %in% c("poisson", "negbin")) "rstanarm" else "brms")
  }

  backend
}

.build_multilevel_formula <- function(random_intercept,
                                      custom_formula,
                                      include_pop_terms) {
  if (!is.null(custom_formula)) {
    return(stats::as.formula(custom_formula))
  }

  rhs_terms <- c("income_o", "income_d", "log_distance", "bias_e_origin")
  if (isTRUE(include_pop_terms)) {
    rhs_terms <- c(rhs_terms, "log_pop_o", "log_pop_d")
  }

  re_term <- switch(
    random_intercept,
    origin = "(1 | origin)",
    destination = "(1 | destination)",
    od = "(1 | od_id)",
    none = NULL
  )

  rhs_all <- c(rhs_terms, re_term)
  rhs_all <- rhs_all[!is.na(rhs_all) & nzchar(rhs_all)]

  stats::as.formula(paste("flow ~", paste(rhs_all, collapse = " + ")))
}

.fit_multilevel_bayes <- function(backend,
                                  model_family,
                                  formula,
                                  data,
                                  iter,
                                  chains,
                                  seed,
                                  refresh) {

  if (backend == "rstanarm") {
    if (!requireNamespace("rstanarm", quietly = TRUE)) {
      stop("Backend 'rstanarm' requested, but package is not installed.")
    }

    if (model_family == "poisson") {
      return(rstanarm::stan_glmer(
        formula = formula,
        data = data,
        family = stats::poisson(link = "log"),
        iter = iter,
        chains = chains,
        seed = seed,
        refresh = refresh
      ))
    }

    if (model_family == "negbin") {
      return(rstanarm::stan_glmer.nb(
        formula = formula,
        data = data,
        iter = iter,
        chains = chains,
        seed = seed,
        refresh = refresh
      ))
    }

    stop(
      "model_family = '", model_family,
      "' requires backend = 'brms' (zero-inflated families are not supported by rstanarm::stan_glmer)."
    )
  }

  if (backend == "brms") {
    if (!requireNamespace("brms", quietly = TRUE)) {
      stop("Backend 'brms' requested, but package is not installed.")
    }

    fam <- switch(
      model_family,
      poisson = brms::poisson(),
      negbin = brms::negbinomial(),
      zip = brms::zero_inflated_poisson(),
      zinb = brms::zero_inflated_negbinomial()
    )

    return(brms::brm(
      formula = formula,
      data = data,
      family = fam,
      iter = iter,
      chains = chains,
      seed = seed,
      refresh = refresh,
      silent = 2
    ))
  }

  stop("Unsupported backend: ", backend)
}

.posterior_linpred_fixef <- function(fit, backend, newdata) {
  if (backend == "rstanarm") {
    lp <- rstanarm::posterior_linpred(
      fit,
      newdata = newdata,
      transform = FALSE,
      re.form = NA
    )
    return(as.matrix(lp))
  }

  lp <- brms::posterior_linpred(
    fit,
    newdata = newdata,
    transform = FALSE,
    re_formula = NA
  )
  as.matrix(lp)
}

.extract_omega_draw <- function(fit, backend, n_draw) {
  dmat <- as.matrix(fit)
  nms <- colnames(dmat)

  # rstanarm: bias_e_origin ; brms: b_bias_e_origin
  cand <- grep("(^bias_e_origin$|^b_bias_e_origin$)", nms, value = TRUE)
  if (length(cand) == 0L) {
    cand <- grep("bias_e_origin", nms, value = TRUE)
  }

  if (length(cand) == 0L) {
    warning("Could not find posterior draws for bias_e_origin; using zeros.")
    return(rep(0, n_draw))
  }

  as.numeric(dmat[, cand[1]])
}

.coef_summary_compat <- function(fit, backend, probs = c(0.025, 0.975)) {
  if (backend == "rstanarm") {
    fit_sum <- summary(fit, probs = probs)
    coef_obj <- if (is.list(fit_sum) && !is.null(fit_sum$coefficients)) fit_sum$coefficients else fit_sum
    if (is.null(dim(coef_obj))) {
      coef_obj <- matrix(coef_obj, nrow = 1)
      rownames(coef_obj) <- "model_term"
    }
    out <- as.data.frame(coef_obj)
    out$term <- rownames(out)
    rownames(out) <- NULL
  } else {
    fx <- brms::fixef(fit, probs = probs)
    out <- as.data.frame(fx)
    out$term <- rownames(out)
    rownames(out) <- NULL
  }

  if ("Estimate" %in% names(out)) names(out)[names(out) == "Estimate"] <- "mean"
  if ("Est.Error" %in% names(out)) names(out)[names(out) == "Est.Error"] <- "sd"
  if ("Q2.5" %in% names(out)) names(out)[names(out) == "Q2.5"] <- "q2.5"
  if ("Q97.5" %in% names(out)) names(out)[names(out) == "Q97.5"] <- "q97.5"
  if ("2.5%" %in% names(out)) names(out)[names(out) == "2.5%"] <- "q2.5"
  if ("97.5%" %in% names(out)) names(out)[names(out) == "97.5%"] <- "q97.5"

  out
}

.prepare_multilevel_bayes_data <- function(mpd_od_df,
                                           coverage_df,
                                           covariates_df,
                                           distance_df,
                                           flow_col,
                                           income_col,
                                           pop_col,
                                           distance_col) {
  req_mpd <- c("origin", "destination", flow_col)
  if (!all(req_mpd %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req_mpd, collapse = ", "))
  }

  req_cov <- c("origin", "population", "user_count")
  if (!all(req_cov %in% names(coverage_df))) {
    stop("`coverage_df` must contain: ", paste(req_cov, collapse = ", "))
  }

  req_covar <- c("area", income_col)
  if (!all(req_covar %in% names(covariates_df))) {
    stop("`covariates_df` must contain: ", paste(req_covar, collapse = ", "))
  }

  has_source <- "mpd_source" %in% names(mpd_od_df) && "mpd_source" %in% names(coverage_df)

  base_df <- mpd_od_df |>
    dplyr::mutate(
      row_id = dplyr::row_number(),
      origin = as.character(.data$origin),
      destination = as.character(.data$destination),
      flow = as.numeric(.data[[flow_col]]),
      od_id = paste(.data$origin, .data$destination, sep = "___")
    )

  distance_source <- "input"

  if (!is.null(distance_df)) {
    req_dist <- c("origin", "destination", distance_col)
    if (!all(req_dist %in% names(distance_df))) {
      stop("`distance_df` must contain: ", paste(req_dist, collapse = ", "))
    }

    dist_tbl <- distance_df |>
      dplyr::transmute(
        origin = as.character(.data$origin),
        destination = as.character(.data$destination),
        distance_km = as.numeric(.data[[distance_col]])
      )

    base_df <- base_df |>
      dplyr::left_join(dist_tbl, by = c("origin", "destination"))
  } else if (distance_col %in% names(base_df)) {
    base_df <- base_df |>
      dplyr::mutate(distance_km = as.numeric(.data[[distance_col]]))
  } else {
    distance_source <- "synthetic"
    warning(
      "No real distance input provided; using synthetic index-based distance. ",
      "Pass `distance_df` to use real OD distances."
    )

    area_levels <- sort(unique(c(base_df$origin, base_df$destination)))
    area_lookup <- tibble::tibble(area = area_levels, area_index = seq_along(area_levels))

    base_df <- base_df |>
      dplyr::left_join(
        dplyr::rename(area_lookup, origin = area, origin_index = area_index),
        by = "origin"
      ) |>
      dplyr::left_join(
        dplyr::rename(area_lookup, destination = area, destination_index = area_index),
        by = "destination"
      ) |>
      dplyr::mutate(distance_km = abs(.data$origin_index - .data$destination_index) + 1) |>
      dplyr::select(-origin_index, -destination_index)
  }

  base_df <- base_df |>
    dplyr::mutate(
      distance_km = as.numeric(.data$distance_km),
      log_distance = log(pmax(.data$distance_km, .Machine$double.eps)),
      log_dist_synth = .data$log_distance
    )

  if (has_source) {
    cov_origin <- coverage_df |>
      dplyr::transmute(
        origin = as.character(.data$origin),
        mpd_source = .data$mpd_source,
        population = as.numeric(.data$population),
        user_count = as.numeric(.data$user_count)
      ) |>
      dplyr::group_by(.data$origin, .data$mpd_source) |>
      dplyr::summarise(
        population = dplyr::first(.data$population),
        user_count = dplyr::first(.data$user_count),
        .groups = "drop"
      )

    base_df <- dplyr::left_join(base_df, cov_origin, by = c("origin", "mpd_source"))
  } else {
    cov_origin <- coverage_df |>
      dplyr::transmute(
        origin = as.character(.data$origin),
        population = as.numeric(.data$population),
        user_count = as.numeric(.data$user_count)
      ) |>
      dplyr::group_by(.data$origin) |>
      dplyr::summarise(
        population = dplyr::first(.data$population),
        user_count = dplyr::first(.data$user_count),
        .groups = "drop"
      )

    base_df <- dplyr::left_join(base_df, cov_origin, by = "origin")
  }

  pop_area_map <- coverage_df |>
    dplyr::transmute(
      area = as.character(.data$origin),
      pop_cov = as.numeric(.data$population)
    ) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(pop_cov = dplyr::first(.data$pop_cov), .groups = "drop")

  incomes <- covariates_df |>
    dplyr::transmute(
      area = as.character(.data$area),
      income_val = as.numeric(.data[[income_col]]),
      pop_val = if (pop_col %in% names(covariates_df)) as.numeric(.data[[pop_col]]) else NA_real_
    ) |>
    dplyr::left_join(pop_area_map, by = "area") |>
    dplyr::mutate(pop_val = ifelse(is.finite(.data$pop_val), .data$pop_val, .data$pop_cov)) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(
      income_val = dplyr::first(.data$income_val),
      pop_val = dplyr::first(.data$pop_val),
      .groups = "drop"
    )

  base_df <- base_df |>
    dplyr::left_join(
      dplyr::rename(incomes, origin = area, income_o = income_val, pop_o = pop_val),
      by = "origin"
    ) |>
    dplyr::left_join(
      dplyr::rename(incomes, destination = area, income_d = income_val, pop_d = pop_val),
      by = "destination"
    ) |>
    dplyr::mutate(
      pop_o = ifelse(is.finite(.data$pop_o), .data$pop_o, as.numeric(.data$population)),
      pop_d = ifelse(is.finite(.data$pop_d), .data$pop_d, .data$pop_o),
      log_pop_o = log(pmax(.data$pop_o, .Machine$double.eps)),
      log_pop_d = log(pmax(.data$pop_d, .Machine$double.eps)),
      bias_e_origin = 1 - (.data$user_count / .data$population)
    )

  finite_bias <- is.finite(base_df$bias_e_origin)
  bad_bias_n <- sum(!finite_bias)
  if (bad_bias_n > 0) {
    warning(bad_bias_n, " row(s) have non-finite origin bias ratio; excluded from model fitting.")
  }

  req_fit <- c("flow", "income_o", "income_d", "log_distance", "bias_e_origin")

  model_df <- base_df |>
    dplyr::filter(
      is.finite(.data$flow),
      .data$flow >= 0,
      dplyr::if_all(dplyr::all_of(req_fit), is.finite)
    )

  has_pop_terms <- all(is.finite(model_df$log_pop_o)) && all(is.finite(model_df$log_pop_d))
  if (!has_pop_terms) {
    model_df <- model_df |>
      dplyr::mutate(log_pop_o = NA_real_, log_pop_d = NA_real_)
  }

  dropped_n <- nrow(base_df) - nrow(model_df)
  if (dropped_n > 0) {
    warning(dropped_n, " row(s) were excluded from model fitting due to missing/non-finite required fields.")
  }

  list(
    base_df = base_df,
    model_df = model_df,
    has_pop_terms = has_pop_terms,
    distance_source = distance_source
  )
}
