# Data Redistribution Decision

Last updated: 2026-04-25

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

## Recommended Package Strategy

Default recommendation:

- Keep `debiasR` small.
- Continue shipping simulated/tiny examples in the main package.
- Document external download of the Zenodo dataset by DOI for empirical workflows.

CRAN-safe optional data package:

- Create a separate data-only package named, for example, `debiasRdata`.
- License the data package as `CC BY 4.0`.
- Include exactly `msoa_OD_travel2work.csv.gz` as the first empirical asset.
- Include attribution, DOI, license, checksum, and source-version metadata.
- Keep `debiasR` licensed `MIT + file LICENSE`.
- Put `debiasRdata` in `Suggests`, not `Imports`.
- Use `requireNamespace("debiasRdata", quietly = TRUE)` in examples/tests/vignettes.
- Access the file with `system.file()` from `debiasRdata`.
- Skip empirical tests/vignettes gracefully when `debiasRdata` is unavailable.

Fallback if the data package is not created:

- Use a tiny packaged example in `debiasR`.
- Provide a documented external download workflow with DOI citation, expected filenames, and checksums.
- Keep all CRAN examples and tests independent of network access.

## Decision

`debiasR` should not redistribute the full Zenodo resource.

If empirical packaged data is needed, use a separate optional `debiasRdata` package containing only `msoa_OD_travel2work.csv.gz`. Otherwise, keep the main package on simulated/tiny data and document the Zenodo DOI as an external data source.
