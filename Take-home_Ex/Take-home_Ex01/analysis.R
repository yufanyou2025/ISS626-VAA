## ---- setup ----
# Complete AI-assisted worked analysis. See the declaration in the report.
# Run from the repository root: Rscript Take-home_Ex/Take-home_Ex01/analysis.R
if (.Platform$OS.type == "windows") {
  invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
}
required <- c("sf", "dplyr", "readr", "ggplot2", "spatstat.geom",
              "spatstat.explore", "spatstat.random", "jsonlite", "digest")
missing_packages <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) stop("Install required packages: ", paste(missing_packages, collapse = ", "))
suppressPackageStartupMessages({
  library(sf); library(dplyr); library(ggplot2)
  library(spatstat.geom); library(spatstat.explore); library(spatstat.random)
})
base_dir <- "Take-home_Ex/Take-home_Ex01"
fig_dir <- file.path(base_dir, "figures")
out_dir <- file.path(base_dir, "outputs")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
manifest <- jsonlite::fromJSON(file.path(base_dir, "notes/input-manifest.json"))
for (i in seq_len(nrow(manifest$files))) {
  file <- file.path(base_dir, manifest$files$path[i])
  if (!file.exists(file)) stop("Missing original input: ", file, "; see data/README.md")
  stopifnot(identical(digest::digest(file = file, algo = "sha256"), manifest$files$sha256[i]))
}
theme_set(theme_minimal(base_size = 12, base_family = "sans") +
  theme(plot.title = element_text(face = "bold", colour = "#20394f"),
        plot.title.position = "plot", plot.caption = element_text(hjust = 0),
        panel.grid.minor = element_blank(), legend.position = "bottom"))
save_plot <- function(plot, filename, width = 10, height = 6) {
  ggsave(file.path(fig_dir, filename), plot, width = width, height = height,
         dpi = 180, bg = "white")
}

## ---- data-preparation ----
raw <- readr::read_csv(file.path(base_dir, "data/raw/kaggle/thailand_road_accident_fatalities_2024.csv"),
                      locale = readr::locale(encoding = "UTF-8"), show_col_types = FALSE)
stopifnot(nrow(raw) == 12762L, ncol(raw) == 13L, nrow(readr::problems(raw)) == 0L)
exact_duplicates <- sum(duplicated(raw))
dat <- distinct(raw)
parts <- do.call(rbind, strsplit(dat$confirmed_death_date, "/", fixed = TRUE))
stopifnot(ncol(parts) == 3L, all(as.integer(parts[, 3]) == 2567L))
dat$death_date <- as.Date(sprintf("%04d-%02d-%02d", as.integer(parts[, 3]) - 543L,
                                  as.integer(parts[, 2]), as.integer(parts[, 1])))
stopifnot(!anyNA(dat$death_date))
period <- dat %>% filter(death_date >= as.Date("2024-01-01"), death_date <= as.Date("2024-09-30"))
# All nonmissing values support this reversed header interpretation.
stopifnot(all(is.na(period$acc_lat) | (period$acc_lat >= 97 & period$acc_lat <= 106)),
          all(is.na(period$acc_long) | (period$acc_long >= 5 & period$acc_long <= 21)))
period <- period %>% mutate(longitude = acc_lat, latitude = acc_long,
                           has_coordinates = is.finite(longitude) & is.finite(latitude))
located <- period %>% filter(has_coordinates, between(longitude, -180, 180),
                            between(latitude, -90, 90))
