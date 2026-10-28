# In-class Exercise 8 — reproduce in RStudio

This project uses the course-provided `Hands-on_Ex08.zip` (received 28 October 2026) to reproduce the Chapter 18 Huff-model workflow. The raw ZIP is not committed or served publicly; its redistribution terms and the vintage of the store-sales observations were not supplied. The rendered figures, audit tables, code and a SHA-256 input manifest are committed.

From the repository root in RStudio:

1. Put `Hands-on_Ex08.zip` on the Windows Desktop, or set `INCLASS_EX08_ZIP` to its full path: `Sys.setenv(INCLASS_EX08_ZIP = "C:/path/to/Hands-on_Ex08.zip")`.
2. Install the required packages once: `install.packages(c("sf", "dplyr", "readr", "tidyr", "tmap", "ggplot2", "scales", "MCI", "digest", "units", "tibble", "knitr"))`.
3. Run `source("In-class_Ex/In-class_Ex08/analysis.R")`. The script runs `prepare.R`, validates the join keys and coordinate system, calculates all 17,276 village–store interactions, and regenerates the figures and audit outputs.
4. Run `quarto::quarto_render("In-class_Ex/In-class_Ex08/In-class_Ex08.qmd")` from the repository root to refresh the page.

The script expects the archive structure `data/aspatial/{pop2019.csv,Store_sales_data.csv}` and `data/geospatial/{STORES_TC,TOWN_TC,VILLAGE_TC}` with complete shapefile components. `STORES_TC1` and `storeCD.csv` are supplementary archive files, not inputs to this model. The expected shapes are 28 modelled stores, 622 source villages, and 617 villages with matched positive population. If these change, the script stops for review rather than quietly changing the reported analysis.

The original teaching material is [Chapter 18: Retail Trade Area Analysis](https://r4gdsa.netlify.app/chap18). The R implementation uses [MCI's Huff functions](https://search.r-project.org/CRAN/refmans/MCI/html/MCI-package.html). Source data are the supplied ZIP, not a new public download.
