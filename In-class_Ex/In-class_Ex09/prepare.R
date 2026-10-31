# Hands-on Exercise 9: prepare the supplied Singapore condominium data.
# Run from the ISS626-VAA project root in RStudio.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

root09 <- "In-class_Ex/In-class_Ex09"
data_root09 <- file.path(root09, "data")
input09 <- file.path(data_root09, "data")
output09 <- file.path(root09, "outputs")
dir.create(output09, recursive = TRUE, showWarnings = FALSE)

zip09 <- Sys.getenv("INCLASS_EX09_ZIP", unset = "")
if (!nzchar(zip09)) {
  zip09 <- file.path(Sys.getenv("USERPROFILE"), "Desktop", "Hands-on_Ex09.zip")
}
if (!file.exists(zip09)) stop("Set INCLASS_EX09_ZIP to Hands-on_Ex09.zip.")
members09 <- utils::unzip(zip09, list = TRUE)$Name
if (any(grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", members09))) {
  stop("Unsafe archive path in input ZIP.")
}
if (!file.exists(file.path(input09, "geospatial", "MP14_SUBZONE_WEB_PL.shp"))) {
  dir.create(data_root09, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(zip09, exdir = data_root09)
}

shape09 <- file.path(input09, "geospatial", "MP14_SUBZONE_WEB_PL.shp")
csv09 <- file.path(input09, "aspatial", "Condo_resale_2015.csv")
if (!all(file.exists(c(shape09, csv09)))) stop("Chapter 13 inputs are incomplete.")

subzones_raw09 <- st_read(shape09, quiet = TRUE)
if (st_crs(subzones_raw09)$input != "SVY21" ||
    !grepl("Transverse Mercator", st_crs(subzones_raw09)$wkt)) {
  stop("Unexpected subzone source CRS; review before assigning EPSG:3414.")
}
invalid09 <- sum(!st_is_valid(subzones_raw09))
subzones09 <- subzones_raw09 |>
  st_make_valid() |>
  st_transform(3414)
stopifnot(all(st_is_valid(subzones09)), st_crs(subzones09)$epsg == 3414)

condo_raw09 <- read_csv(csv09, show_col_types = FALSE)
needed09 <- c("LONGITUDE", "LATITUDE", "SELLING_PRICE", "AREA_SQM", "AGE",
              "PROX_CBD", "PROX_CHILDCARE", "PROX_ELDERLYCARE",
              "PROX_URA_GROWTH_AREA", "PROX_HAWKER_MARKET",
              "PROX_KINDERGARTEN", "PROX_MRT", "PROX_PARK",
              "PROX_PRIMARY_SCH", "PROX_TOP_PRIMARY_SCH",
              "PROX_SHOPPING_MALL", "PROX_SUPERMARKET", "PROX_BUS_STOP",
              "NO_Of_UNITS", "FAMILY_FRIENDLY", "FREEHOLD", "LEASEHOLD_99YR")
if (!all(needed09 %in% names(condo_raw09))) stop("The condo CSV schema changed.")
if (anyNA(condo_raw09[needed09]) ||
    any(condo_raw09$SELLING_PRICE <= 0) ||
    any(condo_raw09$AREA_SQM <= 0) ||
    any(!is.finite(as.matrix(condo_raw09[needed09])))) {
  stop("Missing, nonfinite, or nonpositive required analysis values.")
}
if (any(condo_raw09$LONGITUDE < 103.5 | condo_raw09$LONGITUDE > 104.2 |
        condo_raw09$LATITUDE < 1.1 | condo_raw09$LATITUDE > 1.6)) {
  stop("Coordinates fall outside a plausible Singapore extent.")
}

condo09 <- condo_raw09 |>
  mutate(record_id = row_number(), LOG_SELLING_PRICE = log(SELLING_PRICE)) |>
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = 4326,
           remove = FALSE) |>
  st_transform(3414)
inside09 <- lengths(st_within(condo09, st_union(subzones09))) > 0
if (!all(inside09)) stop("Some transactions fall outside the subzone boundary.")
duplicate_coords09 <- sum(duplicated(st_coordinates(condo09)))
stopifnot(nrow(condo09) == 1436L, nrow(subzones09) == 323L)

audit09 <- tibble::tibble(
  check = c("Condominium resale records", "Master Plan 2014 subzones",
            "Invalid source subzone geometries repaired",
            "Transactions outside the subzone union",
            "Repeated transaction coordinates retained", "Missing analysis values",
            "Analysis CRS", "Outcome period"),
  result = as.character(c(nrow(condo09), nrow(subzones09), invalid09,
                          sum(!inside09), duplicate_coords09, 0,
                          "EPSG:3414 (metres)", "2015 resale transactions"))
)
write_csv(audit09, file.path(output09, "input-audit.csv"))
manifest09 <- tibble::tibble(
  source = c(basename(zip09), basename(shape09), basename(csv09)),
  sha256 = vapply(c(zip09, shape09, csv09),
                  function(p) digest::digest(file = p, algo = "sha256"),
                  character(1))
)
write_csv(manifest09, file.path(output09, "input-manifest.csv"))
