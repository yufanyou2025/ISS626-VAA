# Take-home Exercise 1 — Greater Bangkok road fatalities

The project contains a complete worked analysis of geocoded fatality records in the six-province Greater Bangkok area during January–September 2024.

## Deliverables

- [Technical report source](technical-report.qmd) and [published report](https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex01/technical-report.html).
- [Executive summary source](executive-summary.qmd) and [published slides](https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex01/executive-summary.html).
- [Complete R workflow](analysis.R), [aggregated outputs](outputs/), and [figures](figures/).
- [Source documentation](data/README.md), [source inspection](notes/source-inspection.md), and [input checksums](notes/input-manifest.json).
- [Reader's walkthrough](WORKBOOK.md) and [submission status](SUBMISSION.md).

The course prohibits submitting generated analytical work as independently completed student work; this package does not satisfy that authorship requirement as written.

## Key results

The original file has 12,762 records. After removing 24 exact duplicate rows, 9,498 of 12,738 records lack coordinates. Spatial filtering retains 530 records at 503 unique locations inside the study area.

Bangkok contains 232 of those records. A conditional uniform-location test rejects CSR (global Monte Carlo p = 0.005), but intensity-adjusted results are sensitive to bandwidth and influential inverse-intensity weights. The conclusion distinguishes observed concentration from unresolved interaction.

## Reproduce locally

Open the root `ISS626-VAA.Rproj` in RStudio. Commands below run from the repository root.

1. Obtain the inputs using `data/README.md`, or run the download script:
   `./Take-home_Ex/Take-home_Ex01/download-inputs.ps1`.
2. Install the packages listed in `outputs/package-versions.csv`, plus `knitr` and `rmarkdown` for Quarto. R 4.6.1 and Quarto 1.10.18 were used. The recorded versions describe the verified environment; future package versions may differ.
3. Run `./Take-home_Ex/Take-home_Ex01/render.ps1` on Windows. It renders the report (which executes the analysis), the slides, and the home page.
4. Alternatively run `Rscript Take-home_Ex/Take-home_Ex01/analysis.R`, then render the two QMD files with Quarto.
5. Run `python Take-home_Ex/Take-home_Ex01/check_submission.py` to check structural requirements, interpretation word limits, local links, and input exclusion.

The script verifies the original files' SHA-256 hashes before analysis. It stops on missing or changed inputs and on failed assertions. Simulation seed 20260910 is fixed. Aggregated figures and tables are regenerated; raw data are never rewritten.

The report runs all calculations once through `source(analysis.R)`. Folded code blocks show that same script, organised by stage, without executing it twice. Slides consume the report's outputs; they must be rendered after the report.

## Publishing

The existing repository tracks rendered `_site` files and has a GitHub-triggered Vercel production deployment. Publish those rendered outputs alongside source changes. Verify the public pages after deployment; see `SUBMISSION.md`.

Raw and intermediate individual-level datasets are ignored by Git and excluded from Quarto resources. The public figures and output tables contain aggregated or statistical results. The Kaggle licence is not treated as permission to redistribute its raw records.

