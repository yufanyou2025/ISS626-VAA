# Value-added question: where did the national share of recorded conflict move?
# Bernoulli spatial scan: equal 21-month early/recent windows, conditional on
# both the township totals and the nationwide number of recent events.
# This tests geographic redistribution, not a causal change or population risk.
early02 <- events02 |> filter(event_date <= as.Date("2022-09-30")) |> count(township_id)
recent02 <- events02 |> filter(event_date >= as.Date("2024-01-01")) |> count(township_id)
scan_data02 <- st_drop_geometry(inference02) |>
  left_join(rename(early02, early = n), by = "township_id") |>
  left_join(rename(recent02, recent = n), by = "township_id") |>
  mutate(across(c(early, recent), ~replace_na(.x, 0L)), total = early + recent)
sites02 <- st_point_on_surface(inference02)
dist02 <- as.matrix(st_distance(sites02)) / 1000
candidates02 <- list()
candidate_centres02 <- integer()
candidate_radii02 <- numeric()
for (centre in seq_len(nrow(inference02))) {
  order02 <- order(dist02[centre, ], inference02$township_id)
  for (size in 1:30) {
    members <- order02[seq_len(size)]
    mass <- sum(scan_data02$total[members])
    if (mass > 0 && mass <= .2 * sum(scan_data02$total)) {
      candidates02[[length(candidates02) + 1L]] <- members
      candidate_centres02 <- c(candidate_centres02, centre)
      candidate_radii02 <- c(candidate_radii02, max(dist02[centre, members]))
    }
  }
}
# Deduplicate identical circles' membership so the search is reproducible.
keys02 <- vapply(candidates02, function(z) paste(sort(z), collapse = ","), character(1))
unique02 <- !duplicated(keys02)
candidates02 <- candidates02[unique02]
candidate_centres02 <- candidate_centres02[unique02]
candidate_radii02 <- candidate_radii02[unique02]
A02 <- Matrix::sparseMatrix(i = rep(seq_along(candidates02), lengths(candidates02)),
                            j = unlist(candidates02), x = 1,
                            dims = c(length(candidates02), nrow(inference02)))
inside_n02 <- as.numeric(A02 %*% scan_data02$total)
total_n02 <- sum(scan_data02$total)
recent_n02 <- sum(scan_data02$recent)
base_p02 <- recent_n02 / total_n02
term02 <- function(a, b) ifelse(a > 0, a * log(pmax(a, 1e-100) / b), 0)
llr02 <- function(inside_recent) {
  inside_old <- inside_n02 - inside_recent
  outside_recent <- recent_n02 - inside_recent
  outside_old <- total_n02 - inside_n02 - outside_recent
  out <- term02(inside_recent, inside_n02 * base_p02) +
    term02(inside_old, inside_n02 * (1 - base_p02)) +
    term02(outside_recent, (total_n02 - inside_n02) * base_p02) +
    term02(outside_old, (total_n02 - inside_n02) * (1 - base_p02))
  ifelse(inside_recent / inside_n02 > base_p02, out, 0)
}
observed_recent02 <- as.numeric(A02 %*% scan_data02$recent)
observed_llr02 <- llr02(observed_recent02)
draw_labels02 <- function() {
  left_recent <- recent_n02
  left_total <- total_n02
  draw <- integer(nrow(inference02))
  for (i in seq_len(length(draw) - 1L)) {
    draw[i] <- rhyper(1, left_recent, left_total - left_recent, scan_data02$total[i])
    left_recent <- left_recent - draw[i]
    left_total <- left_total - scan_data02$total[i]
  }
  draw[length(draw)] <- left_recent
  stopifnot(sum(draw) == recent_n02, all(draw <= scan_data02$total))
  draw
}
set.seed(config02$seed + 100L)
message("Spatial redistribution scan: ", length(candidates02), " candidate circles")
null_max02 <- replicate(config02$nsim,
                        max(llr02(as.numeric(A02 %*% draw_labels02()))))
# Report at most three non-overlapping candidates. Each p-value compares with
# the maximum from the entire search, not a single preselected circle.
selected02 <- integer()
used02 <- integer()
for (j in order(observed_llr02, decreasing = TRUE)) {
  if (!any(candidates02[[j]] %in% used02)) {
    selected02 <- c(selected02, j)
    used02 <- c(used02, candidates02[[j]])
  }
  if (length(selected02) == 3L) break
}
scan_results02 <- bind_rows(lapply(seq_along(selected02), function(rank) {
  j <- selected02[rank]
  z <- candidates02[[j]]
  inside_recent <- observed_recent02[j]
  inside_early <- inside_n02[j] - inside_recent
  tibble(cluster = rank, centre = scan_data02$township[candidate_centres02[j]],
         radius_km = candidate_radii02[j], townships = length(z),
         early_events = inside_early, recent_events = inside_recent,
         early_share = inside_early / (total_n02 - recent_n02),
         recent_share = inside_recent / recent_n02,
         share_ratio = (inside_recent / recent_n02) / (inside_early / (total_n02 - recent_n02)),
         llr = observed_llr02[j],
         search_adjusted_p = (1 + sum(null_max02 >= observed_llr02[j])) / (config02$nsim + 1),
         members = paste(scan_data02$township[z], collapse = "; "))
}))
write_csv(scan_results02, file.path(out02, "redistribution-scan.csv"))
write_csv(tibble(simulation = seq_along(null_max02), maximum_llr = null_max02),
          file.path(out02, "scan-null-maxima.csv"))
write_csv(tibble(early_window = "2021-01-01 to 2022-09-30", recent_window = "2024-01-01 to 2025-09-30",
                 early_events = total_n02 - recent_n02, recent_events = recent_n02,
                 candidate_circles = length(candidates02), max_townships = 30,
                 maximum_combined_event_share = .2, simulations = config02$nsim,
                 seed = config02$seed + 100L), file.path(out02, "scan-design.csv"))
scan_membership02 <- rep("Outside selected clusters", nrow(inference02))
for (rank in seq_along(selected02)) {
  if (scan_results02$search_adjusted_p[rank] < .05)
    scan_membership02[candidates02[[selected02[rank]]]] <- paste("Cluster", rank)
}
