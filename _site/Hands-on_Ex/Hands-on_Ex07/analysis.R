# Hands-on Exercise 7: eldercare accessibility using the supplied OD network.
# Run from the ISS626-VAA project root in a fresh RStudio session.
source("Hands-on_Ex/Hands-on_Ex07/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(SpatialAcc)
  library(ggplot2)
  library(tmap)
})
forest07 <- "#315747"
copper07 <- "#9b5a40"
gold07 <- "#a18449"
palette07 <- c("#ecebdc", "#b9cbaa", "#70937b", forest07)

# The three Chapter 17 measures answer different questions and have different
# scales. D is in kilometres; the origin and destination vectors exactly match
# its rows and columns because prepare.R checks fid order explicitly.
stopifnot(identical(rownames(distmat_km07), as.character(hex07$fid)),
          identical(colnames(distmat_km07), as.character(elder07$fid)))
hansen07 <- SpatialAcc::ac(hex07$demand, elder07$capacity, distmat_km07,
                           power = 0.5, family = "Hansen")
kd5_07 <- SpatialAcc::ac(hex07$demand, elder07$capacity, distmat_km07,
                         d0 = 5, power = 2, family = "KD2SFCA")
sam07 <- SpatialAcc::ac(hex07$demand, elder07$capacity, distmat_km07,
                        power = 2, family = "SAM")
kd10_07 <- SpatialAcc::ac(hex07$demand, elder07$capacity, distmat_km07,
                          d0 = 10, power = 2, family = "KD2SFCA")
stopifnot(all(vapply(list(hansen07, kd5_07, sam07, kd10_07),
                     function(x) length(x) == nrow(hex07) &&
                       all(is.finite(x) & x >= 0), logical(1))))
nearest07 <- apply(distmat_km07, 1, min)
reachable5_07 <- rowSums(distmat_km07 <= 5)
reachable10_07 <- rowSums(distmat_km07 <= 10)
stopifnot(all((kd5_07 == 0) == (reachable5_07 == 0)),
          all((kd10_07 == 0) == (reachable10_07 == 0)))
score07 <- tibble(fid = hex07$fid,
                  Hansen = as.numeric(hansen07),
                  KD2SFCA_5km = as.numeric(kd5_07),
                  SAM = as.numeric(sam07),
                  KD2SFCA_10km = as.numeric(kd10_07),
                  nearest_km = as.numeric(nearest07),
                  centres_within_5km = as.integer(reachable5_07),
                  centres_within_10km = as.integer(reachable10_07))
hex_access07 <- left_join(hex07, score07, by = "fid",
                          relationship = "one-to-one")
stopifnot(nrow(hex_access07) == nrow(hex07),
          !anyNA(hex_access07$Hansen))

# Assign a region using one representative point per hexagon. A polygon
# intersection can duplicate origins that straddle subzone boundaries.
hex_point07 <- suppressWarnings(st_point_on_surface(hex_access07))
regions07 <- st_join(hex_point07, select(mpsz07, REGION_N),
                     join = st_intersects, left = TRUE) |>
  st_drop_geometry() |>
  select(fid, REGION_N)
stopifnot(nrow(regions07) == nrow(hex07), !anyDuplicated(regions07$fid))
score07 <- left_join(score07, regions07, by = "fid",
                     relationship = "one-to-one")
region07 <- score07 |>
  filter(!is.na(REGION_N)) |>
  group_by(REGION_N) |>
  summarise(hexagons = n(),
            median_Hansen = median(Hansen),
            median_KD2SFCA_5km = median(KD2SFCA_5km),
            zero_KD2SFCA_5km = sum(KD2SFCA_5km == 0),
            median_SAM = median(SAM),
            median_nearest_km = median(nearest_km),
            .groups = "drop") |>
  arrange(desc(median_Hansen))
write_csv(region07, file.path(out07, "region-summary.csv"))
summary07 <- tibble(
  measure = c("Subzones", "Hexagon origins", "Eldercare destinations",
              "Complete origin-destination pairs", "Hexagons outside region polygons",
              "Hexagons with no centre within 5 km",
              "Hexagons with no centre within 10 km",
              "Median nearest-network distance (km)",
              "Maximum nearest-network distance (km)",
              "Hansen median", "KD2SFCA 5 km median", "SAM median"),
  value = c(nrow(mpsz07), nrow(hex07), nrow(elder07), nrow(od07),
            sum(is.na(score07$REGION_N)), sum(kd5_07 == 0),
            sum(kd10_07 == 0), median(nearest07), max(nearest07),
            median(hansen07), median(kd5_07), median(sam07)))
write_csv(summary07, file.path(out07, "summary.csv"))
cor07 <- cor(score07[c("Hansen", "KD2SFCA_5km", "SAM")],
             method = "spearman")
cor_table07 <- tibble(
  pair = c("Hansen vs KD2SFCA", "Hansen vs SAM", "KD2SFCA vs SAM"),
  spearman_rho = c(cor07["Hansen", "KD2SFCA_5km"],
                   cor07["Hansen", "SAM"],
                   cor07["KD2SFCA_5km", "SAM"]))
