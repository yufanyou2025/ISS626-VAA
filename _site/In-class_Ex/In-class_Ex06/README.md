# In-class Exercise 6: reproducibility

This project extends the Chapter 11 Hunan EHSA workflow by comparing Queen and rook contiguity. It reuses the public 2005–2021 Hunan GDPPC CSV and 88-county shapefile from In-class Exercise 5. The source is pinned to course-repository commit `567a99d2dc576cb3b9d46dabea209f55d9fb5fba`; exact file URLs, SHA-256 hashes and the 3 October 2026 access date are in [`../In-class_Ex05/outputs/source-manifest.csv`](../In-class_Ex05/outputs/source-manifest.csv). Raw data are downloaded on first use to an ignored directory and are not copied to the published site.

Open the ISS626-VAA project in RStudio, install missing packages once, and run from the project root:

```r
install.packages(c("sf", "sfdep", "spdep", "dplyr", "tidyr", "readr",
                   "ggplot2", "tmap", "plotly", "Kendall", "digest", "knitr"))
source("In-class_Ex/In-class_Ex06/analysis.R", encoding = "UTF-8")
```

`analysis.R` sources the validated preparation code from Exercise 5, constructs both cubes, runs fixed-seed annual Gi* and EHSA calculations, and regenerates the CSV tables and PNG figures. Render `In-class_Ex06.qmd` to rebuild the page and interactive Changsha chart. EPSG:32650 supplies metre coordinates for the inverse-distance calculation. The annual Gi* tests use 499 simulations and BH adjustment within each year; EHSA uses the chapter's `k = 1`, 99 simulations and 0.01 class threshold. BH on county Mann–Kendall trend p-values is reported separately. The implementation does not claim that `sfdep` applies FDR to every EHSA space-time bin.
