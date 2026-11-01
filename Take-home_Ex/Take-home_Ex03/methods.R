# Shared-parameter Huff model calibrated against aggregate station entry totals.
# A destination is a physical access site, including all of its rail lines.
# Local residence-to-station shares are unobserved, so this is aggregate
# calibration, not an MCI regression on observed individual station choices.

huff_prob <- function(distance, station, decay = 2, beta_lines = 0,
                      beta_bus = 0, offset = 200) {
  D <- as.matrix(distance)
  if (!is.numeric(D) || !length(D) || any(!is.finite(D)) || any(D < 0)) {
    stop("Distances must be a finite nonnegative numeric matrix in metres.")
  }
  if (ncol(D) != nrow(station) || !"lines" %in% names(station) ||
      any(!is.finite(station$lines)) || any(station$lines < 1)) {
    stop("Station rows must match distance columns and lines must be positive.")
  }
  pars <- c(decay, beta_lines, beta_bus, offset)
  if (any(!is.finite(pars)) || decay <= 0 || offset <= 0) {
    stop("Model parameters must be finite; decay and offset must be positive.")
  }
  attraction <- beta_lines * log(station$lines)
  if ("bus_count" %in% names(station)) {
    if (any(!is.finite(station$bus_count)) || any(station$bus_count < 0)) {
      stop("Bus-stop counts must be finite and nonnegative.")
    }
    attraction <- attraction + beta_bus * log1p(station$bus_count)
  } else if (beta_bus != 0) {
    stop("A nonzero bus coefficient requires station$bus_count.")
  }
  # The 200 m offset regularises colocated origins and station centre points.
  # Compute normalized utilities in log space to avoid numerical overflow.
  U <- sweep(-decay * log(D + offset), 2, attraction, "+")
  U <- exp(U - apply(U, 1, max))
  P <- U / rowSums(U)
  dimnames(P) <- dimnames(D)
  if (max(abs(rowSums(P) - 1)) > 1e-10 || any(!is.finite(P))) {
    stop("Huff probabilities failed their row-sum or finite-value check.")
  }
  P
}

huff_aggregate <- function(probability, weights) {
  P <- as.matrix(probability)
  if (length(weights) != nrow(P) || any(!is.finite(weights)) ||
      any(weights < 0) || sum(weights) <= 0) {
    stop("Origin weights must match probability rows and have positive mass.")
  }
  shares <- as.numeric(crossprod(weights / sum(weights), P))
  names(shares) <- colnames(P)
  if (abs(sum(shares) - 1) > 1e-9 || any(shares < 0)) {
    stop("Aggregate station shares failed the mass-conservation check.")
  }
  shares
}

fit_huff <- function(D, attraction_df, weights, y,
                     training_indices = seq_along(y), delta = 200) {
  D <- as.matrix(D)
  n <- ncol(D)
  if (length(y) != n || !length(training_indices) ||
      anyDuplicated(training_indices) ||
      any(!training_indices %in% seq_len(n))) {
    stop("Training indices must identify unique existing station columns.")
  }
  tr <- as.integer(training_indices)
  if (length(tr) < 3L || any(!is.finite(y[tr])) || any(y[tr] < 0) ||
      sum(y[tr]) <= 0) {
    stop("Calibration needs at least three nonnegative observed station totals.")
  }
  use_bus <- "bus_count" %in% names(attraction_df)
  par_names <- c("decay", "beta_lines", if (use_bus) "beta_bus")
  lower <- c(decay = 0.5, beta_lines = 0, if (use_bus) c(beta_bus = 0))
  upper <- c(decay = 5, beta_lines = 2, if (use_bus) c(beta_bus = 2))
  # Half a count is only a log safeguard for zero-volume stations. It is
  # applied to training observations, never to holdout outcomes.
  target <- (y[tr] + 0.5) / sum(y[tr] + 0.5)
  shares_at <- function(par) {
    P <- huff_prob(D, attraction_df, decay = par[1], beta_lines = par[2],
                   beta_bus = if (use_bus) par[3] else 0, offset = delta)
    huff_aggregate(P, weights)
  }
  loss <- function(par) {
    sh <- shares_at(par)[tr]
    mean((log(pmax(sh / sum(sh), 1e-15)) - log(target))^2)
  }
  # Deterministic starts make optimization reproducible and expose local fits.
  starts <- expand.grid(decay = c(1, 2, 4), beta_lines = c(0.25, 1.5))
  if (use_bus) starts$beta_bus <- rep(c(0.25, 1), length.out = nrow(starts))
  fits <- lapply(seq_len(nrow(starts)), function(i) {
    start <- setNames(as.numeric(starts[i, par_names]), par_names)
    stats::optim(start, loss, method = "L-BFGS-B", lower = lower,
                 upper = upper, control = list(maxit = 300, factr = 1e7))
  })
  objective <- vapply(fits, function(f) f$value, numeric(1))
  best <- fits[[which.min(objective)]]
  names(best$par) <- par_names
  shares <- shares_at(best$par)
  # This count scale uses training totals only. Holdout y is never used here.
  # All destinations, including holdouts, remain in each origin's choice set.
  count_scale <- sum(y[tr]) / sum(shares[tr])
  bounds <- data.frame(parameter = par_names, estimate = unname(best$par),
                       lower = unname(lower), upper = unname(upper))
  bounds$at_boundary <- abs(bounds$estimate - bounds$lower) < 1e-5 |
    abs(bounds$estimate - bounds$upper) < 1e-5
  diagnostics <- do.call(rbind, lapply(seq_along(fits), function(i) {
    f <- fits[[i]]
    data.frame(start = i, loss = f$value, convergence = f$convergence,
               function_evaluations = unname(f$counts["function"]),
               message = if (is.null(f$message)) "" else f$message,
               t(setNames(f$par, par_names)), check.names = FALSE)
  }))
  list(par = best$par, coefficients = best$par, objective = best$value,
       convergence = best$convergence, message = best$message,
       shares = shares, predicted = count_scale * shares,
       training_count_scale = count_scale, training_indices = tr,
       delta = delta, bounds = bounds, diagnostics = diagnostics,
       loss_description = paste("Mean squared log conditional station-share",
                                "error; training observations receive +0.5"))
}

station_metrics <- function(observed, predicted, model = "model") {
  ok <- is.finite(observed) & is.finite(predicted)
  if (!any(ok) || any(observed[ok] < 0) || any(predicted[ok] < 0)) {
    stop("Metrics require finite nonnegative station totals.")
  }
  obs <- observed[ok]
  pred <- predicted[ok]
  data.frame(model = model, stations = length(obs),
             MAE = mean(abs(pred - obs)),
             RMSE = sqrt(mean((pred - obs)^2)),
             RMSLE = sqrt(mean((log1p(pred) - log1p(obs))^2)),
             WAPE = if (sum(obs) > 0) sum(abs(pred - obs)) / sum(obs) else NA_real_,
             Spearman = if (length(obs) > 2 && sd(obs) > 0 && sd(pred) > 0)
               suppressWarnings(cor(obs, pred, method = "spearman")) else NA_real_,
             observed_total = sum(obs), predicted_total = sum(pred))
}

# An equal-attraction inverse-square Huff model provides a transparent baseline.
baseline_huff <- function(D, attraction_df, weights, total, delta = 200) {
  p <- huff_prob(D, attraction_df, decay = 2, beta_lines = 0,
                 beta_bus = 0, offset = delta)
  total * huff_aggregate(p, weights)
}
