# Small transparent helpers, shared by the analysis and its verification.
classify_ehsa02 <- function(gi, p, tau, trend_p, alpha = .05) {
  # Separate bin and trend tests, require the correct sign for each family,
  # and require the final bin for consecutive/sporadic/oscillating classes.
  hot <- gi > 0 & p < alpha
  cold <- gi < 0 & p < alpha
  n <- length(gi)
  classify_family <- function(hit, other, label, direction) {
    proportion <- mean(hit)
    if (!hit[n] && proportion >= .9) return(paste("Historical", label))
    if (proportion >= .9) {
      if (trend_p < alpha && tau * direction > 0) return(paste("Intensifying", label))
      if (trend_p < alpha && tau * direction < 0) return(paste("Diminishing", label))
      return(paste("Persistent", label))
    }
    if (!hit[n]) return(NULL)
    if (sum(hit) == 1L) return(paste("New", label))
    run <- rle(rev(hit))$lengths[1]
    if (run >= 2L && sum(hit) == run) return(paste("Consecutive", label))
    if (any(other)) return(paste("Oscillating", label))
    return(paste("Sporadic", label))
  }
  h <- classify_family(hot, cold, "hot spot", 1)
  if (!is.null(h)) return(h)
  c <- classify_family(cold, hot, "cold spot", -1)
  if (!is.null(c)) return(c)
  "No pattern detected"
}

mk02 <- function(x) {
  r <- Kendall::MannKendall(x)
  c(tau = as.numeric(r$tau), p_value = as.numeric(r$sl))
}

block_trend02 <- function(x, block = 2L, nsim = 999L, seed = 6262026L) {
  # Exploratory sensitivity: shuffle contiguous blocks rather than quarters.
  # This preserves short within-block dependence, not seasonality or all lags.
  n <- length(x)
  blocks <- split(seq_len(n), ceiling(seq_len(n) / block))
  score <- function(z) sum(sign(outer(z, z, "-")[lower.tri(matrix(0, n, n))]))
  observed <- score(x)
  set.seed(seed)
  simulated <- replicate(nsim, score(x[unlist(blocks[sample.int(length(blocks))])]))
  (1 + sum(abs(simulated) >= abs(observed))) / (nsim + 1)
}
