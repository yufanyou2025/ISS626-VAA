# In-class Exercise 7: floating catchment measures for eldercare access.
# Run from the ISS626-VAA project root in a clean RStudio session.
# The shared preparation script validates the supplied ZIP and aligns its OD
# matrix rows/columns with hexagon and eldercare fid values.
source("Hands-on_Ex/Hands-on_Ex07/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(accessibility)
  library(catchment)
  library(ggplot2)
  library(tmap)
})

exercise07 <- "In-class_Ex/In-class_Ex07"
figures07 <- file.path(exercise07, "figures")
outputs07 <- file.path(exercise07, "outputs")
dir.create(figures07, recursive = TRUE, showWarnings = FALSE)
dir.create(outputs07, recursive = TRUE, showWarnings = FALSE)

# The OD destination IDs refer to eldercare centres. The slide example passes
# hexagon demand as land_use_data for cost_to_closest(), which mismatches the
# destination meaning. Supply the centre table with id and capacity instead.
travel07 <- od07 |>
  transmute(from_id = origin_id, to_id = destination_id,
            dist = total_cost)
centres07 <- elder07 |>
  st_drop_geometry() |>
  transmute(id = fid, capacity)
closest07 <- accessibility::cost_to_closest(
  travel_matrix = travel07,
  land_use_data = centres07,
  opportunity = "capacity",
  travel_cost = "dist",
  n = 1,
  group_by = character(0),
  active = TRUE,
  fill_missing_ids = TRUE
)
closest07 <- closest07[match(hex07$fid, closest07$id), ]
stopifnot(nrow(closest07) == nrow(hex07),
          identical(as.character(closest07$id), as.character(hex07$fid)),
          isTRUE(all.equal(as.numeric(closest07$dist / 1000),
                           as.numeric(apply(distmat_km07, 1, min)),
                           tolerance = 1e-9)))

# Chapter/slide parameters. Distance is in kilometres. The first four
# catchment methods are limited to five kilometres by max_cost or the
# outermost step. Gaussian uses scale=2 km with no hard cutoff.
step_weights07 <- list(c(5, 0.01), c(4, 0.05), c(3, 0.1),
                       c(2, 0.4), c(1, 1))
run_ratio07 <- function(...) {
  result <- as.numeric(catchment::catchment_ratio(
    consumers = hex07$demand,
    providers = elder07$capacity,
    cost = distmat_km07,
    ...))
  stopifnot(length(result) == nrow(hex07),
            all(is.finite(result) & result >= 0))
  result
}
two07 <- run_ratio07(max_cost = 5)
enhanced07 <- run_ratio07(weight = step_weights07)
gaussian07 <- run_ratio07(weight = "gaussian", scale = 2)
three07 <- run_ratio07(weight = step_weights07,
                      normalize_weight = TRUE)
modified07 <- run_ratio07(weight = step_weights07,
                         adjust_providers = function(w) w^2)
reachable07 <- rowSums(distmat_km07 < 5)
stopifnot(all((two07 == 0) == (reachable07 == 0)),
          all((enhanced07 == 0) == (reachable07 == 0)),
          all((three07 == 0) == (reachable07 == 0)),
          all((modified07 == 0) == (reachable07 == 0)))

scores07 <- tibble(
  fid = hex07$fid,
  nearest_km = closest07$dist / 1000,
  Two_SFCA = two07,
  Enhanced_2SFCA = enhanced07,
  Gaussian_KD2SFCA = gaussian07,
  Three_SFCA = three07,
  Modified_2SFCA = modified07
)
hex_scores07 <- left_join(hex07, scores07, by = "fid",
                          relationship = "one-to-one")
stopifnot(nrow(hex_scores07) == nrow(hex07),
          !anyNA(hex_scores07$nearest_km))

