# Publication figures: run after analysis.R, from the Quarto project root.
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(readr); library(scales)
})
root03 <- "Take-home_Ex/Take-home_Ex03"
fig03 <- file.path(root03, "figures")
dir.create(fig03, recursive = TRUE, showWarnings = FALSE)
v03 <- readRDS(file.path(root03, "outputs/report-results.rds"))
st03 <- v03$stations
or03 <- v03$origins
forest03 <- "#315747"; copper03 <- "#ad6243"; gold03 <- "#a18449"
theme_set(theme_minimal(base_size = 12, base_family = "sans") +
  theme(plot.title = element_text(face = "bold", colour = "#263c30", size = 17),
        plot.subtitle = element_text(colour = "#5e655f", size = 11),
        plot.caption = element_text(size = 9, hjust = 0, colour = "#62675e"),
        panel.grid.minor = element_blank(), legend.position = "bottom"))
save03 <- function(p, name, w = 10, h = 6.4) {
  ggsave(file.path(fig03, paste0(name, ".png")), p, width = w, height = h,
         dpi = 180, bg = "#faf8f1")
  slide_plot <- p + labs(title = NULL, subtitle = NULL, caption = NULL) +
    theme(text = element_text(size = 16), axis.title = element_text(size = 14),
          axis.text = element_text(size = 13), legend.text = element_text(size = 13),
          legend.title = element_text(size = 13), plot.margin = margin(10, 24, 10, 10))
  ggsave(file.path(fig03, paste0("slide-", name, ".png")), slide_plot,
         width = 9, height = 5.7, dpi = 180, bg = "#faf8f1")
}
map03 <- function(title, subtitle) {
  ggplot() +
    geom_point(data = or03, aes(x / 1000, y / 1000), colour = "#d6d6ca", size = .7) +
    coord_equal() +
    labs(title = title, subtitle = subtitle, x = "SVY21 easting (km)",
         y = "SVY21 northing (km)",
         caption = "Sources: LTA station footprints (Sep 2026); pinned URA/LTA future coordinates; HDB dwelling-weighted origins.\nDistances are straight lines. Grey points show inhabited HDB model cells, not Singapore's land boundary.") +
    theme(panel.grid.major = element_line(colour = "#e6e3d8", linewidth = .2))
}

p <- map03("More stations, two different types of change",
           "January 2026 access sites + the brief's JRL 24 and CRL1 12 line-station labels") +
  geom_point(data = filter(st03, status == "existing"), aes(x/1000, y/1000, shape = "Existing access site"),
             colour = forest03, size = 1.3, alpha = .75) +
  geom_point(data = filter(st03, status == "new"), aes(x/1000, y/1000, shape = "New physical access site"),
             colour = copper03, size = 2.6, stroke = .9) +
  geom_point(data = filter(st03, status == "existing", lines_after > lines_before),
             aes(x/1000, y/1000, shape = "Existing interchange upgrade"),
             colour = gold03, size = 3.5, stroke = 1) +
  scale_shape_manual(values = c("Existing access site" = 16, "New physical access site" = 17,
                                "Existing interchange upgrade" = 1), name = NULL)
save03(p, "network")

existing03 <- st03 |> filter(status == "existing")
existing03$fold <- factor(v03$cv_predictions$fold[match(existing03$destination,
                                                    v03$cv_predictions$destination)],
                          levels = 1:4, labels = c("West", "Mid-west", "Mid-east", "East"))
p <- ggplot(existing03, aes(observed_daily, fitted_daily, colour = fold)) +
  geom_abline(slope = 1, intercept = 0, colour = "#807e71", linetype = 2) +
  geom_point(size = 2.2, alpha = .8) +
  scale_x_log10(labels = label_comma()) + scale_y_log10(labels = label_comma()) +
  scale_colour_manual(values = c(forest03, gold03, copper03, "#727e91"), name = "Longitude sector") +
  labs(title = "Can home locations explain morning station entries?",
       subtitle = "Fitted existing-station mean weekday entries, 06:00–09:59; both axes use a log scale",
       x = "Observed entries per morning", y = "Fitted entries per morning",
       caption = "Source: LTA January 2026 station-volume archive (21 non-holiday weekdays); aggregate-calibrated Huff model.\nThe dashed line is exact agreement. These are calibration results; geographic holdout performance is reported separately.")
save03(p, "model-fit", 9, 6.5)

p <- map03("Where the home-based model misses",
           "Existing station residual = log2(fitted / observed morning entries)") +
  geom_point(data = existing03,
             aes(x/1000, y/1000, colour = log2(pmax(fitted_daily, .01)/pmax(observed_daily, .01))), size = 2.4) +
  scale_colour_gradient2(low = "#5e7597", mid = "#eee5ca", high = copper03,
                        midpoint = 0, name = "Log2 ratio", limits = c(-4, 4), oob = squish) +
  labs(caption = "Sources: LTA Jan 2026 morning station entries; HDB dwelling-weighted Huff model.\n−1 means half the observed volume; +1 means twice. Colours beyond ±4 are capped. Missing private homes and employment trips matter.")
save03(p, "residual-map")

loss03 <- bind_rows(existing03 |> arrange(change_daily) |> slice_head(n = 8),
                    existing03 |> filter(change_daily > 0) |> arrange(desc(change_daily)) |> slice_head(n = 4)) |>
  mutate(station_name = reorder(station_name, change_daily))
