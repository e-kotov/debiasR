#' Bayesian Multilevel Bias Adjustment for OD Flows (v0.2 Stage 1)
#'
#' Estimates bias-adjusted OD flows from MPD counts using a flexible Bayesian
#' multilevel count model. The observed-OD mode corrects observed MPD flows.
#' The complete-grid mode fits to originally observed source rows and predicts
#' adjusted flows for every row in a supplied square OD grid.
#'
#' Core idea:
#' \deqn{\log(\mu^{obs}_{ij}) = f(X_i, X_j, d_{ij}, e_i, u)}
#' where \eqn{e_i} is origin bias from coverage and \eqn{u} is an optional
#' random-effect structure supplied through a model formula.
#'
#' Users can either supply a single reduced-form \code{formula}, or separate
#' \code{mobility_formula} and \code{bias_formula} terms. The split interface
#' keeps the conceptual Level-2 true-flow predictors separate from the Level-1
#' MPD observation-bias predictors, while the current implementation still fits
#' one reduced-form model to observed MPD flows.
#'
#' The adjusted flow is computed from a formula-aware fixed-effect
#' counterfactual prediction with the numeric variables in \code{bias_formula}
#' set to zero, then summarizes draw-level adjusted flows by mean or median.
#'
#' In \code{target_scale = "true_flow"} mode, coverage is treated as an
#' observation-process offset. The fitted model is
#' \deqn{\log E(F^{mpd}_{ij}) = \log(q_{ij}) + \eta^{true}_{ij},}
#' where \eqn{q_{ij}} is derived from origin, destination, or geometric-mean
#' active-user coverage. The returned \code{flow_adj} is the estimated
#' true-flow scale \eqn{\exp(\eta^{true}_{ij})}.
#'
#' @param mpd_od_df Data frame with at least \code{origin}, \code{destination},
#'   and \code{flow_col}. Optional \code{mpd_source} is carried through.
#' @param coverage_df Data frame with at least \code{origin},
#'   \code{population}, \code{user_count}. Optional \code{destination} and
#'   \code{mpd_source} enable destination/source-specific joins.
#' @param covariates_df Optional area-level covariates with at least
#'   \code{area}. Each additional column is made available to \code{formula}
#'   twice using origin and destination suffixes, for example
#'   \code{rural_pct_o} and \code{rural_pct_d}. If \code{pop_col} exists, it is
#'   used for population covariates; otherwise populations are derived from
#'   \code{coverage_df}. Set to \code{NULL} when \code{formula} uses only OD,
#'   distance, coverage, source, or time fields.
#' @param distance_df Optional OD distance data frame with
#'   \code{origin}, \code{destination}, and \code{distance_col}.
#' @param flow_col Name of MPD flow column in \code{mpd_od_df}. Default \code{"flow"}.
#' @param income_col Deprecated. Optional name of the area-level covariate to
#'   use in the default formula when \code{formula = NULL}. Prefer specifying
#'   covariates directly in \code{formula}.
#' @param pop_col Optional population column in \code{covariates_df}. Default
#'   \code{"population"}. If missing, a population proxy is built from
#'   \code{coverage_df}.
#' @param distance_col Name of distance column in \code{distance_df} (or in
#'   \code{mpd_od_df} if \code{distance_df = NULL}). Default \code{"distance_km"}.
#' @param source_col Optional mobile-phone data source column in
#'   \code{mpd_od_df}. If \code{NULL} and \code{mpd_source} exists, that column
#'   is used. Source metadata supports S3 and S4 inputs.
#' @param time_col Optional observation-period column in \code{mpd_od_df}.
#'   Time metadata supports S2 and S4 inputs.
#' @param scenario Input scenario contract: \code{"auto"}, \code{"s1"},
#'   \code{"s2"}, \code{"s3"}, or \code{"s4"}. S1 is single source/single time,
#'   S2 is single source/multiple times, S3 is multiple sources/single time, and
#'   S4 is multiple sources/multiple times. \code{"auto"} infers the scenario
#'   from the supplied source and time columns.
#' @param repeated_observation Repeated-observation structure:
#'   \code{"auto"}, \code{"none"}, \code{"time"}, \code{"source"}, or
#'   \code{"source_time"}. \code{"auto"} maps from \code{scenario}.
#' @param random_intercept Random-intercept structure: \code{"origin"},
#'   \code{"destination"}, \code{"od"}, \code{"source"}, \code{"time"},
#'   \code{"source_time"}, or \code{"none"}. Used only when \code{formula} is
#'   not supplied; formula random-effect terms such as \code{(1 | origin)} or
#'   \code{(1 + log_distance | origin)} take precedence.
#' @param formula Optional model formula using the prepared model data. The
#'   response should usually be \code{flow}. The formula can include any
#'   prepared covariate columns, \code{log_distance}, \code{bias_e_origin},
#'   scenario columns such as \code{mpd_source} and \code{mpd_time}, and
#'   random-effect terms supported by the chosen engine.
#' @param custom_formula Deprecated alias for \code{formula}.
#' @param mobility_formula Optional one-sided formula for the conceptual
#'   true-flow component, for example
#'   \code{~ rural_pct_o + rural_pct_d + log_distance + (1 | origin)}.
#'   Supply together with \code{bias_formula}; do not combine with
#'   \code{formula} or \code{custom_formula}.
#' @param bias_formula Optional one-sided formula for the conceptual MPD
#'   observation-bias component, for example \code{~ bias_e_origin}. Supply
#'   together with \code{mobility_formula}. Fixed-effect variables in this
#'   formula must be numeric, integer, or logical because the adjusted
#'   counterfactual sets them to zero.
#' @param model_family Count family: \code{"poisson"}, \code{"negbin"},
#'   \code{"zip"}, or \code{"zinb"}.
#' @param model_engine Development engine: \code{"bayesian"} uses the existing
#'   Stage-1 Bayesian S1 backend; \code{"frequentist"} uses a faster
#'   Poisson/negative-binomial GLM/GLMM scaffold for S1-S4 model-contract
#'   development before Bayesian scenario support is promoted.
#' @param backend Bayesian backend: \code{"auto"}, \code{"rstanarm"}, or
#'   \code{"brms"}. \code{"auto"} chooses \pkg{rstanarm} for Poisson/NegBin and
#'   \pkg{brms} for zero-inflated families.
#' @param flow_adj_summary Summary for posterior draw-level adjusted flows:
#'   \code{"mean"} or \code{"median"}. This controls how the draw-level
#'   Stage-1 adjusted flows are collapsed into the returned \code{flow_adj}
#'   column after removing the estimated coverage-bias contribution.
#' @param target_scale Adjustment target. \code{"mpd_counterfactual"} preserves
#'   the reduced-form MPD-scale counterfactual. \code{"true_flow"} estimates a
#'   true-flow scale by using coverage as an observation-process offset.
#' @param observation_model Observation model. \code{"reduced_form"} preserves
#'   the existing fitted-bias-covariate path. \code{"coverage_offset"} uses
#'   active-user coverage as a fixed offset and is required for
#'   \code{target_scale = "true_flow"}.
#' @param coverage_scale Coverage rate used by \code{"coverage_offset"}:
#'   \code{"origin"} uses \eqn{p_i}, \code{"destination"} uses \eqn{p_j}, and
#'   \code{"both"} uses \eqn{\sqrt{p_i p_j}}.
#' @param prediction_scope Prediction contract. \code{"observed"} preserves the
#'   original observed-row workflow. \code{"complete_grid"} requires a strict
#'   square OD grid and predicts for all valid rows, while fitting on rows marked
#'   as originally observed when \code{mpd_observed} is present.
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
#'   \code{flow_adj}, source row-status fields, \code{bias_e_origin}, and
#'   log-distance helpers. In \code{prediction_scope = "observed"},
#'   \code{flow_adj} is returned for observed rows in \code{mpd_od_df}. In
#'   \code{prediction_scope = "complete_grid"}, \code{flow_adj} is returned for
#'   every valid row in the supplied square OD grid.
#'   Attributes:
#'   \itemize{
#'     \item \code{"model"}: fitted model object
#'     \item \code{"formula"}: fitted formula
#'     \item \code{"coefficients"}: fixed-effect summary table
#'     \item \code{"model_engine"}: \code{"bayesian"} or \code{"frequentist"}
#'     \item \code{"backend"}: backend used
#'     \item \code{"model_family"}: fitted family
#'     \item \code{"model_terms"}: resolved fixed-effect and random-effect terms
#'     \item \code{"stage"}: development stage label
#'     \item \code{"stage_scope"}: short statement of scope
#'     \item \code{"result_metadata"}: compact Stage-1 metadata bundle
#'     \item \code{"random_intercept"}: grouping structure used
#'     \item \code{"scenario"}: resolved S1-S4 input scenario
#'     \item \code{"repeated_observation"}: resolved repeated-observation structure
#'     \item \code{"flow_adj_summary"}: posterior summary used for \code{flow_adj}
#'     \item \code{"distance_source"}: where distance came from
#'     \item \code{"diagnostics"}: lightweight fit/convergence metadata when available
#'     \item \code{"prototype_notes"}: stage notes
#'   }
#'
#' @examples
#' if (requireNamespace("lme4", quietly = TRUE)) {
#'   areas <- c("A", "B", "C", "D")
#'   mpd <- expand.grid(
#'     origin = areas,
#'     destination = areas,
#'     KEEP.OUT.ATTRS = FALSE
#'   )
#'   mpd$flow <- c(12, 7, 4, 5, 6, 14, 8, 4, 5, 7, 11, 6, 4, 5, 7, 13)
#'
#'   coverage <- data.frame(
#'     origin = areas,
#'     population = c(100, 120, 90, 110),
#'     user_count = c(20, 30, 18, 22)
#'   )
#'
#'   covariates <- data.frame(
#'     area = areas,
#'     rural_pct = c(0.15, 0.35, 0.60, 0.80),
#'     population = c(100, 120, 90, 110)
#'   )
#'
#'   distance <- expand.grid(
#'     origin = areas,
#'     destination = areas,
#'     KEEP.OUT.ATTRS = FALSE
#'   )
#'   distance$distance_km <- abs(
#'     match(distance$origin, areas) - match(distance$destination, areas)
#'   ) + 1
#'
#'   adj <- suppressMessages(
#'     suppressWarnings(
#'       adjust_multilevel_bayes(
#'         mpd_od_df = mpd,
#'         coverage_df = coverage,
#'         covariates_df = covariates,
#'         distance_df = distance,
#'         mobility_formula = ~ rural_pct_o + rural_pct_d + log_distance +
#'           (1 | origin),
#'         bias_formula = ~ bias_e_origin,
#'         model_engine = "frequentist",
#'         model_family = "poisson"
#'       )
#'     )
#'   )
#'
#'   head(adj)
#' }
#' @export
adjust_multilevel_bayes <- function(mpd_od_df,
                                    coverage_df,
                                    covariates_df = NULL,
                                    distance_df = NULL,
                                    flow_col = "flow",
                                    income_col = NULL,
                                    pop_col = "population",
                                    distance_col = "distance_km",
                                    source_col = NULL,
                                    time_col = NULL,
                                    scenario = c("auto", "s1", "s2", "s3", "s4"),
                                    repeated_observation = c("auto", "none", "time", "source", "source_time"),
                                    random_intercept = c("origin", "destination", "od", "source", "time", "source_time", "none"),
                                    formula = NULL,
                                    custom_formula = NULL,
                                    mobility_formula = NULL,
                                    bias_formula = NULL,
                                    model_family = c("poisson", "negbin", "zip", "zinb"),
                                    model_engine = c("bayesian", "frequentist"),
                                    backend = c("auto", "rstanarm", "brms"),
                                    flow_adj_summary = c("mean", "median"),
                                    target_scale = c("mpd_counterfactual", "true_flow"),
                                    observation_model = c("reduced_form", "coverage_offset"),
                                    coverage_scale = c("origin", "destination", "both"),
                                    prediction_scope = c("observed", "complete_grid"),
                                    iter = 1000,
                                    chains = 2,
                                    seed = 123,
                                    refresh = 0,
                                    include_flow_adj_draws = FALSE,
                                    keep_cols = character()) {

  random_intercept_supplied <- !missing(random_intercept)
  random_intercept <- match.arg(random_intercept)
  scenario <- match.arg(scenario)
  model_family <- match.arg(model_family)
  model_engine <- match.arg(model_engine)
  repeated_observation <- match.arg(repeated_observation)
  flow_adj_summary <- match.arg(flow_adj_summary)
  target_scale <- match.arg(target_scale)
  observation_model <- match.arg(observation_model)
  coverage_scale <- match.arg(coverage_scale)
  prediction_scope <- match.arg(prediction_scope)
  .validate_multilevel_observation_contract(
    target_scale = target_scale,
    observation_model = observation_model
  )
  formula_info <- .resolve_multilevel_user_formula(
    formula = formula,
    custom_formula = custom_formula,
    mobility_formula = mobility_formula,
    bias_formula = bias_formula
  )
  if (!is.null(formula_info$formula) && !random_intercept_supplied) {
    random_intercept <- "none"
  }
  start_time <- Sys.time()

  if (model_engine == "frequentist") {
    return(.adjust_multilevel_frequentist_dev(
      mpd_od_df = mpd_od_df,
      coverage_df = coverage_df,
      covariates_df = covariates_df,
      distance_df = distance_df,
      flow_col = flow_col,
      income_col = income_col,
      pop_col = pop_col,
      distance_col = distance_col,
      source_col = source_col,
      time_col = time_col,
      scenario = scenario,
      repeated_observation = repeated_observation,
      random_intercept = random_intercept,
      formula_info = formula_info,
      model_family = model_family,
      flow_adj_summary = flow_adj_summary,
      target_scale = target_scale,
      observation_model = observation_model,
      coverage_scale = coverage_scale,
      prediction_scope = prediction_scope,
      include_flow_adj_draws = include_flow_adj_draws,
      keep_cols = keep_cols,
      start_time = start_time
    ))
  }

  backend <- .resolve_multilevel_backend(
    model_family = model_family,
    backend = backend
  )

  scenario_info <- .resolve_multilevel_scenario(
    mpd_od_df = mpd_od_df,
    coverage_df = coverage_df,
    source_col = source_col,
    time_col = time_col,
    scenario = scenario,
    repeated_observation = repeated_observation
  )
  .validate_multilevel_engine_scope(
    model_engine = model_engine,
    scenario_info = scenario_info
  )

  od_audit <- NULL
  if (prediction_scope == "complete_grid") {
    od_audit <- .audit_multilevel_complete_grid(
      mpd_od_df,
      flow_col = flow_col,
      scenario_cols = scenario_info$audit_cols
    )
    if (!isTRUE(od_audit$strict_square_support[[1]])) {
      stop(
        "`prediction_scope = 'complete_grid'` requires a strict square OD grid: ",
        "same origin and destination area set, expected OD row count, no duplicate pairs, ",
        "and finite non-negative flows."
      )
    }
  }

  prep <- .prepare_multilevel_bayes_data(
    mpd_od_df = mpd_od_df,
    coverage_df = coverage_df,
    covariates_df = covariates_df,
    distance_df = distance_df,
    flow_col = flow_col,
    income_col = income_col,
    pop_col = pop_col,
    distance_col = distance_col,
    source_col = source_col,
    time_col = time_col,
    scenario_info = scenario_info
  )

  prediction_df <- prep$model_df
  fit_candidate_df <- prediction_df
  if (prediction_scope == "complete_grid" && "mpd_observed" %in% names(fit_candidate_df)) {
    fit_candidate_df <- fit_candidate_df |>
      dplyr::filter(.data$mpd_observed)
  }

  scenario_terms <- .resolve_multilevel_formula_terms(
    data = fit_candidate_df,
    repeated_observation = scenario_info$repeated_observation,
    random_intercept = random_intercept
  )
  fit_formula_info <- .resolve_multilevel_target_formula_info(
    formula_info = formula_info,
    target_scale = target_scale
  )

  fit_formula <- .build_multilevel_formula(
    random_intercept = random_intercept,
    formula_info = fit_formula_info,
    default_covariate_col = prep$default_covariate_col,
    include_pop_terms = prep$has_pop_terms,
    scenario_terms = scenario_terms,
    target_scale = target_scale
  )
  if (observation_model == "coverage_offset") {
    .validate_multilevel_coverage_offset_data(
      data = prediction_df,
      coverage_scale = coverage_scale
    )
    prediction_df <- .set_multilevel_observation_probability(
      data = prediction_df,
      coverage_scale = coverage_scale
    )
    fit_formula <- .add_multilevel_offset(
      formula = fit_formula,
      offset_col = "log_observation_probability"
    )
  }
  prediction_df <- .filter_multilevel_model_data(
    data = prediction_df,
    formula = fit_formula,
    context = "prediction"
  )
  prediction_df <- .stabilize_multilevel_formula_factor_levels(
    data = prediction_df,
    formula = fit_formula
  )
  fit_df <- prediction_df
  if (prediction_scope == "complete_grid" && "mpd_observed" %in% names(fit_df)) {
    fit_df <- fit_df |>
      dplyr::filter(.data$mpd_observed)
  }

  if (nrow(fit_df) < 2L) {
    stop("Insufficient rows for fitting after preprocessing. Need at least 2 complete rows.")
  }

  if (is.null(formula_info$formula)) {
    .validate_multilevel_random_intercept(fit_df, random_intercept)
    if (random_intercept == "od" && max(tabulate(factor(fit_df$od_id))) <= 1L) {
      warning(
        "OD random intercepts may be weakly identified when each OD pair appears once. ",
        "Use with caution."
      )
    }
  }
  .validate_multilevel_formula_random_effects(fit_df, fit_formula)
  bias_terms <- .resolve_multilevel_bias_terms(fit_formula_info, fit_formula)
  if (target_scale == "mpd_counterfactual") {
    .validate_multilevel_bias_terms_for_counterfactual(prediction_df, bias_terms)
  }

  fit <- .fit_multilevel_bayes(
    backend = backend,
    model_family = model_family,
    formula = fit_formula,
    data = fit_df,
    iter = iter,
    chains = chains,
    seed = seed,
    refresh = refresh
  )

  if (target_scale == "true_flow") {
    mpd_pred_df <- prediction_df
    true_pred_df <- prediction_df
    true_pred_df$log_observation_probability <- 0

    lin_mpd <- .posterior_linpred_fixef(
      fit = fit,
      backend = backend,
      newdata = mpd_pred_df,
      offset_col = "log_observation_probability"
    )
    lin_true <- .posterior_linpred_fixef(
      fit = fit,
      backend = backend,
      newdata = true_pred_df,
      offset_col = "log_observation_probability"
    )
    flow_mpd_pred_draws <- exp(lin_mpd)
    flow_adj_draws <- exp(lin_true)
  } else {
    bias_zero_df <- .counterfactual_multilevel_bias_data(
      prediction_df,
      bias_terms = bias_terms
    )
    lin_true <- .posterior_linpred_fixef(
      fit = fit,
      backend = backend,
      newdata = bias_zero_df
    )

    # Predict the fixed-effect counterfactual where modeled coverage bias is zero.
    flow_mpd_pred_draws <- NULL
    flow_adj_draws <- exp(lin_true)
  }

  flow_adj <- if (flow_adj_summary == "median") {
    apply(flow_adj_draws, 2, stats::median)
  } else {
    colMeans(flow_adj_draws)
  }
  flow_mpd_pred <- if (!is.null(flow_mpd_pred_draws)) {
    if (flow_adj_summary == "median") {
      apply(flow_mpd_pred_draws, 2, stats::median)
    } else {
      colMeans(flow_mpd_pred_draws)
    }
  } else {
    rep(NA_real_, length(flow_adj))
  }

  modeled_out <- prediction_df |>
    dplyr::mutate(
      flow_adj = as.numeric(flow_adj),
      flow_true_pred = if (target_scale == "true_flow") as.numeric(flow_adj) else NA_real_,
      flow_mpd_pred = as.numeric(flow_mpd_pred)
    )

  base_out <- prep$base_df |>
    dplyr::mutate(
      prediction_scope = prediction_scope,
      model_fit_status = dplyr::if_else(
        .data$row_id %in% fit_df$row_id,
        "fit",
        dplyr::if_else(.data$row_id %in% prediction_df$row_id, "predicted", "excluded")
      )
    ) |>
    dplyr::left_join(
      dplyr::select(
        modeled_out,
        dplyr::any_of(c(
          "row_id", "flow_adj", "flow_mpd_pred", "flow_true_pred",
          "observation_probability", "log_observation_probability"
        ))
      ),
      by = "row_id"
    )

  keep_cols <- keep_cols[keep_cols %in% names(base_out)]
  select_cols <- c(
    "origin", "destination",
    if ("mpd_source" %in% names(base_out)) "mpd_source",
    if ("mpd_time" %in% names(base_out)) "mpd_time",
    keep_cols,
    "mpd_observed",
    "mpd_zero_filled",
    "mpd_row_status",
    "prediction_scope",
    "model_fit_status",
    "flow",
    "flow_adj",
    "flow_mpd_pred",
    "flow_true_pred",
    "observation_probability",
    "coverage_rate_o",
    "coverage_rate_d",
    "log_observation_probability",
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
  model_terms <- .summarize_multilevel_model_terms(
    formula = fit_formula,
    formula_info = fit_formula_info,
    default_covariate_col = prep$default_covariate_col,
    include_pop_terms = prep$has_pop_terms,
    scenario_terms = scenario_terms,
    random_intercept = random_intercept,
    bias_terms = bias_terms,
    target_scale = target_scale
  )

  runtime_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  stage_scope <- if (prediction_scope == "complete_grid") {
    "complete_grid_prediction"
  } else {
    "observed_od_only"
  }

  result_metadata <- list(
    backend = backend,
    model_engine = model_engine,
    model_family = model_family,
    stage = "stage_1",
    stage_scope = stage_scope,
    prediction_scope = prediction_scope,
    scenario = scenario_info$scenario,
    source_col = scenario_info$source_col,
    time_col = scenario_info$time_col,
    repeated_observation = scenario_info$repeated_observation,
    scenario_cols = scenario_info$scenario_cols,
    n_sources = scenario_info$n_sources,
    n_time_periods = scenario_info$n_time_periods,
    target_scale = target_scale,
    observation_model = observation_model,
    coverage_scale = if (observation_model == "coverage_offset") coverage_scale else NA_character_,
    offset_column = if (observation_model == "coverage_offset") {
      "log_observation_probability"
    } else {
      NA_character_
    },
    model_terms = model_terms,
    bias_terms = bias_terms,
    random_intercept = random_intercept,
    flow_adj_summary = flow_adj_summary,
    distance_source = prep$distance_source,
    runtime_seconds = runtime_seconds,
    n_input_rows = nrow(prep$base_df),
    n_fit_rows = nrow(fit_df),
    n_prediction_rows = nrow(prediction_df),
    n_zero_filled_prediction_rows = sum(prediction_df$mpd_zero_filled %in% TRUE),
    od_audit = od_audit
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
  attr(out, "model_engine") <- model_engine
  attr(out, "model_family") <- model_family
  attr(out, "target_scale") <- target_scale
  attr(out, "observation_model") <- observation_model
  attr(out, "coverage_scale") <- if (observation_model == "coverage_offset") coverage_scale else NA_character_
  attr(out, "model_terms") <- model_terms
  attr(out, "bias_terms") <- bias_terms
  attr(out, "stage") <- "stage_1"
  attr(out, "stage_scope") <- stage_scope
  attr(out, "result_metadata") <- result_metadata
  attr(out, "random_intercept") <- random_intercept
  attr(out, "scenario") <- scenario_info$scenario
  attr(out, "source_col") <- scenario_info$source_col
  attr(out, "time_col") <- scenario_info$time_col
  attr(out, "repeated_observation") <- scenario_info$repeated_observation
  attr(out, "scenario_info") <- scenario_info
  attr(out, "flow_adj_summary") <- flow_adj_summary
  attr(out, "prediction_scope") <- prediction_scope
  attr(out, "runtime_seconds") <- runtime_seconds
  attr(out, "od_audit") <- od_audit
  attr(out, "distance_source") <- prep$distance_source
  attr(out, "diagnostics") <- diagnostics
  if (target_scale == "true_flow") {
    attr(out, "prototype_notes") <- paste(
      "Coverage-offset true-flow mode: MPD flows are modelled as coverage-scaled observations of true OD flows.",
      "flow_adj equals flow_true_pred; flow_mpd_pred retains the fitted MPD observation scale.",
      "The observation offset is fixed from", coverage_scale, "coverage and is not estimated as a bias covariate."
    )
  } else if (prediction_scope == "complete_grid") {
    attr(out, "prototype_notes") <- paste(
      "Stage-1 complete-grid prediction: fit to originally observed MPD rows when mpd_observed is available.",
      "Rows marked mpd_zero_filled are zero-filled source-missing OD cells predicted on the supplied square grid.",
      "flow_adj removes the fixed-effect contribution from the resolved bias terms and is summarized by", flow_adj_summary
    )
  } else {
    attr(out, "prototype_notes") <- paste(
      "Stage-1 observed mode: bias-adjusted observed OD flows.",
      "No missing OD pairs are created unless prediction_scope = 'complete_grid' is used with a supplied square grid.",
      "flow_adj removes the fixed-effect contribution from the resolved bias terms and is summarized by", flow_adj_summary
    )
  }

  if (isTRUE(include_flow_adj_draws)) {
    attr(out, "flow_adj_draws") <- flow_adj_draws
  }

  out
}

.adjust_multilevel_frequentist_dev <- function(mpd_od_df,
                                               coverage_df,
                                               covariates_df = NULL,
                                               distance_df = NULL,
                                               flow_col = "flow",
                                               income_col = NULL,
                                               pop_col = "population",
                                               distance_col = "distance_km",
                                               source_col = NULL,
                                               time_col = NULL,
                                               scenario = c("auto", "s1", "s2", "s3", "s4"),
                                               repeated_observation = c("auto", "none", "time", "source", "source_time"),
                                               random_intercept = c("origin", "destination", "od", "source", "time", "source_time", "none"),
                                               formula_info = list(formula = NULL, source = "default"),
                                               model_family = c("poisson", "negbin", "zip", "zinb"),
                                               flow_adj_summary = c("mean", "median"),
                                               target_scale = c("mpd_counterfactual", "true_flow"),
                                               observation_model = c("reduced_form", "coverage_offset"),
                                               coverage_scale = c("origin", "destination", "both"),
                                               prediction_scope = c("observed", "complete_grid"),
                                               include_flow_adj_draws = FALSE,
                                               keep_cols = character(),
                                               start_time = Sys.time()) {
  random_intercept_supplied <- !missing(random_intercept)
  scenario <- match.arg(scenario)
  repeated_observation <- match.arg(repeated_observation)
  random_intercept <- match.arg(random_intercept)
  model_family <- match.arg(model_family)
  flow_adj_summary <- match.arg(flow_adj_summary)
  target_scale <- match.arg(target_scale)
  observation_model <- match.arg(observation_model)
  coverage_scale <- match.arg(coverage_scale)
  prediction_scope <- match.arg(prediction_scope)
  .validate_multilevel_observation_contract(
    target_scale = target_scale,
    observation_model = observation_model
  )

  if (model_family %in% c("zip", "zinb")) {
    stop("The internal frequentist development engine supports only Poisson and negative-binomial families.")
  }
  if (!is.null(formula_info$formula) && !random_intercept_supplied) {
    random_intercept <- "none"
  }

  scenario_info <- .resolve_multilevel_scenario(
    mpd_od_df = mpd_od_df,
    coverage_df = coverage_df,
    source_col = source_col,
    time_col = time_col,
    scenario = scenario,
    repeated_observation = repeated_observation
  )

  od_audit <- NULL
  if (prediction_scope == "complete_grid") {
    od_audit <- .audit_multilevel_complete_grid(
      mpd_od_df,
      flow_col = flow_col,
      scenario_cols = scenario_info$audit_cols
    )
    if (!isTRUE(od_audit$strict_square_support[[1]])) {
      stop(
        "`prediction_scope = 'complete_grid'` requires a strict square OD grid: ",
        "same origin and destination area set, expected OD row count, no duplicate OD/source/time keys, ",
        "and finite non-negative flows."
      )
    }
  }

  prep <- .prepare_multilevel_bayes_data(
    mpd_od_df = mpd_od_df,
    coverage_df = coverage_df,
    covariates_df = covariates_df,
    distance_df = distance_df,
    flow_col = flow_col,
    income_col = income_col,
    pop_col = pop_col,
    distance_col = distance_col,
    source_col = source_col,
    time_col = time_col,
    scenario_info = scenario_info
  )

  prediction_df <- prep$model_df
  fit_candidate_df <- prediction_df
  if (prediction_scope == "complete_grid" && "mpd_observed" %in% names(fit_candidate_df)) {
    fit_candidate_df <- fit_candidate_df |>
      dplyr::filter(.data$mpd_observed)
  }

  scenario_terms <- .resolve_multilevel_formula_terms(
    data = fit_candidate_df,
    repeated_observation = scenario_info$repeated_observation,
    random_intercept = random_intercept
  )
  fit_formula_info <- .resolve_multilevel_target_formula_info(
    formula_info = formula_info,
    target_scale = target_scale
  )

  fit_formula <- .build_multilevel_formula(
    random_intercept = random_intercept,
    formula_info = fit_formula_info,
    default_covariate_col = prep$default_covariate_col,
    include_pop_terms = prep$has_pop_terms,
    scenario_terms = scenario_terms,
    target_scale = target_scale
  )
  if (observation_model == "coverage_offset") {
    .validate_multilevel_coverage_offset_data(
      data = prediction_df,
      coverage_scale = coverage_scale
    )
    prediction_df <- .set_multilevel_observation_probability(
      data = prediction_df,
      coverage_scale = coverage_scale
    )
    fit_formula <- .add_multilevel_offset(
      formula = fit_formula,
      offset_col = "log_observation_probability"
    )
  }
  prediction_df <- .filter_multilevel_model_data(
    data = prediction_df,
    formula = fit_formula,
    context = "prediction"
  )
  prediction_df <- .stabilize_multilevel_formula_factor_levels(
    data = prediction_df,
    formula = fit_formula
  )
  fit_df <- prediction_df
  if (prediction_scope == "complete_grid" && "mpd_observed" %in% names(fit_df)) {
    fit_df <- fit_df |>
      dplyr::filter(.data$mpd_observed)
  }

  if (nrow(fit_df) < 2L) {
    stop("Insufficient rows for fitting after preprocessing. Need at least 2 complete rows.")
  }
  if (is.null(formula_info$formula)) {
    .validate_multilevel_random_intercept(fit_df, random_intercept)
  }
  .validate_multilevel_formula_random_effects(fit_df, fit_formula)
  bias_terms <- .resolve_multilevel_bias_terms(fit_formula_info, fit_formula)
  if (target_scale == "mpd_counterfactual") {
    .validate_multilevel_bias_terms_for_counterfactual(prediction_df, bias_terms)
  }

  fit <- .fit_multilevel_frequentist(
    model_family = model_family,
    formula = fit_formula,
    data = fit_df
  )

  if (target_scale == "true_flow") {
    mpd_pred_df <- prediction_df
    true_pred_df <- prediction_df
    true_pred_df$log_observation_probability <- 0
    lin_mpd <- .predict_linpred_fixef_frequentist(fit, mpd_pred_df)
    lin_true <- .predict_linpred_fixef_frequentist(fit, true_pred_df)
    flow_mpd_pred <- exp(as.numeric(lin_mpd))
    flow_adj <- exp(as.numeric(lin_true))
  } else {
    bias_zero_df <- .counterfactual_multilevel_bias_data(
      prediction_df,
      bias_terms = bias_terms
    )
    lin_true <- .predict_linpred_fixef_frequentist(fit, bias_zero_df)
    flow_adj <- exp(as.numeric(lin_true))
    flow_mpd_pred <- rep(NA_real_, length(flow_adj))
  }

  modeled_out <- prediction_df |>
    dplyr::mutate(
      flow_adj = as.numeric(flow_adj),
      flow_true_pred = if (target_scale == "true_flow") as.numeric(flow_adj) else NA_real_,
      flow_mpd_pred = as.numeric(flow_mpd_pred)
    )

  base_out <- prep$base_df |>
    dplyr::mutate(
      prediction_scope = prediction_scope,
      model_fit_status = dplyr::if_else(
        .data$row_id %in% fit_df$row_id,
        "fit",
        dplyr::if_else(.data$row_id %in% prediction_df$row_id, "predicted", "excluded")
      )
    ) |>
    dplyr::left_join(
      dplyr::select(
        modeled_out,
        dplyr::any_of(c(
          "row_id", "flow_adj", "flow_mpd_pred", "flow_true_pred",
          "observation_probability", "log_observation_probability"
        ))
      ),
      by = "row_id"
    )

  keep_cols <- keep_cols[keep_cols %in% names(base_out)]
  select_cols <- c(
    "origin", "destination",
    if ("mpd_source" %in% names(base_out)) "mpd_source",
    if ("mpd_time" %in% names(base_out)) "mpd_time",
    keep_cols,
    "mpd_observed",
    "mpd_zero_filled",
    "mpd_row_status",
    "prediction_scope",
    "model_fit_status",
    "flow",
    "flow_adj",
    "flow_mpd_pred",
    "flow_true_pred",
    "observation_probability",
    "coverage_rate_o",
    "coverage_rate_d",
    "log_observation_probability",
    "distance_km",
    "log_distance",
    "bias_e_origin",
    "log_dist_synth"
  )

  out <- dplyr::select(base_out, dplyr::any_of(select_cols)) |>
    tibble::as_tibble()

  coef_tbl <- .coef_summary_frequentist(fit)
  model_terms <- .summarize_multilevel_model_terms(
    formula = fit_formula,
    formula_info = fit_formula_info,
    default_covariate_col = prep$default_covariate_col,
    include_pop_terms = prep$has_pop_terms,
    scenario_terms = scenario_terms,
    random_intercept = random_intercept,
    bias_terms = bias_terms,
    target_scale = target_scale
  )
  runtime_seconds <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  stage_scope <- if (prediction_scope == "complete_grid") {
    "complete_grid_prediction"
  } else {
    "observed_od_only"
  }
  result_metadata <- list(
    backend = "frequentist_dev",
    model_engine = "frequentist",
    model_family = model_family,
    stage = "frequentist_dev",
    stage_scope = stage_scope,
    prediction_scope = prediction_scope,
    scenario = scenario_info$scenario,
    source_col = scenario_info$source_col,
    time_col = scenario_info$time_col,
    repeated_observation = scenario_info$repeated_observation,
    scenario_cols = scenario_info$scenario_cols,
    n_sources = scenario_info$n_sources,
    n_time_periods = scenario_info$n_time_periods,
    target_scale = target_scale,
    observation_model = observation_model,
    coverage_scale = if (observation_model == "coverage_offset") coverage_scale else NA_character_,
    offset_column = if (observation_model == "coverage_offset") {
      "log_observation_probability"
    } else {
      NA_character_
    },
    model_terms = model_terms,
    bias_terms = bias_terms,
    random_intercept = random_intercept,
    flow_adj_summary = flow_adj_summary,
    distance_source = prep$distance_source,
    runtime_seconds = runtime_seconds,
    n_input_rows = nrow(prep$base_df),
    n_fit_rows = nrow(fit_df),
    n_prediction_rows = nrow(prediction_df),
    n_zero_filled_prediction_rows = sum(prediction_df$mpd_zero_filled %in% TRUE),
    od_audit = od_audit
  )

  attr(out, "model") <- fit
  attr(out, "formula") <- deparse(fit_formula)
  attr(out, "coefficients") <- coef_tbl
  attr(out, "backend") <- "frequentist_dev"
  attr(out, "model_engine") <- "frequentist"
  attr(out, "model_family") <- model_family
  attr(out, "target_scale") <- target_scale
  attr(out, "observation_model") <- observation_model
  attr(out, "coverage_scale") <- if (observation_model == "coverage_offset") coverage_scale else NA_character_
  attr(out, "model_terms") <- model_terms
  attr(out, "bias_terms") <- bias_terms
  attr(out, "stage") <- "frequentist_dev"
  attr(out, "stage_scope") <- stage_scope
  attr(out, "result_metadata") <- result_metadata
  attr(out, "random_intercept") <- random_intercept
  attr(out, "scenario") <- scenario_info$scenario
  attr(out, "source_col") <- scenario_info$source_col
  attr(out, "time_col") <- scenario_info$time_col
  attr(out, "repeated_observation") <- scenario_info$repeated_observation
  attr(out, "scenario_info") <- scenario_info
  attr(out, "flow_adj_summary") <- flow_adj_summary
  attr(out, "prediction_scope") <- prediction_scope
  attr(out, "runtime_seconds") <- runtime_seconds
  attr(out, "od_audit") <- od_audit
  attr(out, "distance_source") <- prep$distance_source
  attr(out, "diagnostics") <- .collect_frequentist_diagnostics(fit, coef_tbl)
  attr(out, "prototype_notes") <- if (target_scale == "true_flow") {
    paste(
      "Internal frequentist development scaffold for coverage-offset true-flow mode.",
      "flow_adj equals flow_true_pred; the intended user-facing inferential method remains Bayesian."
    )
  } else {
    paste(
      "Internal frequentist development scaffold for multilevel scenario testing.",
      "The intended user-facing inferential method remains Bayesian."
    )
  }
  if (isTRUE(include_flow_adj_draws)) {
    attr(out, "flow_adj_draws") <- matrix(flow_adj, nrow = 1L)
  }

  out
}

.fit_multilevel_frequentist <- function(model_family,
                                        formula,
                                        data) {
  has_random_effects <- .formula_has_random_effects(formula)

  if (model_family == "poisson" && !has_random_effects) {
    return(stats::glm(
      formula = formula,
      data = data,
      family = stats::poisson(link = "log")
    ))
  }

  if (model_family == "negbin" && !has_random_effects) {
    if (!requireNamespace("MASS", quietly = TRUE)) {
      stop("The internal negative-binomial frequentist engine requires the optional 'MASS' package.")
    }
    return(MASS::glm.nb(
      formula = formula,
      data = data
    ))
  }

  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Frequentist random-intercept development fits require the optional 'lme4' package.")
  }

  if (model_family == "poisson") {
    return(lme4::glmer(
      formula = formula,
      data = data,
      family = stats::poisson(link = "log")
    ))
  }

  if (model_family == "negbin") {
    return(lme4::glmer.nb(
      formula = formula,
      data = data
    ))
  }

  stop("Unsupported frequentist model family: ", model_family)
}

.predict_linpred_fixef_frequentist <- function(fit, newdata) {
  if (inherits(fit, "merMod")) {
    return(as.numeric(stats::predict(
      fit,
      newdata = newdata,
      type = "link",
      re.form = NA,
      allow.new.levels = TRUE
    )))
  }

  as.numeric(stats::predict(fit, newdata = newdata, type = "link"))
}

.extract_omega_frequentist <- function(fit) {
  coefs <- if (inherits(fit, "merMod")) {
    lme4::fixef(fit)
  } else {
    stats::coef(fit)
  }

  if ("bias_e_origin" %in% names(coefs)) {
    return(as.numeric(coefs[["bias_e_origin"]]))
  }

  warning("Could not find coefficient for bias_e_origin; using zero.")
  0
}

.coef_summary_frequentist <- function(fit) {
  fit_summary <- summary(fit)
  coef_obj <- fit_summary$coefficients
  out <- as.data.frame(coef_obj)
  out$term <- rownames(out)
  rownames(out) <- NULL
  if ("Estimate" %in% names(out)) names(out)[names(out) == "Estimate"] <- "mean"
  if ("Std. Error" %in% names(out)) names(out)[names(out) == "Std. Error"] <- "sd"
  out
}

.collect_frequentist_diagnostics <- function(fit, coefficients) {
  list(
    backend = "frequentist_dev",
    has_bias_term = "bias_e_origin" %in% coefficients$term,
    convergence = list(status = "not_applicable"),
    aic = suppressWarnings(stats::AIC(fit))
  )
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

.validate_multilevel_engine_scope <- function(model_engine, scenario_info) {
  if (model_engine == "bayesian" && !identical(scenario_info$scenario, "s1")) {
    stop(
      "`model_engine = 'bayesian'` currently supports the existing Stage-1 S1 path only. ",
      "Resolved `scenario = '", scenario_info$scenario, "'`; use ",
      "`model_engine = 'frequentist'` for S1-S4 scenario development until the Bayesian transfer is implemented."
    )
  }

  invisible(TRUE)
}

.validate_multilevel_observation_contract <- function(target_scale,
                                                      observation_model) {
  if (target_scale == "true_flow" && observation_model != "coverage_offset") {
    stop(
      "`target_scale = 'true_flow'` requires ",
      "`observation_model = 'coverage_offset'`."
    )
  }
  if (observation_model == "coverage_offset" && target_scale != "true_flow") {
    stop(
      "`observation_model = 'coverage_offset'` is currently supported only with ",
      "`target_scale = 'true_flow'`."
    )
  }

  invisible(TRUE)
}

.resolve_multilevel_target_formula_info <- function(formula_info,
                                                    target_scale) {
  if (target_scale != "true_flow" || !identical(formula_info$interface, "split")) {
    return(formula_info)
  }

  mobility_rhs <- paste(deparse(formula_info$mobility_formula[[2]]), collapse = " ")
  out <- formula_info
  out$formula <- stats::as.formula(paste("flow ~", mobility_rhs))
  out$interface <- "split_true_flow"
  out$bias_variables <- character()
  out
}

.add_multilevel_offset <- function(formula, offset_col) {
  rhs <- paste(deparse(formula[[length(formula)]]), collapse = " ")
  stats::as.formula(paste("flow ~", rhs, "+ offset(", offset_col, ")"))
}

.set_multilevel_observation_probability <- function(data, coverage_scale) {
  if (coverage_scale == "origin") {
    data$observation_probability <- data$coverage_rate_o
  } else if (coverage_scale == "destination") {
    data$observation_probability <- data$coverage_rate_d
  } else {
    data$observation_probability <- sqrt(data$coverage_rate_o * data$coverage_rate_d)
  }
  data$log_observation_probability <- log(data$observation_probability)
  data
}

.validate_multilevel_coverage_offset_data <- function(data, coverage_scale) {
  needed <- switch(
    coverage_scale,
    origin = "coverage_rate_o",
    destination = "coverage_rate_d",
    both = c("coverage_rate_o", "coverage_rate_d")
  )
  missing <- setdiff(needed, names(data))
  if (length(missing) > 0L) {
    stop(
      "`observation_model = 'coverage_offset'` requires prepared coverage column(s): ",
      paste(missing, collapse = ", ")
    )
  }

  invalid <- needed[!vapply(
    needed,
    function(col) all(is.finite(data[[col]]) & data[[col]] > 0),
    logical(1)
  )]
  if (length(invalid) > 0L) {
    stop(
      "`observation_model = 'coverage_offset'` requires positive finite coverage rates. ",
      "Invalid column(s): ",
      paste(invalid, collapse = ", "),
      ". Check that `coverage_df` has positive population and user_count values ",
      "for every required origin/destination/source/time combination."
    )
  }

  invisible(TRUE)
}

.resolve_multilevel_scenario <- function(mpd_od_df,
                                         coverage_df = NULL,
                                         source_col = NULL,
                                         time_col = NULL,
                                         scenario = c("auto", "s1", "s2", "s3", "s4"),
                                         repeated_observation = c("auto", "none", "time", "source", "source_time")) {
  scenario <- match.arg(scenario)
  repeated_observation <- match.arg(repeated_observation)

  source_col <- .resolve_multilevel_optional_col(
    df = mpd_od_df,
    requested_col = source_col,
    default_col = "mpd_source",
    arg_name = "source_col"
  )
  time_col <- .resolve_multilevel_optional_col(
    df = mpd_od_df,
    requested_col = time_col,
    default_col = "mpd_time",
    arg_name = "time_col"
  )

  source_values <- .multilevel_distinct_values(mpd_od_df, source_col)
  time_values <- .multilevel_distinct_values(mpd_od_df, time_col)
  has_source_variation <- length(source_values) > 1L
  has_time_variation <- length(time_values) > 1L

  inferred <- if (has_source_variation && has_time_variation) {
    "s4"
  } else if (has_time_variation) {
    "s2"
  } else if (has_source_variation) {
    "s3"
  } else {
    "s1"
  }
  scenario_resolved <- if (scenario == "auto") inferred else scenario

  .validate_multilevel_scenario(
    scenario = scenario_resolved,
    source_col = source_col,
    time_col = time_col,
    has_source_variation = has_source_variation,
    has_time_variation = has_time_variation
  )

  repeated_resolved <- if (repeated_observation == "auto") {
    switch(
      scenario_resolved,
      s1 = "none",
      s2 = "time",
      s3 = "source",
      s4 = "source_time"
    )
  } else {
    repeated_observation
  }

  .validate_multilevel_repeated_observation(
    repeated_observation = repeated_resolved,
    source_col = source_col,
    time_col = time_col,
    has_source_variation = has_source_variation,
    has_time_variation = has_time_variation
  )

  scenario_cols <- c(
    if (!is.null(source_col)) "mpd_source",
    if (!is.null(time_col)) "mpd_time"
  )
  audit_cols <- c(
    if (!is.null(source_col)) source_col,
    if (!is.null(time_col)) time_col
  )

  list(
    scenario = scenario_resolved,
    source_col = source_col,
    time_col = time_col,
    repeated_observation = repeated_resolved,
    n_sources = length(source_values),
    n_time_periods = length(time_values),
    scenario_cols = scenario_cols,
    audit_cols = audit_cols,
    source_levels = source_values,
    time_levels = time_values
  )
}

.resolve_multilevel_optional_col <- function(df, requested_col, default_col, arg_name) {
  if (!is.null(requested_col)) {
    if (!requested_col %in% names(df)) {
      stop("`", arg_name, "` must name a column in `mpd_od_df`.")
    }
    return(requested_col)
  }

  if (default_col %in% names(df)) {
    return(default_col)
  }

  NULL
}

.multilevel_distinct_values <- function(df, col) {
  if (is.null(col) || !col %in% names(df)) {
    return(character())
  }

  out <- unique(as.character(df[[col]]))
  sort(out[!is.na(out) & nzchar(out)])
}

.validate_multilevel_scenario <- function(scenario,
                                          source_col,
                                          time_col,
                                          has_source_variation,
                                          has_time_variation) {
  if (scenario == "s1" && (has_source_variation || has_time_variation)) {
    stop("`scenario = 's1'` requires at most one source and one time period.")
  }
  if (scenario == "s2" && (!has_time_variation || has_source_variation)) {
    stop("`scenario = 's2'` requires one source and at least two time periods.")
  }
  if (scenario == "s3" && (!has_source_variation || has_time_variation)) {
    stop("`scenario = 's3'` requires at least two sources and one time period.")
  }
  if (scenario == "s4" && (!has_source_variation || !has_time_variation)) {
    stop("`scenario = 's4'` requires at least two sources and at least two time periods.")
  }
  if (scenario %in% c("s2", "s4") && is.null(time_col)) {
    stop("`time_col` is required for scenario ", scenario, ".")
  }
  if (scenario %in% c("s3", "s4") && is.null(source_col)) {
    stop("`source_col` is required for scenario ", scenario, ".")
  }

  invisible(TRUE)
}

.validate_multilevel_repeated_observation <- function(repeated_observation,
                                                      source_col,
                                                      time_col,
                                                      has_source_variation,
                                                      has_time_variation) {
  if (repeated_observation %in% c("source", "source_time") &&
      (is.null(source_col) || !has_source_variation)) {
    stop("`repeated_observation = '", repeated_observation, "'` requires at least two sources.")
  }
  if (repeated_observation %in% c("time", "source_time") &&
      (is.null(time_col) || !has_time_variation)) {
    stop("`repeated_observation = '", repeated_observation, "'` requires at least two time periods.")
  }

  invisible(TRUE)
}

.resolve_multilevel_formula_terms <- function(data,
                                              repeated_observation,
                                              random_intercept = "none") {
  terms <- character()
  if (repeated_observation %in% c("source", "source_time") &&
      random_intercept != "source" &&
      "mpd_source" %in% names(data) &&
      length(.multilevel_distinct_values(data, "mpd_source")) > 1L) {
    terms <- c(terms, "mpd_source")
  }
  if (repeated_observation %in% c("time", "source_time") &&
      random_intercept != "time" &&
      "mpd_time" %in% names(data) &&
      length(.multilevel_distinct_values(data, "mpd_time")) > 1L) {
    terms <- c(terms, "mpd_time")
  }

  unique(terms)
}

.validate_multilevel_random_intercept <- function(fit_df, random_intercept) {
  if (random_intercept == "origin" && length(unique(fit_df$origin)) < 2L) {
    stop("`random_intercept = 'origin'` requires at least 2 distinct origins.")
  }
  if (random_intercept == "destination" && length(unique(fit_df$destination)) < 2L) {
    stop("`random_intercept = 'destination'` requires at least 2 distinct destinations.")
  }
  if (random_intercept == "source" &&
      (!"mpd_source" %in% names(fit_df) || length(.multilevel_distinct_values(fit_df, "mpd_source")) < 2L)) {
    stop("`random_intercept = 'source'` requires at least 2 distinct sources.")
  }
  if (random_intercept == "time" &&
      (!"mpd_time" %in% names(fit_df) || length(.multilevel_distinct_values(fit_df, "mpd_time")) < 2L)) {
    stop("`random_intercept = 'time'` requires at least 2 distinct time periods.")
  }
  if (random_intercept == "source_time" &&
      (!"mpd_source_time" %in% names(fit_df) ||
        length(.multilevel_distinct_values(fit_df, "mpd_source_time")) < 2L)) {
    stop("`random_intercept = 'source_time'` requires at least 2 source-time combinations.")
  }

  invisible(TRUE)
}

.resolve_multilevel_user_formula <- function(formula = NULL,
                                             custom_formula = NULL,
                                             mobility_formula = NULL,
                                             bias_formula = NULL) {
  split_supplied <- !is.null(mobility_formula) || !is.null(bias_formula)
  combined_supplied <- !is.null(formula) || !is.null(custom_formula)

  if (split_supplied && combined_supplied) {
    stop(
      "Use either `formula`/`custom_formula` or the split ",
      "`mobility_formula` + `bias_formula` interface, not both."
    )
  }
  if (split_supplied && (is.null(mobility_formula) || is.null(bias_formula))) {
    stop("Supply both `mobility_formula` and `bias_formula` when using the split formula interface.")
  }
  if (!is.null(formula) && !is.null(custom_formula)) {
    stop("Use only one of `formula` or deprecated `custom_formula`.")
  }

  if (split_supplied) {
    mobility_formula <- .validate_multilevel_one_sided_formula(
      mobility_formula,
      arg_name = "mobility_formula"
    )
    bias_formula <- .validate_multilevel_one_sided_formula(
      bias_formula,
      arg_name = "bias_formula"
    )

    combined_formula <- .combine_multilevel_split_formula(
      mobility_formula = mobility_formula,
      bias_formula = bias_formula
    )

    return(list(
      formula = combined_formula,
      source = "split_formula",
      interface = "split",
      mobility_formula = mobility_formula,
      bias_formula = bias_formula,
      mobility_variables = .formula_fixed_effect_vars(mobility_formula),
      bias_variables = .formula_fixed_effect_vars(bias_formula)
    ))
  }

  if (!is.null(custom_formula)) {
    warning("`custom_formula` is deprecated; use `formula` instead.", call. = FALSE)
    formula <- custom_formula
    source <- "custom_formula"
  } else if (!is.null(formula)) {
    source <- "formula"
  } else {
    source <- "default"
  }

  if (is.null(formula)) {
    return(list(
      formula = NULL,
      source = source,
      interface = "default",
      mobility_formula = NULL,
      bias_formula = NULL,
      mobility_variables = character(),
      bias_variables = character()
    ))
  }

  formula <- stats::as.formula(formula)
  response <- .formula_response_var(formula)
  if (is.null(response)) {
    stop("`formula` must include a response, usually `flow`.")
  }
  if (!identical(response, "flow")) {
    stop("`formula` response must be `flow`; `flow_col` is standardised to `flow` before fitting.")
  }

  list(
    formula = formula,
    source = source,
    interface = "combined",
    mobility_formula = NULL,
    bias_formula = NULL,
    mobility_variables = character(),
    bias_variables = if ("bias_e_origin" %in% all.vars(formula)) "bias_e_origin" else character()
  )
}

.formula_response_var <- function(formula) {
  vars <- all.vars(formula)
  if (length(vars) == 0L || length(formula) < 3L) {
    return(NULL)
  }

  vars[1]
}

.validate_multilevel_one_sided_formula <- function(formula, arg_name) {
  formula <- stats::as.formula(formula)
  if (length(formula) != 2L) {
    stop("`", arg_name, "` must be a one-sided formula such as `~ bias_e_origin`.")
  }

  formula
}

.combine_multilevel_split_formula <- function(mobility_formula, bias_formula) {
  mobility_rhs <- paste(deparse(mobility_formula[[2]]), collapse = " ")
  bias_rhs <- paste(deparse(bias_formula[[2]]), collapse = " ")
  stats::as.formula(paste("flow ~", mobility_rhs, "+", bias_rhs))
}

.formula_random_effect_calls <- function(formula) {
  out <- list()

  walk <- function(x) {
    if (!is.call(x)) {
      return(invisible(NULL))
    }
    if (identical(x[[1]], as.name("|")) || identical(x[[1]], as.name("||"))) {
      out[[length(out) + 1L]] <<- x
      return(invisible(NULL))
    }
    for (i in seq_along(x)[-1L]) {
      walk(x[[i]])
    }
    invisible(NULL)
  }

  walk(formula[[length(formula)]])
  out
}

.formula_random_effect_terms <- function(formula) {
  calls <- .formula_random_effect_calls(formula)
  vapply(
    calls,
    function(x) paste0("(", paste(deparse(x), collapse = " "), ")"),
    character(1)
  )
}

.formula_has_random_effects <- function(formula) {
  length(.formula_random_effect_calls(formula)) > 0L
}

.strip_formula_random_effect_calls <- function(expr) {
  if (!is.call(expr)) {
    return(expr)
  }
  if (identical(expr[[1]], as.name("|")) || identical(expr[[1]], as.name("||"))) {
    return(0)
  }
  if (identical(expr[[1]], as.name("+"))) {
    lhs <- .strip_formula_random_effect_calls(expr[[2]])
    rhs <- .strip_formula_random_effect_calls(expr[[3]])
    if (identical(lhs, 0)) return(rhs)
    if (identical(rhs, 0)) return(lhs)
    return(call("+", lhs, rhs))
  }

  as.call(c(expr[[1]], lapply(as.list(expr[-1]), .strip_formula_random_effect_calls)))
}

.formula_fixed_effect_vars <- function(formula) {
  rhs <- formula[[length(formula)]]
  rhs <- .strip_formula_random_effect_calls(rhs)
  unique(all.vars(rhs))
}

.validate_multilevel_formula_random_effects <- function(fit_df, formula) {
  calls <- .formula_random_effect_calls(formula)
  if (length(calls) == 0L) {
    return(invisible(TRUE))
  }

  for (call in calls) {
    term <- paste0("(", paste(deparse(call), collapse = " "), ")")
    slope_vars <- all.vars(call[[2]])
    group_vars <- all.vars(call[[3]])
    needed_vars <- unique(c(slope_vars, group_vars))
    missing_vars <- setdiff(needed_vars, names(fit_df))
    if (length(missing_vars) > 0L) {
      stop(
        "`formula` random-effect term ", term,
        " references variable(s) not found in prepared model data: ",
        paste(missing_vars, collapse = ", ")
      )
    }

    if (length(group_vars) == 0L) {
      stop("`formula` random-effect term ", term, " must include a grouping variable after `|`.")
    }

    group_df <- fit_df[group_vars]
    group_df <- group_df[stats::complete.cases(group_df), , drop = FALSE]
    n_groups <- nrow(unique(group_df))
    if (n_groups < 2L) {
      stop("`formula` random-effect term ", term, " requires at least 2 grouping levels.")
    }

    if (identical(group_vars, "od_id")) {
      group_count <- tabulate(factor(fit_df$od_id))
      if (length(group_count) > 0L && max(group_count) <= 1L) {
        warning(
          "OD random effects may be weakly identified when each OD pair appears once. ",
          "Use with caution.",
          call. = FALSE
        )
      }
    }
  }

  invisible(TRUE)
}

.filter_multilevel_model_data <- function(data, formula, context = "model") {
  vars <- unique(all.vars(formula))
  missing_vars <- setdiff(vars, names(data))
  if (length(missing_vars) > 0L) {
    stop(
      "`formula` references variable(s) not found in prepared model data: ",
      paste(missing_vars, collapse = ", ")
    )
  }

  keep <- rep(TRUE, nrow(data))
  response <- .formula_response_var(formula)
  for (var in vars) {
    value <- data[[var]]
    if (is.numeric(value) || is.integer(value)) {
      var_keep <- is.finite(value)
    } else {
      var_keep <- !is.na(value)
      if (is.character(value)) {
        var_keep <- var_keep & nzchar(value)
      }
    }
    keep <- keep & var_keep
  }

  if (!is.null(response) && response %in% names(data)) {
    response_value <- suppressWarnings(as.numeric(data[[response]]))
    keep <- keep & is.finite(response_value) & response_value >= 0
  }

  dropped_n <- sum(!keep)
  if (dropped_n > 0L) {
    warning(
      dropped_n,
      " row(s) were excluded from ",
      context,
      " data because `formula` variables were missing, non-finite, or invalid.",
      call. = FALSE
    )
  }

  data[keep, , drop = FALSE]
}

.stabilize_multilevel_formula_factor_levels <- function(data, formula) {
  vars <- setdiff(unique(all.vars(formula)), .formula_response_var(formula))
  for (var in vars) {
    if (var %in% names(data) && is.character(data[[var]])) {
      levels <- sort(unique(data[[var]][!is.na(data[[var]]) & nzchar(data[[var]])]))
      data[[var]] <- factor(data[[var]], levels = levels)
    }
  }

  data
}

.resolve_multilevel_bias_terms <- function(formula_info, formula) {
  bias_variables <- formula_info$bias_variables
  if (is.null(bias_variables)) {
    bias_variables <- character()
  }

  if (identical(formula_info$interface, "split")) {
    return(bias_variables)
  }

  if (!is.null(formula_info$formula)) {
    return(bias_variables)
  }

  if ("bias_e_origin" %in% all.vars(formula)) {
    return("bias_e_origin")
  }

  character()
}

.validate_multilevel_bias_terms_for_counterfactual <- function(data, bias_terms) {
  bias_terms <- unique(bias_terms)
  if (length(bias_terms) == 0L) {
    return(invisible(TRUE))
  }

  missing_terms <- setdiff(bias_terms, names(data))
  if (length(missing_terms) > 0L) {
    stop(
      "`bias_formula` references variable(s) not found in prepared model data: ",
      paste(missing_terms, collapse = ", ")
    )
  }

  invalid_terms <- bias_terms[!vapply(
    bias_terms,
    function(term) {
      is.numeric(data[[term]]) || is.integer(data[[term]]) || is.logical(data[[term]])
    },
    logical(1)
  )]
  if (length(invalid_terms) > 0L) {
    stop(
      "`bias_formula` fixed-effect variable(s) must be numeric, integer, or logical ",
      "so the zero-bias counterfactual can set them to zero: ",
      paste(invalid_terms, collapse = ", ")
    )
  }

  invisible(TRUE)
}

.counterfactual_multilevel_bias_data <- function(data, bias_terms = "bias_e_origin") {
  bias_terms <- unique(bias_terms)
  for (term in bias_terms) {
    if (!term %in% names(data)) {
      next
    }
    if (is.logical(data[[term]])) {
      data[[term]] <- FALSE
    } else {
      data[[term]] <- 0
    }
  }

  data
}

.summarize_multilevel_model_terms <- function(formula,
                                              formula_info,
                                              default_covariate_col,
                                              include_pop_terms,
                                              scenario_terms,
                                              random_intercept,
                                              bias_terms = character(),
                                              target_scale = "mpd_counterfactual") {
  user_formula_supplied <- !is.null(formula_info$formula)
  formula_interface <- formula_info$interface
  if (is.null(formula_interface)) {
    formula_interface <- formula_info$source
  }
  mobility_variables <- formula_info$mobility_variables
  if (is.null(mobility_variables)) {
    mobility_variables <- character()
  }
  default_fixed_effects <- if (user_formula_supplied) {
    character()
  } else {
    out <- c(
      if (!is.null(default_covariate_col)) c("income_o", "income_d"),
      "log_distance",
      if (target_scale == "mpd_counterfactual") "bias_e_origin"
    )
    if (isTRUE(include_pop_terms)) {
      out <- c(out, "log_pop_o", "log_pop_d")
    }
    out
  }

  default_random_effect_term <- switch(
    random_intercept,
    origin = "(1 | origin)",
    destination = "(1 | destination)",
    od = "(1 | od_id)",
    source = "(1 | mpd_source)",
    time = "(1 | mpd_time)",
    source_time = "(1 | mpd_source_time)",
    none = NA_character_
  )
  formula_random_effect_terms <- .formula_random_effect_terms(formula)
  random_effect_term <- if (length(formula_random_effect_terms) > 0L) {
    formula_random_effect_terms
  } else {
    default_random_effect_term
  }

  list(
    formula = paste(deparse(formula), collapse = " "),
    formula_source = formula_info$source,
    formula_interface = formula_interface,
    mobility_formula = if (!is.null(formula_info$mobility_formula)) {
      paste(deparse(formula_info$mobility_formula), collapse = " ")
    } else {
      NA_character_
    },
    bias_formula = if (!is.null(formula_info$bias_formula)) {
      paste(deparse(formula_info$bias_formula), collapse = " ")
    } else {
      NA_character_
    },
    mobility_variables = mobility_variables,
    bias_variables = bias_terms,
    user_formula = user_formula_supplied,
    custom_formula = identical(formula_info$source, "custom_formula"),
    default_area_covariate = default_covariate_col,
    default_fixed_effects = default_fixed_effects,
    scenario_fixed_effects = if (user_formula_supplied) character() else scenario_terms,
    formula_variables = unique(all.vars(formula)),
    requested_random_intercept = random_intercept,
    random_effect_term = random_effect_term,
    formula_random_effects = formula_random_effect_terms
  )
}

.audit_multilevel_complete_grid <- function(mpd_od_df,
                                            flow_col,
                                            scenario_cols = character()) {
  scenario_cols <- scenario_cols[scenario_cols %in% names(mpd_od_df)]
  req <- c("origin", "destination", flow_col, scenario_cols)
  if (!all(req %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req, collapse = ", "))
  }

  origins <- sort(unique(as.character(mpd_od_df$origin)))
  destinations <- sort(unique(as.character(mpd_od_df$destination)))
  area_set <- sort(unique(c(origins, destinations)))
  has_self_flows <- any(as.character(mpd_od_df$origin) == as.character(mpd_od_df$destination))
  expected_od_rows <- length(area_set)^2
  if (!has_self_flows) {
    expected_od_rows <- length(area_set) * max(length(area_set) - 1L, 0L)
  }
  n_scenarios <- if (length(scenario_cols) == 0L) {
    1L
  } else {
    nrow(dplyr::distinct(mpd_od_df, dplyr::across(dplyr::all_of(scenario_cols))))
  }
  expected_od_rows_total <- expected_od_rows * n_scenarios

  duplicate_pairs <- sum(duplicated(mpd_od_df[c("origin", "destination", scenario_cols)]))
  flow <- suppressWarnings(as.numeric(mpd_od_df[[flow_col]]))
  total_flow <- sum(flow, na.rm = TRUE)

  strict_square_support <- identical(origins, destinations) &&
    nrow(mpd_od_df) == expected_od_rows_total &&
    duplicate_pairs == 0L &&
    all(is.finite(flow) & flow >= 0)

  tibble::tibble(
    strict_square_support = strict_square_support,
    same_origin_destination_area_set = identical(origins, destinations),
    include_self_flows = has_self_flows,
    n_areas = length(area_set),
    n_scenarios = n_scenarios,
    scenario_cols = paste(scenario_cols, collapse = ","),
    expected_od_rows = expected_od_rows_total,
    n_od_rows = nrow(mpd_od_df),
    n_duplicate_pairs = duplicate_pairs,
    n_zero_filled = if ("mpd_zero_filled" %in% names(mpd_od_df)) {
      sum(mpd_od_df$mpd_zero_filled %in% TRUE, na.rm = TRUE)
    } else {
      0L
    },
    total_flow = total_flow,
    total_outflow = total_flow,
    total_inflow = total_flow,
    balance_diff = 0
  )
}

.resolve_multilevel_backend <- function(model_family, backend) {
  backend <- match.arg(backend, choices = c("auto", "rstanarm", "brms"))

  if (backend == "auto") {
    return(if (model_family %in% c("poisson", "negbin")) "rstanarm" else "brms")
  }

  backend
}

.build_multilevel_formula <- function(random_intercept,
                                      formula_info = list(formula = NULL, source = "default"),
                                      default_covariate_col = NULL,
                                      include_pop_terms,
                                      scenario_terms = character(),
                                      target_scale = "mpd_counterfactual") {
  if (!is.null(formula_info$formula)) {
    return(stats::as.formula(formula_info$formula))
  }

  rhs_terms <- c(
    if (!is.null(default_covariate_col)) c("income_o", "income_d"),
    "log_distance",
    if (target_scale == "mpd_counterfactual") "bias_e_origin"
  )
  if (isTRUE(include_pop_terms)) {
    rhs_terms <- c(rhs_terms, "log_pop_o", "log_pop_d")
  }
  rhs_terms <- c(rhs_terms, scenario_terms)

  re_term <- switch(
    random_intercept,
    origin = "(1 | origin)",
    destination = "(1 | destination)",
    od = "(1 | od_id)",
    source = "(1 | mpd_source)",
    time = "(1 | mpd_time)",
    source_time = "(1 | mpd_source_time)",
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
  has_random_effects <- .formula_has_random_effects(formula)

  if (backend == "rstanarm") {
    if (!requireNamespace("rstanarm", quietly = TRUE)) {
      stop("Backend 'rstanarm' requested, but package is not installed.")
    }

    if (model_family == "poisson") {
      if (!has_random_effects) {
        return(rstanarm::stan_glm(
          formula = formula,
          data = data,
          family = stats::poisson(link = "log"),
          iter = iter,
          chains = chains,
          seed = seed,
          refresh = refresh
        ))
      }

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
      if (!has_random_effects) {
        return(rstanarm::stan_glm.nb(
          formula = formula,
          data = data,
          iter = iter,
          chains = chains,
          seed = seed,
          refresh = refresh
        ))
      }

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
      poisson = brms::brmsfamily("poisson"),
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

.posterior_linpred_fixef <- function(fit, backend, newdata, offset_col = NULL) {
  if (backend == "rstanarm") {
    offset <- NULL
    if (!is.null(offset_col) && offset_col %in% names(newdata)) {
      offset <- newdata[[offset_col]]
    }
    lp <- rstanarm::posterior_linpred(
      fit,
      newdata = newdata,
      transform = FALSE,
      re.form = NA,
      offset = offset
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

.resolve_multilevel_default_covariate_col <- function(covariates_df,
                                                      income_col = NULL,
                                                      pop_col = "population") {
  if (!is.null(income_col)) {
    if (!income_col %in% names(covariates_df)) {
      stop("`covariates_df` must contain `income_col` column `", income_col, "`.")
    }
    return(income_col)
  }

  preferred <- c(
    "income_norm",
    "rural_pct",
    "income",
    "gni_pc",
    "deprivation_score",
    "imd_score"
  )
  preferred <- preferred[preferred %in% names(covariates_df)]
  if (length(preferred) > 0L) {
    return(preferred[1])
  }

  candidate_cols <- setdiff(names(covariates_df), c("area", pop_col))
  numeric_cols <- candidate_cols[vapply(
    candidate_cols,
    function(col) is.numeric(covariates_df[[col]]) || is.integer(covariates_df[[col]]),
    logical(1)
  )]
  if (length(numeric_cols) > 0L) {
    return(numeric_cols[1])
  }

  NULL
}

.prepare_multilevel_bayes_data <- function(mpd_od_df,
                                           coverage_df,
                                           covariates_df,
                                           distance_df,
                                           flow_col,
                                           income_col,
                                           pop_col,
                                           distance_col,
                                           source_col = NULL,
                                           time_col = NULL,
                                           scenario_info = NULL) {
  req_mpd <- c("origin", "destination", flow_col)
  if (!all(req_mpd %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req_mpd, collapse = ", "))
  }

  req_cov <- c("origin", "population", "user_count")
  if (!all(req_cov %in% names(coverage_df))) {
    stop("`coverage_df` must contain: ", paste(req_cov, collapse = ", "))
  }

  if (is.null(covariates_df)) {
    area_values <- sort(unique(as.character(c(
      mpd_od_df$origin,
      mpd_od_df$destination,
      coverage_df$origin
    ))))
    covariates_df <- tibble::tibble(area = area_values)
  }

  req_covar <- "area"
  if (!all(req_covar %in% names(covariates_df))) {
    stop("`covariates_df` must contain: ", paste(req_covar, collapse = ", "))
  }
  default_covariate_col <- .resolve_multilevel_default_covariate_col(
    covariates_df = covariates_df,
    income_col = income_col,
    pop_col = pop_col
  )

  if (is.null(scenario_info)) {
    scenario_info <- .resolve_multilevel_scenario(
      mpd_od_df = mpd_od_df,
      coverage_df = coverage_df,
      source_col = source_col,
      time_col = time_col,
      scenario = "auto",
      repeated_observation = "auto"
    )
  }
  source_col <- scenario_info$source_col
  time_col <- scenario_info$time_col

  base_df <- mpd_od_df |>
    dplyr::mutate(
      row_id = dplyr::row_number(),
      origin = as.character(.data$origin),
      destination = as.character(.data$destination),
      flow = as.numeric(.data[[flow_col]]),
      od_id = paste(.data$origin, .data$destination, sep = "___")
    )

  if (!is.null(source_col)) {
    base_df$mpd_source <- as.character(mpd_od_df[[source_col]])
  } else if ("mpd_source" %in% names(base_df)) {
    base_df$mpd_source <- as.character(base_df$mpd_source)
  }
  if (!is.null(time_col)) {
    base_df$mpd_time <- as.character(mpd_od_df[[time_col]])
  } else if ("mpd_time" %in% names(base_df)) {
    base_df$mpd_time <- as.character(base_df$mpd_time)
  }
  if ("mpd_source" %in% names(base_df) && "mpd_time" %in% names(base_df)) {
    base_df$mpd_source_time <- paste(base_df$mpd_source, base_df$mpd_time, sep = "___")
  }

  if (!"mpd_observed" %in% names(base_df)) {
    base_df$mpd_observed <- TRUE
  } else {
    base_df$mpd_observed <- base_df$mpd_observed %in% TRUE
  }
  if (!"mpd_zero_filled" %in% names(base_df)) {
    base_df$mpd_zero_filled <- FALSE
  } else {
    base_df$mpd_zero_filled <- base_df$mpd_zero_filled %in% TRUE
  }
  if (!"mpd_row_status" %in% names(base_df)) {
    base_df$mpd_row_status <- ifelse(base_df$mpd_observed, "observed", "zero_filled")
  }

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
    origin_lookup <- area_lookup |>
      dplyr::transmute(origin = .data$area, origin_index = .data$area_index)
    destination_lookup <- area_lookup |>
      dplyr::transmute(destination = .data$area, destination_index = .data$area_index)

    base_df <- base_df |>
      dplyr::left_join(
        origin_lookup,
        by = "origin"
      ) |>
      dplyr::left_join(
        destination_lookup,
        by = "destination"
      ) |>
      dplyr::mutate(distance_km = abs(.data$origin_index - .data$destination_index) + 1) |>
      dplyr::select(-dplyr::all_of(c("origin_index", "destination_index")))
  }

  base_df <- base_df |>
    dplyr::mutate(
      distance_km = as.numeric(.data$distance_km),
      log_distance = log(pmax(.data$distance_km, .Machine$double.eps)),
      log_dist_synth = .data$log_distance
    )

  cov_origin <- coverage_df |>
    dplyr::transmute(
      origin = as.character(.data$origin),
      population = as.numeric(.data$population),
      user_count = as.numeric(.data$user_count)
    )
  if (!is.null(source_col) && source_col %in% names(coverage_df)) {
    cov_origin$mpd_source <- as.character(coverage_df[[source_col]])
  } else if ("mpd_source" %in% names(base_df) && "mpd_source" %in% names(coverage_df)) {
    cov_origin$mpd_source <- as.character(coverage_df$mpd_source)
  }
  if (!is.null(time_col) && time_col %in% names(coverage_df)) {
    cov_origin$mpd_time <- as.character(coverage_df[[time_col]])
  } else if ("mpd_time" %in% names(base_df) && "mpd_time" %in% names(coverage_df)) {
    cov_origin$mpd_time <- as.character(coverage_df$mpd_time)
  }

  join_keys <- intersect(c("origin", "mpd_source", "mpd_time"), names(cov_origin))
  join_keys <- join_keys[join_keys %in% names(base_df)]
  cov_origin <- cov_origin |>
    dplyr::group_by(dplyr::across(dplyr::all_of(join_keys))) |>
    dplyr::summarise(
      population = dplyr::first(.data$population),
      user_count = dplyr::first(.data$user_count),
      .groups = "drop"
    )

  base_df <- dplyr::left_join(base_df, cov_origin, by = join_keys)

  cov_destination <- cov_origin |>
    dplyr::rename(
      destination = origin,
      population_d_coverage = population,
      user_count_d_coverage = user_count
    )
  destination_join_keys <- intersect(c("destination", "mpd_source", "mpd_time"), names(cov_destination))
  destination_join_keys <- destination_join_keys[destination_join_keys %in% names(base_df)]
  base_df <- dplyr::left_join(base_df, cov_destination, by = destination_join_keys)

  pop_area_map <- coverage_df |>
    dplyr::transmute(
      area = as.character(.data$origin),
      .coverage_population = as.numeric(.data$population)
    ) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(.coverage_population = dplyr::first(.data$.coverage_population), .groups = "drop")

  area_covariates <- covariates_df |>
    dplyr::mutate(area = as.character(.data$area)) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), dplyr::first), .groups = "drop") |>
    dplyr::left_join(pop_area_map, by = "area")

  pop_val <- if (pop_col %in% names(area_covariates)) {
    suppressWarnings(as.numeric(area_covariates[[pop_col]]))
  } else {
    rep(NA_real_, nrow(area_covariates))
  }
  area_covariates$pop_val <- ifelse(
    is.finite(pop_val),
    pop_val,
    area_covariates$.coverage_population
  )

  join_covariates <- area_covariates |>
    dplyr::select(-dplyr::all_of(c(".coverage_population", "pop_val")))

  origin_covariates <- join_covariates |>
    dplyr::rename_with(
      .fn = function(x) if (length(x) == 0L) character() else paste0(x, "_o"),
      .cols = -dplyr::all_of("area")
    )
  names(origin_covariates)[names(origin_covariates) == "area"] <- "origin"

  destination_covariates <- join_covariates |>
    dplyr::rename_with(
      .fn = function(x) if (length(x) == 0L) character() else paste0(x, "_d"),
      .cols = -dplyr::all_of("area")
    )
  names(destination_covariates)[names(destination_covariates) == "area"] <- "destination"

  origin_pop <- area_covariates |>
    dplyr::transmute(origin = .data$area, pop_o = .data$pop_val)
  destination_pop <- area_covariates |>
    dplyr::transmute(destination = .data$area, pop_d = .data$pop_val)

  base_df <- base_df |>
    dplyr::left_join(
      origin_covariates,
      by = "origin"
    ) |>
    dplyr::left_join(
      destination_covariates,
      by = "destination"
    ) |>
    dplyr::left_join(
      origin_pop,
      by = "origin"
    ) |>
    dplyr::left_join(
      destination_pop,
      by = "destination"
    ) |>
    dplyr::mutate(
      pop_o = ifelse(is.finite(.data$pop_o), .data$pop_o, as.numeric(.data$population)),
      pop_d = ifelse(is.finite(.data$pop_d), .data$pop_d, .data$pop_o),
      log_pop_o = log(pmax(.data$pop_o, .Machine$double.eps)),
      log_pop_d = log(pmax(.data$pop_d, .Machine$double.eps)),
      coverage_rate_o = .data$user_count / .data$population,
      coverage_rate_d = .data$user_count_d_coverage / .data$population_d_coverage,
      log_coverage_o = log(.data$coverage_rate_o),
      log_coverage_d = log(.data$coverage_rate_d),
      bias_e_origin = 1 - .data$coverage_rate_o
    )

  if (!is.null(default_covariate_col)) {
    default_origin_col <- paste0(default_covariate_col, "_o")
    default_destination_col <- paste0(default_covariate_col, "_d")
    if (default_origin_col %in% names(base_df)) {
      base_df$income_o <- suppressWarnings(as.numeric(base_df[[default_origin_col]]))
    }
    if (default_destination_col %in% names(base_df)) {
      base_df$income_d <- suppressWarnings(as.numeric(base_df[[default_destination_col]]))
    }
  }

  finite_bias <- is.finite(base_df$bias_e_origin)
  bad_bias_n <- sum(!finite_bias)
  if (bad_bias_n > 0) {
    warning(bad_bias_n, " row(s) have non-finite origin bias ratio; excluded from model fitting.")
  }

  req_fit <- c("flow", "log_distance", "bias_e_origin")

  model_df <- base_df |>
    dplyr::filter(
      is.finite(.data$flow),
      .data$flow >= 0,
      dplyr::if_all(dplyr::all_of(req_fit), is.finite)
    )
  if (scenario_info$repeated_observation %in% c("source", "source_time") &&
      "mpd_source" %in% names(model_df)) {
    model_df <- model_df |>
      dplyr::filter(!is.na(.data$mpd_source), nzchar(.data$mpd_source))
  }
  if (scenario_info$repeated_observation %in% c("time", "source_time") &&
      "mpd_time" %in% names(model_df)) {
    model_df <- model_df |>
      dplyr::filter(!is.na(.data$mpd_time), nzchar(.data$mpd_time))
  }

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
    default_covariate_col = default_covariate_col,
    has_pop_terms = has_pop_terms,
    distance_source = distance_source,
    scenario_info = scenario_info
  )
}
