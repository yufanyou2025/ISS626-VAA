# In-class Exercise 8: Huff-model trade areas for Taichung.
# Run from the ISS626-VAA project root after placing Hands-on_Ex08.zip on Desktop.
source("In-class_Ex/In-class_Ex08/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(MCI)
  library(tidyr)
  library(tmap)
  library(ggplot2)
})

figure08 <- file.path(root08, "figures")
dir.create(figure08, recursive = TRUE, showWarnings = FALSE)

# Use interior representative points, not centroids outside concave villages.
# EPSG:3826 is a metre-based CRS. Distances are straight-line, not travel time.
origins08 <- suppressWarnings(st_point_on_surface(village08))
distance_matrix08 <- units::drop_units(st_distance(origins08, stores08))
dimnames(distance_matrix08) <- list(village08$VILLCODE, stores08$Store_CD)
stopifnot(all(dim(distance_matrix08) == c(617L, 28L)),
          all(is.finite(distance_matrix08) & distance_matrix08 > 0))
distance08 <- as.data.frame(distance_matrix08) |>
  tibble::rownames_to_column("VILLCODE") |>
  pivot_longer(-VILLCODE, names_to = "Store_CD", values_to = "distance")
stopifnot(nrow(distance08) == nrow(village08) * nrow(stores08),
          !anyDuplicated(distance08[c("VILLCODE", "Store_CD")]))

interaction08 <- distance08 |>
  left_join(stores08 |> st_drop_geometry() |> select(Store_CD, Store_size),
            by = "Store_CD", relationship = "many-to-one")
stopifnot(!anyNA(interaction08$Store_size))

# Explicitly state the MCI default parameters used in Chapter 18.
huff08 <- MCI::huff.shares(interaction08, "VILLCODE", "Store_CD",
                           "Store_size", "distance",
                           gamma = 1, lambda = -2)
probability_check08 <- huff08 |>
  group_by(VILLCODE) |>
  summarise(probability_sum = sum(p_ij), .groups = "drop")
stopifnot(max(abs(probability_check08$probability_sum - 1)) < 1e-8,
          all(is.finite(huff08$p_ij) & huff08$p_ij > 0))

# With all Store_size values fixed at 100, model utility is proportional to
# inverse squared distance. Check the package output independently.
manual08 <- interaction08 |>
  group_by(VILLCODE) |>
  mutate(p_manual = distance^(-2) / sum(distance^(-2))) |>
  ungroup() |>
  select(VILLCODE, Store_CD, p_manual)
check08 <- huff08 |>
  left_join(manual08, by = c("VILLCODE", "Store_CD"),
            relationship = "one-to-one")
stopifnot(max(abs(check08$p_ij - check08$p_manual)) < 1e-8)

bt08 <- huff08 |>
  filter(Store_CD == "BT") |>
  select(VILLCODE, p_ij)
stopifnot(nrow(bt08) == nrow(village08))
village_bt08 <- village08 |>
  left_join(bt08, by = "VILLCODE", relationship = "one-to-one")
store_bt08 <- stores08 |> filter(Store_CD == "BT")

# The screenshot's all-store map assigns each village to its highest share.
# Sort store code as a reproducible tie-breaker.
winner08 <- huff08 |>
  arrange(VILLCODE, desc(p_ij), Store_CD) |>
  distinct(VILLCODE, .keep_all = TRUE) |>
  transmute(VILLCODE, Leading_store = Store_CD,
            Leading_probability = p_ij)
stopifnot(nrow(winner08) == nrow(village08))
village_ta08 <- village08 |>
  left_join(winner08, by = "VILLCODE", relationship = "one-to-one")
nearest08 <- distance08 |>
  arrange(VILLCODE, distance, Store_CD) |>
  distinct(VILLCODE, .keep_all = TRUE)
stopifnot(identical(winner08$Leading_store,
                    nearest08$Store_CD[match(winner08$VILLCODE,
                                             nearest08$VILLCODE)]))

# shares.total() weights each village's probability by its population.
# Its sum_E_j is an expected count of people, not monetary sales.
huff_pop08 <- huff08 |>
  left_join(village08 |> st_drop_geometry() |> select(VILLCODE, P_CNT),
            by = "VILLCODE", relationship = "many-to-one")
totals08 <- MCI::shares.total(huff_pop08, "VILLCODE", "Store_CD",
                              "p_ij", "P_CNT")
store_compare08 <- stores08 |>
  st_drop_geometry() |>
  select(Store_CD, Store_Name, Total_Sales) |>
  left_join(totals08,
            by = join_by(Store_CD == suppliers_single),
            relationship = "one-to-one") |>
  mutate(Predicted_share = sum_E_j / sum(sum_E_j),
         Observed_share = Total_Sales / sum(Total_Sales),
         Gap_pp = 100 * (Predicted_share - Observed_share))
stopifnot(nrow(store_compare08) == nrow(stores08),
          !anyNA(store_compare08$sum_E_j),
          abs(sum(store_compare08$sum_E_j) - sum(village08$P_CNT)) < 1e-5,
          abs(sum(store_compare08$Predicted_share) - 1) < 1e-8,
          abs(sum(store_compare08$Observed_share) - 1) < 1e-8)
independent08 <- huff_pop08 |>
  group_by(Store_CD) |>
  summarise(expected_people = sum(p_ij * P_CNT), .groups = "drop")
store_compare08 <- store_compare08 |>
  left_join(independent08, by = "Store_CD", relationship = "one-to-one")
stopifnot(max(abs(store_compare08$sum_E_j -
                  store_compare08$expected_people)) < 1e-5)

