# data-raw/build_toy_covariates.R
# Build additional toy covariate dataset for debiasR
# Run manually after data-raw/build_toy_data.R

suppressPackageStartupMessages({
  library(dplyr)
  library(usethis)
})

# Require toy_coverage_df already built and saved in data/
if (!file.exists("data/toy_coverage_df.rda")) {
  stop("toy_coverage_df.rda not found. Run data-raw/build_toy_data.R first.")
}

load("data/toy_coverage_df.rda")  # loads toy_coverage_df into environment

if (!exists("toy_coverage_df")) {
  stop("toy_coverage_df object not found after loading data/toy_coverage_df.rda")
}

# ---------------------------------------------------------------------------
# Base: unique areas (no mpd_source)
# ---------------------------------------------------------------------------

toy_covariates_df <- toy_coverage_df %>%
  distinct(origin) %>%
  arrange(origin) %>%
  mutate(
    # Example external-style income proxy (GNI per capita, arbitrary units)
    gni_pc = 15000 + 2000 * (row_number() - 1L),

    # Normalised income in [0, 1]
    income_norm = gni_pc / max(gni_pc),

    # Additional illustrative covariates
    internet_access = 0.55 + 0.35 * (row_number() - 1L) / max(1L, n() - 1L),
    urbanisation_rate = 0.40 + 0.40 * (row_number() - 1L) / max(1L, n() - 1L),
    ageing_index = 0.8 - 0.3 * (row_number() - 1L) / max(1L, n() - 1L)
  ) %>%
  rename(area = origin) %>%
  select(
    area,
    gni_pc,
    income_norm,
    internet_access,
    urbanisation_rate,
    ageing_index
  )

# ---------------------------------------------------------------------------
# Save toy covariate dataset
# ---------------------------------------------------------------------------

use_data(toy_covariates_df, overwrite = TRUE)
