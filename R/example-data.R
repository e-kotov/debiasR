#' Load empirical travel-to-work example data
#'
#' Loads the MSOA travel-to-work example inputs used by package examples and
#' vignettes. By default, the mobile-phone-derived OD data are read from the
#' optional companion package `debiasRdata`
#' (<https://github.com/de-bias/debiasRdata>) as `msoa_OD_travel2work`. The
#' benchmark OD data are the matching Census 2021 workplace-flow extract
#' `census_msoa_OD_travel2work`, also supplied by `debiasRdata`.
#'
#' Both sources are normalised to the package schema:
#' `origin`, `destination`, and `flow`. The returned coverage table is derived
#' from matched origin totals: Census workplace outflow is used as the benchmark
#' population-like denominator and MPD travel-to-work outflow is used as the
#' active-user numerator for the empirical examples.
#'
#' @param n_areas Number of high-flow overlapping MSOAs to keep for examples.
#'   Use `Inf` or `NULL` to keep all overlapping areas.
#' @param data_package Data package containing the empirical files. Default
#'   `"debiasRdata"`.
#' @param mpd_path Optional explicit path to `msoa_OD_travel2work.csv` or
#'   `.csv.gz`.
#' @param census_path Optional explicit path to the extracted Census 2021
#'   MSOA travel-to-work OD CSV or `.csv.gz`.
#' @param include_self_flows Logical; keep within-MSOA flows. Default `TRUE`.
#' @param complete_grid Logical; if `TRUE`, return MPD and benchmark OD tables
#'   on the same square area grid after area selection. Missing OD pairs are
#'   retained with zero-filled flows and row-status indicators. Default `FALSE`
#'   preserves the observed positive-flow support.
#' @param fill_missing_flow Numeric value used for absent OD pairs when
#'   `complete_grid = TRUE`. Default `0`.
#'
#' @return A named list with normalised OD matrices and derived teaching tables:
#'   `msoa_OD_travel2work` and `mpd_od` for observed MPD flows,
#'   `census_msoa_OD_travel2work` and `benchmark_od` for the Census benchmark,
#'   plus `coverage`, `active_users`, `population`, `covariates`, `distance`,
#'   `od_audit`, and `metadata`.
#'
#' @examplesIf requireNamespace("debiasRdata", quietly = TRUE)
#' ex <- debiasR_example_data(n_areas = 12)
#' names(ex)
#' head(ex$msoa_OD_travel2work)
#' head(ex$census_msoa_OD_travel2work)
#'
#' @export
debiasR_example_data <- function(n_areas = 25,
                                 data_package = "debiasRdata",
                                 mpd_path = NULL,
                                 census_path = NULL,
                                 include_self_flows = TRUE,
                                 complete_grid = FALSE,
                                 fill_missing_flow = 0) {
  complete_grid <- isTRUE(complete_grid)
  if (!is.numeric(fill_missing_flow) ||
      length(fill_missing_flow) != 1L ||
      !is.finite(fill_missing_flow) ||
      fill_missing_flow < 0) {
    stop("`fill_missing_flow` must be a single finite non-negative number.")
  }

  mpd_raw <- .load_example_source(
    path = mpd_path,
    object_names = c("msoa_OD_travel2work", "msoa_od_travel2work"),
    file_names = c("msoa_OD_travel2work.csv.gz", "msoa_OD_travel2work.csv"),
    data_package = data_package,
    label = "MPD travel-to-work OD data"
  )

  census_raw <- .load_example_source(
    path = census_path,
    object_names = c(
      "census_msoa_OD_travel2work",
      "census_msoa_od_travel2work",
      "odwp01ew_msoa_travel2work",
      "ODWP01EW_MSOA"
    ),
    file_names = c(
      "census_msoa_OD_travel2work.csv.gz",
      "census_msoa_OD_travel2work.csv",
      "msoa_census_travel2work.csv.gz",
      "msoa_census_travel2work.csv",
      "ODWP01EW_MSOA_travel2work.csv.gz",
      "ODWP01EW_MSOA_travel2work.csv",
      "ODWP01EW_MSOA.csv.gz",
      "ODWP01EW_MSOA.csv"
    ),
    data_package = data_package,
    label = "Census MSOA travel-to-work benchmark OD data"
  )

  mpd_od <- .normalise_mpd_travel_to_work(mpd_raw, include_self_flows)
  benchmark_od <- .normalise_census_travel_to_work(census_raw, include_self_flows)

  common_areas <- intersect(
    union(mpd_od$origin, mpd_od$destination),
    union(benchmark_od$origin, benchmark_od$destination)
  )

  if (length(common_areas) == 0L) {
    stop("No overlapping MSOA codes were found between MPD and Census OD data.")
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
    dplyr::mutate(mpd_source = "locomizer_travel_to_work") |>
    dplyr::select(.data$origin, .data$destination, .data$mpd_source, .data$flow) |>
    dplyr::arrange(.data$origin, .data$destination)

  benchmark_od <- benchmark_od |>
    dplyr::filter(
      .data$origin %in% selected_areas,
      .data$destination %in% selected_areas
    ) |>
    dplyr::arrange(.data$origin, .data$destination)

  if (nrow(mpd_od) == 0L || nrow(benchmark_od) == 0L) {
    stop("The selected MSOAs do not contain overlapping MPD and Census OD flows.")
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

  covariates <- .build_example_covariates(mpd_od, benchmark_od, coverage)
  distance <- .load_optional_example_distance(
    data_package = data_package,
    areas = final_areas,
    include_self_flows = include_self_flows
  )
  distance_source <- if (nrow(distance) > 0L) {
    distance$distance_source[[1]]
  } else {
    "not_available"
  }

  list(
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
    msoa_OD_travel2work = mpd_od,
    census_msoa_OD_travel2work = benchmark_od,
    metadata = tibble::tibble(
      data_package = data_package,
      mpd_source = "Zenodo 10.5281/zenodo.13327082: msoa_OD_travel2work",
      benchmark_source = "Census 2021 ODWP01EW MSOA workplace flows",
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

.load_optional_example_distance <- function(data_package,
                                            areas,
                                            include_self_flows) {
  if (!requireNamespace(data_package, quietly = TRUE)) {
    return(.empty_example_distance())
  }

  distance_raw <- .load_optional_example_object(
    object_names = c(
      "msoa_OD_distance",
      "msoa_od_distance",
      "msoa_distance",
      "msoa_distance_matrix",
      "distance"
    ),
    data_package = data_package
  )

  if (is.null(distance_raw)) {
    distance_path <- .find_example_file(
      file_names = c(
        "msoa_OD_distance.csv.gz",
        "msoa_OD_distance.csv",
        "msoa_distance.csv.gz",
        "msoa_distance.csv",
        "distance.csv.gz",
        "distance.csv"
      ),
      data_package = data_package
    )
    if (!is.null(distance_path)) {
      distance_raw <- .read_example_csv(distance_path)
    }
  }

  if (is.null(distance_raw)) {
    return(.empty_example_distance())
  }

  .normalise_example_distance(
    distance_raw,
    areas = areas,
    include_self_flows = include_self_flows
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
    c("distance_km", "distance", "dist_km", "distance_m", "dist"),
    required = FALSE
  )

  if (is.null(origin_col) || is.null(destination_col) || is.null(distance_col)) {
    return(.empty_example_distance())
  }

  areas <- sort(unique(as.character(areas)))

  out <- tibble::tibble(
    origin = as.character(df[[origin_col]]),
    destination = as.character(df[[destination_col]]),
    distance_km = suppressWarnings(as.numeric(df[[distance_col]]))
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

.normalise_mpd_travel_to_work <- function(df, include_self_flows) {
  origin_col <- .find_col(df, c("origin", "MSOA21CD_home", "msoa21cd_home"))
  destination_col <- .find_col(df, c("destination", "MSOA21CD_work", "msoa21cd_work"))
  flow_col <- .find_col(df, c("flow", "count", "total_flow"))

  .normalise_od_table(
    df,
    origin_col = origin_col,
    destination_col = destination_col,
    flow_col = flow_col,
    include_self_flows = include_self_flows,
    filter_msoa_codes = TRUE
  )
}

.normalise_census_travel_to_work <- function(df, include_self_flows) {
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
      "Middle layer Super Output Areas code",
      "middle_layer_super_output_areas_code",
      "Area of residence"
    )
  )
  destination_col <- .find_col(
    df,
    c(
      "destination",
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
    filter_msoa_codes = TRUE
  )
}

.normalise_od_table <- function(df,
                                origin_col,
                                destination_col,
                                flow_col,
                                include_self_flows,
                                filter_msoa_codes) {
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

  if (filter_msoa_codes) {
    out <- out |>
      dplyr::filter(
        grepl("^[EW][0-9]{8}$", .data$origin),
        grepl("^[EW][0-9]{8}$", .data$destination)
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
      mpd_source = "locomizer_travel_to_work"
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
