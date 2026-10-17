# Hands-on Exercise 7: validate the supplied archive and construct aligned inputs.
# Open the ISS626-VAA project in RStudio and run from its root directory.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(tidyr)
})
ex07 <- "Hands-on_Ex/Hands-on_Ex07"
data07 <- file.path(ex07, "data")
out07 <- file.path(ex07, "outputs")
fig07 <- file.path(ex07, "figures")
dir.create(data07, recursive = TRUE, showWarnings = FALSE)
dir.create(out07, recursive = TRUE, showWarnings = FALSE)
dir.create(fig07, recursive = TRUE, showWarnings = FALSE)

# The ZIP is deliberately not committed: the workbook describes three of its
# four layers as course-prepared data with restricted reuse. Set this variable
# when your copy is not on the Desktop.
zip07 <- Sys.getenv("HANDSON_EX07_ZIP", unset = "")
if (!nzchar(zip07)) zip07 <- file.path(Sys.getenv("USERPROFILE"),
                                        "Desktop", "Hands-on Exercise 7.zip")
needed07 <- c(
  "data/aspatial/OD_Matrix.csv",
  unlist(lapply(c("MP14_SUBZONE_NO_SEA_PL", "hexagons", "ELDERCARE"),
                function(n) paste0("data/geospatial/", n,
                                   c(".shp", ".shx", ".dbf", ".prj")))))
expected07 <- c(
  "f52e4009b0bea32ca52841223f8c37bd880b022faf8ba1a752c563377665c2ef",
  "bd0fd7fff4064617aedff906c8664768b869aa4fce3a8f0728011e789df10dae",
  "c06a0fbc6324a796994f47f31f45443a7b5c49d80ac279882eee89406c13dfea",
  "d0e3698e14237ee6243b89844c68ce8c959c612df5f763155b857aa97badc3db",
  "154dc78ac6632ba94b86bc576c9ef3311f4b51c2c6df994ce57b5d57f10271d0",
  "7c91fbb2d8012a91cbf45b7e93e04305075709aa662da6d40f285d39c02c5af7",
  "da2e2cb20be7b6391b7f96f3474efe450e1015131068b03fc404fc0246dcc342",
  "03b89082ce3770309eeff20df3a5991ff9339bdae4921b29b518205574336203",
  "3d70480f485191054b744263ab4c9632116edab90b1fd2a0da26d64b8752a11c",
  "66930af902256e2e9b2d2964537739f9aa8953765f87858fccb5cc2f990efcbb",
  "e749a9a786c55e2285b8ca2bf53133cbe449533b5f377ab66a797b2dc6dd03bb",
  "b1624bbb840f373bbbba1b955395d42faaf8a35bb954e3fa0527e777498c4771",
  "3d70480f485191054b744263ab4c9632116edab90b1fd2a0da26d64b8752a11c")
stopifnot(length(needed07) == length(expected07))
if (file.exists(zip07)) {
  archive_sha07 <- digest::digest(zip07, file = TRUE, algo = "sha256")
  stopifnot(identical(archive_sha07,
                      "45a5ea7ef0f3e8e9a7b3f33df5d22044eb4f328da5bf8920ba24f1ba8a097181"))
  entries07 <- utils::unzip(zip07, list = TRUE)$Name
  stopifnot(all(needed07 %in% entries07))
  missing07 <- needed07[!file.exists(file.path(ex07, needed07))]
  if (length(missing07)) utils::unzip(zip07, files = missing07, exdir = ex07)
} else if (!all(file.exists(file.path(ex07, needed07)))) {
  stop("Place Hands-on Exercise 7.zip on the Desktop or set HANDSON_EX07_ZIP.")
}
hash07 <- vapply(file.path(ex07, needed07), digest::digest,
                 character(1), file = TRUE, algo = "sha256")
stopifnot(identical(unname(hash07), expected07))
manifest07 <- tibble(file = needed07, sha256 = hash07,
                     source = "User-supplied Hands-on Exercise 7.zip",
                     archive_sha256 = "45a5ea7ef0f3e8e9a7b3f33df5d22044eb4f328da5bf8920ba24f1ba8a097181",
                     accessed = "2026-10-17")
write_csv(manifest07, file.path(out07, "input-manifest.csv"))

geo07 <- file.path(data07, "geospatial")
mpsz07 <- st_read(file.path(geo07, "MP14_SUBZONE_NO_SEA_PL.shp"), quiet = TRUE)
hex07 <- st_read(file.path(geo07, "hexagons.shp"), quiet = TRUE)
elder07 <- st_read(file.path(geo07, "ELDERCARE.shp"), quiet = TRUE)
valid_before07 <- c(sum(!st_is_valid(mpsz07)), sum(!st_is_valid(hex07)),
                    sum(!st_is_valid(elder07)))
