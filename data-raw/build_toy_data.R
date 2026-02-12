# data-raw/build_toy_data.R
# Build realistic, squared toy datasets for debiasR.
#
# Input files (must exist):
#   data-raw/active-user-count_data.csv
#       - expected: name, origin_users, destination_users, source_mpd
#   data-raw/benchmark-population_data.csv
#       - expected: lad_code, lad_name, origin_population, destination_population
#   data-raw/od_df_mar2020_feb2021.csv
#       - MPD OD flows with origin, destination, total_flow, source_mpd
#   data-raw/internal-migration-benchmark_data.csv
#       - Benchmark OD flows with lad_name_2020, lad_name_2021, Count
#
# Outputs:
#   toy_mpd_od:        squared OD flows for dominant MPD source over S x S
#   toy_benchmark_od:  squared benchmark OD flows over same S x S
#   toy_coverage_df:   area-level coverage with two time points:
#                      origin, origin_population, origin_user_count,
#                      destination, destination_population,
#                      destination_user_count, mpd_source

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(usethis)
})

# ---------- helpers ----------

std_area <- function(x) {
  x |> as.character() |> str_squish()
}

std_source <- function(x) {
  x <- tolower(str_squish(as.character(x)))
  case_when(
    str_detect(x, "facebook|\\bfb\\b") ~ "facebook",
    str_detect(x, "\\bx\\b|twitter")   ~ "twitter",
    str_detect(x, "multi.?app.?1")     ~ "multiapp1",
    str_detect(x, "multi.?app.?2")     ~ "multiapp2",
    TRUE                               ~ x
  )
}

safe_max <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (!any(is.finite(x))) NA_real_ else max(x, na.rm = TRUE)
}

msg <- function(...) {
  message("[build_toy_data] ", paste0(...))
}

# ---------- paths ----------

active_users_path <- "data-raw/active-user-count_data.csv"
pop_bench_path   <- "data-raw/benchmark-population_data.csv"
mpd_od_path      <- "data-raw/od_df_mar2020_feb2021.csv"
bench_od_path    <- "data-raw/internal-migration-benchmark_data.csv"

stopifnot(
  file.exists(active_users_path),
  file.exists(pop_bench_path),
  file.exists(mpd_od_path),
  file.exists(bench_od_path)
)

# ---------- read ----------

aup_raw   <- read_csv(active_users_path,  show_col_types = FALSE)
pop_raw   <- read_csv(pop_bench_path,    show_col_types = FALSE)
mpd_raw   <- read_csv(mpd_od_path,       show_col_types = FALSE)
bench_raw <- read_csv(bench_od_path,     show_col_types = FALSE)

# =====================================================================
# 1. ACTIVE USERS: area-level, two time points per area
# =====================================================================

if (!all(c("name", "origin_users", "destination_users", "source_mpd") %in% names(aup_raw))) {
  stop(
    "active-user-count_data.csv must contain columns: ",
    "{name, origin_users, destination_users, source_mpd}."
  )
}

users_wide <- aup_raw %>%
  transmute(
    area                   = std_area(.data$name),
    origin_user_count_raw  = suppressWarnings(as.numeric(.data$origin_users)),
    dest_user_count_raw    = suppressWarnings(as.numeric(.data$destination_users)),
    mpd_source             = std_source(.data$source_mpd)
  ) %>%
  group_by(area, mpd_source) %>%
  summarise(
    origin_user_count      = safe_max(origin_user_count_raw),
    destination_user_count = safe_max(dest_user_count_raw),
    .groups = "drop"
  ) %>%
  # keep only areas with valid counts at both times
  filter(
    is.finite(origin_user_count), origin_user_count > 0,
    is.finite(destination_user_count), destination_user_count > 0
  )

# =====================================================================
# 2. POPULATION: area-level, two time points per area
# =====================================================================

if (!all(c("lad_name", "origin_population", "destination_population") %in% names(pop_raw))) {
  stop(
    "benchmark-population_data.csv must contain columns: ",
    "{lad_name, origin_population, destination_population}."
  )
}

pop_wide <- pop_raw %>%
  transmute(
    area                      = std_area(.data$lad_name),
    origin_population_raw     = suppressWarnings(as.numeric(.data$origin_population)),
    dest_population_raw       = suppressWarnings(as.numeric(.data$destination_population))
  ) %>%
  group_by(area) %>%
  summarise(
    origin_population      = safe_max(origin_population_raw),
    destination_population = safe_max(dest_population_raw),
    .groups = "drop"
  ) %>%
  filter(
    is.finite(origin_population), origin_population >= 0,
    is.finite(destination_population), destination_population >= 0
  )

# =====================================================================
# 3. AREA-LEVEL COVERAGE (NOT OD)
# =====================================================================

