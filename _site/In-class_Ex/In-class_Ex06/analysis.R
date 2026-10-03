# In-class Exercise 6: a sensitivity check on Hunan emerging hot spots.
# Run from the ISS626-VAA project root in a fresh RStudio session.
source("In-class_Ex/In-class_Ex05/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(sfdep)
  library(tidyr)
  library(ggplot2)
  library(tmap)
})
ex06 <- "In-class_Ex/In-class_Ex06"
fig06 <- file.path(ex06, "figures")
out06 <- file.path(ex06, "outputs")
dir.create(fig06, recursive = TRUE, showWarnings = FALSE)
dir.create(out06, recursive = TRUE, showWarnings = FALSE)
forest06 <- "#315747"
copper06 <- "#9b5a40"
gold06 <- "#a18449"

# Chapter 11: make the balanced cube and include self in Queen neighbours.
# The second specification changes the adjacency rule: Queen counts shared
# vertices or edges, whereas rook requires a shared edge. Both use inverse
# distance weights and the same one-year temporal lag later on.
cube_base06 <- sfdep::spacetime(gdppc05, hunan05,
                                .loc_col = "County", .time_col = "Year")
stopifnot(sfdep::is_spacetime_cube(cube_base06), nrow(cube_base06) == 1496,
          identical(gdppc05$County[1:88], hunan05$County))
cube_distance06 <- cube_base06 |>
  sfdep::activate("geometry") |>
  dplyr::mutate(nb = sfdep::include_self(sfdep::st_contiguity(geometry)),
                wt = sfdep::st_inverse_distance(nb, geometry,
                                                scale = 1, alpha = 1)) |>
  sfdep::set_nbs("nb") |>
  sfdep::set_wts("wt")
cube_rook06 <- cube_base06 |>
  sfdep::activate("geometry") |>
  dplyr::mutate(nb = sfdep::include_self(
                  sfdep::st_contiguity(geometry, queen = FALSE)),
                wt = sfdep::st_inverse_distance(nb, geometry,
                                                scale = 1, alpha = 1)) |>
  sfdep::set_nbs("nb") |>
  sfdep::set_wts("wt")
stopifnot(!identical(cube_distance06$nb, cube_rook06$nb),
          all(lengths(cube_distance06$nb[1:88]) > 1),
          all(lengths(cube_rook06$nb[1:88]) > 1),
          all(vapply(cube_distance06$wt, function(z) all(is.finite(z)), logical(1))),
          all(vapply(cube_rook06$wt, function(z) all(is.finite(z)), logical(1))))
weight_audit06 <- tibble::tibble(
  measure = c("Counties", "Years", "County-year records",
              "Counties with different neighbour counts",
              "Minimum Queen neighbours with self", "Maximum Queen neighbours with self",
              "Minimum rook neighbours with self", "Maximum rook neighbours with self"),
  value = c(nrow(hunan05), dplyr::n_distinct(gdppc05$Year), nrow(gdppc05),
            sum(lengths(cube_distance06$nb[1:88]) !=
                  lengths(cube_rook06$nb[1:88])),
            min(lengths(cube_distance06$nb[1:88])),
            max(lengths(cube_distance06$nb[1:88])),
            min(lengths(cube_rook06$nb[1:88])),
            max(lengths(cube_rook06$nb[1:88]))))
readr::write_csv(weight_audit06, file.path(out06, "cube-and-weights.csv"))

# Spatial-only annual Gi*. Fixing the same seed for the two adjacency rules
# reduces Monte Carlo noise when comparing them, without forcing equal scores.
annual_gi06 <- function(cube, label) {
  dplyr::bind_rows(lapply(2005:2021, function(yr) {
    one <- dplyr::filter(cube, Year == yr)
    stopifnot(identical(one$County, hunan05$County))
    set.seed(626600 + yr)
    gi <- sfdep::local_gstar_perm(one$GDPPC, one$nb, one$wt,
                                  alternative = "two.sided", nsim = 499)
    dplyr::bind_cols(tibble::tibble(specification = label, Year = yr,
                                    County = one$County, GDPPC = one$GDPPC), gi)
  })) |>
    dplyr::group_by(Year) |>
    dplyr::mutate(q_bh = p.adjust(p_sim, method = "BH")) |>
    dplyr::ungroup()
}
gi06 <- dplyr::bind_rows(
  annual_gi06(cube_distance06, "Queen contiguity"),
  annual_gi06(cube_rook06, "Rook contiguity"))
