#' Load empirical travel-to-work example data
#'
#' Loads the LAD travel-to-work example inputs used by package examples and
#' vignettes. By default, the mobile-phone-derived OD data are read from the
#' optional companion package `debiasRdata`
#' (<https://github.com/de-bias/debiasRdata>) as `lad_OD_travel2work`. The
#' benchmark OD data are the matching Census 2021 workplace-flow extract
#' `census_lad_OD_travel2work`, also supplied by `debiasRdata`.
#'
#' Both sources are normalised to the package schema:
#' `origin`, `destination`, and `flow`. The returned coverage table is derived
#' from matched origin totals: Census workplace outflow is used as the benchmark
#' population-like denominator and MPD travel-to-work outflow is used as the
#' active-user numerator for the empirical examples.
#' If `debiasRdata` supplies area-level covariates, the returned `covariates`
#' table uses the selected rows from `lad_covariates` or `msoa_covariates`. If
#' no matching covariate object is available, the package falls back to the
#' derived covariates used in earlier examples.
#' If `debiasRdata` supplies LAD centroids, the optional distance table is
#' computed for the selected example areas from those real centroids rather than
#' from a synthetic placeholder.
#'
#' @param n_areas Number of high-flow overlapping areas to keep for examples.
#'   Use `Inf` or `NULL` to keep all overlapping areas.
#' @param data_package Data package containing the empirical files. Default
#'   `"debiasRdata"`.
#' @param mpd_path Optional explicit path to the observed MPD OD CSV or
#'   `.csv.gz`.
#' @param census_path Optional explicit path to the extracted Census 2021
#'   travel-to-work OD CSV or `.csv.gz`.
#' @param include_self_flows Logical; keep within-area flows. Default `TRUE`.
#' @param complete_grid Logical; if `TRUE`, return MPD and benchmark OD tables
#'   on the same square area grid after area selection. Missing OD pairs are
#'   retained with zero-filled flows and row-status indicators. Default `FALSE`
#'   preserves the observed positive-flow support.
#' @param fill_missing_flow Numeric value used for absent OD pairs when
#'   `complete_grid = TRUE`. Default `0`.
#' @param geography Area level to load from `debiasRdata`. The default `"lad"`
#'   uses `lad_OD_travel2work`, `census_lad_OD_travel2work`, optional
#'   `lad_covariates`, and optional `lad_centroids`. Use `"msoa"` only when
#'   MSOA-level examples are explicitly required.
#'
#' @return A named list with normalised OD matrices and derived teaching tables:
#'   `lad_OD_travel2work` and `mpd_od` for observed MPD flows,
#'   `census_lad_OD_travel2work` and `benchmark_od` for the Census benchmark,
#'   plus `coverage`, `active_users`, `population`, `covariates`, `distance`,
#'   `od_audit`, and `metadata`.
#'
#' @examplesIf requireNamespace("debiasRdata", quietly = TRUE)
#' ex <- debiasR_example_data(n_areas = 12)
#' names(ex)
#' head(ex$lad_OD_travel2work)
#' head(ex$census_lad_OD_travel2work)
#'
#' @export
debiasR_example_data <- function(n_areas = 25,
                                 data_package = "debiasRdata",
                                 mpd_path = NULL,
                                 census_path = NULL,
                                 include_self_flows = TRUE,
                                 complete_grid = FALSE,
                                 fill_missing_flow = 0,
                                 geography = c("lad", "msoa")) {
  geography <- match.arg(geography)
  complete_grid <- isTRUE(complete_grid)
  if (!is.numeric(fill_missing_flow) ||
      length(fill_missing_flow) != 1L ||
      !is.finite(fill_missing_flow) ||
      fill_missing_flow < 0) {
    stop("`fill_missing_flow` must be a single finite non-negative number.")
  }

  source_spec <- .example_source_spec(geography)

  mpd_raw <- .load_example_source(
    path = mpd_path,
    object_names = source_spec$mpd_object_names,
    file_names = source_spec$mpd_file_names,
    data_package = data_package,
    label = source_spec$mpd_label
  )

  census_raw <- .load_example_source(
    path = census_path,
    object_names = source_spec$census_object_names,
    file_names = source_spec$census_file_names,
    data_package = data_package,
    label = source_spec$census_label
  )

  mpd_od <- .normalise_mpd_travel_to_work(
    mpd_raw,
    include_self_flows,
    geography = geography
  )
  benchmark_od <- .normalise_census_travel_to_work(
    census_raw,
    include_self_flows,
    geography = geography
  )

  common_areas <- intersect(
    union(mpd_od$origin, mpd_od$destination),
    union(benchmark_od$origin, benchmark_od$destination)
  )

  if (length(common_areas) == 0L) {
    stop(
      "No overlapping ",
      source_spec$area_label,
      " codes were found between MPD and Census OD data."
    )
  }

  area_scores <- dplyr::bind_rows(
    mpd_od |>
      dplyr::transmute(area = .data$origin, score = .data$flow),
    mpd_od |>
      dplyr::transmute(area = .data$destination, score = .data$flow),
    benchmark_od |>
      dplyr::transmute(area = .data$origin, score = .data$flow),
    benchmark_od |>
      dplyr::transmute(area = .data$destination, score = .data$flow)
  ) |>
    dplyr::filter(.data$area %in% common_areas) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(score = sum(.data$score, na.rm = TRUE), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(.data$score), .data$area)

  if (!is.null(n_areas) && is.finite(n_areas)) {
    n_areas <- as.integer(n_areas)
    if (n_areas < 2L) {
      stop("`n_areas` must be at least 2, `Inf`, or `NULL`.")
    }
    area_scores <- dplyr::slice_head(area_scores, n = n_areas)
  }

  selected_areas <- area_scores$area

  mpd_od <- mpd_od |>
    dplyr::filter(
      .data$origin %in% selected_areas,
      .data$destination %in% selected_areas
    ) |>
    dplyr::mutate(mpd_source = source_spec$mpd_source) |>
    dplyr::select(.data$origin, .data$destination, .data$mpd_source, .data$flow) |>
    dplyr::arrange(.data$origin, .data$destination)

  benchmark_od <- benchmark_od |>
    dplyr::filter(
      .data$origin %in% selected_areas,
      .data$destination %in% selected_areas
    ) |>
    dplyr::arrange(.data$origin, .data$destination)

  if (nrow(mpd_od) == 0L || nrow(benchmark_od) == 0L) {
    stop("The selected areas do not contain overlapping MPD and Census OD flows.")
  }

  coverage <- .build_example_coverage(mpd_od, benchmark_od)
  final_areas <- coverage$origin

  mpd_od <- mpd_od |>
    dplyr::filter(
      .data$origin %in% final_areas,
      .data$destination %in% final_areas
    )
  benchmark_od <- benchmark_od |>
    dplyr::filter(
      .data$origin %in% final_areas,
      .data$destination %in% final_areas
    )

  if (complete_grid) {
    completed <- .complete_example_od_support(
      mpd_od = mpd_od,
      benchmark_od = benchmark_od,
      areas = final_areas,
      include_self_flows = include_self_flows,
      fill_missing_flow = fill_missing_flow
    )
    mpd_od <- completed$mpd_od
    benchmark_od <- completed$benchmark_od
    od_audit <- completed$od_audit
  } else {
    od_audit <- .audit_example_od_support(
      mpd_od = mpd_od,
      benchmark_od = benchmark_od,
      complete_grid = FALSE,
      include_self_flows = include_self_flows
    )
  }

  derived_covariates <- .build_example_covariates(mpd_od, benchmark_od, coverage)
  covariate_bundle <- .load_optional_example_covariates(
    data_package = data_package,
    areas = final_areas,
    geography = geography
  )
  if (nrow(covariate_bundle$covariates) > 0L) {
    covariates <- covariate_bundle$covariates
    covariate_source <- covariate_bundle$covariate_source
  } else {
    covariates <- derived_covariates
    covariate_source <- "derived_from_od_flows"
  }

  distance <- .load_optional_example_distance(
    data_package = data_package,
    areas = final_areas,
    include_self_flows = include_self_flows,
    geography = geography
  )
  distance_source <- if (nrow(distance) > 0L) {
    distance$distance_source[[1]]
  } else {
    "not_available"
  }

  out <- list(
    mpd_od = mpd_od,
    benchmark_od = benchmark_od,
    coverage = coverage,
    active_users = coverage |>
      dplyr::select(.data$origin, .data$user_count, .data$mpd_source),
    population = coverage |>
      dplyr::select(.data$origin, .data$population),
    covariates = covariates,
    distance = distance,
    od_audit = od_audit,
    metadata = tibble::tibble(
      data_package = data_package,
      geography = geography,
      mpd_source = source_spec$mpd_metadata_source,
      benchmark_source = source_spec$benchmark_metadata_source,
      covariate_source = covariate_source,
      distance_source = distance_source,
      complete_grid = complete_grid,
      include_self_flows = include_self_flows,
      fill_missing_flow = fill_missing_flow,
      n_areas = length(final_areas),
      n_mpd_od = nrow(mpd_od),
      n_benchmark_od = nrow(benchmark_od),
      n_expected_od = od_audit$expected_od_rows[[1]],
      n_mpd_zero_filled = od_audit$n_mpd_zero_filled[[1]],
      n_benchmark_zero_filled = od_audit$n_benchmark_zero_filled[[1]],
      mpd_total_flow = od_audit$mpd_total_flow[[1]],
      benchmark_total_flow = od_audit$benchmark_total_flow[[1]],
      mpd_balance_diff = od_audit$mpd_balance_diff[[1]],
      benchmark_balance_diff = od_audit$benchmark_balance_diff[[1]]
    )
  )

  out[[source_spec$mpd_return_name]] <- out$mpd_od
  out[[source_spec$census_return_name]] <- out$benchmark_od
  if (geography == "msoa") {
    out$msoa_OD_travel2work <- out$mpd_od
    out$census_msoa_OD_travel2work <- out$benchmark_od
  }

  out
}

