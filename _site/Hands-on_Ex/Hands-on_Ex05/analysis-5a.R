# Hands-on Exercise 5A: global spatial autocorrelation, Hunan GDPPC 2012.
# Run from the repository root in a clean R session. All outputs are reproducible.
# install.packages(c("sf", "spdep", "tmap", "dplyr", "readr", "ggplot2", "knitr"))
source("Hands-on_Ex/Hands-on_Ex05/prepare.R")
suppressPackageStartupMessages({
  library(spdep)
  library(tmap)
  library(ggplot2)
})
fig5 <- file.path(ex05, "figures")
out5 <- file.path(ex05, "outputs")
tmap_mode("plot")
forest5 <- c("#edf0e7", "#cbd8c0", "#9eb49d", "#64826e", "#2b5148")
save_tm5 <- function(map, name, width = 2200, height = 1500) {
  tmap_save(map, file.path(fig5, paste0(name, ".png")),
            width = width, height = height, units = "px", dpi = 180)
}
map_gdppc <- function(method, title) {
  tm_shape(hunan_m) +
    tm_polygons(fill = "GDPPC",
      fill.scale = tm_scale_intervals(style = method, n = 5, values = forest5),
      fill.legend = tm_legend(title = "RMB per person"),
      col = "#fffdf7", lwd = .35) +
    tm_title(title, size = 1) + tm_layout(frame = FALSE, legend.outside = TRUE)
}
save_tm5(tmap_arrange(map_gdppc("equal", "Equal intervals"),
                      map_gdppc("quantile", "Quantile classes"), ncol = 2),
         "gdppc-classification")

# Queen contiguity is the workbook's primary neighbourhood definition.
queen5 <- poly2nb(hunan_m, queen = TRUE, row.names = hunan$County)
rook5 <- poly2nb(hunan_m, queen = FALSE, row.names = hunan$County)
stopifnot(length(queen5) == 88, all(card(queen5) > 0),
          sum(card(queen5)) == 448, sum(card(rook5)) == 440)
weights5 <- nb2listw(queen5, style = "W", zero.policy = FALSE)
stopifnot(max(abs(vapply(weights5$weights, sum, numeric(1)) - 1)) < 1e-12)
# Reproduce the sfdep sequence projected in class, then cross-check against spdep.
nb_sfdep5 <- sfdep::st_contiguity(sf::st_geometry(hunan_m), queen = TRUE)
wt_sfdep5 <- sfdep::st_weights(nb_sfdep5, style = "W")
stopifnot(identical(unname(spdep::card(nb_sfdep5)), unname(spdep::card(queen5))))
sfdep_moran5 <- sfdep::global_moran(hunan$GDPPC, nb_sfdep5, wt_sfdep5)
sfdep_test5 <- sfdep::global_moran_test(hunan$GDPPC, nb_sfdep5, wt_sfdep5)
set.seed(62651)
sfdep_perm5 <- sfdep::global_moran_perm(hunan$GDPPC, nb_sfdep5, wt_sfdep5,
                                        alternative = "greater", nsim = 999)
writeLines(capture.output(sfdep_moran5, sfdep_test5, sfdep_perm5),
           file.path(out5, "sfdep-moran-check.txt"))
weights_audit <- tibble(
  measure = c("Counties", "Queen directed links", "Queen average neighbours",
              "Rook directed links", "Isolated Queen counties", "S0 row weights"),
  value = c(88, sum(card(queen5)), mean(card(queen5)),
            sum(card(rook5)), sum(card(queen5) == 0), Szero(weights5)))
write_csv(weights_audit, file.path(out5, "weights-audit.csv"))

# The screenshots show the statistic followed by a formal test. The workbook
# uses spdep; sfdep's same statistic is checked in Exercise 5B.
moran_obs <- moran(hunan$GDPPC, weights5, n = 88, S0 = Szero(weights5))$I
stopifnot(abs(sfdep_moran5$I - moran_obs) < 1e-9)
moran_analytic <- moran.test(hunan$GDPPC, weights5, alternative = "greater")
geary_obs <- geary(hunan$GDPPC, weights5, n = 88, n1 = 87, S0 = Szero(weights5))$C
geary_analytic <- geary.test(hunan$GDPPC, weights5, alternative = "greater")
set.seed(62651)
moran_permutation <- moran.mc(hunan$GDPPC, weights5, nsim = 999,
                              alternative = "greater")
set.seed(62652)
geary_permutation <- geary.mc(hunan$GDPPC, weights5, nsim = 999,
                              alternative = "greater")
stopifnot(isTRUE(all.equal(unname(moran_obs),
                            unname(moran_analytic$estimate[1]), tolerance = 1e-8)),
          isTRUE(all.equal(unname(geary_obs),
                            unname(geary_analytic$estimate[1]), tolerance = 1e-8)))
