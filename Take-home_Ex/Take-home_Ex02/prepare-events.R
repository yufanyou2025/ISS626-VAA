# Read the original eLearn input, audit exclusions, then build balanced cubes.
source("Take-home_Ex/Take-home_Ex02/prepare-boundaries.R", encoding = "UTF-8")
suppressPackageStartupMessages(library(tidyr))
raw_path02 <- file.path(ex02, "data/raw/ACLED_Data_Myanmar_Jan2021-Sep2025.csv")
if (!file.exists(raw_path02))
  stop("Download the assignment ACLED CSV from eLearn to ", raw_path02)
raw_hash02 <- digest::digest(raw_path02, algo = "sha256", file = TRUE)
stopifnot(raw_hash02 == "b0e4a044bdfec7883db11a3e8b92922ed6e4aea949b06cdcbcb872b9ebc1db1a")
raw02 <- read_csv(raw_path02, show_col_types = FALSE,
                  col_types = cols(event_date = col_date(), .default = col_guess()))
stopifnot(all(c("event_id_cnty", "event_date", "country", "event_type", "latitude",
                "longitude", "geo_precision", "time_precision", "fatalities",
                "admin1", "admin3") %in% names(raw02)),
          nrow(problems(raw02)) == 0L)
write_csv(tibble(file = basename(raw_path02), sha256 = raw_hash02,
                 accessed = as.character(config02$access_date),
                 source = "ACLED (Armed Conflict Location & Event Data), eLearn assignment file; https://acleddata.com/"),
          file.path(out02, "event-input-manifest.csv"))
input_summary02 <- tibble(
  measure = c("Input rows", "Columns", "Exact duplicate rows", "Duplicate event IDs",
              "Missing event dates", "Missing coordinates", "Missing fatalities",
              "First event date", "Last event date", "Latest record-update timestamp (UTC)"),
  value = as.character(c(nrow(raw02), ncol(raw02), sum(duplicated(raw02)),
                         sum(duplicated(raw02$event_id_cnty)), sum(is.na(raw02$event_date)),
                         sum(!is.finite(raw02$latitude) | !is.finite(raw02$longitude)),
                         sum(is.na(raw02$fatalities)), as.character(min(raw02$event_date)),
                         as.character(max(raw02$event_date)),
                         format(as.POSIXct(max(raw02$timestamp), origin = "1970-01-01", tz = "UTC")))))
write_csv(input_summary02, file.path(out02, "input-summary.csv"))
stopifnot(!anyNA(raw02$event_date), !anyNA(raw02$event_id_cnty))
events02 <- distinct(raw02)
if (anyDuplicated(events02$event_id_cnty))
  stop("Conflicting repeated event IDs require manual review; no automatic latest-record selection.")
audit_events02 <- tibble(stage = "Original rows", retained = nrow(raw02))
audit_stage02 <- function(label) {
  audit_events02 <<- bind_rows(audit_events02, tibble(stage = label, retained = nrow(events02)))
}
audit_stage02("Remove exact duplicate rows")
events02 <- filter(events02, country == "Myanmar")
audit_stage02("Myanmar country records")
events02 <- filter(events02, between(event_date, config02$start, config02$end))
audit_stage02("Study window: 2021-01-01 to 2025-09-30")
write_csv(count(events02, event_type, name = "events"), file.path(out02, "event-type-audit.csv"))
events02 <- filter(events02, event_type %in% config02$event_types)
audit_stage02("Three armed-conflict event types")
write_csv(count(events02, geo_precision, time_precision, name = "events"),
          file.path(out02, "precision-audit.csv"))
swapped02 <- sum(events02$latitude > 90 & events02$longitude < 90, na.rm = TRUE)
if (swapped02 > 0L) stop("Possible latitude/longitude reversal requires source inspection.")
events02 <- filter(events02, is.finite(latitude), is.finite(longitude),
                    between(latitude, -90, 90), between(longitude, -180, 180))
audit_stage02("Finite coordinates within geographic ranges")
stopifnot(swapped02 == 0L, all(events02$fatalities >= 0), !anyNA(events02$fatalities))
events02 <- filter(events02, geo_precision %in% c(1L, 2L))
audit_stage02("Geographic precision 1 or 2")

# Project points into the same CRS. A boundary point can intersect two polygons.
# Use the supplied admin3 label only to resolve one of those existing matches.
points02 <- st_as_sf(events02, coords = c("longitude", "latitude"), crs = 4326,
                     remove = FALSE) |> st_transform(st_crs(townships02))
