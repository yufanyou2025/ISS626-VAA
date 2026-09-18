# Reproduce Hands-on Exercise 3

From the repository root, install R packages and render:

```r
install.packages(c("sf","dplyr","readr","lubridate","spatstat.geom","sparr","stpp","tmap","ggplot2","magick","digest","knitr","rmarkdown"))
```

```powershell
Rscript Hands-on_Ex/Hands-on_Ex03/analysis.R
quarto render Hands-on_Ex/Hands-on_Ex03/Hands-on_Ex03.qmd
```

The first run downloads the original 2023 NASA MODIS Indonesia CSV and a pinned mirror of the Indonesia Geospatial province boundary. `outputs/data-manifest.csv` records URLs and checksums; a changed download fails validation rather than silently changing the study. The main-island selection reproduces the workbook's 297 subdistricts and 741 detections, not the full province.

The expensive densities, bootstrap bandwidth and K estimate are cached locally. Cache keys include input checksums, preparation-script content, the individual calculation expression and package versions. Rendering in a fresh R session uses valid caches; deleting only this exercise's `cache` directory forces recomputation. Cache and raw data are not published. Figures, numeric outputs and R session information are versioned.

The page documents the corrected time window, coastal approximation for K edge weights, density units, and the distinction between homogeneous and intensity-adjusted K. `plotK` opens its own graphics device; the analysis supplies a PNG device for reproducible export.

To refresh navigation on existing pages without recomputing archived Take-home analyses, render `index.qmd` and run `node scripts/sync-rendered-navigation.mjs`.
