# Analytical figures use static raster maps; no geometry is embedded online.
forest02 <- "#315747"
copper02 <- "#a84b35"
paper02 <- "#faf8f1"
grey02 <- "#deddd5"
source02 <- "Source: ACLED, course file accessed 8 Oct 2026. Three armed-conflict event types; Jan 2021-Sep 2025."
map_source02 <- paste(source02, "Boundaries: MIMU v9.4. Counts describe recorded events, not population risk.", sep = "\n")
theme02 <- theme_minimal(base_size = 12, base_family = "sans") +
  theme(plot.background = element_rect(fill = paper02, colour = NA),
        panel.background = element_rect(fill = paper02, colour = NA),
        plot.title = element_text(face = "bold", size = 16, colour = "#24362d"),
        plot.subtitle = element_text(size = 11, margin = margin(b = 10)),
        plot.caption = element_text(size = 8, hjust = 0, colour = "#55564e"),
        panel.grid.minor = element_blank(), legend.position = "bottom",
        strip.text = element_text(face = "bold", size = 12))
map_theme02 <- theme02 + theme(axis.title = element_blank(), axis.text = element_blank(),
                               axis.ticks = element_blank(), panel.grid = element_blank())
save_plot02 <- function(name, p, width = 11, height = 7) {
  ggsave(file.path(fig02, paste0(name, ".png")), p, width = width, height = height,
         dpi = 180, bg = paper02, limitsize = FALSE)
  slide_p <- p + labs(title = NULL, subtitle = NULL, caption = NULL) +
    theme(text = element_text(size = 20), axis.text = element_text(size = 17),
          strip.text = element_text(size = 20), legend.text = element_text(size = 18),
          legend.title = element_text(size = 18), plot.margin = margin(6, 6, 6, 6))
  # Keep map axes absent when overriding the global text size.
  if (grepl("map|sensitivity", name))
    slide_p <- slide_p + theme(axis.text = element_blank(), axis.ticks = element_blank())
  ggsave(file.path(fig02, paste0("slide-", name, ".png")), slide_p,
         width = width, height = if (height > 8) 7.5 else height,
         dpi = 180, bg = paper02, limitsize = FALSE)
}

monthly_total02 <- monthly02 |> group_by(month) |>
  summarise(Events = sum(events), `Reported fatalities` = sum(fatalities), .groups = "drop") |>
  pivot_longer(-month, names_to = "measure", values_to = "count")
p <- ggplot(monthly_total02, aes(month, count)) +
  geom_line(colour = forest02, linewidth = .85) +
  geom_point(size = .9, colour = copper02) +
  facet_wrap(~measure, ncol = 1, scales = "free_y") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Conflict frequency and reported fatalities follow different monthly paths",
       subtitle = "The last observation is September 2025; both panels use complete months",
       x = NULL, y = "Recorded count per month", caption = source02) + theme02
save_plot02("monthly-pattern", p, height = 6.7)

burden02 <- townships02 |> left_join(totals02 |> select(township_id, events, fatalities), by = "township_id") |>
  pivot_longer(c(events, fatalities), names_to = "measure", values_to = "count") |>
  mutate(measure = recode(measure, events = "Events", fatalities = "Reported fatalities"),
         band = cut(count, breaks = c(-1, 0, 50, 200, 500, 1000, Inf),
                    labels = c("0", "1-50", "51-200", "201-500", "501-1,000", ">1,000")))
p <- ggplot(burden02) + geom_sf(aes(fill = band), colour = "#fffdf7", linewidth = .07) +
  facet_wrap(~measure, nrow = 1) +
  scale_fill_manual(values = c("#efeee7", "#e0e5d9", "#b4c7ad", "#7b9e80", "#426c53", "#173c2e"),
                    drop = FALSE, name = "Township total") +
  labs(title = "Where the recorded burden is concentrated", subtitle = "Common count bands support a direct comparison",
       caption = map_source02) + map_theme02
save_plot02("burden-maps", p, height = 9)

lisa_map02 <- townships02 |> left_join(local02 |> filter(specification == "Queen") |>
                                       select(township_id, variable, lisa_class), by = "township_id",
                                     relationship = "one-to-many") |>
  mutate(lisa_class = replace_na(lisa_class, "No spatial test"))
# Replicate island geometries across facets without implying an inferred class.
main_lisa02 <- filter(lisa_map02, !is.na(variable))
island_lisa02 <- bind_rows(lapply(c("Events", "Reported fatalities"), function(v)
  townships02[islands02, ] |> mutate(variable = v, lisa_class = "No spatial test")))
lisa_map02 <- bind_rows(main_lisa02, island_lisa02)
lisa_colours02 <- c("High-high" = copper02, "Low-low" = forest02,
                     "High-low" = "#d6a44c", "Low-high" = "#79a8a4",
                     "Not significant" = grey02, "No spatial test" = "#fffdf7")