points_ll <- st_as_sf(located, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

## ---- study-window ----
boundaries <- st_read(file.path(base_dir, "data/raw/geoBoundaries-THA-ADM1.geojson"), quiet = TRUE)
province_codes <- c("TH-10", "TH-11", "TH-12", "TH-13", "TH-73", "TH-74")
selected <- boundaries[boundaries$shapeISO %in% province_codes, ]
stopifnot(nrow(selected) == 6, !anyDuplicated(selected$shapeISO))
invalid_boundaries <- sum(!st_is_valid(selected))
study <- st_transform(st_make_valid(selected), 32647)
study$province <- sub(" Province$", "", study$shapeName)
window_sf <- st_union(study)
pts <- st_transform(points_ll, 32647)
membership <- st_intersects(pts, window_sf)
pts <- pts[lengths(membership) > 0, ]
province_membership <- st_intersects(pts, study)
ambiguous_boundaries <- sum(lengths(province_membership) != 1L)
# This input has no ambiguous province-boundary points; avoid double counting.
stopifnot(ambiguous_boundaries == 0L, all(st_is_valid(pts)))
pts$province <- study$province[vapply(province_membership, `[`, integer(1), 1)]
xy <- st_coordinates(pts)
W <- as.owin(window_sf)
X <- ppp(xy[, 1], xy[, 2], window = W, checkdup = FALSE)
X_unique <- ppp(xy[!duplicated(xy), 1], xy[!duplicated(xy), 2], window = W)
stopifnot(npoints(X) == nrow(pts), npoints(X) == 530L)
area_km2 <- as.numeric(st_area(window_sf)) / 1e6
audit <- data.frame(
  stage = c("Original input", "Remove identical rows", "Valid dates in Jan-Sep 2024",
            "Usable coordinate pair", "Inside six-province window"),
  retained = c(nrow(raw), nrow(dat), nrow(period), nrow(located), nrow(pts)))
audit$removed <- c(0L, -diff(audit$retained))
audit <- audit[c("stage", "removed", "retained")]
stopifnot(sum(audit$removed) + tail(audit$retained, 1) == nrow(raw))

## ---- descriptive-views ----
thai_names <- c("\u0e01\u0e23\u0e38\u0e07\u0e40\u0e17\u0e1e\u0e21\u0e2b\u0e32\u0e19\u0e04\u0e23",
                "\u0e2a\u0e21\u0e38\u0e17\u0e23\u0e1b\u0e23\u0e32\u0e01\u0e32\u0e23",
                "\u0e19\u0e19\u0e17\u0e1a\u0e38\u0e23\u0e35",
                "\u0e1b\u0e17\u0e38\u0e21\u0e18\u0e32\u0e19\u0e35",
                "\u0e19\u0e04\u0e23\u0e1b\u0e10\u0e21",
                "\u0e2a\u0e21\u0e38\u0e17\u0e23\u0e2a\u0e32\u0e04\u0e23")
name_lookup <- data.frame(province_of_death = thai_names,
                         province = c("Bangkok", "Samut Prakan", "Nonthaburi", "Pathum Thani", "Nakhon Pathom", "Samut Sakhon"))
coverage <- period %>% inner_join(name_lookup, by = "province_of_death") %>%
  group_by(province) %>% summarise(records = n(), located = sum(has_coordinates), .groups = "drop") %>%
  mutate(coverage_pct = 100 * located / records)
counts <- as.data.frame(table(pts$province), stringsAsFactors = FALSE)
names(counts) <- c("province", "mapped_records")
province_table <- study %>% mutate(area_km2 = as.numeric(st_area(geometry)) / 1e6) %>%
  st_drop_geometry() %>% select(province, area_km2) %>% left_join(counts, by = "province") %>%
  mutate(records_per_km2 = mapped_records / area_km2)
monthly <- st_drop_geometry(pts) %>% count(month = format(death_date, "%m")) %>%
  mutate(month = factor(month, levels = sprintf("%02d", 1:9), labels = month.abb[1:9]))
coverage_plot <- ggplot(coverage, aes(reorder(province, coverage_pct), coverage_pct)) +
  geom_col(fill = "#176f82", width = 0.65) +
  geom_text(aes(label = sprintf("%.1f%%  (%d/%d)", coverage_pct, located, records)),
            hjust = -0.1, size = 3.6) + coord_flip(ylim = c(0, 70)) +
  labs(title = "Location availability differs between death-province groups",
       subtitle = "Denominator: records labelled with each province of death, after exact-row deduplication",
       x = NULL, y = "Records with coordinates (%)",
       caption = "These groups do not define the spatial sample; coordinates determine inclusion in the study window.\nSource: Kaggle / Thailand DDC compilation, January-September 2024.")
save_plot(coverage_plot, "coverage.png")
label_points <- suppressWarnings(st_point_on_surface(study))
label_xy <- st_coordinates(label_points)
labels <- data.frame(province = study$province, x = label_xy[,1], y = label_xy[,2])
study_plot <- ggplot() + geom_sf(data = study, fill = "#eef1f3", colour = "#788a98", linewidth = 0.4) +
  geom_sf(data = pts, colour = "#b34a31", size = 1.0, alpha = 0.6) +
  geom_label(data = labels, aes(x, y, label = province), size = 3.1, fill = "white", alpha = 0.85) +
  coord_sf(crs = st_crs(32647), datum = st_crs(4326)) +
  labs(title = "530 located fatality records in Bangkok and five neighbouring provinces",
       subtitle = "Recorded death dates: January-September 2024 · points can overlap",
       x = "Longitude", y = "Latitude",
       caption = "Analysis CRS: WGS 84 / UTM zone 47N (metres).\nSources: Kaggle / DDC compilation; geoBoundaries (OpenStreetMap, Wambacher; ODbL 1.0).")
save_plot(study_plot, "study-area.png", height = 7)
monthly_plot <- ggplot(monthly, aes(month, n)) + geom_col(fill = "#176f82", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.45, size = 4) + expand_limits(y = max(monthly$n) * 1.13) +
  labs(title = "Monthly counts follow confirmed-death dates",
       subtitle = "Located records inside the six-province window; October-December are absent from the input",
       x = NULL, y = "Located fatality records",
       caption = "These are counts, not exposure-adjusted rates or accident-date totals. Source: Kaggle / DDC compilation.")
save_plot(monthly_plot, "monthly.png", height = 5)

## ---- first-order ----
# Fixed district-scale smoothing, assessed at half and double bandwidth.
bandwidths <- c(1500, 3000, 6000)
kde_images <- lapply(bandwidths, function(h) density(X, sigma = h, edge = TRUE, eps = 500))
kde_frames <- lapply(seq_along(bandwidths), function(i) {
  frame <- as.data.frame(kde_images[[i]])
  # FFT smoothing can produce tiny negative round-off values in empty pixels.
  stopifnot(min(frame$value, na.rm = TRUE) > -1e-10)
  frame$intensity <- pmax(frame$value, 0) * 1e6
  frame$bandwidth <- paste0(bandwidths[i] / 1000, " km")
  frame
})
kde_all <- bind_rows(kde_frames)
kde_all$bandwidth <- factor(kde_all$bandwidth, levels = c("1.5 km", "3 km", "6 km"))
kde_plot <- ggplot(kde_all, aes(x, y, fill = intensity)) + geom_raster() +
  geom_sf(data = study, fill = NA, colour = "#53616b", linewidth = 0.25, inherit.aes = FALSE) +
  facet_wrap(~bandwidth, nrow = 1) +
  scale_fill_viridis_c(option = "C", trans = "sqrt", breaks = c(0, 0.1, 0.3, 0.5),
                      name = "Records / km² (square-root scale)",
                      guide = guide_colourbar(barwidth = grid::unit(9, "cm"),
                                              barheight = grid::unit(0.35, "cm"), title.position = "top")) +
  coord_sf(crs = st_crs(32647), datum = NA) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(), panel.grid = element_blank()) +
  labs(title = "Smoothing changes the apparent size and height of concentrations",
       subtitle = "Gaussian kernel density · bandwidth is the kernel standard deviation · one shared colour scale",
       x = NULL, y = NULL,
       caption = "500 m raster grid; edge-corrected event intensity for the observed nine-month period.\nSources: Kaggle / DDC; geoBoundaries (OSM, Wambacher; ODbL 1.0).")
