#!/usr/bin/env Rscript

# Download the public data used in Hands-on Exercise 1.  Files are deliberately
# kept out of Git because they are public source data and can be refreshed.

options(timeout = 600)

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
data_dir <- file.path(root, "Hands-on_Ex", "Hands-on_Ex01", "data")
geo_dir <- file.path(data_dir, "geospatial")
asp_dir <- file.path(data_dir, "aspatial")
dir.create(geo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(asp_dir, recursive = TRUE, showWarnings = FALSE)

download_datagov <- function(dataset_id, destination) {
  if (file.exists(destination)) {
    message("Already available: ", destination)
    return(invisible(destination))
  }

  endpoint <- paste0(
    "https://api-open.data.gov.sg/v1/public/api/datasets/",
    dataset_id,
    "/poll-download"
  )
  metadata <- NULL
  for (attempt in 1:4) {
    metadata <- tryCatch(jsonlite::fromJSON(endpoint), error = function(e) NULL)
    if (!is.null(metadata) && identical(metadata$code, 0L)) break
    if (attempt < 4) {
      wait_seconds <- attempt * 10
      message("data.gov.sg is busy; retrying in ", wait_seconds, " seconds...")
      Sys.sleep(wait_seconds)
    }
  }
  if (is.null(metadata) || !identical(metadata$code, 0L)) {
    stop("data.gov.sg download request failed for ", dataset_id)
  }
  download.file(metadata$data$url, destination, mode = "wb", quiet = TRUE)
  message("Downloaded: ", destination)
  invisible(destination)
}

download_datagov(
  "d_226cacceceff94f0c8b814962a5307c9",
  file.path(geo_dir, "masterplan_subzones.geojson")
)
download_datagov(
  "d_8f468b25193f64be8a16fa7d8f60f553",
  file.path(geo_dir, "cycling_paths.geojson")
)
download_datagov(
  "d_61eefab99958fd70e6aab17320a71f1c",
  file.path(geo_dir, "preschools.geojson")
)

airbnb_file <- file.path(asp_dir, "singapore_listings.csv")
if (!file.exists(airbnb_file)) {
  download.file(
    "https://data.insideairbnb.com/singapore/sg/singapore/2026-06-29/visualisations/listings.csv",
    airbnb_file,
    mode = "wb",
    quiet = TRUE
  )
  message("Downloaded: ", airbnb_file)
}

population_file <- file.path(asp_dir, "respopagesextod2011to2020.csv")
if (!file.exists(population_file)) {
  zip_file <- file.path(asp_dir, "resident_population_2011_2020.zip")
  official_zip <- "https://www.singstat.gov.sg/-/media/files/find_data/population/statistical_tables/singapore-residents-by-planning-areasubzone-age-group-sex-and-type-of-dwelling-june-20112020.zip"
  downloaded <- tryCatch({
    download.file(official_zip, zip_file, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE)

  if (downloaded && file.exists(zip_file) && file.info(zip_file)$size > 0) {
    contents <- unzip(zip_file, list = TRUE)$Name
    csv_name <- contents[grepl("respopagesextod2011to2020\\.csv$", contents, ignore.case = TRUE)]
    if (length(csv_name) == 1) {
      unzip(zip_file, files = csv_name, exdir = asp_dir)
      extracted <- file.path(asp_dir, csv_name)
      if (!identical(normalizePath(extracted), normalizePath(population_file))) {
        file.rename(extracted, population_file)
      }
    }
  }

  if (!file.exists(population_file)) {
    unlink(zip_file)
    message("The legacy SingStat download has moved; using the public course-data mirror.")
    download.file(
      "https://raw.githubusercontent.com/jesseemmlucas/ISSS608-VAA/master/Hands-on_Ex/Hands-on_Ex08/data/aspatial/respopagesextod2011to2020.csv",
      population_file,
      mode = "wb",
      quiet = TRUE
    )
  }
  unlink(zip_file)
  message("Downloaded: ", population_file)
}

message("Data setup complete.")
