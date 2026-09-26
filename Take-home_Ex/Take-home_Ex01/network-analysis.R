## ---- network-setup ----
# Focused road-network case study, run after analysis.R from the repository root.
# The focus centre is the planar 3 km KDE peak; this choice is exploratory.
for (pkg in c("spNetwork", "igraph", "leaflet", "htmlwidgets")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Install required package: ", pkg)
}
road_file <- file.path(base_dir, "data/network/bangkok-focus-roads.geojson")
road_hash <- digest::digest(file = road_file, algo = "sha256")
stopifnot(road_hash == "23241c1439a8bd885177636d531269e853fa329ceff23a61aa76faf17784d35f")
road_all <- st_read(road_file, quiet = TRUE)
stopifnot(st_crs(road_all)$epsg == 32647, all(st_is_valid(road_all)))
road_graph <- igraph::graph_from_data_frame(
  st_drop_geometry(road_all)[, c("start_node", "end_node")], directed = FALSE)
road_components <- igraph::components(road_graph)
edge_component <- road_components$membership[
  match(road_all$start_node, names(road_components$membership))]
road_main <- road_all[edge_component == which.max(road_components$csize),
                      c("way_id", "road_class")]

focus_centre <- st_transform(st_sfc(st_point(unname(peak_ll)), crs = 4326), 32647)
focus_xy <- st_coordinates(focus_centre)[1, ]
focus_box <- st_as_sfc(st_bbox(c(
  xmin = unname(focus_xy[1] - 4000), ymin = unname(focus_xy[2] - 4000),
  xmax = unname(focus_xy[1] + 4000), ymax = unname(focus_xy[2] + 4000)
), crs = st_crs(road_main)))
point_xy <- st_coordinates(pts)
focus_events <- pts[abs(point_xy[, 1] - focus_xy[1]) <= 4000 &
                      abs(point_xy[, 2] - focus_xy[2]) <= 4000, ]
stopifnot(nrow(focus_events) >= 10L)
nearest_road <- st_nearest_feature(focus_events, road_main)
snap_metres <- as.numeric(st_distance(focus_events, road_main[nearest_road, ],
                                      by_element = TRUE))
# Explicit threshold avoids silently treating off-road records as exact road events.
focus_on_road <- focus_events[snap_metres <= 100, ]
road_display <- road_main[lengths(st_intersects(road_main, focus_box)) > 0, ]
road_focus <- suppressWarnings(st_intersection(road_display, focus_box))
road_focus <- st_collection_extract(road_focus, "LINESTRING")
road_focus <- suppressWarnings(st_cast(road_focus, "LINESTRING"))
road_focus <- road_focus[as.numeric(st_length(road_focus)) > 0.01, ]
stopifnot(nrow(focus_on_road) > 0, nrow(road_focus) > 0)

## ---- network-first-order ----
# Chapter 7's lixel-centre workflow. A 700 m bandwidth is an exploratory local
# scale for the sparse 22-record subset, not an automatically selected optimum.
lixels <- spNetwork::lixelize_lines(road_display, 700, mindist = 250)
sample_all <- spNetwork::lines_center(lixels)
# A network route cannot be shorter than its Euclidean distance. Thus samples
# farther than the bandwidth from every event have zero compact-kernel weight.
sample_near <- lengths(st_is_within_distance(sample_all, focus_on_road, dist = 700)) > 0
samples <- sample_all[sample_near, ]
map_lixels <- lixels[sample_near, ]
stopifnot(nrow(samples) == nrow(map_lixels), nrow(samples) > 0)
nkde_start <- Sys.time()
density_m <- spNetwork::nkde(
  road_main, events = focus_on_road, w = rep(1, nrow(focus_on_road)),
  samples = samples, kernel_name = "quartic", bw = 700, div = "bw",
  adaptive = FALSE, method = "continuous", digits = 1, tol = 1,
  max_depth = 8, agg = 5, sparse = TRUE, grid_shape = c(2, 2), verbose = FALSE)
nkde_seconds <- as.numeric(difftime(Sys.time(), nkde_start, units = "secs"))
stopifnot(length(density_m) == nrow(map_lixels), all(is.finite(density_m)),
          all(density_m >= 0))
map_lixels$density_km <- density_m * 1000
map_lixels <- map_lixels[map_lixels$density_km > 0, ]

