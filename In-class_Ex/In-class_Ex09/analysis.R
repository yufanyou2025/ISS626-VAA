# Hands-on Exercise 9: hedonic pricing and geographically weighted regression.
# Run from the ISS626-VAA project root. The supplied ZIP stays local.
source("In-class_Ex/In-class_Ex09/prepare.R", encoding = "UTF-8")
suppressPackageStartupMessages({
  library(ggplot2)
  library(tmap)
  library(GWmodel)
  library(spdep)
})

figure09 <- file.path(root09, "figures")
cache09 <- file.path(root09, "cache")
dir.create(figure09, recursive = TRUE, showWarnings = FALSE)
dir.create(cache09, recursive = TRUE, showWarnings = FALSE)

# The workbook's level-price formula is retained for a comparable OLS/GWR run.
# LEASEHOLD_99YR is omitted because tenure dummies should not all enter with
# an intercept. Preserve the full and revised formulas for inspection.
simple_formula09 <- SELLING_PRICE ~ AREA_SQM
full_formula09 <- SELLING_PRICE ~ AREA_SQM + AGE + PROX_CBD +
  PROX_CHILDCARE + PROX_ELDERLYCARE + PROX_URA_GROWTH_AREA +
  PROX_HAWKER_MARKET + PROX_KINDERGARTEN + PROX_MRT + PROX_PARK +
  PROX_PRIMARY_SCH + PROX_TOP_PRIMARY_SCH + PROX_SHOPPING_MALL +
  PROX_SUPERMARKET + PROX_BUS_STOP + NO_Of_UNITS + FAMILY_FRIENDLY + FREEHOLD
revised_formula09 <- SELLING_PRICE ~ AREA_SQM + AGE + PROX_CBD +
  PROX_CHILDCARE + PROX_MRT + PROX_ELDERLYCARE +
  PROX_URA_GROWTH_AREA + PROX_PARK + PROX_PRIMARY_SCH +
  PROX_SHOPPING_MALL + PROX_BUS_STOP + NO_Of_UNITS +
  FAMILY_FRIENDLY + FREEHOLD

simple09 <- lm(simple_formula09, data = st_drop_geometry(condo09))
full09 <- lm(full_formula09, data = st_drop_geometry(condo09))
revised09 <- lm(revised_formula09, data = st_drop_geometry(condo09))
log_sensitivity09 <- lm(update(revised_formula09, LOG_SELLING_PRICE ~ .),
                        data = st_drop_geometry(condo09))
stopifnot(all(vapply(list(simple09, full09, revised09), nobs, integer(1)) ==
              nrow(condo09)))

# Auxiliary-regression VIF on model columns. This remains reproducible without
# adding an otherwise unused diagnostics package to the RStudio environment.
X09 <- model.matrix(revised09)[, -1, drop = FALSE]
vif09 <- vapply(seq_len(ncol(X09)), function(j) {
  others <- X09[, -j, drop = FALSE]
  1 / (1 - summary(lm(X09[, j] ~ others))$r.squared)
}, numeric(1))
vif_table09 <- tibble::tibble(term = colnames(X09), VIF = unname(vif09))
readr::write_csv(vif_table09, file.path(output09, "vif.csv"))

condo09$OLS_residual <- residuals(revised09)
coords09 <- st_coordinates(condo09)
neighbours09 <- dnearneigh(coords09, d1 = 0, d2 = 1500,
                           bounds = c("GE", "LE"))
isolated09 <- sum(card(neighbours09) == 0)
weights09 <- nb2listw(neighbours09, style = "W", zero.policy = TRUE)
set.seed(20261031)
ols_moran09 <- moran.mc(condo09$OLS_residual, weights09, nsim = 499,
                        alternative = "two.sided", zero.policy = TRUE)

sf_sp09 <- as(condo09, "Spatial")
model_key09 <- digest::digest(list(
  manifest09$sha256[1], deparse(revised_formula09),
  as.character(packageVersion("GWmodel")), "CV-gaussian-2026-10-31"))