.example_source_spec <- function(geography) {
  if (identical(geography, "lad")) {
    return(list(
      area_label = "LAD/LTLA",
      mpd_object_names = c("lad_OD_travel2work", "lad_od_travel2work", "OD_travel2work"),
      mpd_file_names = c(
        "lad_OD_travel2work.csv.gz",
        "lad_OD_travel2work.csv",
        "OD_travel2work.csv.gz",
        "OD_travel2work.csv"
      ),
      census_object_names = c(
        "census_lad_OD_travel2work",
        "census_lad_od_travel2work",
        "census_OD_travel2work",
        "ODWP01EW_LTLA"
      ),
      census_file_names = c(
        "census_lad_OD_travel2work.csv.gz",
        "census_lad_OD_travel2work.csv",
        "census_OD_travel2work.csv.gz",
        "census_OD_travel2work.csv",
        "ODWP01EW_LTLA_travel2work.csv.gz",
        "ODWP01EW_LTLA_travel2work.csv",
        "ODWP01EW_LTLA.csv.gz",
        "ODWP01EW_LTLA.csv"
      ),
      mpd_label = "MPD LAD travel-to-work OD data",
      census_label = "Census LAD/LTLA travel-to-work benchmark OD data",
      mpd_source = "locomizer_travel_to_work_lad",
      mpd_metadata_source = "Zenodo 10.5281/zenodo.13327082: lad_OD_travel2work LAD aggregate",
      benchmark_metadata_source = "Census 2021 ODWP01EW LTLA workplace flows",
      mpd_return_name = "lad_OD_travel2work",
      census_return_name = "census_lad_OD_travel2work"
    ))
  }

  list(
    area_label = "MSOA",
    mpd_object_names = c("msoa_OD_travel2work", "msoa_od_travel2work"),
    mpd_file_names = c("msoa_OD_travel2work.csv.gz", "msoa_OD_travel2work.csv"),
    census_object_names = c(
      "census_msoa_OD_travel2work",
      "census_msoa_od_travel2work",
      "odwp01ew_msoa_travel2work",
      "ODWP01EW_MSOA"
    ),
    census_file_names = c(
      "census_msoa_OD_travel2work.csv.gz",
      "census_msoa_OD_travel2work.csv",
      "msoa_census_travel2work.csv.gz",
      "msoa_census_travel2work.csv",
      "ODWP01EW_MSOA_travel2work.csv.gz",
      "ODWP01EW_MSOA_travel2work.csv",
      "ODWP01EW_MSOA.csv.gz",
      "ODWP01EW_MSOA.csv"
    ),
    mpd_label = "MPD MSOA travel-to-work OD data",
    census_label = "Census MSOA travel-to-work benchmark OD data",
    mpd_source = "locomizer_travel_to_work_msoa",
    mpd_metadata_source = "Zenodo 10.5281/zenodo.13327082: msoa_OD_travel2work",
    benchmark_metadata_source = "Census 2021 ODWP01EW MSOA workplace flows",
    mpd_return_name = "msoa_OD_travel2work",
    census_return_name = "census_msoa_OD_travel2work"
  )
}

