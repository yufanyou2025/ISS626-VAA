# In-class Exercise 5: emerging hot spots in Hunan GDPPC, 2005-2021.
# Source from the repository root in a clean R session.
# install.packages(c("sf", "sfdep", "spdep", "dplyr", "tidyr", "readr",
#                    "ggplot2", "tmap", "plotly", "Kendall", "digest", "knitr"))
source("In-class_Ex/In-class_Ex05/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(sfdep)
  library(ggplot2)
  library(tmap)
  library(tidyr)
})
fig05 <- file.path(ex05, "figures")
out05 <- file.path(ex05, "outputs")
forest05 <- "#315747"
copper05 <- "#9b5a40"

# A balanced cube, with each year's rows in the same order as the polygons.
cube05 <- spacetime(gdppc05, hunan05,
                    .loc_col = "County", .time_col = "Year")
stopifnot(is_spacetime_cube(cube05), nrow(cube05) == 1496,
          identical(gdppc05$County[1:88], hunan05$County))
cube05 <- cube05 |>
  activate("geometry") |>
  mutate(nb = include_self(st_contiguity(geometry)),
         wt = st_inverse_distance(nb, geometry, scale = 1, alpha = 1)) |>
  set_nbs("nb") |>
  set_wts("wt")
stopifnot(all(lengths(cube05$nb[1:88]) > 1),
          all(vapply(cube05$wt, function(x) all(is.finite(x)), logical(1))))
weights_audit05 <- tibble(
  check = c("Cube check", "Observations", "Years", "Locations",
            "Minimum neighbours including self", "Maximum neighbours including self"),
  result = c(as.character(is_spacetime_cube(cube05)), "1496", "17", "88",
             as.character(min(lengths(cube05$nb[1:88]))),
             as.character(max(lengths(cube05$nb[1:88]))))
)
write_csv(weights_audit05, file.path(out05, "cube-audit.csv"))

# Spatial-only Gi* within each year, with reproducible conditional permutations.
# The formal EHSA below adds a time lag, so its Gi* is not identical to this view.
gi_year05 <- bind_rows(lapply(2005:2021, function(yr) {
  one_year <- dplyr::filter(cube05, Year == yr)
  stopifnot(identical(one_year$County, hunan05$County))
  set.seed(626500 + yr)
  result <- local_gstar_perm(one_year$GDPPC, one_year$nb, one_year$wt,
                             alternative = "two.sided", nsim = 499)
  bind_cols(tibble(Year = yr, County = one_year$County,
                   GDPPC = one_year$GDPPC), result)
})) |>
  group_by(Year) |>
  mutate(q_bh = p.adjust(p_sim, method = "BH")) |>
  ungroup()
stopifnot(nrow(gi_year05) == 1496,
          all(is.finite(gi_year05$gi_star)),
          all(gi_year05$p_sim >= 0 & gi_year05$p_sim <= 1),
          all(gi_year05$q_bh >= 0 & gi_year05$q_bh <= 1))
write_csv(gi_year05, file.path(out05, "annual-gistar.csv"))
annual_flags05 <- gi_year05 |>
  group_by(Year) |>
  summarise(unadjusted_p05 = sum(p_sim <= .05),
            bh_q05 = sum(q_bh <= .05),
            .groups = "drop")
write_csv(annual_flags05, file.path(out05, "annual-significance-counts.csv"))

# The named county in the classroom example; the full series is retained.
changsha05 <- filter(gi_year05, County == "Changsha")
changsha_plot05 <- ggplot(changsha05, aes(Year, gi_star)) +
  geom_hline(yintercept = 0, colour = "#a18449", linetype = "dashed") +
  geom_line(colour = forest05, linewidth = 1) +
  geom_point(aes(colour = q_bh <= .05), size = 2.3) +
  scale_colour_manual(values = c("TRUE" = copper05,
                                 "FALSE" = forest05), guide = "none") +
  scale_x_continuous(breaks = seq(2005, 2021, by = 2)) +
  labs(title = "Changsha: annual spatial-only Gi*",
       subtitle = "Point colour marks BH-adjusted annual significance",
       x = "Year", y = "Gi* standard score") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig05, "changsha-gistar.png"), changsha_plot05,
       width = 9, height = 5.2, dpi = 180)

gi_map05 <- bind_rows(lapply(c(2005L, 2021L), function(yr) {
  left_join(hunan05,
            select(filter(gi_year05, Year == yr), County, Year, gi_star),
            by = "County", relationship = "one-to-one")
}))
gi_map_plot05 <- ggplot(gi_map05) +
  geom_sf(aes(fill = gi_star), colour = "#fffdf7", linewidth = .14) +
  facet_wrap(~Year, nrow = 1) +
  scale_fill_gradient2(low = forest05, mid = "#e8e6dc", high = copper05,
                       midpoint = 0, name = "Gi* score") +
  labs(title = "Annual Gi*: the spatial pattern changes over time",
       subtitle = "Spatial-only inverse-distance weights; same colour scale") +
  theme_void(base_size = 13) +
  theme(strip.text = element_text(size = 13, face = "bold"),
        plot.title = element_text(size = 17),
        legend.position = "bottom")
