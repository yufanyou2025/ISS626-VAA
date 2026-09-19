# Hands-on Exercise 4: Spatial Weights and Applications

Follows Chapter 8: https://r4gdsa.netlify.app/chap08.html.

Inputs are the user-supplied `data（Spatio-Temporal Point Patterns Analysis）.zip`, inspected on 19 September 2026. Despite its filename, the archive contains the Hunan shapefile, `Hunan_2012.csv`, and `Dictionary.xlsx`. No substitute inputs are downloaded. Indicator year: 2012. Boundary vintage and original statistical publisher are not stated in the supplied files; this is not a current-boundary or current-GDP analysis.

The original archive and extracted data remain local. Input checksums and validation results are versioned. Keep the original archive to reproduce:

```r
install.packages(c("sf","spdep","tmap","dplyr","readr","readxl","ggplot2","knitr","rmarkdown"))
Sys.setenv(COURSE_DATA_ZIP="C:/path/to/your/data.zip")
source("Hands-on_Ex/Hands-on_Ex04/prepare.R")
```

Run from the repository root. The preparation script checks unique join keys, complete matches, valid geometry, CRS, GDPPC values and input checksums. It never downloads alternative data.