.complete_example_od_support <- function(mpd_od,
                                         benchmark_od,
                                         areas,
                                         include_self_flows,
                                         fill_missing_flow) {
  areas <- sort(unique(as.character(areas)))
  grid <- expand.grid(
    origin = areas,
    destination = areas,
    stringsAsFactors = FALSE
  ) |>
    tibble::as_tibble()

  if (!include_self_flows) {
    grid <- grid |>
      dplyr::filter(.data$origin != .data$destination)
  }

  mpd_completed <- .complete_one_example_od(
    od_df = mpd_od,
    grid = grid,
    prefix = "mpd",
    fill_missing_flow = fill_missing_flow
  )

  benchmark_completed <- .complete_one_example_od(
    od_df = benchmark_od,
    grid = grid,
    prefix = "benchmark",
    fill_missing_flow = fill_missing_flow
  )

  od_audit <- .audit_example_od_support(
    mpd_od = mpd_completed,
    benchmark_od = benchmark_completed,
    complete_grid = TRUE,
    include_self_flows = include_self_flows
  )

  if (!isTRUE(od_audit$strict_square_support[[1]])) {
    stop("Complete-grid construction failed strict square OD support checks.")
  }

  list(
    mpd_od = mpd_completed,
    benchmark_od = benchmark_completed,
    od_audit = od_audit
  )
}

.complete_one_example_od <- function(od_df,
                                     grid,
                                     prefix,
                                     fill_missing_flow) {
  if (anyDuplicated(od_df[c("origin", "destination")]) > 0L) {
    stop("`", prefix, "` OD data contain duplicate origin-destination pairs.")
  }
  if (any(!is.finite(od_df$flow) | od_df$flow < 0)) {
    stop("`", prefix, "` OD flow values must be finite and non-negative.")
  }

  has_source <- "mpd_source" %in% names(od_df)
  source_value <- if (has_source && nrow(od_df) > 0L) {
    od_df$mpd_source[[1]]
  } else {
    "locomizer_travel_to_work"
  }

  joined <- grid |>
    dplyr::left_join(od_df, by = c("origin", "destination"))

  observed_col <- paste0(prefix, "_observed")
  zero_filled_col <- paste0(prefix, "_zero_filled")
  status_col <- paste0(prefix, "_row_status")

  joined[[observed_col]] <- is.finite(joined$flow)
  joined$flow <- ifelse(joined[[observed_col]], joined$flow, fill_missing_flow)
  joined[[zero_filled_col]] <- !joined[[observed_col]]
  joined[[status_col]] <- ifelse(joined[[observed_col]], "observed", "zero_filled")

  if (has_source) {
    joined$mpd_source <- ifelse(
      is.na(joined$mpd_source),
      source_value,
      joined$mpd_source
    )
    joined <- joined |>
      dplyr::select(
        .data$origin,
        .data$destination,
        .data$mpd_source,
        dplyr::all_of(c(observed_col, zero_filled_col, status_col)),
        .data$flow
      )
  } else {
    joined <- joined |>
      dplyr::select(
        .data$origin,
        .data$destination,
        dplyr::all_of(c(observed_col, zero_filled_col, status_col)),
        .data$flow
      )
  }

  joined |>
    dplyr::arrange(.data$origin, .data$destination) |>
    tibble::as_tibble()
}

