# Take-home Exercise 1 — Greater Bangkok road fatalities

The project analyses geocoded fatality records in the six-province Greater Bangkok area during January–September 2024. A focused central Bangkok road-network analysis follows Chapter 7 of *R for Geospatial Data Science and Analytics*.

## Deliverables

- [Technical report source](technical-report.qmd) and [published report](https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex01/technical-report.html).
- [Executive summary source](executive-summary.qmd) and [published slides](https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex01/executive-summary.html).
- [Regional R workflow](analysis.R), [network R workflow](network-analysis.R), [aggregated outputs](outputs/), and [figures](figures/).
- [Pinned OpenStreetMap road snapshot](data/network/README.md) and [road preparation script](prepare-network.R).
- [Source documentation](data/README.md), [source inspection](notes/source-inspection.md), and [input checksums](notes/input-manifest.json).
- [Reader's walkthrough](WORKBOOK.md) and [submission status](SUBMISSION.md).


## Key results

The original file has 12,762 records. After removing 24 exact duplicate rows, 9,498 of 12,738 records lack coordinates. Spatial filtering retains 530 records at 503 unique locations inside the study area.

Bangkok contains 232 of those records. A conditional uniform-location test rejects planar CSR (global Monte Carlo p = 0.005), but intensity-adjusted results are sensitive to bandwidth and influential inverse-intensity weights. The network case study selects an 8 × 8 km square around the regional KDE peak, matches the included records to a 2026 OSM road component, and maps continuous network KDE on lixels. Network K/G curves compare it with uniform placement by road length. Neither analysis estimates road-user risk.

## Reproduce locally

Open the root `ISS626-VAA.Rproj` in RStudio. Commands below run from the repository root.

1. Obtain the inputs using `data/README.md`, or run the download script:
   `./Take-home_Ex/Take-home_Ex01/download-inputs.ps1`.
2. Install the packages listed in `outputs/package-versions.csv`, including `spNetwork`, `igraph`, `leaflet` and `htmlwidgets`, plus `knitr` and `rmarkdown` for Quarto. R 4.6.1 and Quarto 1.10.18 were used. The recorded versions describe the verified environment; future package versions may differ.
3. Run `./Take-home_Ex/Take-home_Ex01/render.ps1` on Windows. It renders the report (which executes the analysis), the slides, and the home page.
4. Alternatively render the two QMD files with Quarto from the project root. The report sources `analysis.R` and `network-analysis.R` in sequence; the slides consume their saved results. The committed road file is ready to use. To rebuild it from the pinned OSM JSON, run `Rscript Take-home_Ex/Take-home_Ex01/prepare-network.R` before rendering.
5. Run `python Take-home_Ex/Take-home_Ex01/check_submission.py` to check structural requirements, interpretation word limits, local links, and input exclusion.

The scripts verify input SHA-256 hashes before analysis. They stop on missing or changed inputs and on failed assertions. The planar simulation seed is 20260910; the network simulation seed is 20260926. Aggregated figures and tables are regenerated; the original Kaggle file and OSM snapshot are not rewritten.

The report runs the regional and network scripts once. Folded code blocks show the same R code, organised by stage, without executing it twice. Slides consume the report's outputs; they must be rendered after the report. The network step is slower because it includes continuous network KDE, a depth check, and 39 road-uniform simulations.

## Publishing

The existing repository tracks rendered `_site` files and has a GitHub-triggered Vercel production deployment. Publish those rendered outputs alongside source changes. Verify the public pages after deployment; see `SUBMISSION.md`.

Raw and intermediate individual-level fatality datasets are ignored by Git and excluded from Quarto resources. The committed OSM road snapshot and its derived lines are public under ODbL with attribution; they contain no fatality records. Public figures and output tables contain aggregated or statistical results. The Kaggle licence is not treated as permission to redistribute its raw records.