p <- ggplot(lisa_map02) + geom_sf(aes(fill = lisa_class), colour = "#fffdf7", linewidth = .07) +
  facet_wrap(~variable, nrow = 1) + scale_fill_manual(values = lisa_colours02, name = NULL) +
  labs(title = "Local Moran's I separates clusters from spatial outliers",
       subtitle = "Only two-sided permutation p < 0.05 receives a cluster or outlier colour; 999 permutations",
       caption = map_source02) + map_theme02
save_plot02("lisa-maps", p, height = 9)

gi_map02 <- bind_rows(lapply(c("Events", "Reported fatalities"), function(v) {
  townships02 |> left_join(local02 |> filter(specification == "Queen", variable == v) |>
                            select(township_id, gi_class, gi_q, gi_star), by = "township_id") |>
    mutate(variable = v, gi_class = replace_na(gi_class, "No spatial test"))
}))
gi_colours02 <- c("Hot spot" = copper02, "Cold spot" = forest02,
                   "Not significant" = grey02, "No spatial test" = "#fffdf7")
p <- ggplot(gi_map02) + geom_sf(aes(fill = gi_class), colour = "#fffdf7", linewidth = .07) +
  facet_wrap(~variable, nrow = 1) + scale_fill_manual(values = gi_colours02, name = NULL) +
  labs(title = "Gi* highlights neighbourhoods with unusually high or low recorded totals",
       subtitle = "Queen neighbours include self; two-sided permutation p < 0.05",
       caption = map_source02) + map_theme02
save_plot02("gistar-maps", p, height = 9)

ehsa_colours02 <- c("New hot spot" = "#e9b04f", "Consecutive hot spot" = "#da7846",
                     "Intensifying hot spot" = "#a72e28", "Persistent hot spot" = "#742a28",
                     "Diminishing hot spot" = "#be866b", "Sporadic hot spot" = "#dd9982",
                     "Oscillating hot spot" = "#c56480", "Historical hot spot" = "#a49388",
                     "New cold spot" = "#9dd3c0", "Consecutive cold spot" = "#5aab98",
                     "Intensifying cold spot" = "#1d655a", "Persistent cold spot" = "#23433f",
                     "Diminishing cold spot" = "#72a59d", "Sporadic cold spot" = "#a6bbb0",
                     "Oscillating cold spot" = "#637d9b", "Historical cold spot" = "#9ba9a7",
                     "No pattern / p >= 0.05" = grey02, "No spatial test" = "#fffdf7")
ehsa_map02 <- bind_rows(lapply(c("Queen", "Rook", "Precision 1 only"), function(spec) {
  townships02 |> left_join(ehsa02 |> filter(specification == spec), by = "township_id") |>
    mutate(specification = spec,
           map_class = case_when(is.na(trend_p) ~ "No spatial test",
                                 trend_p >= .05 | classification == "No pattern detected" ~ "No pattern / p >= 0.05",
                                 TRUE ~ classification))
}))
p <- ggplot(filter(ehsa_map02, specification == "Queen")) +
  geom_sf(aes(fill = map_class), colour = "#fffdf7", linewidth = .1) +
  scale_fill_manual(values = ehsa_colours02, name = NULL) +
  labs(title = "Emerging patterns among townships with significant Gi* trends",
       subtitle = "19 quarters; current + preceding quarter; Mann-Kendall p < 0.05; two-sided Gi* bin p < 0.05",
       caption = paste(map_source02, "Persistent classes with no significant trend are intentionally absent from this trend-filtered map.", sep = "\n")) +
  map_theme02 + theme(legend.position = "right")
save_plot02("ehsa-map", p, width = 10, height = 9.5)

p <- ggplot(ehsa_map02) + geom_sf(aes(fill = map_class), colour = "#fffdf7", linewidth = .04) +
  facet_wrap(~specification, nrow = 1) + scale_fill_manual(values = ehsa_colours02, name = NULL) +
  labs(title = "Location precision changes more than shared-edge versus shared-vertex neighbours",
       subtitle = "Same period and p < 0.05 map filter; location precision 1 is a narrower reporting subset",
       caption = map_source02) + map_theme02 +
  guides(fill = guide_legend(nrow = 3))
save_plot02("ehsa-sensitivity", p, width = 14, height = 9.2)

# Select case histories by explicit rules: the largest event total, plus the
# highest-burden positive-trend final hot spot and negative-trend location.
base_trends02 <- base_ehsa02$trends |> left_join(tot_inference02, by = "township_id")
choose_case02 <- function(d) { if (nrow(d)) head(arrange(d, desc(events)), 1)$township_id else character() }
cases02 <- unique(c(choose_case02(base_trends02),
                    choose_case02(filter(base_trends02, tau > 0, trend_p < .05, final_gi > 0, final_bin_p < .05)),
                    choose_case02(filter(base_trends02, tau < 0, trend_p < .05))))
if (length(cases02) < 3L)
  cases02 <- unique(c(cases02, head(arrange(base_trends02, desc(abs(tau)))$township_id, 3)))[1:3]