.audit_example_od_support <- function(mpd_od,
                                      benchmark_od,
                                      complete_grid,
                                      include_self_flows) {
  mpd_origins <- sort(unique(as.character(mpd_od$origin)))
  mpd_destinations <- sort(unique(as.character(mpd_od$destination)))
  benchmark_origins <- sort(unique(as.character(benchmark_od$origin)))
  benchmark_destinations <- sort(unique(as.character(benchmark_od$destination)))
  area_set <- sort(unique(c(
    mpd_origins,
    mpd_destinations,
    benchmark_origins,
    benchmark_destinations
  )))

  expected_od_rows <- length(area_set)^2
  if (!include_self_flows) {
    expected_od_rows <- length(area_set) * max(length(area_set) - 1L, 0L)
  }

  mpd_total_flow <- sum(mpd_od$flow, na.rm = TRUE)
  benchmark_total_flow <- sum(benchmark_od$flow, na.rm = TRUE)

  same_area_set <- identical(mpd_origins, mpd_destinations) &&
    identical(benchmark_origins, benchmark_destinations) &&
    identical(mpd_origins, benchmark_origins)

  duplicate_mpd <- sum(duplicated(mpd_od[c("origin", "destination")]))
  duplicate_benchmark <- sum(duplicated(benchmark_od[c("origin", "destination")]))
  strict_square_support <- same_area_set &&
    nrow(mpd_od) == expected_od_rows &&
    nrow(benchmark_od) == expected_od_rows &&
    duplicate_mpd == 0L &&
    duplicate_benchmark == 0L &&
    all(is.finite(mpd_od$flow) & mpd_od$flow >= 0) &&
    all(is.finite(benchmark_od$flow) & benchmark_od$flow >= 0)

  tibble::tibble(
    complete_grid = complete_grid,
    include_self_flows = include_self_flows,
    strict_square_support = strict_square_support,
    same_origin_destination_area_set = same_area_set,
    n_areas = length(area_set),
    expected_od_rows = expected_od_rows,
    n_mpd_od = nrow(mpd_od),
    n_benchmark_od = nrow(benchmark_od),
    n_mpd_duplicate_pairs = duplicate_mpd,
    n_benchmark_duplicate_pairs = duplicate_benchmark,
    n_mpd_zero_filled = .sum_logical_col(mpd_od, "mpd_zero_filled"),
    n_benchmark_zero_filled = .sum_logical_col(benchmark_od, "benchmark_zero_filled"),
    mpd_total_flow = mpd_total_flow,
    benchmark_total_flow = benchmark_total_flow,
    mpd_total_outflow = mpd_total_flow,
    mpd_total_inflow = mpd_total_flow,
    benchmark_total_outflow = benchmark_total_flow,
    benchmark_total_inflow = benchmark_total_flow,
    mpd_balance_diff = 0,
    benchmark_balance_diff = 0
  )
}

.sum_logical_col <- function(df, col) {
  if (!col %in% names(df)) {
    return(0L)
  }
  sum(isTRUE(df[[col]]) | df[[col]] %in% TRUE, na.rm = TRUE)
}

.empty_example_distance <- function() {
  tibble::tibble(
    origin = character(),
    destination = character(),
    distance_km = numeric(),
    distance_source = character()
  )
}

.empty_example_covariate_bundle <- function() {
  list(
    covariates = tibble::tibble(),
    covariate_source = "not_available"
  )
}

.load_optional_example_covariates <- function(data_package,
                                              areas,
                                              geography) {
  if (!requireNamespace(data_package, quietly = TRUE)) {
    return(.empty_example_covariate_bundle())
  }

  covariate_spec <- .example_covariate_spec(geography)
  covariates_raw <- .load_optional_example_object(
    object_names = covariate_spec$covariate_object_names,
    data_package = data_package
  )

  if (is.null(covariates_raw)) {
    covariate_path <- .find_example_file(
      file_names = covariate_spec$covariate_file_names,
      data_package = data_package
    )
    if (!is.null(covariate_path)) {
      covariates_raw <- .read_example_csv(covariate_path)
    }
  }

  if (is.null(covariates_raw)) {
    return(.empty_example_covariate_bundle())
  }

  covariates <- .normalise_example_covariates(
    covariates_raw,
    areas = areas
  )

  if (nrow(covariates) == 0L) {
    return(.empty_example_covariate_bundle())
  }

  list(
    covariates = covariates,
    covariate_source = paste0(data_package, "::", covariate_spec$covariate_source)
  )
}

.example_covariate_spec <- function(geography) {
  if (identical(geography, "lad")) {
    return(list(
      covariate_object_names = c(
        "lad_covariates",
        "lad_covariate",
        "lad_area_covariates",
        "covariates"
      ),
      covariate_file_names = c(
        "lad_covariates.csv.gz",
        "lad_covariates.csv",
        "lad_area_covariates.csv.gz",
        "lad_area_covariates.csv",
        "covariates.csv.gz",
        "covariates.csv"
      ),
      covariate_source = "lad_covariates"
    ))
  }

  list(
    covariate_object_names = c(
      "msoa_covariates",
      "msoa_covariate",
      "msoa_area_covariates",
      "covariates"
    ),
    covariate_file_names = c(
      "msoa_covariates.csv.gz",
      "msoa_covariates.csv",
      "msoa_area_covariates.csv.gz",
      "msoa_area_covariates.csv",
      "covariates.csv.gz",
      "covariates.csv"
    ),
    covariate_source = "msoa_covariates"
  )
}

