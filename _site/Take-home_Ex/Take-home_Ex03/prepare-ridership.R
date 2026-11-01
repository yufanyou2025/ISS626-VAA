# Run from the ISS626-VAA project root. The raw LTA-format file is cached locally;
# the published output is a station aggregate with its original station code.
prepare_ridership03 <- function(base_dir = "Take-home_Ex/Take-home_Ex03",
                                raw_path = NULL) {
  stopifnot(requireNamespace("readr", quietly = TRUE),
            requireNamespace("dplyr", quietly = TRUE),
            requireNamespace("digest", quietly = TRUE))
  archive_commit <- "c13cb5943fea4a0118fc6b5b65a9eb923961e31f"
  archive_url <- paste0("https://raw.githubusercontent.com/tiredbeaver/busy-island/",
                        archive_commit, "/data/transport_node_train_202601.csv")
  expected_hash <- "dedecc5f36b35583789b0fab24a7b02b0c3ec45c5e96b23e09b7d54656a841fa"
  if (is.null(raw_path)) raw_path <- file.path(base_dir, "data/raw/transport_node_train_202601.csv")
  dir.create(dirname(raw_path), recursive = TRUE, showWarnings = FALSE)
  output_dir <- file.path(base_dir, "outputs")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(raw_path)) {
    download.file(archive_url, raw_path, mode = "wb", quiet = TRUE)
  }
  input_hash <- digest::digest(raw_path, algo = "sha256", file = TRUE)
  if (!identical(input_hash, expected_hash)) {
    stop("The pinned January 2026 train-volume file has changed. Check its provenance before proceeding.")
  }
  raw <- readr::read_csv(raw_path, show_col_types = FALSE,
    col_types = readr::cols(YEAR_MONTH = readr::col_character(),
      DAY_TYPE = readr::col_character(), TIME_PER_HOUR = readr::col_integer(),
      PT_TYPE = readr::col_character(), PT_CODE = readr::col_character(),
      TOTAL_TAP_IN_VOLUME = readr::col_double(), TOTAL_TAP_OUT_VOLUME = readr::col_double()))
  required <- c("YEAR_MONTH", "DAY_TYPE", "TIME_PER_HOUR", "PT_TYPE", "PT_CODE",
                "TOTAL_TAP_IN_VOLUME", "TOTAL_TAP_OUT_VOLUME")
  stopifnot(identical(names(raw), required), nrow(readr::problems(raw)) == 0L,
            nrow(raw) == 7259L, !anyNA(raw),
            identical(unique(raw$YEAR_MONTH), "2026-01"),
            identical(unique(raw$PT_TYPE), "TRAIN"),
            setequal(unique(raw$DAY_TYPE), c("WEEKDAY", "WEEKENDS/HOLIDAY")),
            all(raw$TIME_PER_HOUR %in% 0:23), all(nzchar(raw$PT_CODE)),
            all(raw$TOTAL_TAP_IN_VOLUME >= 0), all(raw$TOTAL_TAP_OUT_VOLUME >= 0),
            all(raw$TOTAL_TAP_IN_VOLUME %% 1 == 0), all(raw$TOTAL_TAP_OUT_VOLUME %% 1 == 0))
  key <- c("YEAR_MONTH", "DAY_TYPE", "TIME_PER_HOUR", "PT_CODE")
  exact_duplicates <- sum(duplicated(raw))
  key_duplicates <- sum(duplicated(as.data.frame(raw[, key])))
  if (exact_duplicates > 0L || key_duplicates > 0L) {
    stop("Repeated train-volume records need review; no automatic deletion or double counting is allowed.")
  }
  # Annex A of the official API guide defines totals over ALL days in the stated
  # monthly day type. Summing the two disjoint day types gives the month total.
  # We do not multiply these values by the number of weekdays/weekends.
  # Stevens has separate raw DT10 and TE11 tap counts. The spatial station
  # crosswalk identifies them as one physical access site; aggregate their
  # observed entries rather than offering duplicate competing destinations.
  station <- raw |>
    dplyr::mutate(destination = ifelse(PT_CODE %in% c("DT10", "TE11"),
                                     "DT10/TE11", PT_CODE)) |>
    dplyr::group_by(destination) |>
    dplyr::summarise(
      observed_monthly_tap_in = sum(TOTAL_TAP_IN_VOLUME),
      observed_monthly_tap_out = sum(TOTAL_TAP_OUT_VOLUME),
      weekday_monthly_tap_in = sum(TOTAL_TAP_IN_VOLUME[DAY_TYPE == "WEEKDAY"]),
      weekend_monthly_tap_in = sum(TOTAL_TAP_IN_VOLUME[DAY_TYPE == "WEEKENDS/HOLIDAY"]),
      am_weekday_monthly_tap_in = sum(TOTAL_TAP_IN_VOLUME[
        DAY_TYPE == "WEEKDAY" & TIME_PER_HOUR %in% 6:9]),
      source_rows = dplyr::n(),
      source_station_code_count = dplyr::n_distinct(PT_CODE),
      source_station_codes = paste(sort(unique(PT_CODE)), collapse = ";"),
      .groups = "drop") |>
    dplyr::mutate(year_month = "2026-01", days_in_month = 31L,
      nonholiday_weekdays = 21L,
      am_weekday_daily_tap_in = am_weekday_monthly_tap_in / nonholiday_weekdays,
      observed_daily_tap_in = observed_monthly_tap_in / days_in_month,
      observed_daily_tap_out = observed_monthly_tap_out / days_in_month) |>
    dplyr::arrange(destination)
  stopifnot(nrow(station) == 181L, !anyDuplicated(station$destination),
            sum(station$source_station_code_count) == 182L,
            all(c("DT10", "TE11") %in% raw$PT_CODE),
            sum(station$observed_monthly_tap_in) == 88683630,
            sum(station$observed_monthly_tap_out) == 88390800,
            sum(station$source_rows) == nrow(raw),
            all(station$observed_monthly_tap_in ==
                  station$weekday_monthly_tap_in + station$weekend_monthly_tap_in))
  audit <- data.frame(
    measure = c("Input hourly/day-type rows", "Valid TRAIN rows in January 2026",
      "Exact duplicate rows", "Duplicate month/day-type/hour/station keys",
      "Missing required cells", "Negative or fractional volume cells",
      "Distinct observed source station codes", "Physical access sites after Stevens merge",
      "Station/day-type/hour combinations not present within observed 20 hours",
      "Station codes with fewer than 40 source rows", "January days", "Non-holiday weekdays",
      "Monthly tap-ins", "Monthly tap-outs", "Monthly in/out difference",
      "Weekday monthly tap-ins", "Weekend/holiday monthly tap-ins",
      "Weekday 06:00-09:59 monthly tap-ins"),
    value = c(nrow(raw), nrow(raw), exact_duplicates, key_duplicates, sum(is.na(raw)),
      0, dplyr::n_distinct(raw$PT_CODE), nrow(station),
      dplyr::n_distinct(raw$PT_CODE) * length(unique(raw$TIME_PER_HOUR)) * 2L - nrow(raw),
      sum(station$source_rows < 40L), 31, 21,
      sum(station$observed_monthly_tap_in), sum(station$observed_monthly_tap_out),
      sum(station$observed_monthly_tap_in - station$observed_monthly_tap_out),
      sum(station$weekday_monthly_tap_in), sum(station$weekend_monthly_tap_in),
      sum(station$am_weekday_monthly_tap_in)))
  # Missing combinations are not fabricated as observed zero records. Some LRT
  # branches do not operate throughout the network-wide span of operating hours.
  # January 2026 has 22 Monday-Friday dates, less the 1 January public holiday:
  # https://www.mom.gov.sg/newsroom/press-releases/2025/0616-public-holidays-for-2026
  manifest <- data.frame(file = basename(raw_path), sha256 = input_hash,
    bytes = file.info(raw_path)$size, accessed = "2026-11-01",
    observation_month = "2026-01", publisher = "Land Transport Authority, Singapore",
    retrieval = "Public third-party archive; not a direct current DataMall download",
    archive_commit = archive_commit, url = archive_url,
    upstream_url = "https://datamall.lta.gov.sg/content/datamall/en/dynamic-data.html",
    licence = "Singapore Open Data Licence v1.0",
    licence_url = "https://datamall.lta.gov.sg/content/datamall/en/SingaporeOpenDataLicence.html")
  readr::write_csv(station, file.path(output_dir, "observed-station-ridership.csv"))
  readr::write_csv(audit, file.path(output_dir, "ridership-audit.csv"))
  readr::write_csv(manifest, file.path(output_dir, "ridership-input-manifest.csv"))
  invisible(station)
}
