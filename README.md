[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

<img src="assets/debias-logo-white.JPEG" alt="debiasR Logo" width="300"/>

# debiasR R Package Repository

Welcome to the **debiasR** repository. This package is part of the **DEBIAS** project, an international research initiative focused on understanding and correcting biases in human mobility data derived from mobile phone records.

The package provides tools to generate correction factors for origin-destination mobility estimates so researchers can work with bias-adjusted mobility data in demographic, policy, and scientific applications.

Current exported functions:

- `measure_bias()`
- `adjust_inverse_penetration()`
- `adjust_selection_rate()`
- `adjust_selection_rate2()`
- `adjust_raking_ratio()`
- `adjust_coefficient()`
- `adjust_multilevel_bayes()`
- `validate_flow_benchmark()`
- `validate_flow_all()`

The package supports inverse penetration weighting, selection-rate models, raking ratio adjustment, coefficient calibration, and a Bayesian multilevel prototype.

---

## 👥 Core Development Team

The core development team consists of **Francisco Rowe** and **Carmen Cabrera** (University of Liverpool).  
We actively maintain and develop the package and warmly invite contributions from the wider research community — including new methods, bug reports, feature requests, and ideas for improvement.

If you’re interested in collaborating or contributing, please join our growing open-source community.

---

## 🚀 Getting Started

1. Install and load the package from this checkout.
2. Explore the documentation in `R/` and `man/`.
3. Try the simulated datasets in `data/` and the walkthroughs in `vignettes/`.

Example datasets packaged with debiasR:

- `simulated_mpd.od`
- `simulated_benchmark.od`
- `simulated_coverage`
- `simulated_covariates`
- `simulated_distance`
- `simulated_active.users`
- `simulated_pop`

The `data-raw/` folder contains the scripts used to build those datasets.

---

## 🛠️ Contributing

We welcome contributions of all kinds: code, documentation, issues, examples, and methodological ideas.
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the current workflow, branch naming guidance, and pull request templates.

---

## 🙋 License

This repository uses a dual-licensing approach:

- **MIT License** for all software code (see [LICENSE](LICENSE))
- **Creative Commons Attribution 4.0 International (CC BY 4.0)** for documentation, data, and non-code content

See the [LICENSE](LICENSE) file for full details.

---

## 🗂️ Repository Structure

- `R/` - package functions and internal helpers
- `data/` - simulated datasets shipped with the package
- `data-raw/` - scripts for rebuilding the simulated datasets
- `man/` - generated documentation for exported objects
- `tests/` - `testthat` tests
- `vignettes/` - walkthroughs and comparison notebooks
- `notes/` - project briefs, migration notes, and status tracking
- `style/` - plotting and Quarto styling helpers
- `.github/` - issue and pull request templates
- `assets/` - logos and other static assets
- `CONTRIBUTING.md` - contribution guidance
- `NEWS.md` - release notes and migration notes
- `LICENSE` - licensing information
- `README.md` - package overview and usage instructions

### Stable vs Prototype

Most of the package is intended for regular use. `adjust_multilevel_bayes()` is still a stage-1 prototype and does not yet implement stage-2 missing-OD imputation. For the current stability summary, see [notes/project-management/STATUS.md](notes/project-management/STATUS.md).

The repository now separates the main deterministic workflow from the Bayesian prototype so that contributors can focus on the stable API first and treat the Bayesian path as experimental until it is fully hardened.

## 🎉 Acknowledging Contributors

We use the [All Contributors Bot](https://allcontributors.org/) to recognise everyone’s work—code, docs, ideas, design and more.  
After your PR is merged, comment on an issue or PR:

```
@all-contributors please add @your-username for code, doc, etc.
```
(Replace `@your-username` and the contribution types as appropriate.)
See the [emoji key](https://allcontributors.org/docs/en/emoji-key) for available contribution types.

Thank you for helping us build open, collaborative and impactful projects with DEBIAS!

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://franciscorowe.com"><img src="https://avatars.githubusercontent.com/u/28450210?v=4?s=100" width="100px;" alt="Francisco Rowe"/><br /><sub><b>Francisco Rowe</b></sub></a><br /><a href="https://github.com/de-bias/debiasR/commits?author=fcorowe" title="Documentation">📖</a> <a href="https://github.com/de-bias/debiasR/commits?author=fcorowe" title="Code">💻</a> <a href="https://github.com/de-bias/debiasR/issues?q=author%3Afcorowe" title="Bug reports">🐛</a> <a href="#content-fcorowe" title="Content">🖋</a> <a href="#design-fcorowe" title="Design">🎨</a> <a href="#example-fcorowe" title="Examples">💡</a> <a href="#ideas-fcorowe" title="Ideas, Planning, & Feedback">🤔</a> <a href="#infra-fcorowe" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-fcorowe" title="Maintenance">🚧</a> <a href="#platform-fcorowe" title="Packaging/porting to new platform">📦</a> <a href="#projectManagement-fcorowe" title="Project Management">📆</a> <a href="#research-fcorowe" title="Research">🔬</a> <a href="https://github.com/de-bias/debiasR/pulls?q=is%3Apr+reviewed-by%3Afcorowe" title="Reviewed Pull Requests">👀</a> <a href="#tool-fcorowe" title="Tools">🔧</a> <a href="https://github.com/de-bias/debiasR/commits?author=fcorowe" title="Tests">⚠️</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->



## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