.normalise_example_covariates <- function(df, areas) {
  area_col <- .find_col(
    df,
    c(
      "area",
      "lad",
      "lad21cd",
      "lad22cd",
      "ltla",
      "ltla_code",
      "msoa",
      "msoa21cd",
      "msoa_code",
      "code"
    ),
    required = FALSE
  )

  if (is.null(area_col)) {
    return(tibble::tibble())
  }

  areas <- sort(unique(as.character(areas)))
  out <- tibble::as_tibble(df)
  out$area <- as.character(out[[area_col]])
  if (!identical(area_col, "area")) {
    out <- out |>
      dplyr::select(-dplyr::all_of(area_col))
  }

  out <- out |>
    dplyr::filter(
      .data$area %in% areas,
      !is.na(.data$area)
    ) |>
    dplyr::select(dplyr::all_of("area"), dplyr::everything()) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(
      dplyr::across(dplyr::everything(), ~ dplyr::first(.x)),
      .groups = "drop"
    )

  if (!all(areas %in% out$area)) {
    return(tibble::tibble())
  }

  out |>
    dplyr::mutate(.area_order = match(.data$area, areas)) |>
    dplyr::arrange(.data$.area_order) |>
    dplyr::select(-dplyr::all_of(".area_order")) |>
    tibble::as_tibble()
}

.load_optional_example_distance <- function(data_package,
                                            areas,
                                            include_self_flows,
                                            geography) {
  if (!requireNamespace(data_package, quietly = TRUE)) {
    return(.empty_example_distance())
  }

  distance_spec <- .example_distance_spec(geography)
  distance_raw <- .load_optional_example_object(
    object_names = distance_spec$distance_object_names,
    data_package = data_package
  )

  if (is.null(distance_raw)) {
    distance_path <- .find_example_file(
      file_names = distance_spec$distance_file_names,
      data_package = data_package
    )
    if (!is.null(distance_path)) {
      distance_raw <- .read_example_csv(distance_path)
    }
  }

  if (!is.null(distance_raw)) {
    distance <- .normalise_example_distance(
      distance_raw,
      areas = areas,
      include_self_flows = include_self_flows
    )
    if (nrow(distance) > 0L) {
      return(distance)
    }
  }

  centroids_raw <- .load_optional_example_object(
    object_names = distance_spec$centroid_object_names,
    data_package = data_package
  )

  if (is.null(centroids_raw)) {
    centroid_path <- .find_example_file(
      file_names = distance_spec$centroid_file_names,
      data_package = data_package
    )
    if (!is.null(centroid_path)) {
      centroids_raw <- .read_example_csv(centroid_path)
    }
  }

  if (is.null(centroids_raw)) {
    return(.empty_example_distance())
  }

  centroids <- .normalise_example_centroids(centroids_raw, areas = areas)
  .build_example_centroid_distance(
    centroids,
    areas = areas,
    include_self_flows = include_self_flows,
    distance_source = distance_spec$centroid_distance_source
  )
}

.example_distance_spec <- function(geography) {
  if (identical(geography, "lad")) {
    return(list(
      distance_object_names = c(
        "lad_OD_distance",
        "lad_od_distance",
        "lad_distance",
        "lad_distance_matrix",
        "distance"
      ),
      distance_file_names = c(
        "lad_OD_distance.csv.gz",
        "lad_OD_distance.csv",
        "lad_distance.csv.gz",
        "lad_distance.csv",
        "distance.csv.gz",
        "distance.csv"
      ),
      centroid_object_names = c(
        "lad_centroids",
        "lad_centroid",
        "lad_area_centroids",
        "lad_points"
      ),
      centroid_file_names = c(
        "lad_centroids.csv.gz",
        "lad_centroids.csv",
        "lad_centroid.csv.gz",
        "lad_centroid.csv"
      ),
      centroid_distance_source = "debiasRdata_lad_centroids"
    ))
  }

  list(
    distance_object_names = c(
      "msoa_OD_distance",
      "msoa_od_distance",
      "msoa_distance",
      "msoa_distance_matrix",
      "distance"
    ),
    distance_file_names = c(
      "msoa_OD_distance.csv.gz",
      "msoa_OD_distance.csv",
      "msoa_distance.csv.gz",
      "msoa_distance.csv",
      "distance.csv.gz",
      "distance.csv"
    ),
    centroid_object_names = c(
      "msoa_centroids",
      "msoa_centroid",
      "msoa_area_centroids",
      "msoa_points"
    ),
    centroid_file_names = c(
      "msoa_centroids.csv.gz",
      "msoa_centroids.csv",
      "msoa_centroid.csv.gz",
      "msoa_centroid.csv"
    ),
    centroid_distance_source = "debiasRdata_msoa_centroids"
  )
}

.load_optional_example_object <- function(object_names, data_package) {
  env <- new.env(parent = emptyenv())
  for (object_name in object_names) {
    suppressWarnings(
      utils::data(list = object_name, package = data_package, envir = env)
    )
    if (exists(object_name, envir = env, inherits = FALSE)) {
      return(get(object_name, envir = env, inherits = FALSE))
    }
  }
  NULL
}