stopifnot(nrow(gi06) == 2 * 88 * 17,
          all(is.finite(gi06$gi_star)),
          all(dplyr::between(gi06$p_sim, 0, 1)),
          all(dplyr::between(gi06$q_bh, 0, 1)))
readr::write_csv(gi06, file.path(out06, "annual-gistar.csv"))
yearly06 <- gi06 |>
  dplyr::group_by(specification, Year) |>
  dplyr::summarise(raw_p05 = sum(p_sim <= .05), bh_q05 = sum(q_bh <= .05),
                   .groups = "drop")
readr::write_csv(yearly06, file.path(out06, "annual-significance.csv"))
wide06 <- gi06 |>
  dplyr::select(specification, Year, County, gi_star) |>
  tidyr::pivot_wider(names_from = specification, values_from = gi_star)
comparison06 <- wide06 |>
  dplyr::group_by(Year) |>
  dplyr::summarise(spearman = cor(`Queen contiguity`, `Rook contiguity`,
                                 method = "spearman"),
                   median_absolute_change = median(abs(`Queen contiguity` -
                                                       `Rook contiguity`)),
                   opposite_sign = sum(sign(`Queen contiguity`) !=
                                       sign(`Rook contiguity`)),
                   .groups = "drop")
readr::write_csv(comparison06, file.path(out06, "annual-sensitivity.csv"))

# The workbook's Changsha plot and Mann-Kendall test, repeated for both rules.
changsha06 <- dplyr::filter(gi06, County == "Changsha")
changsha_plot06 <- ggplot2::ggplot(changsha06,
                                  ggplot2::aes(Year, gi_star,
                                               colour = specification,
                                               group = specification)) +
  ggplot2::geom_hline(yintercept = 0, colour = gold06, linetype = "dashed") +
  ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 1.8) +
  ggplot2::scale_colour_manual(values = c("Queen contiguity" = forest06,
                                          "Rook contiguity" = copper06)) +
  ggplot2::scale_x_continuous(breaks = seq(2005, 2021, 2)) +
  ggplot2::labs(title = "Changsha: how adjacency changes Gi*",
                x = "Year", y = "Spatial-only Gi* score", colour = NULL) +
  ggplot2::theme_minimal(base_size = 13)
ggplot2::ggsave(file.path(fig06, "changsha-comparison.png"), changsha_plot06,
                width = 9.5, height = 5.5, dpi = 180)
mk06 <- gi06 |>
  dplyr::group_by(specification, County) |>
  dplyr::summarise(mk = list(unclass(Kendall::MannKendall(gi_star))),
                   .groups = "drop") |>
  tidyr::unnest_wider(mk) |>
  dplyr::mutate(p_value = as.numeric(sl)) |>
  dplyr::group_by(specification) |>
  dplyr::mutate(q_bh = p.adjust(p_value, method = "BH")) |>
  dplyr::ungroup()
stopifnot(nrow(mk06) == 176, all(is.finite(mk06$tau)))
readr::write_csv(mk06, file.path(out06, "mann-kendall.csv"))

map_2021_06 <- dplyr::left_join(
  hunan05,
  dplyr::select(dplyr::filter(gi06, Year == 2021),
                County, specification, gi_star),
  by = "County", relationship = "one-to-many")
gi_map06 <- ggplot2::ggplot(map_2021_06) +
  ggplot2::geom_sf(ggplot2::aes(fill = gi_star), colour = "#fffdf7", linewidth = .12) +
  ggplot2::facet_wrap(~specification, nrow = 1) +
  ggplot2::scale_fill_gradient2(low = forest06, mid = "#e8e6dc",
                                high = copper06, midpoint = 0,
                                name = "Gi* score") +
  ggplot2::labs(title = "2021: identical counties, different neighbours",
                subtitle = "Spatial-only Gi*; common colour scale") +
  ggplot2::theme_void(base_size = 13) +
  ggplot2::theme(strip.text = ggplot2::element_text(face = "bold", size = 12),
                 legend.position = "bottom")
ggplot2::ggsave(file.path(fig06, "gistar-2021-weights.png"), gi_map06,
                width = 12, height = 6.6, dpi = 180)

# Formal EHSA: identical data, lag and simulation settings, different neighbours.
# Each run begins with the same seed. sfdep uses its own unadjusted bin-p
# threshold for classification; BH below applies only to location trend tests.
run_ehsa06 <- function(cube, label) {
  set.seed(626606)
  sfdep::emerging_hotspot_analysis(
    x = cube, .var = "GDPPC", k = 1, nsim = 99,
    nb_col = "nb", wt_col = "wt", threshold = .01) |>
    dplyr::mutate(specification = label,
                  trend_q_bh = p.adjust(p_value, method = "BH"))
}
ehsa06 <- dplyr::bind_rows(
  run_ehsa06(cube_distance06, "Queen contiguity"),
  run_ehsa06(cube_rook06, "Rook contiguity"))
