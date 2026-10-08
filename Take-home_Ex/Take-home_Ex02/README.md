# Take-home Exercise 2 — Myanmar conflict geography

Study window: **1 January 2021–30 September 2025**. Geography: **MIMU v9.4 townships**. Due: **25 October 2026, 11:59 pm Singapore time**.

## Current progress

The analytical sample contains 53,899 reported events and 89,005 reported fatalities, with complete 57-month and 19-quarter cubes. Local Moran, Gi*, quarterly EHSA, dependence/precision checks and a spatial redistribution scan are implemented. The HTML report and reveal.js summary are rendered locally. Public map publication awaits clarification of the MIMU online-use restriction; see [submission status](SUBMISSION.md).

- [Specification and methodological decisions](notes/brief-and-design.md)
- [Input instructions and restrictions](data/README.md)
- [Shared parameters](config.R)
- [Executable boundary validation](prepare-boundaries.R)
- [Boundary checks](outputs/boundary-audit.csv)
- [Township neighbour checks](outputs/township-neighbour-audit.csv)
- [Pinned input hashes](outputs/boundary-manifest.csv)
- [Technical report source](technical-report.qmd)
- [Executive summary source](executive-summary.qmd)
- [Statistical results](outputs/)

## Run the completed preparation step

Open `ISS626-VAA.Rproj` and run from the project root:

```r
# Install once if needed:
# install.packages(c("sf", "spdep", "dplyr", "readr", "digest"))
source("Take-home_Ex/Take-home_Ex02/prepare-boundaries.R", encoding = "UTF-8")
```

The script stops if the downloaded content differs from the validated snapshot. Boundary inputs remain in ignored local directories. The outputs contain audit information and names, not geometry or conflict records.

## Reproduce the complete project

1. Obtain the original eLearn CSV using `data/README.md`. Its SHA-256 hash is checked before analysis. Boundary contents are also pinned, and are downloaded if absent.
2. Install `sf`, `sfdep`, `spdep`, `dplyr`, `tidyr`, `readr`, `ggplot2`, `Kendall`, `digest`, `jsonlite`, `scales`, `knitr` and `rmarkdown`. Verified package versions are recorded in `outputs/package-versions.csv`.
3. Run `./Take-home_Ex/Take-home_Ex02/render.ps1` from the project root on Windows. The normal report render executes the complete workflow. The slides consume its output. R 4.6.1 and Quarto 1.10.18 were used.
4. Run `Rscript Take-home_Ex/Take-home_Ex02/verify.R` and `python Take-home_Ex/Take-home_Ex02/check_submission.py`. The optional `check-browser.mjs` uses Playwright/Chrome for browser, slide and mobile checks.

There are 999 simulations per test, a one-quarter temporal neighbourhood, seed 6262026 for local/EHSA/trend checks and seed 6262126 for the scan. Spatial inference excludes three isolated townships while keeping their descriptive counts. Gi* uses an explicit space-time graph and a fixed all-bin reference; it does not silently inherit the classroom package's different standardisation.

The report has nine principal visuals, all with concise interpretations. The deck has 12 slides in total: cover, contents and 10 content slides. Static maps contain no downloadable boundary geometry. The raw ACLED file, boundaries and event-level intermediates are not included in Git or the submission ZIP.

## Remaining external steps

Confirm the MIMU publication scope, publish and verify the report/slides and coursework navigation, then provide the required URLs through eLearn. No external submission is claimed.

Progress commits record actual completed work with normal timestamps.