.normalise_example_distance <- function(df,
                                        areas,
                                        include_self_flows) {
  origin_col <- .find_col(
    df,
    c("origin", "MSOA21CD_home", "msoa21cd_home", "origin_msoa", "from"),
    required = FALSE
  )
  destination_col <- .find_col(
    df,
    c("destination", "MSOA21CD_work", "msoa21cd_work", "destination_msoa", "to"),
    required = FALSE
  )
  distance_col <- .find_col(
    df,
    c("distance_km", "distance", "dist_km", "distance_m", "dist_m", "dist"),
    required = FALSE
  )

  if (is.null(origin_col) || is.null(destination_col) || is.null(distance_col)) {
    return(.empty_example_distance())
  }

  areas <- sort(unique(as.character(areas)))

  distance <- suppressWarnings(as.numeric(df[[distance_col]]))
  if (.clean_colnames(distance_col) %in% c("distance_m", "dist_m")) {
    distance <- distance / 1000
  }

  out <- tibble::tibble(
    origin = as.character(df[[origin_col]]),
    destination = as.character(df[[destination_col]]),
    distance_km = distance
  ) |>
    dplyr::filter(
      .data$origin %in% areas,
      .data$destination %in% areas,
      is.finite(.data$distance_km),
      .data$distance_km >= 0
    )

  if (!include_self_flows) {
    out <- out |>
      dplyr::filter(.data$origin != .data$destination)
  }

  out |>
    dplyr::group_by(.data$origin, .data$destination) |>
    dplyr::summarise(distance_km = dplyr::first(.data$distance_km), .groups = "drop") |>
    dplyr::mutate(distance_source = "debiasRdata") |>
    dplyr::arrange(.data$origin, .data$destination) |>
    tibble::as_tibble()
}

.normalise_example_centroids <- function(df, areas) {
  area_col <- .find_col(
    df,
    c(
      "area",
      "lad",
      "lad21cd",
      "lad22cd",
      "ltla",
      "ltla_code",
      "msoa",
      "msoa21cd",
      "msoa_code",
      "code"
    ),
    required = FALSE
  )
  longitude_col <- .find_col(
    df,
    c("longitude", "long", "lon", "x_longitude"),
    required = FALSE
  )
  latitude_col <- .find_col(
    df,
    c("latitude", "lat", "y_latitude"),
    required = FALSE
  )
  easting_col <- .find_col(
    df,
    c("easting", "bng_e", "x", "x_coord"),
    required = FALSE
  )
  northing_col <- .find_col(
    df,
    c("northing", "bng_n", "y", "y_coord"),
    required = FALSE
  )

  if (is.null(area_col) ||
      ((is.null(longitude_col) || is.null(latitude_col)) &&
        (is.null(easting_col) || is.null(northing_col)))) {
    return(.empty_example_centroids())
  }

  areas <- sort(unique(as.character(areas)))
  out <- tibble::tibble(
    area = as.character(df[[area_col]]),
    longitude = .numeric_or_missing(df, longitude_col),
    latitude = .numeric_or_missing(df, latitude_col),
    easting = .numeric_or_missing(df, easting_col),
    northing = .numeric_or_missing(df, northing_col)
  ) |>
    dplyr::filter(
      .data$area %in% areas,
      !is.na(.data$area)
    ) |>
    dplyr::group_by(.data$area) |>
    dplyr::summarise(
      longitude = dplyr::first(.data$longitude),
      latitude = dplyr::first(.data$latitude),
      easting = dplyr::first(.data$easting),
      northing = dplyr::first(.data$northing),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$area)

  if (!all(areas %in% out$area)) {
    return(.empty_example_centroids())
  }

  out |>
    tibble::as_tibble()
}

.empty_example_centroids <- function() {
  tibble::tibble(
    area = character(),
    longitude = numeric(),
    latitude = numeric(),
    easting = numeric(),
    northing = numeric()
  )
}

.numeric_or_missing <- function(df, col) {
  if (is.null(col)) {
    return(rep(NA_real_, nrow(df)))
  }
  suppressWarnings(as.numeric(df[[col]]))
}

.build_example_centroid_distance <- function(centroids,
                                             areas,
                                             include_self_flows,
                                             distance_source = "debiasRdata_centroids") {
  areas <- sort(unique(as.character(areas)))
  if (length(areas) == 0L ||
      nrow(centroids) == 0L ||
      !all(areas %in% centroids$area)) {
    return(.empty_example_distance())
  }

  grid <- expand.grid(
    origin = areas,
    destination = areas,
    stringsAsFactors = FALSE
  ) |>
    tibble::as_tibble()

  if (!include_self_flows) {
    grid <- grid |>
      dplyr::filter(.data$origin != .data$destination)
  }

  origin_coords <- centroids |>
    dplyr::transmute(
      origin = .data$area,
      origin_longitude = .data$longitude,
      origin_latitude = .data$latitude,
      origin_easting = .data$easting,
      origin_northing = .data$northing
    )
  destination_coords <- centroids |>
    dplyr::transmute(
      destination = .data$area,
      destination_longitude = .data$longitude,
      destination_latitude = .data$latitude,
      destination_easting = .data$easting,
      destination_northing = .data$northing
    )

  out <- grid |>
    dplyr::left_join(origin_coords, by = "origin") |>
    dplyr::left_join(destination_coords, by = "destination")

  can_use_lon_lat <- all(is.finite(out$origin_longitude)) &&
    all(is.finite(out$origin_latitude)) &&
    all(is.finite(out$destination_longitude)) &&
    all(is.finite(out$destination_latitude))
  can_use_bng <- all(is.finite(out$origin_easting)) &&
    all(is.finite(out$origin_northing)) &&
    all(is.finite(out$destination_easting)) &&
    all(is.finite(out$destination_northing))

  if (can_use_lon_lat) {
    distance_km <- .haversine_km(
      lon1 = out$origin_longitude,
      lat1 = out$origin_latitude,
      lon2 = out$destination_longitude,
      lat2 = out$destination_latitude
    )
  } else if (can_use_bng) {
    distance_km <- sqrt(
      (out$destination_easting - out$origin_easting)^2 +
        (out$destination_northing - out$origin_northing)^2
    ) / 1000
  } else {
    return(.empty_example_distance())
  }

  out |>
    dplyr::transmute(
      .data$origin,
      .data$destination,
      distance_km = distance_km,
      distance_source = distance_source
    ) |>
    dplyr::filter(is.finite(.data$distance_km), .data$distance_km >= 0) |>
    dplyr::arrange(.data$origin, .data$destination) |>
    tibble::as_tibble()
}