cache_file09 <- file.path(cache09, paste0("gwr-", model_key09, ".rds"))
if (file.exists(cache_file09)) {
  gwr_result09 <- readRDS(cache_file09)
} else {
  message("Selecting fixed Gaussian CV bandwidth...")
  bw_fixed09 <- GWmodel::bw.gwr(revised_formula09, data = sf_sp09,
                                approach = "CV", kernel = "gaussian",
                                adaptive = FALSE, longlat = FALSE)
  message("Fitting fixed-bandwidth GWR...")
  gwr_fixed09 <- GWmodel::gwr.basic(revised_formula09, data = sf_sp09,
                                    bw = bw_fixed09, kernel = "gaussian",
                                    adaptive = FALSE, longlat = FALSE)
  message("Selecting adaptive Gaussian CV bandwidth...")
  bw_adaptive09 <- GWmodel::bw.gwr(revised_formula09, data = sf_sp09,
                                   approach = "CV", kernel = "gaussian",
                                   adaptive = TRUE, longlat = FALSE)
  message("Fitting adaptive-bandwidth GWR...")
  gwr_adaptive09 <- GWmodel::gwr.basic(revised_formula09, data = sf_sp09,
                                       bw = bw_adaptive09, kernel = "gaussian",
                                       adaptive = TRUE, longlat = FALSE)
  gwr_result09 <- list(bw_fixed = bw_fixed09, fixed = gwr_fixed09,
                       bw_adaptive = bw_adaptive09,
                       adaptive = gwr_adaptive09)
  saveRDS(gwr_result09, cache_file09)
}
bw_fixed09 <- gwr_result09$bw_fixed
bw_adaptive09 <- gwr_result09$bw_adaptive
gwr_fixed09 <- gwr_result09$fixed
gwr_adaptive09 <- gwr_result09$adaptive

local09 <- st_as_sf(gwr_adaptive09$SDF) |> st_transform(3414)
if (!all(c("Local_R2", "AREA_SQM") %in% names(local09))) {
  stop("Unexpected GWmodel output columns; inspect GWR SDF.")
}
if (!"residual" %in% names(local09)) stop("GWR residual column is missing.")
set.seed(20261032)
gwr_moran09 <- moran.mc(local09$residual, weights09, nsim = 499,
                        alternative = "two.sided", zero.policy = TRUE)
# spdep's two-sided display can print p=0 at the extreme observed rank.
# Use a plus-one rank calculation around the randomisation expectation;
# 499 permutations imply the smallest attainable p is 1/500 = 0.002.
permutation_p09 <- function(test, n) {
  simulated <- head(test$res, -1)
  observed <- tail(test$res, 1)
  expected <- -1 / (n - 1)
  (1 + sum(abs(simulated - expected) >= abs(observed - expected))) /
    (length(simulated) + 1)
}

aicc_lm09 <- function(fit) {
  k <- length(coef(fit)) + 1 # Include estimated residual variance.
  n <- nobs(fit)
  AIC(fit) + 2 * k * (k + 1) / (n - k - 1)
}
metric09 <- tibble::tibble(
  model = c("Simple OLS", "Full OLS", "Revised OLS",
            "Fixed GWR", "Adaptive GWR"),
  n = nrow(condo09),
  AICc = c(aicc_lm09(simple09), aicc_lm09(full09),
           aicc_lm09(revised09), gwr_fixed09$GW.diagnostic$AICc,
           gwr_adaptive09$GW.diagnostic$AICc),
  R2 = c(summary(simple09)$r.squared, summary(full09)$r.squared,
         summary(revised09)$r.squared,
         gwr_fixed09$GW.diagnostic$gw.R2,
         gwr_adaptive09$GW.diagnostic$gw.R2),
  RMSE_in_sample = c(sqrt(mean(residuals(simple09)^2)),
                     sqrt(mean(residuals(full09)^2)),
                     sqrt(mean(residuals(revised09)^2)),
                     sqrt(mean(gwr_fixed09$SDF$residual^2)),
                     sqrt(mean(local09$residual^2)))
)
stopifnot(all(is.finite(metric09$AICc)),
          all(is.finite(metric09$RMSE_in_sample)))
