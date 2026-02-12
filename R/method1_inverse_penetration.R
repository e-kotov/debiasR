#' Method 1: Inverse penetration rate weights
#'
#' Adjusts MPD-derived OD flows using inverse penetration weights derived from
#' coverage information on population and active users at origins and/or
#' destinations.
#'
#' The coverage data frame is expected to contain, at minimum:
#' \itemize{
#'   \item \code{origin}, \code{origin_population}, \code{origin_user_count}
#'   \item \code{destination}, \code{destination_population}, \code{destination_user_count}
#' }
#' possibly with a \code{mpd_source} column for source-specific coverage.
#'
#' Penetration at origins is defined as
#'
#' \deqn{p^{(O)}_i = \frac{U^{(O)}_i}{P^{(O)}_i}}
#'
#' and the inverse-penetration weight is \eqn{w^{(O)}_i = P^{(O)}_i / U^{(O)}_i}.
#' Analogously for destinations.
#'
#' For \code{weight_by = "origin"}, adjusted flows are:
#'
#' \deqn{F^{adj}_{ij} = w^{(O)}_i F^{mpd}_{ij}.}
#'
#' For \code{weight_by = "destination"}:
#'
#' \deqn{F^{adj}_{ij} = w^{(D)}_j F^{mpd}_{ij}.}
#'
#' For \code{weight_by = "both"}, we use the geometric mean of the two:
#'
#' \deqn{w^{(B)}_{ij} = \sqrt{w^{(O)}_i w^{(D)}_j}, \quad
#'       F^{adj}_{ij} = w^{(B)}_{ij} F^{mpd}_{ij}.}
#'
#' @param mpd_od_df Data frame of MPD flows with at least:
#'   \code{origin, destination,} and a flow column (default \code{"flow"}).
#'   If present, \code{mpd_source} is used to match coverage by source.
#' @param coverage_df Data frame with at least:
#'   \itemize{
#'     \item \code{origin, origin_population, origin_user_count}
#'     \item \code{destination, destination_population, destination_user_count}
#'   }
#'   and optionally \code{mpd_source}.
#' @param flow_col Name of the MPD flow column in \code{mpd_od_df}. Default "flow".
#' @param weight_by One of \code{"origin"}, \code{"destination"}, \code{"both"}.
#'
#' @return A tibble with:
#'   \itemize{
#'     \item \code{origin, destination} (and \code{mpd_source} if present),
#'     \item \code{flow}: original MPD flow,
#'     \item \code{flow_adj}: adjusted flow,
#'     \item \code{weight_origin}: origin-side inverse-penetration weight (if applicable),
#'     \item \code{weight_destination}: destination-side weight (if applicable),
#'     \item \code{weight_both}: geometric mean of the two (if \code{weight_by = "both"}).
#'   }
#'
#' @export
method1_inverse_penetration <- function(mpd_od_df,
                                        coverage_df,
                                        flow_col  = "flow",
                                        weight_by = c("origin", "destination", "both")) {

  weight_by <- match.arg(weight_by)

  # --- basic checks -------------------------------------------------------

  req_mpd <- c("origin", "destination", flow_col)
  if (!all(req_mpd %in% names(mpd_od_df))) {
    stop("`mpd_od_df` must contain: ", paste(req_mpd, collapse = ", "))
  }

  has_source <- "mpd_source" %in% names(mpd_od_df) &&
    "mpd_source" %in% names(coverage_df)

  # origin-side requirements
  if (weight_by %in% c("origin", "both")) {
    req_cov_o <- c("origin", "origin_population", "origin_user_count")
    if (!all(req_cov_o %in% names(coverage_df))) {
      stop("`coverage_df` must contain origin columns: ",
           paste(req_cov_o, collapse = ", "),
           " for weight_by = '", weight_by, "'.")
    }
  }

  # destination-side requirements
  if (weight_by %in% c("destination", "both")) {
    req_cov_d <- c("destination", "destination_population", "destination_user_count")
    if (!all(req_cov_d %in% names(coverage_df))) {
      stop("`coverage_df` must contain destination columns: ",
           paste(req_cov_d, collapse = ", "),
           " for weight_by = '", weight_by, "'.")
    }
  }

  # --- build origin weights -----------------------------------------------

  if (weight_by %in% c("origin", "both")) {
    if (has_source) {
      cov_o <- coverage_df |>
        dplyr::select(origin, mpd_source,
                      origin_population, origin_user_count) |>
        dplyr::distinct() |>
        dplyr::mutate(
          weight_origin = origin_population / origin_user_count
        )
    } else {
      cov_o <- coverage_df |>
        dplyr::select(origin,
                      origin_population, origin_user_count) |>
        dplyr::distinct() |>
        dplyr::mutate(
          weight_origin = origin_population / origin_user_count
        )
    }
  } else {
    cov_o <- NULL
  }

  # --- build destination weights ------------------------------------------

  if (weight_by %in% c("destination", "both")) {
    if (has_source) {
      cov_d <- coverage_df |>
        dplyr::select(destination, mpd_source,
                      destination_population, destination_user_count) |>
        dplyr::distinct() |>
        dplyr::mutate(
          weight_destination = destination_population / destination_user_count
        )
    } else {
      cov_d <- coverage_df |>
        dplyr::select(destination,
                      destination_population, destination_user_count) |>
        dplyr::distinct() |>
        dplyr::mutate(
          weight_destination = destination_population / destination_user_count
        )
    }
  } else {
    cov_d <- NULL
  }

  # --- join weights onto MPD OD -------------------------------------------

  out <- mpd_od_df

  # origin weights
  if (!is.null(cov_o)) {
    if (has_source) {
      out <- out |>
        dplyr::left_join(
          cov_o |>
            dplyr::select(origin, mpd_source, weight_origin),
          by = c("origin", "mpd_source")
        )
    } else {
      out <- out |>
        dplyr::left_join(
          cov_o |>
            dplyr::select(origin, weight_origin),
          by = "origin"
        )
    }
  }

  # destination weights
  if (!is.null(cov_d)) {
    if (has_source) {
      out <- out |>
        dplyr::left_join(
          cov_d |>
            dplyr::select(destination, mpd_source, weight_destination),
          by = c("destination", "mpd_source")
        )
    } else {
      out <- out |>
        dplyr::left_join(
          cov_d |>
            dplyr::select(destination, weight_destination),
          by = "destination"
        )
    }
  }

  # --- compute adjusted flows --------------------------------------------

  flow_vec <- out[[flow_col]]

  if (weight_by == "origin") {
    out$flow_adj <- flow_vec * out$weight_origin

  } else if (weight_by == "destination") {
    out$flow_adj <- flow_vec * out$weight_destination

  } else if (weight_by == "both") {
    # geometric mean when both weights are available and positive
    out$weight_both <- sqrt(out$weight_origin * out$weight_destination)
    out$flow_adj    <- flow_vec * out$weight_both
  }

  # final ordering: keep original flow explicitly
  out <- out |>
    dplyr::rename(flow = !!rlang::sym(flow_col)) |>
    tibble::as_tibble()

  out
}
