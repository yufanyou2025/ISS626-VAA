# Take-home Exercise 3 — Singapore rail station catchments

The assignment investigates station-level demand and catchment redistribution after adding the specified Jurong Region Line and Cross Island Line phase 1 stations.

The brief, required outputs and decisions are recorded in [notes/brief-and-design.md](notes/brief-and-design.md). The outcome is mean non-holiday weekday entries from 06:00 to 09:59 in January 2026. The calibrated network has 181 physical access sites; the defined JRL24 + CRL1 expansion has 210, including 29 new sites and seven existing interchange upgrades.

Inputs are documented in [data/README.md](data/README.md). Raw downloads and intermediate caches stay out of Git and the website. Source code, provenance, model checks, aggregate results and rendered report/slides are versioned at genuine milestones with normal timestamps.

## Run from the Quarto project root

Install R, Quarto and the packages below, then open `ISS626-VAA.Rproj`:

```r
install.packages(c("sf", "dplyr", "tidyr", "readr", "digest", "jsonlite",
                   "ggplot2", "scales", "leaflet", "htmlwidgets", "htmltools",
                   "knitr", "rmarkdown", "MCI"))
source("Take-home_Ex/Take-home_Ex03/analysis.R", encoding = "UTF-8")
source("Take-home_Ex/Take-home_Ex03/visualise.R", encoding = "UTF-8")
```

Or run `./Take-home_Ex/Take-home_Ex03/render.ps1` on Windows. The normal report render runs the complete analysis, checks numerical invariants, renders the slides and home page, and refreshes navigation. The `EX03_REUSE_VERIFIED=1` environment switch skips recomputation only for layout QA after a verified run; it is unnecessary for reproduction. No random sampling is used: optimizer starts, fold boundaries and grid anchors are deterministic.

Missing inputs download automatically from the documented URLs and are checked against frozen hashes. If an upstream official snapshot changes, the script stops with an explanation. The local submission ZIP includes the five licensed raw snapshots at the expected paths, as well as the tracked street bridge and address reference, so its analysis works without source-data downloads. Basemap tiles need internet access. Exact R package versions are in `outputs/package-versions.csv`, with the analysis session in `outputs/session-info.txt`; R and Quarto versions are in `outputs/software-versions.txt`.

## Contents and checks

- `prepare-spatial.R`: HDB address join, geometry checks, station identity and future-scope reconciliation.
- `prepare-ridership.R`: pinned archive download, hourly checks, Stevens merge and morning/day aggregation.
- `methods.R`: stable Huff probabilities, shared-parameter calibration, baselines and error metrics.
- `analysis.R`: full interaction frames, model comparisons, geographic holdouts, expansion and accessibility/sensitivity checks.
- `visualise.R`: report figures, slide variants and an interactive station explorer.
- `technical-report.qmd` and `executive-summary.qmd`: HTML report and revealjs deck.
- `verify.R`, `check_submission.py`, `check-browser.mjs`: numerical, document, browser, mobile and slide checks.
- `package_submission.py`: exact-revision project archive plus hash-checked permitted source snapshots.

Run `Rscript Take-home_Ex/Take-home_Ex03/verify.R`, `python Take-home_Ex/Take-home_Ex03/check_submission.py` and `node Take-home_Ex/Take-home_Ex03/check-browser.mjs` after rendering. Browser QA uses the documented local Playwright installation or `PLAYWRIGHT_PATH`. Set `EX03_BASE_URL=https://iss-626-vaa.vercel.app` for public checks.

## Interpretation and submission

Dwelling units are market-potential weights, not observed household rail trips. The fixed-total scenario describes station-access redistribution; it does not estimate induced travel, train crowding or future operating income. The nearest-station coverage extension uses original building points and straight-line distance rather than verified walking routes. The technical report documents residuals, holdouts and the public ridership archive's verification limit.

See [SUBMISSION.md](SUBMISSION.md) for verified delivery links and package details. eLearn submission remains the student's external step; no upload is claimed. Deadline: **15 November 2026, 11:59 pm Singapore time**.