method_names07 <- c(
  Two_SFCA = "2SFCA (5 km)",
  Enhanced_2SFCA = "Enhanced 2SFCA",
  Gaussian_KD2SFCA = "Gaussian KD2SFCA",
  Three_SFCA = "3SFCA",
  Modified_2SFCA = "Modified 2SFCA"
)
metric07 <- function(x, name) tibble(
  measure = name,
  minimum = min(x),
  median = median(x),
  p90 = as.numeric(quantile(x, .9)),
  maximum = max(x),
  zeros = sum(x == 0)
)
summary07 <- bind_rows(
  metric07(scores07$nearest_km, "Nearest centre (km)"),
  bind_rows(lapply(names(method_names07), function(name)
    metric07(scores07[[name]], unname(method_names07[name]))))
)
write_csv(summary07, file.path(outputs07, "method-summary.csv"))

# One representative point assigns an origin to a single planning region.
# Origins outside the supplied subzone coverage remain on the maps.
origin_points07 <- suppressWarnings(st_point_on_surface(hex_scores07))
origin_region07 <- st_join(origin_points07,
                           select(mpsz07, REGION_N),
                           join = st_intersects, left = TRUE) |>
  st_drop_geometry() |>
  select(fid, REGION_N)
stopifnot(nrow(origin_region07) == nrow(hex07),
          !anyDuplicated(origin_region07$fid))
scores07 <- left_join(scores07, origin_region07, by = "fid",
                      relationship = "one-to-one")
region07 <- scores07 |>
  filter(!is.na(REGION_N)) |>
  group_by(REGION_N) |>
  summarise(hexagons = n(),
            median_nearest_km = median(nearest_km),
            zero_2sfca = sum(Two_SFCA == 0),
            median_2sfca = median(Two_SFCA),
            median_enhanced = median(Enhanced_2SFCA),
            median_gaussian = median(Gaussian_KD2SFCA),
            median_3sfca = median(Three_SFCA),
            median_modified = median(Modified_2SFCA),
            .groups = "drop") |>
  arrange(median_nearest_km)
write_csv(region07, file.path(outputs07, "region-summary.csv"))

correlation07 <- cor(scores07[names(method_names07)],
                     method = "spearman")
correlation_table07 <- as.data.frame(as.table(correlation07)) |>
  as_tibble() |>
  rename(method_a = Var1, method_b = Var2, rho = Freq) |>
  filter(as.integer(method_a) < as.integer(method_b))
write_csv(correlation_table07,
          file.path(outputs07, "method-rank-correlations.csv"))

audit07 <- tibble(
  check = c("Subzones", "Hexagon origins", "Eldercare destinations",
            "OD pairs", "Invalid subzones repaired",
            "Missing or duplicate OD pairs", "Unassigned planning regions",
            "Distance unit", "Demand / capacity assumption",
            "Catchment limit", "Gaussian scale"),
  result = c(nrow(mpsz07), nrow(hex07), nrow(elder07), nrow(od07),
             valid_before07[1], 0, sum(is.na(scores07$REGION_N)),
             "network kilometres", "100 per origin / 100 per centre",
             "5 km (four bounded methods)", "2 km (no hard cutoff)")
)
write_csv(audit07, file.path(outputs07, "input-and-model-audit.csv"))

