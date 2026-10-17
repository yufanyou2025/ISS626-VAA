# In-class Exercise 7 — run in RStudio

This page follows the [In-class Exercise 7 accessibility slides](https://isss626-ay2026-27aug.netlify.app/in-class_ex/in-class_ex07/in-class_ex07-accessibility#/title-slide). It reuses the verified `Hands-on Exercise 7.zip` from the earlier hands-on exercise. The raw archive and extracted data stay local because the workbook describes course-prepared material with restricted reuse. The public repository includes source code, summary outputs and rendered figures, but not raw shapefiles or OD records.

Open the ISS626-VAA project in RStudio. Put `Hands-on Exercise 7.zip` on the Windows Desktop or set `HANDSON_EX07_ZIP` to its absolute path. From the project root, install the required packages and run the script:

```r
install.packages(c("sf", "dplyr", "readr", "tidyr", "digest", "ggplot2",
                   "tmap", "scales", "knitr", "accessibility", "remotes"))
remotes::install_github("uva-bi-sdad/catchment@b96fb58adcd0e476cbb634aeb6ce27981fbc1dc3")
source("In-class_Ex/In-class_Ex07/analysis.R", encoding = "UTF-8")
```

The analysis sources `Hands-on_Ex/Hands-on_Ex07/prepare.R`, which validates the input archive and OD matrix, assigns the already-metre SVY21 coordinates to EPSG:3414, and repairs invalid subzone polygons. It checks that the `accessibility` nearest-centre result matches the independent row minima of the OD matrix. It then calculates five `catchment` ratios, six maps, a common-percentile comparison, regional distributions and summary tables. Render `In-class_Ex/In-class_Ex07/In-class_Ex07.qmd` with Quarto to rebuild the page. The analysis was run with `catchment` GitHub commit `b96fb58adcd0e476cbb634aeb6ce27981fbc1dc3` and `accessibility` 1.5.0; see `outputs/session-info.txt` for other versions.

Four methods use a five-kilometre outer bound. The Gaussian method uses `scale = 2` km without a hard bound. Distances come from the supplied OD matrix in metres and are converted to kilometres. The shared `outputs/input-manifest.csv` in Hands-on Exercise 7 records the component hashes. This in-class exercise's `outputs/input-and-model-audit.csv` records counts and assumptions. The archive's component vintages are not independently documented, so the maps should not be treated as a current service inventory.