save_plot(kde_plot, "kde-bandwidths.png", width = 13, height = 6)
peak <- kde_frames[[2]][which.max(kde_frames[[2]]$intensity), ]
peak_sf <- st_as_sf(peak, coords = c("x", "y"), crs = 32647)
peak_province <- study$province[st_intersects(peak_sf, study)[[1]]]
peak_ll <- st_coordinates(st_transform(peak_sf, 4326))[1, ]

## ---- second-order ----
# Conditional CSR: retain n, independently sample uniform locations in the same polygon.
r <- seq(0, 10000, by = 50)
test_range <- r >= 250 & r <= 10000
l_curve <- function(pattern) Lest(pattern, r = r, correction = "translate")$trans - r
observed_l <- l_curve(X)
nsim <- 199L
set.seed(20260910)
simulated_l <- replicate(nsim, l_curve(runifpoint(npoints(X), win = W)))
observed_stat <- max(abs(observed_l[test_range]))
simulated_stats <- apply(abs(simulated_l[test_range, , drop = FALSE]), 2, max)
p_global <- (1 + sum(simulated_stats >= observed_stat)) / (nsim + 1)
critical <- unname(quantile(simulated_stats, 0.95, type = 1))
csr_df <- data.frame(distance_km = r[test_range] / 1000,
                     observed = observed_l[test_range] / 1000,
                     lower = -critical / 1000, upper = critical / 1000)