stopifnot(nrow(mpsz07) == 323, nrow(hex07) == 3125, nrow(elder07) == 120,
          all(grepl("SVY21", c(st_crs(mpsz07)$input, st_crs(hex07)$input,
                               st_crs(elder07)$input))),
          all(as.numeric(st_bbox(mpsz07)) > 0),
          !any(st_is_empty(mpsz07)), !any(st_is_empty(hex07)),
          !any(st_is_empty(elder07)))
# These coordinates already use the SVY21 metre grid. The .prj files lack an
# EPSG authority code, so assign 3414; transforming unknown coordinates would
# risk moving the features. Repair invalid polygon topology afterwards.
mpsz07 <- st_make_valid(suppressWarnings(st_set_crs(mpsz07, 3414)))
hex07 <- suppressWarnings(st_set_crs(hex07, 3414))
elder07 <- suppressWarnings(st_set_crs(elder07, 3414))
stopifnot(all(st_is_valid(mpsz07)), all(st_is_valid(hex07)),
          all(st_is_valid(elder07)))
hex07 <- hex07 |> select(fid) |> mutate(demand = 100)
elder07 <- elder07 |> select(fid, NAME) |> mutate(capacity = 100)
stopifnot(!anyDuplicated(hex07$fid), !anyDuplicated(elder07$fid),
          all(hex07$demand > 0), all(elder07$capacity > 0))

od07 <- read_csv(file.path(data07, "aspatial/OD_Matrix.csv"),
                show_col_types = FALSE, col_types = cols(
                  origin_id = col_integer(), destination_id = col_integer(),
                  entry_cost = col_double(), network_cost = col_double(),
                  exit_cost = col_double(), total_cost = col_double()))
stopifnot(nrow(od07) == nrow(hex07) * nrow(elder07),
          !anyNA(od07),
          !anyDuplicated(od07[c("origin_id", "destination_id")]),
          setequal(od07$origin_id, hex07$fid),
          setequal(od07$destination_id, elder07$fid),
          all(vapply(od07[c("entry_cost", "network_cost", "exit_cost",
                            "total_cost")], function(x) all(is.finite(x) & x >= 0),
                     logical(1))),
          max(abs(od07$entry_cost + od07$network_cost + od07$exit_cost -
                    od07$total_cost)) < 1e-5)
origin_count07 <- table(od07$origin_id)
dest_count07 <- table(od07$destination_id)
stopifnot(all(origin_count07 == nrow(elder07)),
          all(dest_count07 == nrow(hex07)))

# pivot_wider follows the workbook. The explicit fid alignment is necessary:
# the distance matrix must have the same row and column order as the sf layers.
wide07 <- od07 |>
  select(origin_id, destination_id, total_cost) |>
  pivot_wider(names_from = destination_id, values_from = total_cost)
origin_names07 <- as.character(hex07$fid)
dest_names07 <- as.character(elder07$fid)
wide07 <- wide07[match(hex07$fid, wide07$origin_id), ]
stopifnot(identical(as.character(wide07$origin_id), origin_names07),
          all(dest_names07 %in% names(wide07)))
distmat_km07 <- as.matrix(wide07[, dest_names07, drop = FALSE]) / 1000
rownames(distmat_km07) <- origin_names07
colnames(distmat_km07) <- dest_names07
storage.mode(distmat_km07) <- "double"
stopifnot(identical(dim(distmat_km07), c(3125L, 120L)),
          all(is.finite(distmat_km07)), all(distmat_km07 > 0),
          isTRUE(all.equal(distmat_km07[1, 1],
                           od07$total_cost[od07$origin_id == hex07$fid[1] &
                                             od07$destination_id == elder07$fid[1]] / 1000)))
audit07 <- tibble(
  check = c("Subzones", "Hexagon origins", "Eldercare destinations", "OD pairs",
            "Invalid subzones before repair", "Invalid subzones after repair",
            "Missing or duplicate OD pairs", "Minimum network distance (km)",
            "Maximum network distance (km)", "CRS / cost unit"),
  result = c(nrow(mpsz07), nrow(hex07), nrow(elder07), nrow(od07),
             valid_before07[1], sum(!st_is_valid(mpsz07)), 0,
             round(min(distmat_km07), 3), round(max(distmat_km07), 3),
             "EPSG:3414 / kilometres"))
write_csv(audit07, file.path(out07, "input-audit.csv"))
message("Validated user-supplied ZIP: 3,125 origins x 120 destinations.")
