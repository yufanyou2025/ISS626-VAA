# Validate the exact MIMU v9.4 input before working with conflict records.
source("Take-home_Ex/Take-home_Ex02/config.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})
boundary_dir02 <- file.path(ex02, "data/boundaries")
shape_dir02 <- file.path(boundary_dir02, "mimu-v9.4")
out02 <- file.path(ex02, "outputs")
dir.create(shape_dir02, recursive = TRUE, showWarnings = FALSE)
dir.create(out02, recursive = TRUE, showWarnings = FALSE)
shape02 <- file.path(shape_dir02, paste0(config02$boundary_layer, ".shp"))
if (!file.exists(shape02)) {
  archive02 <- file.path(boundary_dir02, "mimu-v9.4-townships.zip")
  if (!file.exists(archive02))
    download.file(config02$boundary_url, archive02, mode = "wb", method = "libcurl")
  unzip(archive02, exdir = shape_dir02)
}

# ZIP metadata changes with server download time, so pin its content files.
expected02 <- c(
  shp = "7616d353dd931087c36a1356b596e10046de333c2723f315f670025a5b07c0c1",
  dbf = "fabc135fbe34acc0e04c733433aeb0b1edd2dccd976ecec5ce0e73e904a8189f",
  prj = "de5c1395a1ffc517ee2112b217c89595d01a7944eb65374c06547d4771b29167"
)
manifest02 <- tibble(
  file = paste0(config02$boundary_layer, ".", names(expected02)),
  sha256 = vapply(names(expected02), function(ext) {
    digest::digest(file.path(shape_dir02, paste0(config02$boundary_layer, ".", ext)),
                   algo = "sha256", file = TRUE)
  }, character(1)),
  source = config02$boundary_url,
  accessed = as.character(config02$access_date)
)
if (!identical(unname(manifest02$sha256), unname(expected02)))
  stop("MIMU content differs from the validated v9.4 snapshot. Inspect the change before analysis.")
write_csv(manifest02, file.path(out02, "boundary-manifest.csv"))

# English labels and stable P-codes are retained; Myanmar labels are unnecessary
# for the join and are not transliterated or inferred from a console display.
boundary_raw02 <- st_read(shape02, quiet = TRUE)
required02 <- c("TS_PCODE", "TS", "ST", "PCode_V")
stopifnot(all(required02 %in% names(boundary_raw02)),
          nrow(boundary_raw02) == 330L,
          all(boundary_raw02$PCode_V == 9.4),
          !anyNA(boundary_raw02$TS_PCODE),
          !anyDuplicated(boundary_raw02$TS_PCODE),
          !is.na(st_crs(boundary_raw02)),
          st_crs(boundary_raw02)$epsg == 4326)
invalid02 <- sum(!st_is_valid(boundary_raw02))
townships02 <- boundary_raw02 |>
  transmute(township_id = TS_PCODE, township = TS, state = ST) |>
  arrange(township_id) |>
  st_transform(config02$crs) |>
  st_make_valid()
stopifnot(all(st_is_valid(townships02)), !any(st_is_empty(townships02)))

# An island is not silently connected to a distant mainland township.
# A 10 m tolerance addresses tiny digitisation gaps in the 1:250,000 layer.
queen02 <- spdep::poly2nb(townships02, queen = TRUE,
                         snap = config02$spatial_snap_m,
                         row.names = townships02$township_id)
rook02 <- spdep::poly2nb(townships02, queen = FALSE,
                        snap = config02$spatial_snap_m,
                        row.names = townships02$township_id)
components02 <- spdep::n.comp.nb(queen02)
islands02 <- spdep::card(queen02) == 0L
audit02 <- tibble(
  check = c("Township polygons", "Unique township P-codes", "Invalid before repair",
            "Invalid after repair", "Queen graph components", "Queen islands",
            "Minimum Queen neighbours (excluding islands)", "Maximum Queen neighbours",
            "Complete monthly periods", "Complete quarterly periods"),
  value = c(nrow(townships02), n_distinct(townships02$township_id), invalid02,
            sum(!st_is_valid(townships02)), components02$nc, sum(islands02),
            min(spdep::card(queen02)[!islands02]), max(spdep::card(queen02)), 57, 19)
)
write_csv(audit02, file.path(out02, "boundary-audit.csv"))
write_csv(st_drop_geometry(townships02) |>
            mutate(queen_neighbours = spdep::card(queen02),
                   rook_neighbours = spdep::card(rook02),
                   component = components02$comp.id,
                   spatial_island = islands02),
          file.path(out02, "township-neighbour-audit.csv"))
writeLines(capture.output(sessionInfo()), file.path(out02, "boundary-session-info.txt"))
print(audit02)
message("MIMU v9.4 content, geometry and neighbourhood audit complete.")
