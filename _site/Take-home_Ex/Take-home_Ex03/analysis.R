# Exercise 3: reproducible aggregate station-choice analysis.
# Run/source this script from the ISS626-VAA Quarto project root.
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})
base03 <- "Take-home_Ex/Take-home_Ex03"
source(file.path(base03, "methods.R"), encoding = "UTF-8")
source(file.path(base03, "prepare-ridership.R"), encoding = "UTF-8")
# Download/check the ridership input before spatial preparation reads its codes.
# This ordering is essential when starting with an empty data/raw directory.
observed_ridership03 <- prepare_ridership03(base03)
source(file.path(base03, "prepare-spatial.R"), encoding = "UTF-8")

grid_origins03 <- function(buildings, cell_size = 250) {
  # The grid is anchored at the SVY21 (0,0) coordinate origin. A cell retains
  # its dwelling-weighted centre, not an arbitrary geometric cell centre.
  out <- buildings |>
    sf::st_drop_geometry() |>
    mutate(gx = floor(x / cell_size), gy = floor(y / cell_size)) |>
    group_by(gx, gy) |>
    summarise(x = weighted.mean(x, dwelling_units),
              y = weighted.mean(y, dwelling_units),
              market_potential = sum(dwelling_units), blocks = n(),
              .groups = "drop") |>
    mutate(origin_id = paste0("G", cell_size, "_", gx, "_", gy)) |>
    arrange(origin_id)
  stopifnot(!anyDuplicated(out$origin_id), all(out$market_potential > 0),
            abs(sum(out$market_potential) - sum(buildings$dwelling_units)) < 1e-6)
  sf_out <- st_as_sf(out, coords = c("x", "y"), crs = 3414, remove = FALSE)
  ll <- st_coordinates(st_transform(sf_out, 4326))
  out$lon <- ll[, 1]
  out$lat <- ll[, 2]
  out
}

distance_matrix03 <- function(origin, station) {
  D <- sqrt(outer(origin$x, station$x, "-")^2 +
              outer(origin$y, station$y, "-")^2)
  dimnames(D) <- list(origin$origin_id, station$station_id)
  stopifnot(all(is.finite(D)), all(D >= 0))
  D
}

predict_huff03 <- function(D, stations, weights, fit, offset = fit$delta) {
  huff_prob(D, st_drop_geometry(stations), decay = fit$par[["decay"]],
            beta_lines = fit$par[["beta_lines"]], offset = offset)
}

interaction_frame03 <- function(origin, stations, D, P, beta_lines) {
  # Each destination block contains every origin, matching R's column-major
  # matrix order. These are actual complete frames, not sampled OD records.
  n_origin <- nrow(origin)
  data.frame(origin_id = rep(origin$origin_id, times = nrow(stations)),
    destination = rep(stations$station_id, each = n_origin),
    market_potential = rep(origin$market_potential, times = nrow(stations)),
    lines = rep(stations$lines, each = n_origin),
    attraction = rep(stations$lines^beta_lines, each = n_origin),
    distance = as.vector(D), p_ij = as.vector(P))
}

