# Data Redistribution Decision

Last updated: 2026-05-18

## Question

Can the Zenodo resource at <https://doi.org/10.5281/zenodo.13327082> be redistributed inside `debiasR`, and is that sensible for CRAN?

## Source Reviewed

Zenodo record:

- Title: "Anonymised human location data for urban mobility research"
- DOI: `10.5281/zenodo.13327082`
- Published: 2024-08-15
- Version: `v1`
- Resource type: dataset
- License: Creative Commons Attribution 4.0 International (`CC BY 4.0`)
- Record URL: <https://zenodo.org/records/13327082>

Files listed by Zenodo:

- `hex_OD_allactivity.csv.gz`, 166.3 MB
- `msoa_OD_allactivity.csv.gz`, 13.2 MB
- `msoa_OD_travel2work.csv.gz`, 1.5 MB
- `trajectory_GLA_sample5000.csv.gz`, 6.9 MB

Local file metadata for the candidate asset:

- `msoa_OD_travel2work.csv.gz` compressed size: 1,544,665 bytes
- uncompressed CSV size from `gzip -l`: 20,064,481 bytes

## License Assessment

The Zenodo record is licensed `CC BY 4.0`. The Creative Commons deed permits redistribution and adaptation, including commercial reuse, provided attribution is given, the license is linked, and changes are indicated.

Decision:

- Redistribution appears legally compatible in principle if attribution and license notices are preserved.
- Any redistributed copy must include dataset citation, DOI, license, creator attribution, and a note on whether the packaged copy was modified.
- This is a documentation and packaging obligation, not a blocker.

## CRAN Suitability

Relevant CRAN policy points:

- Packages should be the minimum necessary size.
- As a general rule, neither data nor documentation should exceed 5 MB.
- Large data should be considered for a separate data-only package.
- Source package tarballs should preferably remain under 10 MB.
- Internet resources used in examples/tests should fail gracefully.

Policy reference: <https://cran.r-project.org/web/packages/policies.html>
License reference: <https://creativecommons.org/licenses/by/4.0/>

Decision:

- Do not bundle the full Zenodo record in `debiasR`.
- The full record is about 187.9 MB on Zenodo and is not appropriate for the main package.
- `msoa_OD_travel2work.csv.gz` is small enough compressed to be plausible as an optional packaged data asset, but its uncompressed size and third-party licensing make it cleaner to keep out of the core software package unless there is a strong empirical-example need.

## Implemented Package Strategy

Current strategy:

- Keep `debiasR` small.
- Continue shipping simulated/tiny fixtures in the main package.
- Use the separate optional companion package
  `debiasRdata` (<https://github.com/de-bias/debiasRdata>) for empirical MSOA
  travel-to-work workflows.
- Keep `debiasRdata` in `Suggests`, not `Imports`, so examples and checks can
  fail gracefully when the data package is absent.

Implemented optional data package:

- Package name: `debiasRdata`.
- Repository: <https://github.com/de-bias/debiasRdata>.
- License: `CC BY 4.0 + file LICENSE`.
- Included empirical assets:
  - `msoa_OD_travel2work`
  - `census_msoa_OD_travel2work`
- Compressed normalised CSV files are also installed under `inst/extdata` in
  `debiasRdata`.
- Attribution, DOI, license, checksum, row-count, and source-version metadata
  are recorded in `debiasRdata`.
- Keep `debiasR` licensed `MIT + file LICENSE`.
- Use `requireNamespace("debiasRdata", quietly = TRUE)` in examples/tests/vignettes.
- Access installed data objects or files from `debiasRdata`.
- Skip empirical tests/vignettes gracefully when `debiasRdata` is unavailable.

Remaining data gap:

- `msoa_OD_distance` is not available yet.
- Empirical Bayesian rendering in `debiasR` remains gated until `debiasRdata`
  supplies a real MSOA OD distance table.

## Decision

`debiasR` should not redistribute the full Zenodo resource.

The separate optional `debiasRdata` package now implements the empirical data
route. `debiasR` should continue to keep the full Zenodo resource out of the
main package, use `debiasRdata` conditionally for empirical MSOA examples, and
keep all package checks independent of network access.
