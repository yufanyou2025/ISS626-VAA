# Hands-on Exercise 5B: local spatial autocorrelation, Hunan GDPPC 2012.
# Run from the repository root in a clean R session.
# install.packages(c("sf", "sfdep", "spdep", "tmap", "dplyr",
#                    "readr", "ggplot2", "knitr"))
source("Hands-on_Ex/Hands-on_Ex05/prepare.R")
suppressPackageStartupMessages({
  library(sfdep)
  library(spdep)
  library(tmap)
  library(ggplot2)
})
fig5 <- file.path(ex05, "figures")
out5 <- file.path(ex05, "outputs")
tmap_mode("plot")
save_tm5b <- function(map, name, width = 2200, height = 1500) {
  tmap_save(map, file.path(fig5, paste0(name, ".png")),
            width = width, height = height, units = "px", dpi = 180)
}
forest5 <- c("#edf0e7", "#cbd8c0", "#9eb49d", "#64826e", "#2b5148")
map5 <- function(data, column, title, legend, style = "pretty",
                 n = 5, values = forest5) {
  tm_shape(data) +
    tm_polygons(fill = column,
      fill.scale = tm_scale_intervals(style = style, n = n, values = values),
      fill.legend = tm_legend(title = legend),
      col = "#fffdf7", lwd = .35) +
    tm_title(title, size = 1) + tm_layout(frame = FALSE, legend.outside = TRUE)
}
save_tm5b(tmap_arrange(
  map5(hunan_m, "GDPPC", "Equal intervals", "RMB per person", "equal"),
  map5(hunan_m, "GDPPC", "Quantile classes", "RMB per person", "quantile"),
  ncol = 2), "local-gdppc-classification")

# Queen contiguity reproduces the class slide's sfdep workflow.
nb5 <- st_contiguity(st_geometry(hunan_m), queen = TRUE)
wt5 <- st_weights(nb5, style = "W")
stopifnot(length(nb5) == 88, all(spdep::card(nb5) > 0),
          sum(spdep::card(nb5)) == 448,
          max(abs(vapply(wt5, sum, numeric(1)) - 1)) < 1e-12)
global5b <- global_moran(hunan_m$GDPPC, nb5, wt5)
stopifnot(abs(global5b$I - 0.3007499695) < 1e-6)
set.seed(62653)
local_raw <- local_moran(hunan_m$GDPPC, nb5, wt5,
                         alternative = "two.sided", nsim = 999)
stopifnot(nrow(local_raw) == nrow(hunan_m), all(is.finite(local_raw$ii)),
          all(local_raw$p_ii_sim >= 0 & local_raw$p_ii_sim <= 1))
local_lag <- st_lag(hunan_m$GDPPC, nb5, wt5)
z <- as.numeric(scale(hunan_m$GDPPC))
lag_z <- st_lag(z, nb5, wt5)
quadrant <- dplyr::case_when(
  z >= 0 & lag_z >= 0 ~ "High-High",
  z < 0 & lag_z < 0 ~ "Low-Low",
  z >= 0 & lag_z < 0 ~ "High-Low",
  TRUE ~ "Low-High"
)
local_raw$p_bh <- p.adjust(local_raw$p_ii_sim, method = "BH")
lisa <- hunan_m |>
  mutate(ii = local_raw$ii, p_ii = local_raw$p_ii,
         p_ii_sim = local_raw$p_ii_sim, p_bh = local_raw$p_bh,
         lag_GDPPC = local_lag, z_GDPPC = z, z_lag = lag_z,
         quadrant = quadrant,
         cluster = if_else(p_ii_sim <= .05, quadrant, "Not flagged"),
         cluster_bh = if_else(p_bh <= .05, quadrant, "Not flagged"))
cluster_levels <- c("Not flagged", "Low-Low", "Low-High",
                    "High-Low", "High-High")
lisa$cluster <- factor(lisa$cluster, levels = cluster_levels)
lisa$cluster_bh <- factor(lisa$cluster_bh, levels = cluster_levels)
local_table <- st_drop_geometry(lisa) |>
  select(County, NAME_2, GDPPC, ii, p_ii, p_ii_sim, p_bh,
         lag_GDPPC, z_GDPPC, z_lag, quadrant, cluster, cluster_bh)