plot_base <- ggplot() +
  geom_sf(data = road_display, colour = "#ced4d9", linewidth = 0.12) +
  coord_sf(xlim = unname(focus_xy[1] + c(-4000, 4000)),
           ylim = unname(focus_xy[2] + c(-4000, 4000)), expand = FALSE, datum = NA) +
  theme_void() + theme(plot.title = element_text(colour = "#20394f"),
                       plot.caption = element_text(hjust = 0))
network_points_plot <- plot_base +
  geom_sf(data = road_display, colour = "#333b43", linewidth = 0.18) +
  geom_sf(data = focus_on_road, colour = "#121820", fill = "#121820", size = 1.4) +
  labs(title = "Roads and located fatality records in the central Bangkok focus",
       subtitle = sprintf("8 × 8 km display · %d records within 100 m of the mapped road component",
                          nrow(focus_on_road)),
       caption = "Roads: © OpenStreetMap contributors (ODbL), snapshot 26 September 2026.\nPoints: Kaggle / DDC compilation, confirmed deaths January–September 2024. CRS: EPSG:32647.")
save_plot(network_points_plot, "network-points.png", width = 10, height = 8)

network_density_plot <- plot_base +
  geom_sf(data = map_lixels, aes(colour = density_km), linewidth = 0.55) +
  geom_sf(data = focus_on_road, colour = "#111827", size = 1.0, alpha = 0.8) +
  scale_colour_viridis_c(option = "B", begin = 0.12, end = 0.95,
                         trans = "sqrt", name = "Records / network km") +
  labs(title = "Recorded fatalities concentrate along parts of the street network",
       subtitle = "Continuous network KDE · quartic kernel · 700 m route bandwidth · 700 m lixel target",
       caption = "Black dots are the included fatality records. Density is per road kilometre over the observed nine months.\nRoads: © OpenStreetMap contributors (ODbL), 26 September 2026; points: Kaggle / DDC compilation.")
save_plot(network_density_plot, "network-nkde.png", width = 11, height = 8)
save_plot(network_density_plot + labs(title = NULL, subtitle = NULL, caption = NULL) +
            theme(text = element_text(size = 16), legend.text = element_text(size = 12)),
          "slide-network-nkde.png", width = 12, height = 5.5)

# A small precision check follows Gelb's max_depth discussion. Values at 100
# systematically selected locations in lixel-list order are compared.
depth_ids <- unique(round(seq(1, nrow(samples), length.out = 100)))
density_depth10 <- spNetwork::nkde(
  road_main, events = focus_on_road, w = rep(1, nrow(focus_on_road)),
  samples = samples[depth_ids, ], kernel_name = "quartic", bw = 700, div = "bw",
  adaptive = FALSE, method = "continuous", digits = 1, tol = 1,
  max_depth = 10, agg = 5, sparse = TRUE, grid_shape = c(2, 2), verbose = FALSE)
depth_mae_km <- mean(abs(density_m[depth_ids] - density_depth10)) * 1000
depth_max_abs_km <- max(abs(density_m[depth_ids] - density_depth10)) * 1000

## ---- network-second-order ----
# The simulation window is the clipped inner road network, matching the event
# selection window. The OSM extract extends another ~1 km for the KDE buffer.
set.seed(20260926)
network_k <- spNetwork::kfunctions(
  road_focus, focus_on_road, start = 0, end = 1500, step = 100,
  width = 100, nsim = 39, conf_int = 0.05, digits = 1, tol = 1,
  resolution = 100, agg = 5, verbose = FALSE, calc_g_func = TRUE)
k_values <- network_k$values
kg_curves <- bind_rows(
  data.frame(distance_km = k_values$distances / 1000,
             observed = k_values$obs_k / 1000, lower = k_values$lower_k / 1000,
             upper = k_values$upper_k / 1000, function_name = "Network K"),
  data.frame(distance_km = k_values$distances / 1000,
             observed = k_values$obs_g / 1000, lower = k_values$lower_g / 1000,
             upper = k_values$upper_g / 1000, function_name = "Network G"))
