# Hands-on Exercises 5A and 5B: Hunan spatial autocorrelation

These pages use the Hunan teaching extract supplied for the earlier spatial-weights exercise: `Hunan.shp` with its sidecars, `Hunan_2012.csv`, and `Dictionary.xlsx`. The CSV is the 2012 cross-section. The supplied archive does not document the original statistical publisher or the date of the boundary geometry, so neither is inferred. Inputs were checked on 26 September 2026. The MD5 values in `outputs/input-checksums.csv` identify the exact files used.

The raw files are not committed to GitHub. On the author's computer they are already in `Hands-on_Ex/Hands-on_Ex04/data/`. To reproduce from a fresh clone, obtain the same supplied ZIP and set `COURSE_DATA_ZIP` to its full path before running the scripts. `prepare.R` extracts only the seven expected files into the ignored `Hands-on_Ex/Hands-on_Ex05/data/` directory, checks their MD5 values against the Exercise 4 manifest, joins on unique `County` keys, validates all 88 polygons and transforms to EPSG:32650 for metric operations. A ZIP with different content fails explicitly instead of silently changing the analysis.

From the repository root, in clean R sessions:

```r
# Install once, if needed:
install.packages(c("sf", "spdep", "sfdep", "tmap", "dplyr",
                   "readr", "ggplot2", "knitr"))

# In separate clean sessions, run:
source("Hands-on_Ex/Hands-on_Ex05/analysis-5a.R", encoding = "UTF-8")
source("Hands-on_Ex/Hands-on_Ex05/analysis-5b.R", encoding = "UTF-8")
```

Then render `Hands-on_Ex05a.qmd` and `Hands-on_Ex05b.qmd` with Quarto. Each page sources its analysis script and regenerates the CSVs and figures. Seeds are fixed in the scripts. Outputs record package versions and the exact test results. The analytical approach follows [Chapter 9](https://r4gdsa.netlify.app/chap09.html) and [Chapter 10](https://r4gdsa.netlify.app/chap10.html) of the course workbook; prose and checks are specific to the supplied extract.