p <- ggplot(loss03, aes(change_daily, station_name)) +
  geom_vline(xintercept = 0, colour = "#807e71") +
  geom_segment(aes(x = 0, xend = change_daily, yend = station_name), colour = "#bcab8d", linewidth = 1) +
  geom_point(aes(colour = change_daily > 0), size = 3, show.legend = FALSE) +
  scale_colour_manual(values = c(`FALSE` = copper03, `TRUE` = forest03)) +
  scale_x_continuous(labels = label_comma()) +
  labs(title = "Existing sites can gain as well as lose",
       subtitle = "Eight largest reductions and four largest increases after adding the specified lines",
       x = "Change in entries per weekday morning", y = NULL,
       caption = "Source: fitted Huff model, fixed January 2026 morning-entry total. Change = expanded scenario minus fitted baseline.\nThese differences describe access-station choice, not transfer flows, observed future losses or operating revenue.")
save03(p, "existing-change", 9.5, 6.5)

new03 <- st03 |> filter(status == "new") |> arrange(desc(expanded_daily)) |> slice_head(n = 12) |>
  mutate(station_name = reorder(station_name, expanded_daily))
p <- ggplot(new03, aes(expanded_daily, station_name)) +
  geom_col(fill = forest03, width = .68) + scale_x_continuous(labels = label_comma()) +
  labs(title = "New stations with the strongest modelled draw",
       subtitle = "Top twelve new physical access sites under a fixed household market",
       x = "Predicted entries per weekday morning", y = NULL,
       caption = "Source: aggregate-calibrated Huff scenario; JRL24 + CRL phase 1. Existing interchanges are excluded from this ranking.\nCurrent HDB dwelling weights are held fixed; future housing, jobs, service frequency and induced trips are not forecast.")
save03(p, "new-stations", 9.5, 6.5)

p <- map03("Which neighbourhoods turn towards the new sites?",
           "Probability that a modelled HDB origin chooses one of the 29 new physical access sites") +
  geom_point(data = or03, aes(x/1000, y/1000, colour = new_station_probability), size = 1.4) +
  scale_colour_gradientn(colours = c("#e4e5d8", "#b9c8a2", "#729478", forest03),
                         labels = label_percent(), name = "New-site probability") +
  geom_point(data = filter(st03, status == "new"), aes(x/1000, y/1000),
             shape = 17, colour = copper03, size = 1.8)
save03(p, "catchment-shift")

p <- map03("Access gain is different from switching stations",
           "250 m model cells: the nearest physical station crosses the 800 m screening threshold") +
  geom_point(data = filter(or03, nearest_before_m > 800, nearest_after_m <= 800),
             aes(x/1000, y/1000, size = market_potential), colour = forest03, alpha = .8) +
  geom_point(data = filter(st03, status == "new"), aes(x/1000, y/1000),
             shape = 17, colour = copper03, size = 1.8) +
  scale_size_continuous(range = c(.7, 3.5), name = "HDB dwellings", labels = label_comma()) +
  labs(caption = "Sources: HDB matched dwellings; LTA/URA station locations. Triangles = new station sites; grey = other HDB cells.\nMap uses grid centroids; headline totals use original building points. An 800 m straight-line screen does not verify walking access.")
save03(p, "access-gain")

# A self-contained station explorer keeps the report readable while allowing
# the reader to inspect every prediction, rather than just selected rankings.
suppressPackageStartupMessages(library(leaflet))
st03$popup03 <- paste0("<strong>", htmltools::htmlEscape(st03$station_name), "</strong><br>",
  htmltools::htmlEscape(st03$destination), "<br>Status: ", st03$status,
  "<br>Observed AM entries: ", ifelse(is.na(st03$observed_daily), "not open in baseline", comma(round(st03$observed_daily))),
  "<br>Fitted AM entries: ", ifelse(is.na(st03$fitted_daily), "new site", comma(round(st03$fitted_daily))),
  "<br>Expanded scenario: ", comma(round(st03$expanded_daily)),
  "<br>Rail lines: ", st03$lines_before, " → ", st03$lines_after)
pal03 <- colorFactor(c(forest03, copper03), domain = c("existing", "new"))
m03 <- leaflet(st03, options = leafletOptions(minZoom = 10)) |>
  addTiles(urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
           attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors') |>
  addCircleMarkers(lng = ~lon, lat = ~lat, radius = ~pmax(4, sqrt(expanded_daily)/18),
                   color = ~pal03(status), fillOpacity = .8, weight = 1,
                   popup = ~popup03, label = ~station_name) |>
  addLegend(position = "bottomright", pal = pal03, values = ~status, title = "Physical access sites") |>
  addControl("January 2026 weekday mornings · fixed-market scenario<br>Sources: LTA; HDB; URA/LTA coordinates", position = "bottomleft")
widget_cache03 <- file.path(root03, "cache")
dir.create(widget_cache03, recursive = TRUE, showWarnings = FALSE)
widget_file03 <- normalizePath(file.path(widget_cache03, "station-explorer.html"), mustWork = FALSE)
htmlwidgets::saveWidget(m03, widget_file03, selfcontained = TRUE)
stopifnot(file.copy(widget_file03, file.path(fig03, "station-explorer.html"), overwrite = TRUE))
message("Exercise 3 publication figures and station explorer written.")
