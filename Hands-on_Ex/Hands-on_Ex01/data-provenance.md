# Data provenance

This exercise was prepared on 28 August 2026. Raw downloads are excluded from the repository and can be recreated with `Rscript scripts/download_data.R`.

| Dataset | Use in the exercise | Source |
|---|---|---|
| Master Plan 2014 Subzone Boundary (No Sea) | Planning-subzone polygons | [data.gov.sg](https://data.gov.sg/datasets/d_226cacceceff94f0c8b814962a5307c9/view) |
| Cycling Path Network | Line features for the buffer example | [data.gov.sg](https://data.gov.sg/datasets/d_8f468b25193f64be8a16fa7d8f60f553/view) |
| Pre-Schools Location | Point features for the count and density analysis | [data.gov.sg](https://data.gov.sg/datasets/d_61eefab99958fd70e6aab17320a71f1c/view) |
| Singapore listings | Example aspatial point data | [Inside Airbnb](https://insideairbnb.com/get-the-data/) |
| Singapore residents by planning area/subzone, age, sex and dwelling type, 2011–2020 | Attribute table for the thematic maps | [Singapore Department of Statistics](https://www.singstat.gov.sg/find-data/search-by-theme/population/geographic-distribution/latest-data) |

The current data.gov.sg releases are supplied as GeoJSON rather than the shapefile/KML formats used in the original workbook. The workflow still demonstrates the same `sf` import, projection, overlay, buffer, join, and mapping operations. Results will naturally vary if a source dataset is refreshed.

The historical 2011–2020 CSV has been retired from its former SingStat URL. The download script tries that URL first and then uses an [unmodified public course-data mirror](https://github.com/jesseemmlucas/ISSS608-VAA/blob/master/Hands-on_Ex/Hands-on_Ex08/data/aspatial/respopagesextod2011to2020.csv) if needed.
