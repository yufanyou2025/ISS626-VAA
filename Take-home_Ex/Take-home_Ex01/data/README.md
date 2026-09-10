# Source data and acquisition

Accessed on 10 September 2026. Original downloads are stored under `data/raw/` locally and excluded from Git and the website. Raw files remain unchanged; `analysis.R` creates the analytical objects in memory and exports aggregated results. `notes/input-manifest.json` records exact file hashes and sizes.

## Fatality records

- Publisher on Kaggle: Pornsak Kamchan.
- [Dataset page](https://www.kaggle.com/datasets/pornsakkamchan/thailand-road-accident-fatalities-2024).
- Version downloaded: 1; publisher last-updated timestamp: 2025-01-05T16:29:55.41Z.
- [Download endpoint](https://www.kaggle.com/api/v1/datasets/download/pornsakkamchan/thailand-road-accident-fatalities-2024).
- Local archive: `raw/thailand-road-accident-fatalities-2024.zip`.
- Extracted file: `raw/kaggle/thailand_road_accident_fatalities_2024.csv`.
- File inspection: UTF-8 text; 12,762 data rows and 13 columns. This is the input file size, not the final study sample or a verified national death total.
- Publisher description: Thailand, 2024 / B.E. 2567, compiled from three sources by the Department of Disease Control. The primary-source chain and detailed collection definitions still need verification.
- Licence label: “Other (specified in description)”. The retrieved description contains no clear redistribution grant. Do not upload the raw records to GitHub based on that label alone.

To obtain the same inputs, download version 1 from the dataset's version history, preserve the ZIP, and extract the CSV into `raw/kaggle/`. Compare file hashes with the manifest. If only another version is available, record the new version and investigate differences instead of silently replacing the input.

## Administrative boundaries

- [geoBoundaries metadata endpoint](https://www.geoboundaries.org/api/current/gbOpen/THA/ADM1/).
- Boundary ID: `THA-ADM1-36821470`.
- Coverage: Thailand ADM1, 77 units; represented year 2017; build date 12 December 2023.
- Source attribution in metadata: OpenStreetMap, Wambacher.
- Licence in metadata: Open Data Commons Open Database License 1.0; see [OpenStreetMap copyright](https://www.openstreetmap.org/copyright).
- [Pinned GeoJSON download](https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/THA/ADM1/geoBoundaries-THA-ADM1.geojson).
- Local file: `raw/geoBoundaries-THA-ADM1.geojson`.

Download the pinned file to the stated location. Preserve the metadata and attribution. The boundary's represented year is not 2024; evaluate whether that matters for your selected administrative area.

## Metadata and provenance

Metadata snapshots are stored in `../notes/kaggle-metadata.json` and `../notes/geoboundaries-metadata.json`. A checksum establishes which bytes were used; it does not establish the accuracy or completeness of the underlying observations.

Your final report must document its own chosen observation period, preparation decisions, exclusions, spatial extent, source limitations, and reproduction instructions. They are not established by downloading these files.
