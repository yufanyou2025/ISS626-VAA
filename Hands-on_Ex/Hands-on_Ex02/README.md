# Reproducing Hands-on Exercises 2A and 2B

Run from the repository root with R and Quarto installed:

```r
install.packages(c("sf", "spatstat", "terra", "tmap", "tidyverse", "jsonlite", "knitr", "rmarkdown"))
```

```powershell
quarto render Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02a.qmd
quarto render Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02b.qmd
```

Each page executes its analysis in a fresh render session. `prepare.R` downloads the two original GeoJSON files from the public data.gov.sg poll-download API if absent, checks they are readable, repairs polygon geometries and applies the chapter exclusions. Raw files and simulation caches are ignored by Git. Retain the downloaded files to repeat the exact snapshot; public sources may change. The manifest records the original download's checksum and dates. Compare checksums when re-downloading; do not silently treat an updated download as the same snapshot.

You may also run `Rscript Hands-on_Ex/Hands-on_Ex02/analysis-2a.R` and `Rscript Hands-on_Ex/Hands-on_Ex02/analysis-2b.R` independently. Seeds and simulation counts are specified in those scripts. Tables, curves and session versions are in `outputs/`; downloadable PNG figures are in `figures/`.

The pages follow workbook Chapters 4 and 5 (https://r4gdsa.netlify.app/chap04.html and https://r4gdsa.netlify.app/chap05.html). They use current package syntax, preserve metre coordinates for projected rasters, centre K by pi*r^2, and distinguish pointwise simulation envelopes from global tests.

For a site update, render `index.qmd` and `about.qmd`, then run `node scripts/sync-rendered-navigation.mjs`. This refreshes navigation on archived pages without rerunning the Take-home report (its original raw inputs are deliberately not versioned). `node scripts/verify-exercise02.mjs` checks both new pages and their local links, and confirms that existing Take-home report bodies match HEAD apart from the shared header. Run this verification before committing.