network_kg_plot <- ggplot(kg_curves, aes(distance_km, observed)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#dbeafe") +
  geom_line(colour = "#142e52", linewidth = 1) +
  facet_wrap(~function_name, scales = "free_y") +
  labs(title = "Network K and G compared with uniform points on the same roads",
       subtitle = "39 fixed-count simulations · pointwise 95% Monte Carlo bands",
       x = "Route distance (km)", y = "Network function value (km)",
       caption = "The bands are exploratory pointwise comparisons, not a global test.\nData: Kaggle / DDC; roads: © OpenStreetMap contributors (ODbL).")
save_plot(network_kg_plot, "network-kg.png", width = 11, height = 5.5)
save_plot(network_kg_plot + labs(title = NULL, subtitle = NULL, caption = NULL) +
            theme(text = element_text(size = 17)),
          "slide-network-kg.png", width = 12, height = 5.5)

## ---- network-outputs ----
network_summary <- list(
  road_snapshot = "2026-09-26T13:27:05Z", road_edges_total = nrow(road_all),
  road_edges_largest_component = nrow(road_main),
  road_edges_focus = nrow(road_focus),
  road_length_focus_km = sum(as.numeric(st_length(road_focus))) / 1000,
  focus_records = nrow(focus_events), snap_accepted = nrow(focus_on_road),
  snap_excluded = nrow(focus_events) - nrow(focus_on_road),
  snap_median_m = median(snap_metres), snap_max_m = max(snap_metres),
  lixels = nrow(lixels), sampled_lixels = nrow(samples),
  nonzero_lixels = nrow(map_lixels), bandwidth_m = 700,
  nkde_max_records_per_km = max(map_lixels$density_km),
  nkde_runtime_seconds = nkde_seconds,
  depth_comparison_samples = length(depth_ids), depth_mae_per_km = depth_mae_km,
  depth_max_abs_per_km = depth_max_abs_km,
  network_k_simulations = 39, network_k_seed = 20260926,
  k_above_upper = sum(k_values$obs_k > k_values$upper_k),
  g_above_upper = sum(k_values$obs_g > k_values$upper_g))
jsonlite::write_json(network_summary, file.path(out_dir, "network-summary.json"),
                     pretty = TRUE, auto_unbox = TRUE, digits = 10)
readr::write_csv(k_values, file.path(out_dir, "network-kg.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "session-info.txt"))
network_versions <- data.frame(package = c("spNetwork", "igraph", "leaflet", "htmlwidgets"),
                               version = vapply(c("spNetwork", "igraph", "leaflet", "htmlwidgets"),
                                                function(p) as.character(packageVersion(p)), character(1)))
versions <- bind_rows(versions, network_versions)
readr::write_csv(versions, file.path(out_dir, "package-versions.csv"))

# Two switchable layers mirror the chapter's point and lixel visualisations.
road_view <- st_transform(road_display, 4326)
density_view <- st_transform(map_lixels, 4326)
event_view <- st_transform(focus_on_road, 4326)
road_palette <- leaflet::colorBin(c("#d7e9fc", "#a9d0f3", "#74b4e8", "#3787cc", "#184e91"),
                                  domain = density_view$density_km,
                                  bins = c(0, 0.0004, 0.0008, 0.0012, 0.0016, 0.002),
                                  right = FALSE)
network_map <- leaflet::leaflet(options = leaflet::leafletOptions(zoomControl = TRUE)) |>
  leaflet::addTiles() |>
  leaflet::addPolylines(data = road_view, color = "#9aa3ad", weight = 0.65,
                        opacity = 0.65, group = "Road network") |>
  leaflet::addPolylines(data = density_view, color = ~road_palette(density_km),
                        weight = 2.1, opacity = 0.94, group = "Network density") |>
  leaflet::addCircleMarkers(data = event_view, radius = 3.2, color = "#111827",
                            fillColor = "#111827", fillOpacity = 0.95,
                            stroke = TRUE, weight = 0.7, group = "Fatality records") |>
  leaflet::addLayersControl(
    overlayGroups = c("Road network", "Network density", "Fatality records"),
    options = leaflet::layersControlOptions(collapsed = FALSE)) |>
  leaflet::addLegend(pal = road_palette, values = density_view$density_km,
                     title = "Records / network km", opacity = 1,
                     labFormat = leaflet::labelFormat(digits = 4),
                     position = "bottomright") |>
  leaflet::fitBounds(lng1 = min(st_coordinates(st_transform(focus_box, 4326))[, 1]),
                     lat1 = min(st_coordinates(st_transform(focus_box, 4326))[, 2]),
                     lng2 = max(st_coordinates(st_transform(focus_box, 4326))[, 1]),
                     lat2 = max(st_coordinates(st_transform(focus_box, 4326))[, 2]))