coverage_area <- users_wide %>%
  inner_join(pop_wide, by = "area") %>%
  transmute(
    origin                   = area,
    origin_population,
    origin_user_count,
    destination              = area,
    destination_population,
    destination_user_count,
    mpd_source
  )

if (nrow(coverage_area) == 0L) {
  stop("No overlapping areas with valid users and populations in coverage.")
}

# =====================================================================
# 4. MPD OD: normalise and pick dominant source
# =====================================================================

if (!all(c("origin", "destination", "total_flow", "source_mpd") %in% names(mpd_raw))) {
  stop(
    "od_df_mar2020_feb2021.csv must contain columns: ",
    "{origin, destination, total_flow, source_mpd}."
  )
}

mpd_norm <- mpd_raw %>%
  transmute(
    origin      = std_area(.data$origin),
    destination = std_area(.data$destination),
    flow        = suppressWarnings(as.numeric(.data$total_flow)),
    mpd_source  = std_source(.data$source_mpd)
  ) %>%
  filter(is.finite(flow), flow >= 0) %>%
  distinct(origin, destination, mpd_source, .keep_all = TRUE)

if (nrow(mpd_norm) == 0L) {
  stop("No valid MPD OD flows after cleaning.")
}

top_source <- mpd_norm %>%
  count(mpd_source, wt = flow, sort = TRUE) %>%
  slice(1) %>%
  pull(mpd_source)

mpd_top <- mpd_norm %>%
  filter(mpd_source == top_source)

# =====================================================================
# 5. BENCHMARK OD: normalise
# =====================================================================

if (!all(c("lad_name_2020", "lad_name_2021", "Count") %in% names(bench_raw))) {
  stop(
    "internal-migration-benchmark_data.csv must contain columns: ",
    "{lad_name_2020, lad_name_2021, Count}."
  )
}

bench_norm <- bench_raw %>%
  transmute(
    origin      = std_area(.data$lad_name_2020),
    destination = std_area(.data$lad_name_2021),
    flow        = suppressWarnings(as.numeric(.data$Count))
  ) %>%
  filter(is.finite(flow), flow >= 0) %>%
  distinct(origin, destination, .keep_all = TRUE)

# =====================================================================
# 6. Select area set S and square the OD matrices
# =====================================================================

K <- 12L

areas_with_cov <- coverage_area %>%
  filter(mpd_source == top_source) %>%
  pull(origin) %>%
  unique()

sel_origins <- mpd_top %>%
  group_by(origin) %>%
  summarise(total_out = sum(flow, na.rm = TRUE), .groups = "drop") %>%
  slice_max(order_by = total_out, n = K, with_ties = FALSE) %>%
  pull(origin)

S <- intersect(sel_origins, areas_with_cov)

if (length(S) < 4L) {
  # fallback: top K areas with coverage that appear in MPD origins
  candidate <- intersect(areas_with_cov, unique(mpd_top$origin))
  S <- candidate[seq_len(min(length(candidate), K))]
}

S <- sort(unique(S))

if (length(S) < 2L) {
  stop("Insufficient areas with consistent coverage and MPD flows to define S.")
}

# Square MPD OD over S x S
toy_mpd_od <- tidyr::crossing(origin = S, destination = S) %>%
  left_join(
    mpd_top %>% select(origin, destination, flow),
    by = c("origin", "destination")
  ) %>%
  mutate(
    mpd_source = top_source,
    flow = replace_na(flow, 0)
  ) %>%
  arrange(origin, destination)

# Square benchmark OD over S x S
toy_benchmark_od <- tidyr::crossing(origin = S, destination = S) %>%
  left_join(
    bench_norm %>% select(origin, destination, flow),
    by = c("origin", "destination")
  ) %>%
  mutate(
    flow = replace_na(flow, 0)
  ) %>%
  arrange(origin, destination)

# Final area-level coverage restricted to S and top_source
toy_coverage_df <- coverage_area %>%
  filter(mpd_source == top_source, origin %in% S) %>%
  distinct(origin, mpd_source, .keep_all = TRUE) %>%
  select(
    origin,
    origin_population,
    origin_user_count,
    destination,
    destination_population,
    destination_user_count,
    mpd_source
  ) %>%
  arrange(origin)

# =====================================================================
# 7. Sanity prints and save
# =====================================================================

msg("Top MPD source used: ", top_source)
msg("Areas in S: ", length(S))
msg("toy_mpd_od rows: ", nrow(toy_mpd_od), " (should be |S|^2)")
msg("toy_benchmark_od rows: ", nrow(toy_benchmark_od), " (should be |S|^2)")
msg("toy_coverage_df rows: ", nrow(toy_coverage_df), " (should be |S|)")
msg("toy_coverage_df columns: ", paste(names(toy_coverage_df), collapse = ", "))

use_data(toy_mpd_od, toy_benchmark_od, toy_coverage_df, overwrite = TRUE)
