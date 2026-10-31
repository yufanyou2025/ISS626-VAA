# Hands-on Exercise 9 — reproduce in RStudio

This project follows [Chapter 13 of R for Geospatial Data Science and Analytics](https://r4gdsa.netlify.app/chap13.html) with the supplied Singapore `Hands-on_Ex09.zip`. It is filed under the portal's **In-class Exercise** menu, as requested. The ZIP is kept local because no redistribution permission was supplied. The rendered page, code, audit tables and figures are versioned.

From the repository root in RStudio:

1. Place `Hands-on_Ex09.zip` on the Windows Desktop, or set `INCLASS_EX09_ZIP` to its full path with `Sys.setenv(INCLASS_EX09_ZIP = "C:/path/to/Hands-on_Ex09.zip")`.
2. Install packages once: `install.packages(c("sf", "dplyr", "readr", "tibble", "digest", "GWmodel", "spdep", "ggplot2", "scales", "tmap"))`.
3. Run `source("In-class_Ex/In-class_Ex09/analysis.R")`. This loads `prepare.R`, validates the shapefile/CSV, fits the OLS and GWR models, runs the residual spatial tests, and regenerates the figures and output tables. The first GWR bandwidth searches may take several minutes; later runs use an ignored local cache keyed to the ZIP hash, formula and GWmodel version.
4. Run `quarto::quarto_render("In-class_Ex/In-class_Ex09/In-class_Ex09.qmd")` to regenerate the page.

The archive should contain `data/geospatial/MP14_SUBZONE_WEB_PL` shapefile components and `data/aspatial/Condo_resale_2015.csv`. The input manifest records exact SHA-256 hashes. The condominium dataset represents 2015 resale records; the Master Plan boundary is the 2014 edition. The data's original compiler and field-construction methods are not documented in the supplied archive, so those unknowns are not filled in by assumption.

The OLS and GWR comparison is based on the same 1,436 records, same level-price outcome and same revised predictors. AICc and in-sample error describe fitted models, not independent forecasting performance. The 1.5 km Moran test uses the same row-standardised distance-band weights for OLS and adaptive GWR residuals. Repeated coordinates are retained as separate transactions.
