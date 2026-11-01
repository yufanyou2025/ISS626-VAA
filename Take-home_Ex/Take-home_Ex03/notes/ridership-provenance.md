# Observed ridership: January 2026

The observed input is LTA's Passenger Volume by Train Stations, an hourly table split between `WEEKDAY` and `WEEKENDS/HOLIDAY`. This exercise retrieved a public archived copy on 1 November 2026 because LTA's current authenticated endpoint exposes only the latest three months. It is not a new download of January data from LTA. The older reference month is a limitation, particularly for recently opened stations and new housing.

- Publisher: [Land Transport Authority DataMall](https://datamall.lta.gov.sg/content/datamall/en/dynamic-data.html).
- Archive: [tiredbeaver/busy-island, pinned file](https://github.com/tiredbeaver/busy-island/blob/c13cb5943fea4a0118fc6b5b65a9eb923961e31f/data/transport_node_train_202601.csv).
- Retrieval URL: `https://raw.githubusercontent.com/tiredbeaver/busy-island/c13cb5943fea4a0118fc6b5b65a9eb923961e31f/data/transport_node_train_202601.csv`.
- Archive commit: `c13cb5943fea4a0118fc6b5b65a9eb923961e31f`, 31 March 2026. GitHub file history shows the CSV first committed on 21 February 2026 at `b0a9577631f04eb48664214f1e73985e8eaccca5`.
- SHA-256: `dedecc5f36b35583789b0fab24a7b02b0c3ec45c5e96b23e09b7d54656a841fa`.
- File size: 325,165 bytes. No other code, narrative or analysis from the archive is used.

## Interpretation and checks

The [official LTA API User Guide v6.11, 30 October 2026](https://datamall.lta.gov.sg/content/dam/datamall/datasets/LTA_DataMall_API_User_Guide.pdf), Annex A, printed page 59, defines the record as a total across **all days of the given day type in the month**, for the stated hour. The values are monthly totals, not a typical weekday mean. Summing the hours and the two day types gives the monthly count. Dividing by 31 gives January's calendar-day mean. Tap-ins measure entries to the rail system; they are not unique people, platform occupancy or on-train passenger loads. Tap-ins and tap-outs are separate quantities and are not added together to represent passengers.

The downloaded schema matches Annex A. It contains 7,259 records, 182 unique source station codes, and no repeated month/day-type/hour/station key. Required cells are complete and volumes are nonnegative integers. Stevens is recorded separately as DT10 and TE11. These two source series are added together as `DT10/TE11`, giving **181 physical access sites** without changing the total. This follows the spatial crosswalk rather than assuming every raw code is a distinct station. The output retains the source-code list and count for each physical destination.

Monthly totals are 88,683,630 tap-ins and 88,390,800 tap-outs, a difference of 292,830 (0.33% of tap-ins); the two totals are kept separate. The weekday and weekend/holiday tap-in totals are 64,945,301 and 23,738,329. The weekday 06:00-09:59 subtotal is 18,549,493. The morning target is this subtotal divided by 21 non-holiday weekdays; it is closer to residential access demand than all-day station entries, although it still includes trips from private homes and other origins.

January 2026 contains 22 Monday-Friday dates. New Year's Day (Thursday, 1 January) is the only January public holiday in the [official MOM 2026 public-holiday list](https://www.mom.gov.sg/newsroom/press-releases/2025/0616-public-holidays-for-2026), giving 21 non-holiday weekdays. The script stores this denominator explicitly and uses 31 days for the separate all-day diagnostic. The morning window includes hours 6, 7, 8 and 9, i.e. 06:00 through 09:59, rather than ending at 09:00.

There are 21 unlisted source-station/day-type/hour combinations within the 20 network-wide observed hours (00:00 and 05:00-23:00); 12 source station codes have fewer than 40 rows. The script preserves published totals and does not invent missing hourly records. Most incomplete hourly coverage occurs on Bukit Panjang LRT. Aggregated station codes may include several lines, using `/` in this file; matching must split codes or explicitly map them to physical stations. Observed station codes and the checked physical-station crosswalk, rather than a present-day station count, define the January baseline.

The hash freezes the archived file and detects later changes. It does not independently certify the archive against an LTA-signed original, and this provenance limitation should remain visible in the report.

## Attribution and redistribution

Contains information from Passenger Volume by Train Stations (January 2026), published by the Land Transport Authority and accessed on 1 November 2026 via the public archive above, made available under the [Singapore Open Data Licence version 1.0](https://datamall.lta.gov.sg/content/datamall/en/SingaporeOpenDataLicence.html). No official endorsement is implied.

The licence permits copying, distribution and adaptation with attribution. The local raw file is nevertheless excluded from Git and the published website to keep the project small. `prepare-ridership.R` downloads the pinned file automatically when the cache is absent and checks its SHA-256 before use. Published station aggregates and their manifest retain the source and licence link.