write_csv(local_table, file.path(out5, "local-moran-results.csv"))
lisa_counts <- bind_rows(
  count(local_table, cluster, name = "count") |>
    mutate(rule = "Unadjusted two-sided permutation p <= 0.05",
           class = as.character(cluster)) |> select(rule, class, count),
  count(local_table, cluster_bh, name = "count") |>
    mutate(rule = "Benjamini-Hochberg q <= 0.05",
           class = as.character(cluster_bh)) |> select(rule, class, count))
write_csv(lisa_counts, file.path(out5, "lisa-class-counts.csv"))

diverging5 <- c("#9b5a40", "#d1a084", "#f0eee6", "#8eac9b", "#315747")
cluster_colours <- c("#e0ded6", "#315747", "#83a292",
                     "#d5ac85", "#9b5a40")
cluster_map <- function(col, title) {
  tm_shape(lisa) +
    tm_polygons(fill = col,
      fill.scale = tm_scale_categorical(values = cluster_colours),
      fill.legend = tm_legend(title = "Local class"),
      col = "#fffdf7", lwd = .35) +
    tm_title(title, size = 1) + tm_layout(frame = FALSE, legend.outside = TRUE)
}
save_tm5b(tmap_arrange(
  map5(lisa, "ii", "Local Moran's I", "Local I", values = diverging5),
  map5(lisa, "p_ii_sim", "Two-sided permutation p", "p value",
       values = rev(forest5)), ncol = 2), "lisa-statistic-and-p")
save_tm5b(tmap_arrange(
  cluster_map("cluster", "Exploratory LISA, p <= 0.05"),
  cluster_map("cluster_bh", "LISA after BH adjustment, q <= 0.05"),
  ncol = 2), "lisa-clusters")
scatter <- ggplot(local_table, aes(z_GDPPC, z_lag, colour = quadrant)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "#a18449") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#a18449") +
  geom_point(size = 2.2, alpha = .85) +
  geom_smooth(aes(group = 1), method = "lm", se = FALSE,
              colour = "#263e35") +
  scale_colour_manual(values = c("High-High" = "#9b5a40",
                                 "Low-Low" = "#315747",
                                 "High-Low" = "#d5ac85",
                                 "Low-High" = "#83a292")) +
  labs(title = "County GDPPC against its Queen-neighbour lag",
       subtitle = "Quadrants describe direction; significance is assessed separately",
       x = "Standardized GDP per capita",
       y = "Spatial lag of standardized GDPPC", colour = "Quadrant") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig5, "lisa-scatterplot.png"), scatter,
       width = 9, height = 6.5, dpi = 180)

# Gi* includes the target area. Distances are metres in EPSG:32650.
threshold_m <- critical_threshold(st_geometry(hunan_m))
fixed_nb <- include_self(st_dist_band(st_geometry(hunan_m),
                                      upper = threshold_m + 1))
fixed_wt <- st_weights(fixed_nb, style = "W")
knn_nb <- include_self(st_knn(st_geometry(hunan_m), k = 6))
knn_wt <- st_weights(knn_nb, style = "W")
stopifnot(all(spdep::card(fixed_nb) > 1), all(spdep::card(knn_nb) == 7),
          max(abs(vapply(fixed_wt, sum, numeric(1)) - 1)) < 1e-12)
set.seed(62654)
gi_fixed <- local_gstar_perm(hunan_m$GDPPC, fixed_nb, fixed_wt,
                             alternative = "two.sided", nsim = 999)
set.seed(62655)
gi_knn_result <- local_gstar_perm(hunan_m$GDPPC, knn_nb, knn_wt,
                                  alternative = "two.sided", nsim = 999)
stopifnot(nrow(gi_fixed) == 88, nrow(gi_knn_result) == 88,
          all(is.finite(gi_fixed$gi_star)), all(is.finite(gi_knn_result$gi_star)))