csr_plot <- ggplot(csr_df, aes(distance_km, observed)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#dce8ed") +
  geom_hline(yintercept = 0, linetype = 2, colour = "#788a98") +
  geom_line(colour = "#b34a31", linewidth = 1.1) +
  labs(title = "Located fatalities depart from a spatially uniform reference",
       subtitle = sprintf("Conditional CSR · 199 simulations · global MAD p = %.3f", p_global),
       x = "Distance r (km)", y = "L(r) − r (km)",
       caption = "Translation edge correction. Band: global 95% Monte Carlo threshold for max |L(r)−r| over 0.25–10 km.\nA rejection of uniformity does not isolate event interaction from spatially varying intensity.")
save_plot(csr_plot, "csr-envelope.png")

## ---- sensitivity ----
# Descriptive inhomogeneous L curves, not a calibrated hypothesis test.
# Intensity is re-estimated leave-one-out at each point and bandwidth.
inhom_curve <- function(pattern, h) {
  kval <- Kinhom(pattern, sigma = h, r = r, correction = "translate",
                leaveoneout = TRUE, renormalise = TRUE, normpower = 2)
  sqrt(pmax(kval$trans, 0) / pi) - r
}
inhom <- bind_rows(lapply(c(3000, 6000), function(h) {
  data.frame(distance_km = r[test_range] / 1000,
             value = inhom_curve(X, h)[test_range] / 1000,
             curve = paste0("All records; bandwidth ", h/1000, " km"))
}), data.frame(distance_km = r[test_range] / 1000,
               value = inhom_curve(X_unique, 3000)[test_range] / 1000,
               curve = "Unique locations; bandwidth 3 km"))
inhom_plot <- ggplot(inhom, aes(distance_km, value, colour = curve)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "#788a98") + geom_line(linewidth = 1) +
  scale_colour_manual(values = c("#176f82", "#b34a31", "#6c5c8d"), name = NULL) +
  labs(title = "Residual pattern depends on the intensity estimate",
       subtitle = "Inhomogeneous L(r) − r · translation correction · leave-one-out intensity",
       x = "Distance r (km)", y = "Inhomogeneous L(r) − r (km)",
       caption = "The dashed line is the Poisson theoretical reference. No significance envelope is fitted here.\nUnique-location sensitivity removes coincident records; it does not identify unique crashes.")
save_plot(inhom_plot, "inhomogeneous-sensitivity.png")
unique_l <- l_curve(X_unique)
intensity_diagnostics <- bind_rows(lapply(c(3000, 6000), function(h) {
  lambda <- density(X, sigma = h, edge = TRUE, at = "points", leaveoneout = TRUE)
  stopifnot(all(is.finite(lambda)), all(lambda > 0))
  data.frame(bandwidth_km = h/1000, min_intensity_km2 = min(lambda)*1e6,
             max_intensity_km2 = max(lambda)*1e6,
             largest_inverse_intensity_share_pct = 100 * max(1/lambda) / sum(1/lambda))
}))
at_distances <- c(1000, 3000, 5000, 10000)
l_summary <- data.frame(distance_km = at_distances / 1000,
                        all_records_L_minus_r_km = observed_l[match(at_distances, r)] / 1000,
                        unique_locations_L_minus_r_km = unique_l[match(at_distances, r)] / 1000)
inhom_summary <- inhom %>% filter(distance_km %in% (at_distances/1000))

## ---- export-results ----
# Presentation variants use the same plotted evidence with larger labels.
slide_plots <- list(coverage = coverage_plot, study = study_plot, monthly = monthly_plot,
                    kde = kde_plot, csr = csr_plot, inhom = inhom_plot)
for (name in names(slide_plots)) {
  plot <- slide_plots[[name]] + labs(title = NULL, subtitle = NULL, caption = NULL) +
    theme(text = element_text(size = 17), legend.text = element_text(size = 14),
          legend.title = element_text(size = 14))
  if (name == "inhom") plot <- plot + guides(colour = guide_legend(nrow = 2))
  for (i in seq_along(plot$layers)) {
    if (inherits(plot$layers[[i]]$geom, "GeomText") || inherits(plot$layers[[i]]$geom, "GeomLabel")) {
      plot$layers[[i]]$aes_params$size <- 4.5
    }
  }
  save_plot(plot, paste0("slide-", name, ".png"), width = 12, height = 5.5)
}
summary <- list(
  raw_records = nrow(raw), exact_duplicate_rows = exact_duplicates,
  deduplicated_records = nrow(dat), located_national = nrow(located),
  missing_coordinates = sum(!period$has_coordinates),
  missing_coordinates_pct = 100 * mean(!period$has_coordinates),
  study_records = npoints(X), unique_locations = npoints(X_unique),
  excess_coincident_records = npoints(X) - npoints(X_unique),
  distinct_location_dates = nrow(distinct(st_drop_geometry(pts), longitude, latitude, death_date)),
  observation_start = as.character(min(period$death_date)), observation_end = as.character(max(period$death_date)),
  study_start = as.character(min(pts$death_date)), study_end = as.character(max(pts$death_date)),
  area_km2 = area_km2, average_intensity_per_km2 = npoints(X) / area_km2,
  invalid_selected_boundaries = invalid_boundaries, ambiguous_province_boundaries = ambiguous_boundaries,
  global_csr_p = p_global, global_csr_stat_km = observed_stat/1000,
  global_csr_critical_km = critical/1000, simulations = nsim, seed = 20260910,
  peak_3km_intensity = peak$intensity, peak_province = peak_province,
  peak_longitude = unname(peak_ll[1]), peak_latitude = unname(peak_ll[2]),
  kde_peak_intensities = vapply(kde_frames, function(z) max(z$intensity), numeric(1)))
jsonlite::write_json(summary, file.path(out_dir, "summary.json"), pretty = TRUE, auto_unbox = TRUE, digits = 10)
tables <- list(audit = audit, coverage = coverage, province_counts = province_table,
               monthly = monthly, l_summary = l_summary, inhom_summary = inhom_summary,
               csr_curve = csr_df, inhom_curves = inhom, intensity_diagnostics = intensity_diagnostics)
for (name in names(tables)) readr::write_csv(tables[[name]], file.path(out_dir, paste0(name, ".csv")))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "session-info.txt"))
versions <- data.frame(package = required, version = vapply(required, function(p) as.character(packageVersion(p)), character(1)))
readr::write_csv(versions, file.path(out_dir, "package-versions.csv"))
saveRDS(list(summary = summary, tables = tables), file.path(out_dir, "report-results.rds"))
cat(jsonlite::toJSON(summary, pretty = TRUE, auto_unbox = TRUE, digits = 6), "\n")