.haversine_km <- function(lon1, lat1, lon2, lat2) {
  radius_km <- 6371.0088
  to_radians <- pi / 180
  lon1 <- lon1 * to_radians
  lat1 <- lat1 * to_radians
  lon2 <- lon2 * to_radians
  lat2 <- lat2 * to_radians

  delta_lon <- lon2 - lon1
  delta_lat <- lat2 - lat1
  a <- sin(delta_lat / 2)^2 +
    cos(lat1) * cos(lat2) * sin(delta_lon / 2)^2
  2 * radius_km * asin(pmin(1, sqrt(a)))
}

.load_example_source <- function(path,
                                 object_names,
                                 file_names,
                                 data_package,
                                 label) {
  if (!is.null(path)) {
    if (!file.exists(path)) {
      stop("`", label, "` path does not exist: ", path)
    }
    return(.read_example_csv(path))
  }

  if (requireNamespace(data_package, quietly = TRUE)) {
    obj <- .load_example_object(object_names, data_package)
    if (!is.null(obj)) {
      return(obj)
    }

    file_path <- .find_example_file(file_names, data_package)
    if (!is.null(file_path)) {
      return(.read_example_csv(file_path))
    }
  }

  env_dirs <- Sys.getenv(
    c("DEBIASRDATA_EXTDATA", "DEBIASRDATA_PATH", "DEBIASR_DATA_DIR"),
    unset = NA_character_
  )
  env_dirs <- env_dirs[!is.na(env_dirs) & nzchar(env_dirs)]

  for (root in env_dirs) {
    file_path <- .find_file_in_root(file_names, root)
    if (!is.null(file_path)) {
      return(.read_example_csv(file_path))
    }
  }

  stop(
    label, " could not be found. Install `", data_package, "` or pass an ",
    "explicit file path."
  )
}

.load_example_object <- function(object_names, data_package) {
  env <- new.env(parent = emptyenv())
  for (object_name in object_names) {
    suppressWarnings(
      utils::data(list = object_name, package = data_package, envir = env)
    )
    if (exists(object_name, envir = env, inherits = FALSE)) {
      return(get(object_name, envir = env, inherits = FALSE))
    }
  }
  NULL
}

.find_example_file <- function(file_names, data_package) {
  roots <- c(
    system.file("extdata", package = data_package),
    system.file(package = data_package)
  )
  roots <- roots[nzchar(roots)]

  for (root in roots) {
    file_path <- .find_file_in_root(file_names, root)
    if (!is.null(file_path)) {
      return(file_path)
    }
  }
  NULL
}

.find_file_in_root <- function(file_names, root) {
  for (file_name in file_names) {
    candidates <- c(
      file.path(root, file_name),
      file.path(root, "extdata", file_name),
      file.path(root, "data", file_name)
    )
    candidates <- candidates[file.exists(candidates)]
    if (length(candidates) > 0L) {
      return(candidates[[1]])
    }
  }
  NULL
}