stopifnot(nrow(ehsa06) == 176,
          !anyDuplicated(ehsa06[c("specification", "location")]))
readr::write_csv(ehsa06, file.path(out06, "ehsa-results.csv"))
classes06 <- ehsa06 |>
  dplyr::count(specification, classification, name = "count") |>
  dplyr::arrange(specification, dplyr::desc(count))
readr::write_csv(classes06, file.path(out06, "class-counts.csv"))
class_compare06 <- dplyr::inner_join(
  ehsa06 |>
    dplyr::filter(specification == "Queen contiguity") |>
    dplyr::transmute(location, queen_class = classification,
                     queen_trend_p = p_value, queen_trend_q = trend_q_bh),
  ehsa06 |>
    dplyr::filter(specification == "Rook contiguity") |>
    dplyr::transmute(location, rook_class = classification,
                     rook_trend_p = p_value, rook_trend_q = trend_q_bh),
  by = "location", relationship = "one-to-one") |>
  dplyr::mutate(same_class = queen_class == rook_class)
readr::write_csv(class_compare06, file.path(out06, "classification-comparison.csv"))

class_plot06 <- ggplot2::ggplot(classes06,
                               ggplot2::aes(x = classification, y = count,
                                            fill = specification)) +
  ggplot2::geom_col(position = "dodge", width = .72) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(values = c("Queen contiguity" = forest06,
                                        "Rook contiguity" = copper06)) +
  ggplot2::labs(title = "EHSA classes under two weighting rules",
                x = NULL, y = "Counties", fill = NULL) +
  ggplot2::theme_minimal(base_size = 13)
ggplot2::ggsave(file.path(fig06, "class-comparison.png"), class_plot06,
                width = 10, height = 7.2, dpi = 180)

map_data06 <- dplyr::left_join(
  hunan05,
  dplyr::select(ehsa06, location, specification, classification,
                p_value, trend_q_bh),
  by = c("County" = "location"), relationship = "one-to-many") |>
  dplyr::mutate(family = dplyr::case_when(
    trend_q_bh > .05 ~ "Trend not BH-significant",
    grepl("cold", classification, ignore.case = TRUE) ~ "Cold-spot family",
    grepl("hot", classification, ignore.case = TRUE) ~ "Hot-spot family",
    TRUE ~ "Other class"),
    family = factor(family, levels = c("Trend not BH-significant",
                                         "Cold-spot family", "Hot-spot family",
                                         "Other class")))
stopifnot(nrow(map_data06) == 176, !any(is.na(map_data06$classification)))
tmap::tmap_mode("plot")
make_map06 <- function(spec) {
  tmap::tm_shape(dplyr::filter(map_data06, specification == spec)) +
    tmap::tm_polygons(fill = "family",
      fill.scale = tmap::tm_scale_categorical(
        values = c("#e0ded6", forest06, copper06, gold06)),
      fill.legend = tmap::tm_legend(title = "EHSA family"),
      col = "#fffdf7", lwd = .35) +
    tmap::tm_title(spec, size = 1) +
    tmap::tm_layout(frame = FALSE, legend.outside = TRUE)
}
tmap::tmap_save(tmap::tmap_arrange(
  make_map06("Queen contiguity"), make_map06("Rook contiguity"),
  ncol = 2), file.path(fig06, "ehsa-weight-maps.png"),
  width = 2200, height = 1500, units = "px", dpi = 180)

summary06 <- tibble::tibble(
  measure = c("Counties with identical EHSA class", "Counties whose class changes",
              "2021 Gi* Spearman correlation", "2021 opposite Gi* signs",
              "Queen BH-significant MK trends", "Rook BH-significant MK trends"),
  value = c(sum(class_compare06$same_class), sum(!class_compare06$same_class),
            round(dplyr::filter(comparison06, Year == 2021)$spearman, 3),
            dplyr::filter(comparison06, Year == 2021)$opposite_sign,
            sum(dplyr::filter(mk06, specification == "Queen contiguity")$q_bh <= .05),
            sum(dplyr::filter(mk06, specification == "Rook contiguity")$q_bh <= .05)))
readr::write_csv(summary06, file.path(out06, "summary.csv"))
writeLines(capture.output(sessionInfo()), file.path(out06, "session-info.txt"))
print(summary06)
message("In-class Exercise 6: Chapter 11 reproduction and weights sensitivity complete.")
