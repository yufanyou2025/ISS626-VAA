# Shared input preparation for Hands-on Exercises 5A and 5B.
# Run from the Quarto project root, or source from the RStudio project.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})
ex05 <- "Hands-on_Ex/Hands-on_Ex05"
dir.create(file.path(ex05, "outputs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ex05, "figures"), recursive = TRUE, showWarnings = FALSE)
zip_path <- Sys.getenv("COURSE_DATA_ZIP", unset = "")
data_dir <- file.path(ex05, "data")
if (nzchar(zip_path) && !file.exists(file.path(data_dir, "geospatial/Hunan.shp"))) {
  entries <- utils::unzip(zip_path, list = TRUE)$Name
  wanted <- c("data/aspatial/Hunan_2012.csv", "data/aspatial/Dictionary.xlsx",
              paste0("data/geospatial/Hunan.", c("shp", "shx", "dbf", "prj", "qpj")))
  stopifnot(all(wanted %in% entries))
  stopifnot(!any(grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", entries)))
  dir.create(ex05, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(zip_path, files = wanted, exdir = ex05)
}
if (!file.exists(file.path(data_dir, "geospatial/Hunan.shp"))) {
  # Exercises 4 and In-class 4 already use the same supplied Hunan archive locally.
  data_dir <- "Hands-on_Ex/Hands-on_Ex04/data"
}
manifest <- read_csv("Hands-on_Ex/Hands-on_Ex04/outputs/input-checksums.csv",
                     show_col_types = FALSE)
stopifnot(nrow(manifest) == 7)
source_files <- file.path(dirname(data_dir), manifest$file)
stopifnot(all(file.exists(source_files)))
stopifnot(identical(unname(tools::md5sum(source_files)), manifest$md5))
write_csv(tibble(file = manifest$file, md5 = manifest$md5),
          file.path(ex05, "outputs/input-checksums.csv"))

hunan_boundary <- st_read(file.path(data_dir, "geospatial/Hunan.shp"), quiet = TRUE)
hunan2012 <- read_csv(file.path(data_dir, "aspatial/Hunan_2012.csv"),
                      show_col_types = FALSE)
stopifnot(inherits(hunan_boundary, "sf"), inherits(hunan2012, "tbl_df"))
stopifnot(nrow(hunan_boundary) == 88, nrow(hunan2012) == 88,
          !anyDuplicated(hunan_boundary$County), !anyDuplicated(hunan2012$County),
          setequal(hunan_boundary$County, hunan2012$County),
          st_crs(hunan_boundary)$epsg == 4326,
          all(st_is_valid(hunan_boundary)), !any(st_is_empty(hunan_boundary)))
hunan <- left_join(hunan_boundary, hunan2012, by = "County",
                   relationship = "one-to-one") |>
  select(NAME_2, ID_3, NAME_3, County, GDPPC)
stopifnot(nrow(hunan) == 88, all(is.finite(hunan$GDPPC)),
          all(hunan$GDPPC > 0), identical(hunan$County, hunan_boundary$County))
hunan_m <- st_transform(hunan, 32650)
stopifnot(st_crs(hunan_m)$epsg == 32650)
input_audit <- tibble(
  check = c("Boundary counties", "Indicator counties", "Matched counties",
            "Duplicate County keys", "Missing GDPPC", "Invalid geometries",
            "Source EPSG", "Analysis EPSG"),
  value = c(nrow(hunan_boundary), nrow(hunan2012), nrow(hunan), 0,
            sum(is.na(hunan$GDPPC)), sum(!st_is_valid(hunan)), 4326, 32650))
write_csv(input_audit, file.path(ex05, "outputs/input-audit.csv"))
message("Hunan preparation passed: 88 unique, matched counties; EPSG:32650 analysis geometry.")