.read_example_csv <- function(path) {
  utils::read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

.normalise_mpd_travel_to_work <- function(df, include_self_flows, geography) {
  origin_col <- .find_col(
    df,
    c(
      "origin",
      "MSOA21CD_home",
      "msoa21cd_home",
      "LAD22CD_home",
      "lad22cd_home",
      "origin_lad",
      "from"
    )
  )
  destination_col <- .find_col(
    df,
    c(
      "destination",
      "MSOA21CD_work",
      "msoa21cd_work",
      "LAD22CD_work",
      "lad22cd_work",
      "destination_lad",
      "to"
    )
  )
  flow_col <- .find_col(df, c("flow", "count", "total_flow"))

  .normalise_od_table(
    df,
    origin_col = origin_col,
    destination_col = destination_col,
    flow_col = flow_col,
    include_self_flows = include_self_flows,
    area_pattern = .example_area_pattern(geography)
  )
}

.normalise_census_travel_to_work <- function(df, include_self_flows, geography) {
  indicator_col <- .find_col(
    df,
    c(
      "Place of work indicator (4 categories) code",
      "place_of_work_indicator_4_categories_code",
      "place_of_work_indicator_code"
    ),
    required = FALSE
  )

  if (!is.null(indicator_col)) {
    indicator <- suppressWarnings(as.integer(df[[indicator_col]]))
    df <- df[indicator == 3L & !is.na(indicator), , drop = FALSE]
  }

  origin_col <- .find_col(
    df,
    c(
      "origin",
      "Lower tier local authorities code",
      "lower_tier_local_authorities_code",
      "Middle layer Super Output Areas code",
      "middle_layer_super_output_areas_code",
      "Area of residence"
    )
  )
  destination_col <- .find_col(
    df,
    c(
      "destination",
      "LTLA of workplace code",
      "ltla_of_workplace_code",
      "MSOA of workplace code",
      "msoa_of_workplace_code",
      "Area of workplace"
    )
  )
  flow_col <- .find_col(
    df,
    c(
      "flow",
      "Count",
      "count",
      "All categories: Method of travel to work"
    )
  )

  .normalise_od_table(
    df,
    origin_col = origin_col,
    destination_col = destination_col,
    flow_col = flow_col,
    include_self_flows = include_self_flows,
    area_pattern = .example_area_pattern(geography)
  )
}

.example_area_pattern <- function(geography) {
  switch(
    geography,
    lad = "^(E0[6789]|W06)[0-9]{6}$",
    msoa = "^[EW][0-9]{8}$",
    "^(E0[6789]|W06)[0-9]{6}$"
  )
}

.normalise_od_table <- function(df,
                                origin_col,
                                destination_col,
                                flow_col,
                                include_self_flows,
                                area_pattern) {
  out <- tibble::tibble(
    origin = as.character(df[[origin_col]]),
    destination = as.character(df[[destination_col]]),
    flow = suppressWarnings(as.numeric(df[[flow_col]]))
  ) |>
    dplyr::filter(
      !is.na(.data$origin),
      !is.na(.data$destination),
      is.finite(.data$flow),
      .data$flow >= 0
    )

  if (!is.null(area_pattern) && nzchar(area_pattern)) {
    out <- out |>
      dplyr::filter(
        grepl(area_pattern, .data$origin),
        grepl(area_pattern, .data$destination)
      )
  }

  if (!include_self_flows) {
    out <- out |>
      dplyr::filter(.data$origin != .data$destination)
  }

  out |>
    dplyr::group_by(.data$origin, .data$destination) |>
    dplyr::summarise(flow = sum(.data$flow, na.rm = TRUE), .groups = "drop") |>
    dplyr::filter(.data$flow > 0) |>
    tibble::as_tibble()
}

.find_col <- function(df, candidates, required = TRUE) {
  clean_names <- .clean_colnames(names(df))
  clean_candidates <- .clean_colnames(candidates)

  idx <- match(clean_candidates, clean_names)
  idx <- idx[!is.na(idx)]

  if (length(idx) > 0L) {
    return(names(df)[idx[[1]]])
  }

  if (required) {
    stop(
      "Could not find any of these columns: ",
      paste(candidates, collapse = ", ")
    )
  }

  NULL
}

.clean_colnames <- function(x) {
  x <- tolower(as.character(x))
  gsub("[^a-z0-9]+", "_", x)
}

.build_example_coverage <- function(mpd_od, benchmark_od) {
  source_value <- if ("mpd_source" %in% names(mpd_od) && nrow(mpd_od) > 0L) {
    mpd_od$mpd_source[[1]]
  } else {
    "locomizer_travel_to_work"
  }

  mpd_origin <- mpd_od |>
    dplyr::group_by(.data$origin) |>
    dplyr::summarise(user_count = sum(.data$flow, na.rm = TRUE), .groups = "drop")

  census_origin <- benchmark_od |>
    dplyr::group_by(.data$origin) |>
    dplyr::summarise(population = sum(.data$flow, na.rm = TRUE), .groups = "drop")

  dplyr::inner_join(census_origin, mpd_origin, by = "origin") |>
    dplyr::filter(.data$population > 0, .data$user_count > 0) |>
    dplyr::mutate(
      destination = .data$origin,
      mpd_source = source_value
    ) |>
    dplyr::select(
      .data$origin,
      .data$destination,
      .data$population,
      .data$user_count,
      .data$mpd_source
    ) |>
    dplyr::arrange(.data$origin) |>
    tibble::as_tibble()
}

.build_example_covariates <- function(mpd_od, benchmark_od, coverage) {
  mpd_inflow <- mpd_od |>
    dplyr::group_by(area = .data$destination) |>
    dplyr::summarise(mpd_inflow = sum(.data$flow, na.rm = TRUE), .groups = "drop")

  census_inflow <- benchmark_od |>
    dplyr::group_by(area = .data$destination) |>
    dplyr::summarise(census_inflow = sum(.data$flow, na.rm = TRUE), .groups = "drop")

  coverage |>
    dplyr::transmute(
      area = .data$origin,
      population = .data$population,
      mpd_outflow = .data$user_count,
      census_outflow = .data$population,
      coverage_score = .data$user_count / .data$population
    ) |>
    dplyr::left_join(mpd_inflow, by = "area") |>
    dplyr::left_join(census_inflow, by = "area") |>
    dplyr::mutate(
      mpd_inflow = dplyr::coalesce(.data$mpd_inflow, 0),
      census_inflow = dplyr::coalesce(.data$census_inflow, 0),
      income_norm = .normalise01(.data$census_inflow)
    ) |>
    dplyr::arrange(.data$area) |>
    tibble::as_tibble()
}

.normalise01 <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- NA_real_
  if (!any(is.finite(x))) {
    return(rep(NA_real_, length(x)))
  }
  xmin <- min(x, na.rm = TRUE)
  xmax <- max(x, na.rm = TRUE)
  if (xmax <= xmin) {
    return(rep(1, length(x)))
  }
  (x - xmin) / (xmax - xmin)
}