write_csv(cor_table07, file.path(out07, "rank-correlations.csv"))

# Thematic maps retain each method's own numeric scale. A common rank map
# below is for comparing relative positions, not the units of the scores.
tmap_mode("plot")
make_map07 <- function(field, title, legend) {
  tm_shape(hex_access07) +
    tm_polygons(fill = field,
      fill.scale = tm_scale_continuous(values = palette07),
      fill.legend = tm_legend(title = legend),
      col = "#fffdf7", lwd = 0.08) +
    tm_shape(elder07) +
    tm_dots(fill = copper07, col = "#392e2b", size = 0.045,
            lwd = 0.2) +
    tm_title(title, size = 1.15) +
    tm_layout(frame = FALSE, legend.outside = TRUE)
}
tmap_save(make_map07("Hansen", "Hansen potential", "Hansen score"),
          file.path(fig07, "hansen-map.png"),
          width = 1700, height = 1250, units = "px", dpi = 170)
tmap_save(make_map07("KD2SFCA_5km", "KD2SFCA, 5 km", "Capacity / demand"),
          file.path(fig07, "kd2sfca-map.png"),
          width = 1700, height = 1250, units = "px", dpi = 170)
tmap_save(make_map07("SAM", "Spatial accessibility measure", "SAM score"),
          file.path(fig07, "sam-map.png"),
          width = 1700, height = 1250, units = "px", dpi = 170)

rank07 <- score07 |>
  select(fid, Hansen, KD2SFCA_5km, SAM) |>
  pivot_longer(-fid, names_to = "method", values_to = "score") |>
  group_by(method) |>
  mutate(percentile = percent_rank(score) * 100) |>
  ungroup()
rank_map07 <- left_join(hex07, rank07, by = "fid",
                        relationship = "one-to-many")
rank_plot07 <- ggplot(rank_map07) +
  geom_sf(aes(fill = percentile), colour = NA) +
  facet_wrap(~method, nrow = 1,
             labeller = as_labeller(c(Hansen = "Hansen",
                                    KD2SFCA_5km = "KD2SFCA (5 km)",
                                    SAM = "SAM"))) +
  scale_fill_gradient(low = "#ecebdc", high = forest07,
                      limits = c(0, 100), name = "Within-method\npercentile") +
  labs(title = "Relative accessibility depends on the measure",
       subtitle = "Ranks are within each method; they do not make score units equal") +
  theme_void(base_size = 13) +
  theme(strip.text = element_text(face = "bold", size = 12),
        legend.position = "bottom")
ggsave(file.path(fig07, "method-ranks.png"), rank_plot07,
       width = 14, height = 6.5, dpi = 180, bg = "white")

region_long07 <- rank07 |>
  left_join(regions07, by = "fid", relationship = "many-to-one") |>
  filter(!is.na(REGION_N)) |>
  mutate(method = factor(method,
                         levels = c("Hansen", "KD2SFCA_5km", "SAM"),
                         labels = c("Hansen", "KD2SFCA, 5 km", "SAM")))
region_plot07 <- ggplot(region_long07,
                        aes(x = REGION_N, y = percentile)) +
  geom_boxplot(fill = "#b9cbaa", colour = forest07,
               outlier.alpha = .2, linewidth = .35) +
  stat_summary(fun = mean, geom = "point", shape = 18,
               size = 2.2, colour = copper07) +
  facet_wrap(~method, ncol = 1) +
  coord_flip() +
  labs(title = "Accessibility varies within planning regions",
       subtitle = "Centre points are means; boxes show the distribution of hexagons",
       x = NULL, y = "Within-method percentile (0 = lowest, 100 = highest)") +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))
ggsave(file.path(fig07, "region-boxplots.png"), region_plot07,
       width = 10, height = 10, dpi = 180, bg = "white")

catch07 <- score07 |>
  mutate(catchment = case_when(
    centres_within_5km > 0 ~ "Within 5 km",
    centres_within_10km > 0 ~ "5-10 km only",
    TRUE ~ "Beyond 10 km"),
    catchment = factor(catchment,
                       levels = c("Within 5 km", "5-10 km only",
                                  "Beyond 10 km"))) |>
  count(catchment, name = "hexagons")
write_csv(catch07, file.path(out07, "catchment-counts.csv"))
catch_plot07 <- ggplot(catch07, aes(catchment, hexagons, fill = catchment)) +
  geom_col(width = .65) +
  geom_text(aes(label = scales::comma(hexagons)), vjust = -.4) +
  scale_fill_manual(values = c(forest07, gold07, copper07), guide = "none") +
  expand_limits(y = max(catch07$hexagons) * 1.12) +
  labs(title = "Reachable eldercare centres by network distance",
       x = NULL, y = "Hexagons") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig07, "catchment-counts.png"), catch_plot07,
       width = 8, height = 4.8, dpi = 180, bg = "white")

writeLines(capture.output(sessionInfo()), file.path(out07, "session-info.txt"))
print(summary07)
print(region07)
print(cor_table07)
message("Hands-on Exercise 7: three accessibility measures and figures complete.")