readr::write_csv(metric09, file.path(output09, "model-comparison.csv"))

moran_table09 <- tibble::tibble(
  model = c("Revised OLS", "Adaptive GWR"),
  Moran_I = c(unname(ols_moran09$statistic),
              unname(gwr_moran09$statistic)),
  Monte_Carlo_p = c(permutation_p09(ols_moran09, nrow(condo09)),
                    permutation_p09(gwr_moran09, nrow(condo09))),
  neighbours_within_1500m_isolated = isolated09,
  permutations = 499
)
readr::write_csv(moran_table09, file.path(output09, "residual-moran.csv"))
bandwidth09 <- tibble::tibble(
  model = c("Fixed Gaussian GWR", "Adaptive Gaussian GWR"),
  CV_bandwidth = c(bw_fixed09, bw_adaptive09),
  unit = c("metres", "nearest observations")
)
readr::write_csv(bandwidth09, file.path(output09, "bandwidths.csv"))

coeff09 <- as.data.frame(summary(revised09)$coefficients)
coeff09$term <- rownames(coeff09)
readr::write_csv(coeff09 |>
                   dplyr::relocate(term),
                 file.path(output09, "revised-ols-coefficients.csv"))
local_summary09 <- tibble::tibble(
  measure = c("Local R2 median", "Local R2 10th percentile",
              "Local R2 90th percentile", "Area coefficient median",
              "Area coefficient 10th percentile",
              "Area coefficient 90th percentile",
              "Area coefficient negative count"),
  value = c(median(local09$Local_R2),
            quantile(local09$Local_R2, 0.1),
            quantile(local09$Local_R2, 0.9),
            median(local09$AREA_SQM),
            quantile(local09$AREA_SQM, 0.1),
            quantile(local09$AREA_SQM, 0.9),
            sum(local09$AREA_SQM < 0))
)
readr::write_csv(local_summary09, file.path(output09, "local-summary.csv"))

forest09 <- "#315747"
copper09 <- "#a96646"
neutral09 <- "#f3efe6"
base_theme09 <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank())

price_plot09 <- ggplot(st_drop_geometry(condo09), aes(SELLING_PRICE / 1e6)) +
  geom_histogram(bins = 35, fill = forest09, colour = "white") +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1)) +
  labs(title = "Condominium resale prices, 2015",
       subtitle = "The long upper tail reaches S$18 million",
       x = "Selling price (S$ million)", y = "Transactions") + base_theme09
ggsave(file.path(figure09, "price-distribution.png"), price_plot09,
       width = 9, height = 5.5, dpi = 180, bg = "white")

size_plot09 <- ggplot(st_drop_geometry(condo09),
                       aes(AREA_SQM, SELLING_PRICE / 1e6)) +
  geom_point(alpha = 0.35, colour = forest09, size = 1.5) +
  geom_smooth(method = "lm", se = FALSE, colour = copper09) +
  labs(title = "Floor area and resale price",
       x = "Area (square metres)", y = "Selling price (S$ million)") +
  base_theme09
ggsave(file.path(figure09, "size-price.png"), size_plot09,
       width = 9, height = 5.5, dpi = 180, bg = "white")

predictors09 <- all.vars(revised_formula09)[-1]
corr09 <- cor(st_drop_geometry(condo09)[predictors09])
corr_long09 <- as.data.frame(as.table(corr09))
corr_plot09 <- ggplot(corr_long09, aes(Var1, Var2, fill = Freq)) +
  geom_tile(colour = "white", linewidth = 0.25) +
  scale_fill_gradient2(low = copper09, mid = neutral09, high = forest09,
                       midpoint = 0, limits = c(-1, 1), name = "Pearson r") +
  coord_equal() +
  labs(title = "Correlation among revised-model predictors",
       x = NULL, y = NULL) +
  base_theme09 +
  theme(axis.text.x = element_text(angle = 55, hjust = 1, size = 8),
        axis.text.y = element_text(size = 8))
ggsave(file.path(figure09, "predictor-correlation.png"), corr_plot09,
       width = 12, height = 10, dpi = 180, bg = "white")

