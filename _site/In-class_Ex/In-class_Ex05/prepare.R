# In-class Exercise 5: pinned teaching-data download and validation.
# Run from the Quarto project root; RStudio's project console works too.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})
ex05 <- "In-class_Ex/In-class_Ex05"
data05 <- file.path(ex05, "data")
dir.create(file.path(data05, "geospatial"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(data05, "aspatial"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ex05, "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ex05, "outputs"), recursive = TRUE, showWarnings = FALSE)

# Pin the public course repository to a specific commit. The source data are
# not confused with the different, single-year Hunan_2012.csv used in Exercise 4.
source_ref <- "567a99d2dc576cb3b9d46dabea209f55d9fb5fba"
source_root <- paste0("https://raw.githubusercontent.com/tskam/",
                      "ISSS626-AY2026-27Aug/", source_ref,
                      "/In-class_Ex/In-class_Ex05/data/")
source_files <- c(
  "aspatial/Hunan_GDPPC.csv",
  paste0("geospatial/Hunan.", c("shp", "shx", "dbf", "prj", "qpj"))
)
expected_sha256 <- c(
  "1c2e81fe553e094fd0eda5522aa79638fff37549236f17e8f94cc63b077ea8ee",
  "44590fdd9752e783bc2a16de295dfbdbddc2449639e1bed5ff59cad189df9bf3",
  "2b18629f2b6aaba6c7c6187c99520b70539d7f77f438376cfe3d2cfb5283d946",
  "4db74d73ad63cd9776742f3caa3b8f967993d4657427fe8b17b57ec6ff247566",
  "98aaf3d1c0ecadf1a424a4536de261c3daf4e373697cb86c40c43b989daf52eb",
  "1de411dcdeedce3219242306fc29bfa1d7fa08883e4ff6779baf798ec50d1657"
)
for (relative in source_files) {
  target <- file.path(data05, relative)
  if (!file.exists(target)) {
    utils::download.file(paste0(source_root, relative), target,
                         mode = "wb", quiet = TRUE)
  }
  stopifnot(file.exists(target), file.size(target) > 0)
}
manifest05 <- tibble(
  file = source_files,
  source_url = paste0(source_root, source_files),
  accessed = "2026-10-03",
  sha256 = vapply(file.path(data05, source_files),
                  digest::digest, character(1), algo = "sha256", file = TRUE)
)
stopifnot(all(manifest05$sha256 == expected_sha256))
write_csv(manifest05, file.path(ex05, "outputs/source-manifest.csv"))

hunan05 <- st_read(file.path(data05, "geospatial/Hunan.shp"), quiet = TRUE)
gdppc05 <- read_csv(file.path(data05, "aspatial/Hunan_GDPPC.csv"),
                    show_col_types = FALSE)
stopifnot(all(is.finite(gdppc05$Year)), all(gdppc05$Year %% 1 == 0))
gdppc05 <- mutate(gdppc05, Year = as.integer(Year))
stopifnot(nrow(hunan05) == 88, nrow(gdppc05) == 88 * 17,
          identical(sort(unique(gdppc05$Year)), 2005:2021),
          !anyDuplicated(hunan05$County),
          !anyDuplicated(gdppc05[c("County", "Year")]),
          setequal(hunan05$County, gdppc05$County),
          all(table(gdppc05$County) == 17),
          all(table(gdppc05$Year) == 88),
          all(is.finite(gdppc05$GDPPC)), all(gdppc05$GDPPC > 0),
          all(st_is_valid(hunan05)), !any(st_is_empty(hunan05)),
          st_crs(hunan05)$epsg == 4326)
hunan05 <- st_transform(hunan05, 32650)
stopifnot(st_crs(hunan05)$epsg == 32650)
# sfdep propagates geometry-context neighbour lists by row position. The source
# CSV starts with Longshan while the shapefile starts with Anxiang; align every
# annual slice to the polygon order before constructing the cube.
gdppc05 <- arrange(gdppc05, Year, match(County, hunan05$County))
stopifnot(all(vapply(split(gdppc05$County, gdppc05$Year),
                     identical, logical(1), hunan05$County)))
audit05 <- tibble(
  check = c("Counties", "Years", "County-year observations", "Duplicate county-years",
            "Missing GDPPC", "Invalid polygons", "Input EPSG", "Metric EPSG"),
  result = c(nrow(hunan05), n_distinct(gdppc05$Year), nrow(gdppc05),
             0, sum(is.na(gdppc05$GDPPC)), sum(!st_is_valid(hunan05)),
             4326, 32650)
)
write_csv(audit05, file.path(ex05, "outputs/input-audit.csv"))
message("Validated Hunan cube inputs: 88 counties x 17 years (2005-2021).")