global_results <- tibble(
  statistic = c("Moran's I", "Geary's C"),
  observed = c(moran_obs, geary_obs),
  randomisation_expectation = c(unname(moran_analytic$estimate[2]),
                                 unname(geary_analytic$estimate[2])),
  analytic_p_one_sided = c(moran_analytic$p.value, geary_analytic$p.value),
  permutation_p_one_sided = c(moran_permutation$p.value,
                               geary_permutation$p.value),
  permutations = 999L,
  alternative = c("positive association (I high)",
                  "positive association (C low)"))
write_csv(global_results, file.path(out5, "global-results.csv"))
writeLines(capture.output(moran_analytic, geary_analytic,
                          moran_permutation, geary_permutation),
           file.path(out5, "test-reports.txt"))
permutation_values <- bind_rows(
  # spdep stores the observed value as the final element of $res.
  tibble(statistic = "Moran's I",
         value = head(moran_permutation$res, -1)),
  tibble(statistic = "Geary's C",
         value = head(geary_permutation$res, -1)))
stopifnot(nrow(permutation_values) == 1998)
write_csv(permutation_values, file.path(out5, "permutation-values.csv"))
permutation_summary <- permutation_values |>
  group_by(statistic) |>
  summarise(simulated_mean = mean(value), simulated_sd = sd(value),
            simulated_min = min(value), simulated_max = max(value),
            .groups = "drop")
write_csv(permutation_summary, file.path(out5, "permutation-summary.csv"))
reference_lines <- tibble(statistic = c("Moran's I", "Geary's C"),
                          observed = c(moran_obs, geary_obs),
                          null = c(-1 / 87, 1))
permutation_plot <- ggplot(permutation_values, aes(value)) +
  geom_histogram(bins = 24, fill = "#94a994", colour = "#fffefa") +
  geom_vline(data = reference_lines, aes(xintercept = observed),
             colour = "#94633d", linewidth = 1.1) +
  geom_vline(data = reference_lines, aes(xintercept = null),
             colour = "#283e38", linetype = "dashed", linewidth = .8) +
  facet_wrap(~statistic, scales = "free_x") +
  labs(title = "Random permutations under spatial independence",
       subtitle = "Copper: observed statistic · dashed forest: null expectation",
       x = "Statistic from permuted GDP per capita", y = "Frequency") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig5, "global-permutations.png"), permutation_plot,
       width = 11, height = 5.4, dpi = 180)

# The standardized Moran scatterplot has slope equal to I for row-standardized W.
z5 <- as.numeric(scale(hunan$GDPPC))
lag_z5 <- lag.listw(weights5, z5)
scatter5 <- tibble(County = hunan$County, z = z5, lag_z = lag_z5)
stopifnot(abs(unname(coef(lm(lag_z ~ z, data = scatter5))[2]) - moran_obs) < 1e-9)
scatter_plot <- ggplot(scatter5, aes(z, lag_z)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "#a18449") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#a18449") +
  geom_point(colour = "#315747", alpha = .8, size = 2) +
  geom_smooth(method = "lm", se = FALSE, colour = "#94633d") +
  labs(title = "Moran scatterplot: GDP per capita",
       subtitle = sprintf("Slope = Moran's I = %.3f; Queen, row-standardized weights",
                          moran_obs),
       x = "Standardized GDP per capita", y = "Spatial lag of standardized GDPPC") +
  theme_minimal(base_size = 13)
ggsave(file.path(fig5, "moran-scatterplot.png"), scatter_plot,
       width = 9, height = 6, dpi = 180)

# Successive topological orders describe how association changes with separation.
moran_corr <- sp.correlogram(queen5, hunan$GDPPC, order = 6,
                            method = "I", style = "W")
geary_corr <- sp.correlogram(queen5, hunan$GDPPC, order = 6,
                            method = "C", style = "W")
writeLines(capture.output(print(moran_corr)), file.path(out5, "moran-correlogram.txt"))
writeLines(capture.output(print(geary_corr)), file.path(out5, "geary-correlogram.txt"))
png(file.path(fig5, "moran-correlogram.png"), width = 1800, height = 1100, res = 180)
plot(moran_corr, main = "Moran's I across six Queen neighbour orders",
     xlab = "Neighbour order", ylab = "Moran's I", col = "#315747", pch = 19)
dev.off()
png(file.path(fig5, "geary-correlogram.png"), width = 1800, height = 1100, res = 180)
plot(geary_corr, main = "Geary's C across six Queen neighbour orders",
     xlab = "Neighbour order", ylab = "Geary's C", col = "#94633d", pch = 19)
dev.off()
writeLines(capture.output(sessionInfo()), file.path(out5, "session-5a.txt"))
print(weights_audit)
print(global_results)
print(permutation_summary)
message("Hands-on Exercise 5A: global statistics, permutations and correlograms complete.")
