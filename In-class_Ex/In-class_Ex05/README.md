# In-class Exercise 5: reproduction and data provenance

This exercise uses the Hunan county shapefile and the 2005–2021 `Hunan_GDPPC.csv` provided in the [course repository](https://github.com/tskam/ISSS626-AY2026-27Aug/tree/567a99d2dc576cb3b9d46dabea209f55d9fb5fba/In-class_Ex/In-class_Ex05/data). The source is pinned to commit `567a99d2dc576cb3b9d46dabea209f55d9fb5fba`, accessed 3 October 2026. The [source manifest](outputs/source-manifest.csv) records each URL and SHA-256 hash. The raw files are downloaded into ignored `data/`; they are not copied into this repository. The original statistical publisher, boundary vintage and price base are not established by the class CSV.

From the root of the ISS626-VAA RStudio/Quarto project, install missing packages once and run:

```r
install.packages(c("sf", "sfdep", "spdep", "dplyr", "tidyr", "readr",
                   "ggplot2", "tmap", "plotly", "Kendall", "digest", "knitr"))
source("In-class_Ex/In-class_Ex05/analysis.R", encoding = "UTF-8")
```

`prepare.R` downloads and checks the six pinned files, verifies 88 polygons and a complete 88-county × 17-year panel, transforms to EPSG:32650, and aligns every annual row sequence to the polygon order. `analysis.R` rebuilds all tables and PNGs with fixed seeds. Rendering `In-class_Ex05.qmd` executes the full analysis and embeds an interactive Changsha chart. A fresh render needs internet access on the first run to fetch the public class data.

The annual Gi* analysis uses 499 permutations and BH adjustment within each year. The built-in `sfdep` EHSA uses one time lag and 99 simulations, as in the class slide, with the documented inverse-distance spatial weights passed explicitly. The two outputs answer related but non-identical questions; see the page's methodological distinction.