matches02 <- st_intersects(points02, townships02)
normal02 <- function(x) gsub("[^a-z0-9]", "", tolower(ifelse(is.na(x), "", x)))
assigned02 <- vapply(seq_along(matches02), function(i) {
  z <- matches02[[i]]
  if (length(z) == 1L) return(z)
  if (length(z) > 1L) {
    exact <- z[normal02(townships02$township[z]) == normal02(events02$admin3[i])]
    if (length(exact) == 1L) return(exact)
  }
  NA_integer_
}, integer(1))
join_audit02 <- tibble(
  category = c("One intersecting township", "No intersecting township",
               "Multiple intersecting townships", "Multiple resolved by admin3", "Unresolved multiple matches"),
  events = c(sum(lengths(matches02) == 1), sum(lengths(matches02) == 0),
             sum(lengths(matches02) > 1), sum(lengths(matches02) > 1 & !is.na(assigned02)),
             sum(lengths(matches02) > 1 & is.na(assigned02))))
write_csv(join_audit02, file.path(out02, "spatial-join-audit.csv"))
# Unmatched events are retained privately for inspection; no nearest-polygon snap.
dir.create(file.path(ex02, "data/processed"), recursive = TRUE, showWarnings = FALSE)
saveRDS(events02[is.na(assigned02), ], file.path(ex02, "data/processed/unmatched-events.rds"))
events02$township_id <- townships02$township_id[assigned02]
events02$mapped_township <- townships02$township[assigned02]
events02 <- filter(events02, !is.na(township_id))
audit_stage02("Unique or admin3-resolved township intersection")
events02 <- mutate(events02,
                    month = as.Date(format(event_date, "%Y-%m-01")),
                    quarter = (as.integer(format(event_date, "%Y")) - 2021L) * 4L +
                      (as.integer(format(event_date, "%m")) - 1L) %/% 3L + 1L)
audit_events02 <- audit_events02 |>
  mutate(excluded_at_stage = lag(retained, default = first(retained)) - retained)
write_csv(audit_events02, file.path(out02, "sample-audit.csv"))
write_csv(events02 |>
            summarise(compared = sum(!is.na(admin3)),
                       equal_after_simple_normalisation = sum(normal02(admin3) == normal02(mapped_township)),
                       different_or_missing = sum(normal02(admin3) != normal02(mapped_township))),
          file.path(out02, "admin-label-audit.csv"))
saveRDS(events02, file.path(ex02, "data/processed/events.rds"))

# The full calendar, including zero recorded counts, defines the cube template.
monthly02 <- expand_grid(month = seq(config02$start, as.Date("2025-09-01"), by = "month"),
                         township_id = townships02$township_id) |>
  left_join(events02 |> group_by(month, township_id) |>
              summarise(events = n(), fatalities = sum(fatalities),
                         precise_events = sum(geo_precision == 1L), .groups = "drop"),
            by = c("month", "township_id")) |>
  mutate(across(c(events, fatalities, precise_events), ~replace_na(.x, 0L)))
quarterly02 <- monthly02 |>
  mutate(quarter = (as.integer(format(month, "%Y")) - 2021L) * 4L +
           (as.integer(format(month, "%m")) - 1L) %/% 3L + 1L) |>
  group_by(quarter, township_id) |>
  summarise(across(c(events, fatalities, precise_events), sum), .groups = "drop") |>
  arrange(quarter, township_id)
totals02 <- events02 |> group_by(township_id) |>
  summarise(events = n(), fatalities = sum(fatalities),
             precise_events = sum(geo_precision == 1L), .groups = "drop")
totals02 <- st_drop_geometry(townships02) |> left_join(totals02, by = "township_id") |>
  mutate(across(c(events, fatalities, precise_events), ~replace_na(.x, 0L)))
stopifnot(nrow(monthly02) == 330L * 57L, nrow(quarterly02) == 330L * 19L,
          !anyDuplicated(monthly02[c("month", "township_id")]),
          !anyDuplicated(quarterly02[c("quarter", "township_id")]),
          sum(monthly02$events) == nrow(events02),
          sum(quarterly02$events) == nrow(events02),
          sum(totals02$fatalities) == sum(events02$fatalities))
write_csv(monthly02, file.path(out02, "monthly-cube.csv"))
write_csv(quarterly02, file.path(out02, "quarterly-cube.csv"))
write_csv(totals02, file.path(out02, "township-totals.csv"))
write_csv(monthly02 |> group_by(month) |>
            summarise(events = sum(events), fatalities = sum(fatalities), .groups = "drop"),
          file.path(out02, "national-monthly.csv"))
write_csv(events02 |> count(event_type, name = "events"), file.path(out02, "analytical-event-types.csv"))
message("Sample audit and balanced 57-month / 19-quarter cubes complete.")
print(audit_events02)