ggsave(file.path(fig05, "annual-gistar-comparison.png"), gi_map_plot05,
       width = 12, height = 6.5, dpi = 180)

# Mann-Kendall trend over each county's annual spatial-only Gi* series.
mk05 <- gi_year05 |>
  group_by(County) |>
  summarise(mk = list(unclass(Kendall::MannKendall(gi_star))),
            .groups = "drop") |>
  unnest_wider(mk) |>
  mutate(p_value = as.numeric(sl),
         q_bh = p.adjust(p_value, method = "BH")) |>
  arrange(p_value, desc(abs(tau)))
stopifnot(nrow(mk05) == 88, all(is.finite(mk05$tau)),
          all(mk05$p_value >= 0 & mk05$p_value <= 1))
write_csv(mk05, file.path(out05, "mann-kendall-results.csv"))
changsha_mk05 <- filter(mk05, County == "Changsha")
mk_map05 <- left_join(hunan05,
                      select(mk05, County, tau, p_value, q_bh),
                      by = "County", relationship = "one-to-one")
mk_plot05 <- ggplot(mk_map05) +
  geom_sf(aes(fill = tau), colour = "#fffdf7", linewidth = .14) +
  scale_fill_gradient2(low = forest05, mid = "#e8e6dc", high = copper05,
                       midpoint = 0, limits = c(-1, 1), name = "Kendall tau") +
  labs(title = "Direction of county Gi* trends, 2005-2021",
       subtitle = "Mann-Kendall tau; magnitude is not a hot-spot class") +
  theme_void(base_size = 13) + theme(legend.position = "bottom")
ggsave(file.path(fig05, "mann-kendall-tau.png"), mk_plot05,
       width = 9, height = 7, dpi = 180)

# The built-in EHSA uses each year and the immediately preceding year (k=1).
# Passing nb_col and wt_col keeps our documented spatial rule; sfdep's
# classification uses its own unadjusted simulated p-values at threshold=.01.
set.seed(626505)
ehsa05 <- emerging_hotspot_analysis(
  x = cube05, .var = "GDPPC", k = 1, nsim = 99,
  nb_col = "nb", wt_col = "wt", threshold = .01)
stopifnot(nrow(ehsa05) == 88, !anyDuplicated(ehsa05$location))
ehsa05 <- ehsa05 |>
  mutate(trend_q_bh = p.adjust(p_value, method = "BH"),
         broad_class = case_when(
           grepl("cold", classification, ignore.case = TRUE) ~ "Cold-spot family",
           grepl("hot", classification, ignore.case = TRUE) ~ "Hot-spot family",
           TRUE ~ "Other / no class"))
write_csv(ehsa05, file.path(out05, "ehsa-results.csv"))
class_counts05 <- count(ehsa05, classification, sort = TRUE, name = "count")
write_csv(class_counts05, file.path(out05, "classification-counts.csv"))
ehsa_map05 <- left_join(hunan05, ehsa05,
                        by = c("County" = "location"),
                        relationship = "one-to-one") |>
  mutate(exploratory_class = if_else(p_value <= .05,
                                      broad_class, "Not flagged"),
         adjusted_class = if_else(trend_q_bh <= .05,
                                   broad_class, "Not flagged"),
         across(c(exploratory_class, adjusted_class),
                ~ factor(.x, levels = c("Not flagged", "Cold-spot family",
                                        "Hot-spot family", "Other / no class"))))
stopifnot(nrow(ehsa_map05) == 88, !any(is.na(ehsa_map05$classification)))

count_plot05 <- ggplot(class_counts05,
                       aes(x = reorder(classification, count), y = count)) +
  geom_col(fill = forest05, width = .72) +
  geom_text(aes(label = count), hjust = -.15, size = 3.5) +
  coord_flip() +
  expand_limits(y = max(class_counts05$count) * 1.12) +
  labs(title = "EHSA classifications in the 88-county extract",
       x = NULL, y = "Counties") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig05, "ehsa-class-counts.png"), count_plot05,
       width = 10, height = 7, dpi = 180)

tmap_mode("plot")
map_class05 <- function(column, title) {
  tm_shape(ehsa_map05) +
    tm_polygons(fill = column,
      fill.scale = tm_scale_categorical(values = c("#e0ded6", forest05,
                                                  copper05, "#a18449")),
      fill.legend = tm_legend(title = "Class family"),
      col = "#fffdf7", lwd = .35) +
    tm_title(title, size = 1) + tm_layout(frame = FALSE, legend.outside = TRUE)
}
ehsa_maps05 <- tmap_arrange(
  map_class05("exploratory_class", "MK p <= 0.05"),
  map_class05("adjusted_class", "MK BH q <= 0.05"), ncol = 2)
tmap_save(ehsa_maps05, file.path(fig05, "ehsa-class-map.png"),
          width = 2200, height = 1500, units = "px", dpi = 180)

writeLines(capture.output(sessionInfo()), file.path(out05, "session-info.txt"))
print(audit05)
print(annual_flags05)
print(changsha_mk05)
print(class_counts05)
message("In-class Exercise 5: cube, annual Gi*, MK tests and EHSA maps complete.")