gi_fixed$p_bh <- p.adjust(gi_fixed$p_sim, method = "BH")
gi_knn_result$p_bh <- p.adjust(gi_knn_result$p_sim, method = "BH")
class_gi <- function(p, sign) {
  ifelse(p > .05, "Not flagged",
         ifelse(sign > 0, "Hot spot", "Cold spot"))
}
gistar <- hunan_m |>
  mutate(gi_star = gi_fixed$gi_star, p_sim = gi_fixed$p_sim,
         p_bh = gi_fixed$p_bh,
         gi_knn = gi_knn_result$gi_star, p_knn = gi_knn_result$p_sim,
         class = class_gi(p_sim, gi_star),
         class_bh = class_gi(p_bh, gi_star),
         class_knn = class_gi(p_knn, gi_knn))
gistar$class <- factor(gistar$class,
                       levels = c("Not flagged", "Cold spot", "Hot spot"))
gistar$class_bh <- factor(gistar$class_bh,
                          levels = c("Not flagged", "Cold spot", "Hot spot"))
gistar$class_knn <- factor(gistar$class_knn,
                           levels = c("Not flagged", "Cold spot", "Hot spot"))
gi_table <- st_drop_geometry(gistar) |>
  select(County, GDPPC, gi_star, p_sim, p_bh, gi_knn, p_knn,
         class, class_bh, class_knn)
write_csv(gi_table, file.path(out5, "gistar-results.csv"))
gi_counts <- bind_rows(
  count(gi_table, class, name = "count") |>
    mutate(rule = "Fixed distance, unadjusted p <= 0.05",
           class = as.character(class)) |> select(rule, class, count),
  count(gi_table, class_bh, name = "count") |>
    mutate(rule = "Fixed distance, BH q <= 0.05",
           class = as.character(class_bh)) |> select(rule, class, count),
  count(gi_table, class_knn, name = "count") |>
    mutate(rule = "6 nearest neighbours, unadjusted p <= 0.05",
           class = as.character(class_knn)) |> select(rule, class, count))
write_csv(gi_counts, file.path(out5, "gistar-class-counts.csv"))
distance_audit <- tibble(
  measure = c("Fixed threshold metres", "Fixed threshold kilometres",
              "Fixed neighbours including self: minimum",
              "Fixed neighbours including self: maximum",
              "kNN neighbours including self", "Different Gi* class in kNN"),
  value = c(threshold_m, threshold_m / 1000,
            min(spdep::card(fixed_nb)), max(spdep::card(fixed_nb)),
            min(spdep::card(knn_nb)),
            sum(as.character(gistar$class) != as.character(gistar$class_knn))))
write_csv(distance_audit, file.path(out5, "distance-audit.csv"))

gi_colours <- c("#e0ded6", "#315747", "#9b5a40")
gi_map <- function(col, title) {
  tm_shape(gistar) +
    tm_polygons(fill = col,
      fill.scale = tm_scale_categorical(values = gi_colours),
      fill.legend = tm_legend(title = "Gi* class"),
      col = "#fffdf7", lwd = .35) +
    tm_title(title, size = 1) + tm_layout(frame = FALSE, legend.outside = TRUE)
}
save_tm5b(tmap_arrange(
  map5(gistar, "gi_star", "Gi* fixed distance", "Gi* z score",
       values = diverging5),
  map5(gistar, "p_sim", "Two-sided permutation p", "p value",
       values = rev(forest5)), ncol = 2), "gistar-statistic-and-p")
save_tm5b(tmap_arrange(
  gi_map("class", "Gi* fixed distance, p <= 0.05"),
  gi_map("class_bh", "Gi* BH adjusted, q <= 0.05"),
  ncol = 2), "gistar-clusters")
save_tm5b(tmap_arrange(
  gi_map("class", "Fixed distance"),
  gi_map("class_knn", "6 nearest neighbours"),
  ncol = 2), "gistar-weight-sensitivity")
writeLines(capture.output(sessionInfo()), file.path(out5, "session-5b.txt"))
print(lisa_counts)
print(gi_counts)
print(distance_audit)
message("Hands-on Exercise 5B: local Moran, Gi*, BH checks and maps complete.")