case_series02 <- base_ehsa02$bins |> filter(township_id %in% cases02) |>
  left_join(st_drop_geometry(inference02), by = "township_id") |>
  mutate(period = as.Date(paste0(2021 + (quarter - 1) %/% 4, "-",
                                sprintf("%02d", ((quarter - 1) %% 4) * 3 + 1), "-01")),
         significant = p_two < .05,
         label = paste(township, state, sep = ", "))
p <- ggplot(case_series02, aes(period, gi_star)) +
  geom_hline(yintercept = 0, colour = "#99998d", linetype = "dashed") +
  geom_line(colour = forest02, linewidth = .8) +
  geom_point(aes(fill = significant), shape = 21, colour = forest02, size = 2.5) +
  scale_fill_manual(values = c("TRUE" = copper02, "FALSE" = paper02), name = "Gi* bin p < 0.05") +
  facet_wrap(~label, ncol = 1) + scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(title = "A high burden and an increasing spatial concentration are different signals",
       subtitle = "Case selection: largest total, largest increasing final hot spot, largest declining concentration",
       x = NULL, y = "Space-time Gi* score", caption = source02) + theme02
save_plot02("case-histories", p, height = 8)
write_csv(base_trends02 |> filter(township_id %in% cases02) |>
            left_join(blocks02, by = "township_id"), file.path(out02, "case-townships.csv"))

scan_map02 <- inference02 |> mutate(cluster = scan_membership02)
p <- ggplot(scan_map02) + geom_sf(aes(fill = cluster), colour = "#fffdf7", linewidth = .1) +
  scale_fill_manual(values = c("Cluster 1" = copper02, "Cluster 2" = "#d4a14c",
                              "Cluster 3" = forest02, "Outside selected clusters" = grey02), name = NULL) +
  labs(title = "Spatial scan: where a larger share of national conflict moved",
       subtitle = "Early: Jan 2021-Sep 2022; recent: Jan 2024-Sep 2025; only search-adjusted p < 0.05",
       caption = paste(map_source02, "Circular search around township interior points; 1-30 townships; <=20% of combined events.", sep = "\n")) +
  map_theme02 + theme(legend.position = "right")
save_plot02("redistribution-map", p, width = 10, height = 9)
p <- scan_results02 |> select(cluster, centre, early_share, recent_share) |>
  pivot_longer(c(early_share, recent_share), names_to = "window", values_to = "share") |>
  mutate(window = recode(window, early_share = "Jan 2021-Sep 2022", recent_share = "Jan 2024-Sep 2025"),
         label = paste0("Cluster ", cluster, " (", centre, ")")) |>
  ggplot(aes(label, share, fill = window)) + geom_col(position = "dodge", width = .65) +
  coord_flip() + scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  scale_fill_manual(values = c(forest02, copper02), name = NULL) +
  labs(title = "The scan isolates redistribution from the national increase in events",
       x = NULL, y = "Share of nationwide mainland events in each window", caption = source02) + theme02
save_plot02("redistribution-shares", p, height = 4.5)

# Results objects for prose and slides: all reported quantities are computed.
summary02 <- list(
  input = nrow(raw02), analytical_events = nrow(events02), fatalities = sum(events02$fatalities),
  precise_events = sum(events02$geo_precision == 1L),
  zero_townships = sum(totals02$events == 0),
  mainland_events = sum(tot_inference02$events),
  island_events = sum(totals02$events[totals02$township_id %in% townships02$township_id[islands02]]),
  global_i = as.numeric(global02$statistic), global_p = global02$p.value,
  top_townships = head(arrange(totals02, desc(events)), 10),
  top_fatalities = head(arrange(totals02, desc(fatalities)), 10),
  top10_share = sum(head(sort(totals02$events, decreasing = TRUE), 10)) / nrow(events02),
  state_totals = totals02 |> group_by(state) |> summarise(events = sum(events), fatalities = sum(fatalities), .groups = "drop") |> arrange(desc(events)),
  peak_month = monthly_total02 |> filter(measure == "Events") |> arrange(desc(count)) |> head(1),
  local_counts = local02 |> filter(specification == "Queen") |> count(variable, lisa_class),
  gi_counts = local02 |> filter(specification == "Queen") |> count(variable, gi_class),
  trend_significant = sum(base_ehsa02$trends$trend_p < .05),
  trend_bh = sum(base_ehsa02$trends$trend_q < .05),
  block2_significant = sum(blocks02$block2_p < .05),
  block3_significant = sum(blocks02$block3_p < .05),
  median_lag1 = median(blocks02$lag1),
  rook_class_agreement = mean(base_ehsa02$trends$classification == rook_ehsa02$trends$classification),
  precision_class_agreement = mean(base_ehsa02$trends$classification == precision_ehsa02$trends$classification),
  ehsa_counts = count(base_ehsa02$trends, classification),
  scan = scan_results02,
  cases = read_csv(file.path(out02, "case-townships.csv"), show_col_types = FALSE)
)
saveRDS(summary02, file.path(out02, "report-results.rds"))
jsonlite::write_json(summary02, file.path(out02, "report-results.json"), pretty = TRUE, auto_unbox = TRUE)
