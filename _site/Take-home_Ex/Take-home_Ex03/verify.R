# Meaningful numerical verification; run after analysis.R from project root.
# This script checks saved results without re-running the empirical fits.
verify_report03 <- function(base_dir = "Take-home_Ex/Take-home_Ex03") {
  output <- file.path(base_dir, "outputs")
  source(file.path(base_dir, "methods.R"), encoding = "UTF-8")
  r <- readRDS(file.path(output, "report-results.rds"))
  existing_frame <- readRDS(file.path(output, "spatial-interaction-existing.rds"))
  expanded_frame <- readRDS(file.path(output, "spatial-interaction-expanded.rds"))
  checks <- list()
  add <- function(label, value, passed) {
    checks[[length(checks) + 1L]] <<- data.frame(check = label,
      value = as.character(value), passed = isTRUE(passed))
  }
  ns <- nrow(r$existing_stations)
  ne <- nrow(r$expanded_stations)
  no <- nrow(r$origins)
  total <- r$settings$fixed_market
  add("Existing physical sites", ns, ns == 181L)
  add("Expanded physical sites", ne, ne == 210L)
  add("Unique source HDB origins", nrow(r$buildings),
      nrow(r$buildings) == 10740L && !anyDuplicated(r$buildings$origin_id))
  add("Dwelling market potential", sum(r$origins$market_potential),
      sum(r$origins$market_potential) == 1167327 &&
        sum(r$origins$market_potential) == sum(r$buildings$dwelling_units))
  add("January weekday morning volume conserved", total,
      abs(total - 18549493 / 21) < 1e-6)
  add("New physical alternatives", sum(r$stations$status == "new"),
      sum(r$stations$status == "new") == 29L)
  upgrade <- with(r$stations, status == "existing" & lines_after > lines_before)
  add("Existing physical sites with added lines", sum(upgrade), sum(upgrade) == 7L)
  add("Main optimizer converged", r$fit$convergence, r$fit$convergence == 0L)
  bounds <- r$fit$bounds
  add("Finite coefficients inside declared bounds", paste(round(bounds$estimate, 6), collapse = "; "),
      all(is.finite(bounds$estimate)) && all(bounds$estimate >= bounds$lower) &&
        all(bounds$estimate <= bounds$upper))
  # A boundary optimum is a diagnostic to disclose, not a numerical failure.
  add("Coefficient boundary flags (diagnostic)", sum(bounds$at_boundary), TRUE)
  add("Selected optimization loss equals best start", r$fit$objective,
      abs(r$fit$objective - min(r$fit$diagnostics$loss)) < 1e-10)
  for (which_frame in c("existing", "expanded")) {
    frame <- if (which_frame == "existing") existing_frame else expanded_frame
    stations <- if (which_frame == "existing") ns else ne
    add(paste(which_frame, "complete origin-destination pairs"), nrow(frame),
        nrow(frame) == no * stations &&
          !anyDuplicated(frame[c("origin_id", "destination")]))
    ps <- tapply(frame$p_ij, frame$origin_id, sum)
    probability_error <- max(abs(ps - 1))
    add(paste(which_frame, "probability row-sum maximum error"), probability_error,
        probability_error < 1e-10 && all(is.finite(frame$p_ij)) &&
          all(frame$p_ij >= 0 & frame$p_ij <= 1))
    reconstructed <- tapply(frame$market_potential * frame$p_ij,
                            frame$destination, sum)
    reconstructed <- reconstructed / sum(r$origins$market_potential) * total
    predicted <- if (which_frame == "existing") {
      stats::setNames(r$stations$fitted_daily[r$stations$status == "existing"],
                      r$stations$destination[r$stations$status == "existing"])
    } else stats::setNames(r$stations$expanded_daily, r$stations$destination)
    reconstruction_error <- max(abs(reconstructed - predicted[names(reconstructed)]))
    add(paste(which_frame, "volumes reconstructed from interaction frame"),
        reconstruction_error, reconstruction_error < 1e-6)
    add(paste(which_frame, "aggregate count conservation error"),
        sum(predicted) - total, abs(sum(predicted) - total) < 1e-6)
  }
  add("Spatial holdout prediction coverage", nrow(r$cv_predictions),
      nrow(r$cv_predictions) == ns && !anyDuplicated(r$cv_predictions$destination) &&
        all(is.finite(r$cv_predictions$fitted_daily)) &&
        all(is.finite(r$cv_predictions$baseline_daily)))
  a <- r$accessibility
  add("Building-point access mass reconciliation", nrow(a),
      all(a$dwellings_after - a$dwellings_before == a$dwellings_newly_served) &&
        all(a$dwellings_after + a$dwellings_still_beyond == a$dwelling_units_total))
  add("All sensitivity optimizers converged", paste(r$sensitivity$convergence, collapse = "; "),
      all(r$sensitivity$convergence == 0L))

  # Independently reproduce complete choice sets for five origins with MCI.
  # Distance already includes the same offset; attraction is lines^beta.
  preview <- existing_frame[existing_frame$origin_id %in%
    head(unique(existing_frame$origin_id), 5), ]
  preview$distance <- preview$distance + r$settings$distance_offset_m
  independent <- MCI::huff.shares(preview, "origin_id", "destination",
    "attraction", "distance", gamma = 1, lambda = -r$fit$par[["decay"]],
    check_df = FALSE)
  comparison <- merge(preview[c("origin_id", "destination", "p_ij")],
    independent[c("origin_id", "destination", "p_ij")],
    by = c("origin_id", "destination"), suffixes = c("_ours", "_MCI"))
  independent_error <- max(abs(comparison$p_ij_ours - comparison$p_ij_MCI))
  add("Independent MCI probability check", independent_error,
      nrow(comparison) == nrow(preview) && independent_error < 1e-10)

  # Leakage check on a small synthetic fixture: radically changing the withheld
  # outcome must not affect calibration or its training-only count scale.
  dd <- matrix(c(0, 1000, 2000, 3000, 4000, 5000,
    600, 1400, 2200, 2800, 3600, 4200,
    3000, 2500, 1900, 1300, 700, 100), nrow = 3, byrow = TRUE)
  aa <- data.frame(lines = c(1, 2, 1, 3, 1, 1))
  ww <- c(500, 300, 200)
  yy <- 1e5 * huff_aggregate(huff_prob(dd, aa, decay = 2.1, beta_lines = 0.7), ww)
  f1 <- fit_huff(dd, aa, ww, yy, training_indices = 1:5)
  yy[6] <- 1e12
  f2 <- fit_huff(dd, aa, ww, yy, training_indices = 1:5)
  leakage_error <- max(abs(f1$predicted - f2$predicted))
  add("Synthetic held-out outcome leakage check", leakage_error, leakage_error < 1e-10)
  result <- do.call(rbind, checks)
  readr::write_csv(result, file.path(output, "model-verification.csv"))
  if (!all(result$passed)) {
    stop("Numerical verification failed: ", paste(result$check[!result$passed], collapse = "; "))
  }
  message("Exercise 3: ", nrow(result), " numerical checks passed.")
  invisible(result)
}

verification03 <- verify_report03()