run_analysis03 <- function(base_dir = base03) {
  output <- file.path(base_dir, "outputs")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  observed <- if (identical(base_dir, base03)) observed_ridership03 else
    prepare_ridership03(base_dir)
  # prepare-spatial.R creates the three checked sf inputs on being sourced.
  buildings <- hdb_origins03
  existing <- existing_stations03
  expanded <- expanded_stations03
  stopifnot(all(c("station_id", "lines", "x", "y") %in% names(existing)),
            all(existing$station_id %in% expanded$station_id),
            !anyDuplicated(existing$station_id), !anyDuplicated(expanded$station_id),
            all(buildings$dwelling_units > 0),
            setequal(existing$station_id, observed$destination))
  # Join by verified source code and retain the station matrix order.
  obs <- observed[match(existing$station_id, observed$destination), ]
  y <- obs$am_weekday_daily_tap_in
  y_all <- obs$observed_daily_tap_in
  stopifnot(!anyNA(y), all(y >= 0), sum(y) > 0)
  market_total <- sum(y)
  origins <- grid_origins03(buildings, 250)
  weights <- origins$market_potential
  D <- distance_matrix03(origins, existing)
  D_after <- distance_matrix03(origins, expanded)
  attr <- st_drop_geometry(existing) |> select(lines)
  attr_after <- st_drop_geometry(expanded) |> select(lines)
  message("Calibrating morning Huff model on ", nrow(origins), " weighted grid origins.")
  fit <- fit_huff(D, attr, weights, y)
  P <- predict_huff03(D, existing, weights, fit)
  P_after <- predict_huff03(D_after, expanded, weights, fit)
  fitted <- market_total * huff_aggregate(P, weights)
  after <- market_total * huff_aggregate(P_after, weights)
  fixed <- baseline_huff(D, attr, weights, market_total)
  metrics <- bind_rows(station_metrics(y, fixed, "Inverse-square baseline: calibration sample"),
    station_metrics(y, fitted, "Calibrated Huff: calibration sample"))

  # Geographic holdouts are longitude quartiles of station sites. Their outcomes
  # are withheld, but their locations/lines remain in the station choice set.
  # No total from a held-out sector is used for the prediction count scale.
  longitude_breaks <- quantile(existing$lon, probs = seq(0, 1, length.out = 5),
                               names = FALSE, type = 7)
  stopifnot(length(unique(longitude_breaks)) == 5L)
  folds <- as.integer(cut(existing$lon, breaks = longitude_breaks,
                          include.lowest = TRUE, labels = FALSE))
  cv <- data.frame(destination = existing$station_id, fold = folds,
                   observed_daily = y, fitted_daily = NA_real_,
                   baseline_daily = NA_real_)
  cv_details <- list()
  cv_coefficients <- list()
  baseline_share <- fixed / sum(fixed)
  for (fold in seq_len(4)) {
    tr <- which(folds != fold)
    te <- which(folds == fold)
    message("Spatial holdout ", fold, "/4.")
    ff <- fit_huff(D, attr, weights, y, training_indices = tr)
    cv$fitted_daily[te] <- ff$predicted[te]
    baseline_scale <- sum(y[tr]) / sum(baseline_share[tr])
    cv$baseline_daily[te] <- baseline_scale * baseline_share[te]
    cv_details[[fold]] <- bind_rows(
      station_metrics(y[te], ff$predicted[te], "Calibrated Huff"),
      station_metrics(y[te], cv$baseline_daily[te], "Inverse-square baseline")) |>
      mutate(fold = fold, training_stations = length(tr))
    cv_coefficients[[fold]] <- ff$bounds |> mutate(fold = fold,
      objective = ff$objective, convergence = ff$convergence)
  }
  cv_metrics <- bind_rows(
    station_metrics(y, cv$baseline_daily, "Inverse-square baseline: spatial holdout"),
    station_metrics(y, cv$fitted_daily, "Calibrated Huff: spatial holdout"))

  # The all-day diagnostic changes the response, not the market or its weights.
  # It tests the consequence of using residential origins for all-day entries.
  message("Fitting all-day diagnostic.")
  fit_all_day <- fit_huff(D, attr, weights, y_all)
  all_day_fitted <- sum(y_all) * fit_all_day$shares
  all_day_metrics <- bind_rows(
    station_metrics(y_all, baseline_huff(D, attr, weights, sum(y_all)),
                    "All-day inverse-square baseline"),
    station_metrics(y_all, all_day_fitted, "All-day calibrated Huff"))

  before_index <- match(expanded$station_id, existing$station_id)
  is_new <- is.na(before_index)
  station_results <- st_drop_geometry(expanded) |>
    transmute(destination = station_id, station_name, x, y, lon, lat,
      status = if_else(is_new, "new", "existing"),
      lines_before = ifelse(is_new, 0, existing$lines[before_index]),
      lines_after = lines,
      observed_daily = .env$y[.env$before_index],
      fitted_daily = .env$fitted[.env$before_index], expanded_daily = as.numeric(.env$after),
      change_daily = expanded_daily - ifelse(is_new, 0, fitted_daily),
      change_pct = ifelse(is_new, NA_real_, 100 * change_daily / fitted_daily),
      cv_fitted_daily = cv$fitted_daily[before_index],
      cv_baseline_daily = cv$baseline_daily[before_index],
      future_lines = if ("future_lines" %in% names(expanded)) future_lines else "")
  stopifnot(sum(is_new) == nrow(expanded) - nrow(existing),
            abs(sum(station_results$expanded_daily) - market_total) < 1e-5,
            abs(sum(station_results$fitted_daily, na.rm = TRUE) - market_total) < 1e-5)
  winner_before <- existing$station_id[max.col(P, ties.method = "first")]
  winner_after <- expanded$station_id[max.col(P_after, ties.method = "first")]
  origin_results <- origins |>
    mutate(nearest_before_m = apply(D, 1, min),
      nearest_after_m = apply(D_after, 1, min),
      winner_before = winner_before, winner_after = winner_after,
      new_station_probability = rowSums(P_after[, is_new, drop = FALSE]),
      winner_changed = winner_before != winner_after,
      new800 = nearest_before_m > 800 & nearest_after_m <= 800)

  # The accessibility extension uses original building representative points,
  # avoiding a 250m grid's artificial threshold-crossing effects.
  nearest_building_before <- st_nearest_feature(buildings, existing)
  nearest_building_after <- st_nearest_feature(buildings, expanded)
  distance_building_before <- as.numeric(st_distance(buildings,
    existing[nearest_building_before, ], by_element = TRUE))
  distance_building_after <- as.numeric(st_distance(buildings,
    expanded[nearest_building_after, ], by_element = TRUE))
  accessibility <- bind_rows(lapply(c(600, 800, 1000), function(threshold) {
    a <- distance_building_before <= threshold
    b <- distance_building_after <= threshold
    data.frame(threshold_m = threshold, buildings = nrow(buildings),
      dwelling_units_total = sum(buildings$dwelling_units),
      dwellings_before = sum(buildings$dwelling_units[a]),
      dwellings_after = sum(buildings$dwelling_units[b]),
      dwellings_newly_served = sum(buildings$dwelling_units[!a & b]),
      dwellings_still_beyond = sum(buildings$dwelling_units[!b]),
      buildings_newly_served = sum(!a & b))
  }))
  building_access <- st_drop_geometry(buildings) |>
    select(origin_id, dwelling_units, x, y, lon, lat) |>
    mutate(nearest_before_m = distance_building_before,
      nearest_after_m = distance_building_after,
      new800 = nearest_before_m > 800 & nearest_after_m <= 800)

  # Sensitivity ranges are alternative specifications, not confidence intervals.
  sensitivity_runs <- list()
  sensitivity_station <- list()
  specs <- data.frame(specification = c("250m / offset 100m", "250m / offset 200m",
    "250m / offset 400m", "500m / offset 200m"),
    grid_m = c(250, 250, 250, 500), offset_m = c(100, 200, 400, 200))
  for (s in seq_len(nrow(specs))) {
    message("Sensitivity ", s, "/", nrow(specs), ".")
    oo <- if (specs$grid_m[s] == 250) origins else grid_origins03(buildings, 500)
    dd <- if (specs$grid_m[s] == 250) D else distance_matrix03(oo, existing)
    da <- if (specs$grid_m[s] == 250) D_after else distance_matrix03(oo, expanded)
    ff <- if (s == 2) fit else fit_huff(dd, attr, oo$market_potential, y,
                                      delta = specs$offset_m[s])
    pp <- predict_huff03(da, expanded, oo$market_potential, ff)
    aa <- market_total * huff_aggregate(pp, oo$market_potential)
    mm <- station_metrics(y, market_total * ff$shares, "Calibrated Huff")
    sensitivity_runs[[s]] <- cbind(specs[s, ], data.frame(origins = nrow(oo),
      decay = ff$par[["decay"]], beta_lines = ff$par[["beta_lines"]],
      objective = ff$objective, convergence = ff$convergence,
      MAE = mm$MAE, WAPE = mm$WAPE, RMSLE = mm$RMSLE,
      new_station_daily = sum(aa[is_new]),
      new_station_share = sum(aa[is_new]) / market_total))
    sensitivity_station[[s]] <- data.frame(specification = specs$specification[s],
      destination = expanded$station_id, expanded_daily = aa)
  }
  sensitivity <- bind_rows(sensitivity_runs)
  sensitivity_station <- bind_rows(sensitivity_station)
  scenario_totals <- data.frame(measure = c("Existing physical station sites",
      "Expanded physical station sites", "New physical station sites",
      "Existing sites with added lines", "Grid origins (250m)",
      "Source HDB building origins", "Dwelling market potential",
      "Observed weekday AM entries per day", "Fitted weekday AM entries per day",
      "Expanded weekday AM entries per day", "New-site weekday AM entries per day",
      "New-site share of fixed market", "Dwelling weight changing leading station",
      "Share of dwelling weight changing leading station"),
    value = c(nrow(existing), nrow(expanded), sum(is_new),
      sum(station_results$lines_after > station_results$lines_before & !is_new),
      nrow(origins), nrow(buildings), sum(weights), market_total, sum(fitted),
      sum(after), sum(after[is_new]), sum(after[is_new]) / market_total,
      sum(weights[origin_results$winner_changed]),
      sum(weights[origin_results$winner_changed]) / sum(weights)))
  audit <- data.frame(check = c("Origin grid mass difference",
      "Maximum existing probability sum error", "Maximum expanded probability sum error",
      "Existing aggregate mass difference", "Expanded aggregate mass difference",
      "Station-volume unmatched identifiers", "Main optimizer convergence code",
      "Expanded sites nearer-or-equal for each HDB building"),
    value = c(sum(weights) - sum(buildings$dwelling_units),
      max(abs(rowSums(P) - 1)), max(abs(rowSums(P_after) - 1)),
      sum(fitted) - market_total, sum(after) - market_total,
      sum(!existing$station_id %in% observed$destination), fit$convergence,
      as.integer(all(distance_building_after <= distance_building_before + 1e-6))))
  stopifnot(all(is.finite(cv$fitted_daily)), all(is.finite(cv$baseline_daily)),
            all(distance_building_after <= distance_building_before + 1e-6))

  write_csv(station_results, file.path(output, "station-results.csv"))
  write_csv(origin_results, file.path(output, "origin-results.csv"))
  write_csv(origins |> select(origin_id, market_potential, x, y, lon, lat, blocks),
            file.path(output, "origin-market-potential.csv"))
  write_csv(station_results, file.path(output, "destination-attractions.csv"))
  write_csv(fit$bounds, file.path(output, "coefficients.csv"))
  write_csv(fit$diagnostics, file.path(output, "optimizer-diagnostics.csv"))
  write_csv(fit_all_day$bounds, file.path(output, "all-day-coefficients.csv"))
  write_csv(all_day_metrics, file.path(output, "all-day-metrics.csv"))
  write_csv(data.frame(destination = existing$station_id, observed_daily = y_all,
    fitted_daily = all_day_fitted), file.path(output, "all-day-station-results.csv"))
  write_csv(metrics, file.path(output, "model-metrics.csv"))
  write_csv(cv_metrics, file.path(output, "cv-metrics.csv"))
  write_csv(bind_rows(cv_details), file.path(output, "cv-sector-metrics.csv"))
  write_csv(bind_rows(cv_coefficients), file.path(output, "cv-coefficients.csv"))
  write_csv(cv, file.path(output, "cv-predictions.csv"))
  write_csv(scenario_totals, file.path(output, "scenario-totals.csv"))
  write_csv(accessibility, file.path(output, "accessibility-thresholds.csv"))
  write_csv(building_access, file.path(output, "building-accessibility.csv"))
  write_csv(sensitivity, file.path(output, "sensitivity.csv"))
  write_csv(sensitivity_station, file.path(output, "sensitivity-station-results.csv"))
  write_csv(audit, file.path(output, "model-audit.csv"))
  existing_frame <- interaction_frame03(origins, existing, D, P, fit$par[["beta_lines"]])
  expanded_frame <- interaction_frame03(origins, expanded, D_after, P_after,
                                        fit$par[["beta_lines"]])
  saveRDS(existing_frame, file.path(output, "spatial-interaction-existing.rds"), compress = "xz")
  saveRDS(expanded_frame, file.path(output, "spatial-interaction-expanded.rds"), compress = "xz")
  write_csv(existing_frame, file.path(output, "interactions-existing.csv.gz"))
  write_csv(expanded_frame, file.path(output, "interactions-expanded.csv.gz"))
  write_csv(head(existing_frame, 100), file.path(output, "interaction-existing-preview.csv"))
  write_csv(head(expanded_frame, 100), file.path(output, "interaction-expanded-preview.csv"))
  results <- list(origins = origin_results, stations = station_results,
    buildings = buildings, building_accessibility = building_access,
    existing_stations = existing, expanded_stations = expanded,
    fit = fit, fit_all_day = fit_all_day, metrics = metrics,
    all_day_metrics = all_day_metrics, cv_metrics = cv_metrics,
    cv_predictions = cv, scenario_totals = scenario_totals,
    sensitivity = sensitivity, sensitivity_station = sensitivity_station,
    accessibility = accessibility, audit = audit,
    settings = list(outcome = "Mean non-holiday weekday 06:00–09:59 entries",
      month = "2026-01", weekday_denominator = 21L, grid_m = 250,
      distance_offset_m = 200, crs = 3414, fixed_market = market_total,
      spatial_folds = "Four station-longitude quartiles, west to east",
      distance = "Straight-line metres", market_unit = "HDB dwelling units"))
  saveRDS(results, file.path(output, "report-results.rds"), compress = "xz")
  writeLines(trimws(capture.output(sessionInfo()), which = "right"),
              file.path(output, "session-info.txt"))
  packages <- c("sf", "dplyr", "tidyr", "readr", "digest", "jsonlite",
                "ggplot2", "scales", "leaflet", "htmlwidgets", "htmltools",
                "knitr", "rmarkdown", "MCI")
  write_csv(data.frame(package = packages,
    version = vapply(packages, function(p) as.character(utils::packageVersion(p)), character(1))),
    file.path(output, "package-versions.csv"))
  message("Exercise 3 analysis complete: ", nrow(existing_frame), " existing pairs; ",
          nrow(expanded_frame), " expanded pairs.")
  invisible(results)
}

results03 <- run_analysis03()