diagnostic09 <- tibble::tibble(fitted = fitted(revised09) / 1e6,
                               residual = residuals(revised09) / 1e6)
resid_plot09 <- ggplot(diagnostic09, aes(fitted, residual)) +
  geom_point(alpha = 0.35, colour = forest09, size = 1.5) +
  geom_hline(yintercept = 0, colour = copper09, linewidth = 0.7) +
  geom_smooth(se = FALSE, colour = copper09) +
  labs(title = "Revised OLS residuals versus fitted prices",
       x = "Fitted price (S$ million)", y = "Residual (S$ million)") +
  base_theme09
ggsave(file.path(figure09, "ols-residual-diagnostic.png"), resid_plot09,
       width = 9, height = 5.5, dpi = 180, bg = "white")

tmap_mode("plot")
residual_cap09 <- as.numeric(quantile(abs(condo09$OLS_residual), 0.98))
condo09$OLS_residual_display <- pmax(
  pmin(condo09$OLS_residual, residual_cap09), -residual_cap09)
outline09 <- tm_shape(subzones09) +
  tm_polygons(fill = neutral09, col = "#a39d90", lwd = 0.25)
price_map09 <- outline09 + tm_shape(condo09) +
  tm_dots(fill = "LOG_SELLING_PRICE", size = 0.06,
          fill.scale = tm_scale_continuous(values = c(neutral09, copper09,
                                                       forest09)),
          fill.legend = tm_legend(title = "Log(S$ price)")) +
  tm_title("2015 condominium resale locations", size = 1.1) +
  tm_layout(frame = FALSE, legend.outside = TRUE)
tmap_save(price_map09, file.path(figure09, "transaction-map.png"),
          width = 1700, height = 1400, units = "px", dpi = 170)
htmlwidgets::saveWidget(
  tmap::tmap_leaflet(price_map09),
  file = file.path(figure09, "transaction-interactive.html"),
  selfcontained = TRUE
)

resid_map09 <- outline09 + tm_shape(condo09) +
  tm_dots(fill = "OLS_residual_display", size = 0.07,
          fill.scale = tm_scale_continuous(values = c(copper09, neutral09,
                                                       forest09), midpoint = 0),
          fill.legend = tm_legend(title = "OLS error (S$; capped)")) +
  tm_title("Where revised OLS over- and under-predicts", size = 1.1) +
  tm_layout(frame = FALSE, legend.outside = TRUE)
tmap_save(resid_map09, file.path(figure09, "ols-residual-map.png"),
          width = 1700, height = 1400, units = "px", dpi = 170)

local_r2_map09 <- outline09 + tm_shape(local09) +
  tm_dots(fill = "Local_R2", size = 0.07,
          fill.scale = tm_scale_continuous(values = c(neutral09,
                                                       "#a9c2a7", forest09)),
          fill.legend = tm_legend(title = "Local R-squared")) +
  tm_title("Adaptive GWR: local model fit", size = 1.1) +
  tm_layout(frame = FALSE, legend.outside = TRUE)
tmap_save(local_r2_map09, file.path(figure09, "local-r2.png"),
          width = 1700, height = 1400, units = "px", dpi = 170)

area_map09 <- outline09 + tm_shape(local09) +
  tm_dots(fill = "AREA_SQM", size = 0.07,
          fill.scale = tm_scale_continuous(values = c(copper09,
                                                       neutral09, forest09)),
          fill.legend = tm_legend(title = "S$ per sq m")) +
  tm_title("Adaptive GWR: local floor-area coefficient", size = 1.1) +
  tm_layout(frame = FALSE, legend.outside = TRUE)
tmap_save(area_map09, file.path(figure09, "local-area-coefficient.png"),
          width = 1700, height = 1400, units = "px", dpi = 170)

writeLines(sub("[[:space:]]+$", "", capture.output(sessionInfo())),
           file.path(output09, "session-info.txt"))
print(metric09)
print(bandwidth09)
print(moran_table09)
message("Hands-on Exercise 9 analysis complete.")
