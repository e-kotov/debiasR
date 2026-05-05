# Coauthor Package Overview

Last updated: 2026-05-05

## Purpose

This note is a quick orientation guide for collaborators who want to understand what `debiasR` currently does, what is stable, and what is still in progress.

## Core Components

### 1. Measure Bias

Purpose:

- compare benchmark population against active-user coverage
- quantify where mobile-phone-derived data appear under- or over-representative

Main functions:

- `measure_bias()`
- `validate_bias_residual_structure()`

Current status:

- implemented
- Stage 3 diagnostics are ready for maintainer review

### 2. Adjust Bias

Purpose:

- transform observed mobile-phone OD flows into adjusted OD-flow estimates using alternative correction strategies

Main deterministic methods:

- `adjust_inverse_penetration()`
- `adjust_selection_rate()`
- `adjust_selection_rate2()`
- `adjust_raking_ratio()`
- `adjust_coefficient()`

Bayesian method:

- `adjust_multilevel_bayes()`

Current status:

- deterministic methods are the main stable path
- Bayesian method is still a stage-1 prototype for observed OD pairs only
- stage-2 missing-OD imputation is not implemented

### 3. Validate Adjusted Flows

Purpose:

- compare adjusted OD flows against benchmark OD flows
- evaluate not only overall fit, but also residual reduction, residual structure, and destination-allocation fidelity

Main functions:

- `validate_flow_overall()`
- `validate_flow_pairs()`
- `validate_flow_residuals()`
- `validate_flow_residual_structure()`
- `validate_flow_distribution()`

Current status:

- implemented
- Stage 2 validation layer is ready for maintainer review

## Current Data Position

Packaged in the main package:

- simulated OD flows
- simulated benchmark flows
- simulated coverage
- simulated covariates
- simulated distance

Empirical data:

- the Zenodo-based empirical data are not bundled in the main package
- the leading option is a separate optional data package, for example `debiasRdata`
- `msoa_OD_travel2work.csv.gz` is the preferred empirical candidate if that route is taken

## What Is Stable Now

- deterministic adjustment methods
- overall validation
- OD-level residual diagnostics
- distributional validation
- measure-bias residual diagnostics

## What Is Still In Progress

- maintainer review of Stage 2 validation outputs
- maintainer review of Stage 3 measure-bias outputs
- decision on whether empirical data should live in a separate `debiasRdata` package
- Stage 4 origin-destination random-effects extension
- Bayesian path hardening and possible stage-2 imputation design

## Suggested Reading Order

1. `README.md`
2. `notes/project-management/STATUS.md`
3. `notes/project-management/TASK_BOARD.md`
4. `notes/project-management/STAGE2_IMPLEMENTATION_REPORT.md`
5. `notes/project-management/STAGE3_IMPLEMENTATION_REPORT.md`

## One-Sentence Summary

`debiasR` is an R package for measuring, adjusting, and validating bias in mobile-phone-derived origin-destination mobility flows, with deterministic methods now usable, richer validation and measure-bias diagnostics implemented, and Bayesian and empirical-data extensions still under active development.
