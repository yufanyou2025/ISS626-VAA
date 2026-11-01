# Source and method checks, 1 November 2026

## Scenario scope

The assignment specifies the original 24 JRL stations and the 12 stations of CRL Phase 1. This is a defined scenario rather than a claim that all current expansion projects are included.

- [LTA Jurong Region Line project page](https://www.lta.gov.sg/content/ltagov/en/upcoming_projects/rail_expansion/jurong_region_line.html): Stage 1 comprises JS1-JS8 and JW1-JW2, excluding JS2A, with opening now stated as 2028; Stage 2 JE1-JE7 is stated as 2028; Stage 3 JS9-JS12 and JW3-JW5 as 2029. JS2A is an additional infill station for the mid-2030s. Exclude it from the brief's original 24. The page currently totals 25 stations because it includes that infill.
- [LTA Cross Island Line project page](https://www.lta.gov.sg/content/ltagov/en/upcoming_projects/rail_expansion/cross_island_line.html): Phase 1 is CR2-CR13, 12 stations, targeted for 2030. The six Phase 2 stations and four Punggol Extension stations target 2032 and lie outside the requested scenario.
- Future line platforms at Choa Chu Kang, Boon Lay, Jurong East, Pasir Ris, Hougang, Ang Mo Kio and Bright Hill connect to existing physical stations. Avoid treating them as independent competing stations or duplicating their observed demand. The 36 line-station entries therefore imply 29 new physical station destinations and seven upgraded existing interchanges.
- The January observed baseline precedes some 2026 openings. Any later stations in the September geospatial layer must be identified as outside the calibrated January baseline rather than silently assigned zero observed demand.

## Future coordinate provenance

[Wu Tingfeng's Singapore Train Station Coordinates](https://github.com/elliotwutingfeng/singapore_train_station_coordinates) is explicitly linked by the assignment. Pin commit `9f5972c71db8a529801eee9c527946a45a78e409` (5 March 2026). `future_stations.csv` has `station_code`, `station_name`, `lat`, `lon`, `source`, `comment`. Its [dataset licence](https://github.com/elliotwutingfeng/singapore_train_station_coordinates/blob/9f5972c71db8a529801eee9c527946a45a78e409/LICENSE-DATASET.md) attributes URA data.gov.sg and LTA DataMall under the Singapore Open Data Licence. The repository's Apache licence applies to code, while coordinate data follow the dataset licence.

## Method reference

Zhu, Z., He, Y., Guo, X., Zhang, Y., and Chen, J. (2021). [Improved Huff Model for Estimating Urban Rail Transit Station Catchment Areas considering Station Choices](https://doi.org/10.1155/2021/6374724). *Journal of Advanced Transportation*, 2021, 6374724. Open-access primary article, published 9 March 2021.

The study supports probabilistic station choice with overlapping catchments and station attractiveness, rather than proximity alone. Its Xi'an application adds walking, cycling and feeder-bus access and uses local facility/service measures. This exercise can borrow that modelling logic, but should calibrate its own Singapore parameters and describe straight-line distance and available attraction variables as proxies. It does not replicate the paper's full multimodal travel-time model or inherit its numeric parameter choices.

## HDB market potential

[HDB Property Information](https://data.gov.sg/datasets/d_17f5382f26140b1fdae0ba2ef6239d2f/view) includes `blk_no`, `street`, `residential`, `total_dwelling_units`, and flags such as `commercial`; its current October 2026 update reports buildings completed through December 2025. [HDB Existing Building](https://data.gov.sg/datasets/d_16b157c52ed637edd6ba1232e026258d/view) supplies geographic footprints. Both are available under the Singapore Open Data Licence. Dwellings measure housing stock, not residents or trips. Their use as local market potential requires an explicit generation/normalisation assumption and excludes non-HDB homes unless supplemented.