# Individual tmap figures follow the slide sequence. A continuous legend is
# used because 1,281 tied zeros make quantile classes misleading or unstable.
forest07 <- "#315747"
copper07 <- "#9b5a40"
palette07 <- c("#eeeade", "#c7d1b3", "#98b39a", "#648c73", forest07)
tmap_mode("plot")
map07 <- function(field, title, legend, reverse = FALSE) {
  values <- if (reverse) c("#f0e8de", "#ddbba5", "#bd846b", "#8f493c")
            else palette07
  tm_shape(hex_scores07) +
    tm_polygons(fill = field,
      fill.scale = tm_scale_continuous(values = values),
      fill.legend = tm_legend(title = legend),
      col = "#fffdf7", lwd = 0.07) +
    tm_shape(elder07) +
    tm_dots(fill = copper07, col = "#392e2b", size = 0.04,
            lwd = 0.2) +
    tm_title(title, size = 1.1) +
    tm_layout(frame = FALSE, legend.outside = TRUE)
}
map_specs07 <- list(
  list("nearest_km", "Nearest eldercare centre", "Network km", "nearest-centre.png", TRUE),
  list("Two_SFCA", "2SFCA, 5 km", "Capacity / demand", "2sfca.png", FALSE),
  list("Enhanced_2SFCA", "Enhanced 2SFCA", "Weighted ratio", "enhanced-2sfca.png", FALSE),
  list("Gaussian_KD2SFCA", "Gaussian KD2SFCA", "Weighted ratio", "gaussian-kd2sfca.png", FALSE),
  list("Three_SFCA", "3SFCA", "Weighted ratio", "3sfca.png", FALSE),
  list("Modified_2SFCA", "Modified 2SFCA", "Weighted ratio", "modified-2sfca.png", FALSE)
)
for (spec in map_specs07) {
  tmap_save(map07(spec[[1]], spec[[2]], spec[[3]], spec[[5]]),
            file.path(figures07, spec[[4]]),
            width = 1700, height = 1250, units = "px", dpi = 170)
}

# A common percentile scale helps compare relative geography, without
# claiming that the five raw scores have the same units or distribution.
rank07 <- scores07 |>
  select(fid, all_of(names(method_names07))) |>
  pivot_longer(-fid, names_to = "method", values_to = "score") |>
  group_by(method) |>
  mutate(percentile = percent_rank(score) * 100) |>
  ungroup() |>
  mutate(method = factor(method, levels = names(method_names07),
                         labels = unname(method_names07)))
rank_map07 <- left_join(hex07, rank07, by = "fid",
                        relationship = "one-to-many")
rank_plot07 <- ggplot(rank_map07) +
  geom_sf(aes(fill = percentile), colour = NA) +
  facet_wrap(~method, ncol = 3) +
  scale_fill_gradient(low = "#eeeade", high = forest07,
                      limits = c(0, 100),
                      name = "Within-method\npercentile") +
  labs(title = "How the catchment rule changes relative accessibility",
       subtitle = "Percentiles are calculated separately for each method") +
  theme_void(base_size = 13) +
  theme(strip.text = element_text(face = "bold"),
        legend.position = "bottom")
ggsave(file.path(figures07, "method-percentiles.png"), rank_plot07,
       width = 13, height = 8.5, dpi = 180, bg = "white")

region_ranks07 <- rank07 |>
  left_join(origin_region07, by = "fid", relationship = "many-to-one") |>
  filter(!is.na(REGION_N))
region_plot07 <- ggplot(region_ranks07,
                        aes(x = REGION_N, y = percentile)) +
  geom_boxplot(fill = "#b9cbaa", colour = forest07,
               outlier.alpha = .18, linewidth = .3) +
  facet_wrap(~method, ncol = 2) +
  coord_flip() +
  labs(title = "Regional distributions are wider than one median",
       x = NULL, y = "Within-method percentile") +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))
ggsave(file.path(figures07, "region-percentiles.png"), region_plot07,
       width = 12, height = 10, dpi = 180, bg = "white")

nearest_plot07 <- ggplot(scores07, aes(x = nearest_km)) +
  geom_histogram(binwidth = 1, fill = forest07,
                 colour = "#fffdf7", boundary = 0) +
  geom_vline(xintercept = 5, linetype = "dashed", colour = copper07,
             linewidth = .9) +
  labs(title = "Nearest-centre network distance",
       subtitle = "Dashed line marks the five-kilometre catchment",
       x = "Kilometres", y = "Hexagons") +
  theme_minimal(base_size = 13)
ggsave(file.path(figures07, "nearest-distance-distribution.png"),
       nearest_plot07, width = 9, height = 5.2, dpi = 180, bg = "white")

writeLines(trimws(capture.output(sessionInfo()), which = "right"),
           file.path(outputs07, "session-info.txt"))
print(summary07)
print(region07)
message("In-class Exercise 7: six maps and comparison figures complete.")
