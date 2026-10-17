# Hands-on Exercise 7 — reproducibility and data provenance

Open the ISS626-VAA project in RStudio. Put the user-supplied `Hands-on Exercise 7.zip` on the Windows Desktop, or set `HANDSON_EX07_ZIP` to its absolute path. From the project root, run:

```r
install.packages(c("sf", "dplyr", "readr", "tidyr", "digest", "SpatialAcc",
                   "ggplot2", "tmap", "scales", "knitr"))
source("Hands-on_Ex/Hands-on_Ex07/analysis.R", encoding = "UTF-8")
```

Alternatively, render `Hands-on_Ex/Hands-on_Ex07/Hands-on_Ex07.qmd` in RStudio/Quarto. The QMD sources the analysis, which sources `prepare.R`. The latter checks the ZIP SHA-256 (`45a5ea7ef0f3e8e9a7b3f33df5d22044eb4f328da5bf8920ba24f1ba8a097181`), extracts required files if needed, verifies every required component, repairs invalid subzones, and aligns the complete OD matrix with the spatial feature IDs. `outputs/input-manifest.csv` lists the component checksums; `outputs/input-audit.csv` and `outputs/session-info.txt` record validation and package versions.

The four inputs in the supplied archive are Master Plan 2014 subzones (`MP14_SUBZONE_NO_SEA_PL`), a hexagon grid, eldercare centre locations (`ELDERCARE`) and `OD_Matrix.csv`. The [Chapter 17 workbook](https://r4gdsa.netlify.app/chap17.html) describes three of the layers as prepared for teaching and research use, with approval needed for other uses. Consequently, the archive and extracted `data/` directory are not in the public repository. Only scripts, aggregate tables and rendered figures are versioned. The archive does not state an independent collection date or publisher for every prepared layer; the input was received on 17 October 2026.

The script fixes demand to 100 for each of 3,125 hexagons and capacity to 100 for each of 120 centres, as in the workbook. Network costs are converted from metres to kilometres. Hansen (`power=0.5`), KD2SFCA (`d0=5`, `power=2`), and SAM (`power=2`) are calculated with `SpatialAcc::ac()`. A ten-kilometre KD2SFCA run is a threshold sensitivity check. Figures are written to `figures/` and summary CSVs to `outputs/`. No random simulation is used. Running the script again regenerates the published results from the same archive; results from a changed archive are intentionally rejected by the checksum test.