rank_rho08 <- cor(store_compare08$Predicted_share,
                  store_compare08$Observed_share, method = "spearman")
mae_pp08 <- mean(abs(store_compare08$Gap_pp))

# A limited sensitivity check: with equal store size, changing distance decay
# alters probability levels but cannot change which store is geographically
# closest. It is not a validation against observed patronage.
sensitivity08 <- bind_rows(lapply(c(-1, -2, -3), function(lam) {
  h <- MCI::huff.shares(interaction08, "VILLCODE", "Store_CD",
                         "Store_size", "distance", gamma = 1,
                         lambda = lam)
  tibble(lambda = lam,
         BT_population_weighted_share = sum(h$p_ij[h$Store_CD == "BT"] *
           village08$P_CNT[match(h$VILLCODE[h$Store_CD == "BT"],
                                 village08$VILLCODE)]) / sum(village08$P_CNT),
         BT_median_local_probability = median(h$p_ij[h$Store_CD == "BT"]))
}))

summary08 <- tibble(
  measure = c("Modeled villages", "Stores", "Village-store pairs",
              "Population represented", "BT median local probability",
              "Median leading-store probability", "Spearman rank correlation",
              "Mean absolute share gap (percentage points)"),
  value = c(nrow(village08), nrow(stores08), nrow(huff08),
            sum(village08$P_CNT), median(bt08$p_ij),
            median(winner08$Leading_probability), rank_rho08, mae_pp08)
)
write_csv(summary08, file.path(output08, "model-summary.csv"))
write_csv(store_compare08 |>
            select(Store_CD, Store_Name, Total_Sales, sum_E_j,
                   Predicted_share, Observed_share, Gap_pp),
          file.path(output08, "store-share-comparison.csv"))
write_csv(sensitivity08, file.path(output08, "distance-sensitivity.csv"))

# Four publication figures, with the established warm-neutral / forest style.
tmap_mode("plot")
forest08 <- "#315747"
copper08 <- "#a96646"
neutral08 <- "#f3efe6"
location_map08 <- tm_shape(village08) +
  tm_polygons(fill = neutral08, col = "#938e82", lwd = 0.35) +
  tm_shape(stores08) +
  tm_dots(fill = copper08, col = "#302f2b", size = 0.09) +
  tm_title("Stores and modelled villages", size = 1.15) +
  tm_layout(frame = FALSE)
tmap_save(location_map08, file.path(figure08, "locations.png"),
          width = 1700, height = 1350, units = "px", dpi = 170)

bt_map08 <- tm_shape(village_bt08) +
  tm_polygons(fill = "p_ij",
              fill.scale = tm_scale_continuous(
                values = c(neutral08, "#b7cdb6", forest08)),
              fill.legend = tm_legend(title = "Huff probability"),
              col = "#7b8177", lwd = 0.35) +
  tm_shape(store_bt08) +
  tm_dots(fill = copper08, col = "#302f2b", size = 0.16) +
  tm_title("Store BT: patronage probability", size = 1.1) +
  tm_layout(frame = FALSE, legend.outside = TRUE) +
  tm_compass(type = "8star", size = 1.1) +
  tm_scalebar() + tm_grid(alpha = 0.15)
tmap_save(bt_map08, file.path(figure08, "bt-probability.png"),
          width = 1800, height = 1400, units = "px", dpi = 170)

store_codes08 <- sort(stores08$Store_CD)
trade_palette08 <- setNames(
  grDevices::hcl(h = seq(12, 372, length.out = length(store_codes08) + 1)[-(length(store_codes08) + 1)],
                 c = 55, l = rep(c(65, 77), length.out = length(store_codes08))),
  store_codes08)
trade_map08 <- tm_shape(village_ta08) +
  tm_polygons(fill = "Leading_store",
              fill.scale = tm_scale_categorical(values = trade_palette08),
              fill.legend = tm_legend(title = "Leading store"),
              col = "#454943", lwd = 0.35) +
  tm_shape(stores08) +
  tm_dots(fill = "#253831", col = "#fffaf0", size = 0.07) +
  tm_title("Trade areas of stores", size = 1.15) +
  tm_layout(frame = TRUE, legend.outside = TRUE) +
  tm_compass(type = "8star", size = 1.1) +
  tm_scalebar() + tm_grid(alpha = 0.15)
tmap_save(trade_map08, file.path(figure08, "trade-areas.png"),
          width = 2200, height = 1700, units = "px", dpi = 170)

share_plot08 <- store_compare08 |>
  mutate(Store_CD = reorder(Store_CD, Observed_share)) |>
  ggplot(aes(y = Store_CD)) +
  geom_segment(aes(x = Predicted_share, xend = Observed_share,
                   yend = Store_CD), colour = "#bcb4a6", linewidth = 0.55) +
  geom_point(aes(x = Predicted_share, colour = "Modelled population share"),
             size = 2.8) +
  geom_point(aes(x = Observed_share, colour = "Observed sales share"),
             size = 2.8) +
  scale_colour_manual(values = c("Modelled population share" = forest08,
                                 "Observed sales share" = copper08),
                      name = NULL) +
  scale_x_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(title = "Modelled population allocation and observed sales",
       subtitle = "Shares are normalized within the 28-store network; monetary sales and people are not the same unit",
       x = "Share of network total", y = "Store code") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold"),
        panel.grid.major.y = element_blank())
ggsave(file.path(figure08, "share-comparison.png"), share_plot08,
       width = 11, height = 10, dpi = 180, bg = "white")

writeLines(trimws(capture.output(sessionInfo()), which = "right"),
           file.path(output08, "session-info.txt"))
print(summary08)
message("In-class Exercise 8: model audit and four figures complete.")
