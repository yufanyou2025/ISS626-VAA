# In-class Exercise 8: prepare the supplied Taichung teaching data.
# Run from the ISS626-VAA project root in RStudio.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

root08 <- "In-class_Ex/In-class_Ex08"
data_root08 <- file.path(root08, "data")
input08 <- file.path(data_root08, "data")
output08 <- file.path(root08, "outputs")
dir.create(output08, recursive = TRUE, showWarnings = FALSE)

zip08 <- Sys.getenv("INCLASS_EX08_ZIP", unset = "")
if (!nzchar(zip08)) {
  zip08 <- file.path(Sys.getenv("USERPROFILE"), "Desktop", "Hands-on_Ex08.zip")
}
if (!file.exists(zip08)) {
  stop("Set INCLASS_EX08_ZIP to the supplied Hands-on_Ex08.zip path.")
}
archive_listing08 <- utils::unzip(zip08, list = TRUE)$Name
if (any(grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", archive_listing08))) {
  stop("The input archive contains an unsafe path.")
}
if (!file.exists(file.path(input08, "geospatial", "VILLAGE_TC.shp"))) {
  dir.create(data_root08, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(zip08, exdir = data_root08)
}

geo08 <- file.path(input08, "geospatial")
csv08 <- file.path(input08, "aspatial")
required08 <- c(file.path(geo08, c("STORES_TC.shp", "TOWN_TC.shp",
                                        "VILLAGE_TC.shp")),
                file.path(csv08, c("pop2019.csv", "Store_sales_data.csv")))
if (!all(file.exists(required08))) {
  stop("Chapter 18 inputs are incomplete in the supplied ZIP.")
}

stores_raw08 <- st_read(geo08, layer = "STORES_TC", quiet = TRUE)
town08 <- st_read(geo08, layer = "TOWN_TC", quiet = TRUE)
village_raw08 <- st_read(geo08, layer = "VILLAGE_TC", quiet = TRUE)
if (!all(vapply(list(stores_raw08, town08, village_raw08),
                function(x) st_crs(x)$epsg == 3826, logical(1)))) {
  stop("Expected all three layers in TWD97 / TM2 zone 121 (EPSG:3826).")
}
if (any(!st_is_valid(village_raw08))) village_raw08 <- st_make_valid(village_raw08)
if (anyDuplicated(stores_raw08$Store_CD) ||
    anyDuplicated(village_raw08$VILLCODE)) {
  stop("Store and village identifiers must be unique.")
}

pop_raw08 <- read_csv(file.path(csv08, "pop2019.csv"),
                      col_types = cols(V_ID = col_character(), .default = col_guess()),
                      show_col_types = FALSE)
sales_raw08 <- read_csv(file.path(csv08, "Store_sales_data.csv"),
                        col_types = cols(`Store Code` = col_character(),
                                         .default = col_guess()),
                        show_col_types = FALSE)
pop08 <- pop_raw08 |>
  mutate(V_ID = gsub("-", "", V_ID, fixed = TRUE))
if (anyDuplicated(pop08$V_ID)) stop("Population join keys are not unique.")

sales08 <- sales_raw08 |>
  group_by(`Store Code`) |>
  summarise(Total_Bill = sum(Bills, na.rm = TRUE),
            Total_Sales = sum(Amount, na.rm = TRUE), .groups = "drop")
stores08 <- stores_raw08 |>
  left_join(sales08, by = join_by(Store_CD == `Store Code`),
            relationship = "one-to-one") |>
  mutate(Store_size = 100)
if (anyNA(stores08$Total_Sales) || any(stores08$Total_Sales < 0)) {
  stop("Every modeled store must have a nonnegative sales total.")
}

village_joined08 <- village_raw08 |>
  left_join(pop08 |> select(V_ID, H_CNT, P_CNT, M_CNT, F_CNT),
            by = join_by(VILLCODE == V_ID), relationship = "one-to-one")
missing_population08 <- sum(is.na(village_joined08$P_CNT))
village08 <- village_joined08 |>
  filter(!is.na(P_CNT) & P_CNT > 0)
if (anyNA(village08$P_CNT) || any(village08$P_CNT <= 0)) {
  stop("Modeled villages need positive population counts.")
}
if (nrow(stores08) != 28 || nrow(village08) != 617) {
  stop("Unexpected input counts. Review the archive before interpreting results.")
}

audit08 <- tibble(
  check = c("Source villages", "Villages with matched positive population",
            "Villages excluded for missing/zero population", "Modeled stores",
            "Sales rows", "Sales codes outside the 28-store network",
            "Projected CRS", "Store attractiveness assumption",
            "Distance measure"),
  value = as.character(c(nrow(village_raw08), nrow(village08),
                         missing_population08, nrow(stores08),
                         nrow(sales_raw08),
                         sum(!sales08$`Store Code` %in% stores08$Store_CD),
                         "EPSG:3826", "100 for each store",
                         "straight-line metres from point-on-surface"))
)
write_csv(audit08, file.path(output08, "input-audit.csv"))

manifest08 <- tibble(
  source = c(basename(zip08), basename(required08)),
  sha256 = vapply(c(zip08, required08),
                  function(p) digest::digest(file = p, algo = "sha256"),
                  character(1))
)
write_csv(manifest08, file.path(output08, "input-manifest.csv"))
