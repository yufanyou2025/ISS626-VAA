# Full core workflow. Executed by the technical report in a fresh R process.
source("Take-home_Ex/Take-home_Ex02/prepare-events.R", encoding = "UTF-8")
source("Take-home_Ex/Take-home_Ex02/methods.R", encoding = "UTF-8")
suppressPackageStartupMessages({ library(sfdep); library(ggplot2) })
spdep::set.coresOption(1L)
fig02 <- file.path(ex02, "figures")
dir.create(fig02, recursive = TRUE, showWarnings = FALSE)

# Three genuine islands remain in descriptive tables and in the full cube.
# Spatial inference uses the connected 327-township mainland component.
inference02 <- townships02[!islands02, ]
nb02 <- subset(queen02, !islands02)
nb_rook02 <- subset(rook02, !islands02)
stopifnot(all(spdep::card(nb02) > 0), all(spdep::card(nb_rook02) > 0),
          spdep::n.comp.nb(nb02)$nc == 1L)
lw02 <- spdep::nb2listw(nb02, style = "W")
tot_inference02 <- totals02[match(inference02$township_id, totals02$township_id), ]
stopifnot(identical(tot_inference02$township_id, inference02$township_id))

run_local02 <- function(x, nb, variable, spec) {
  lw <- spdep::nb2listw(nb, style = "W")
  set.seed(config02$seed)
  moran <- spdep::localmoran_perm(x, lw, nsim = config02$nsim,
                                  alternative = "two.sided", iseed = config02$seed,
                                  no_repeat_in_row = TRUE)
  z <- x - mean(x)
  lag_z <- spdep::lag.listw(lw, z)
  # Column 6 is the alternative-aware simulated p, not the folded tail (col 7).
  p <- moran[, 6]
  gi_nb <- spdep::include.self(nb)
  gi_wt <- spdep::nb2listw(gi_nb, style = "W")
  gi <- spdep::localG_perm(x, gi_wt, nsim = config02$nsim,
                           alternative = "two.sided", iseed = config02$seed,
                           no_repeat_in_row = TRUE)
  gi_result <- attr(gi, "internals")
  gi_p <- gi_result[, "Pr(z != E(Gi)) Sim"]
  tibble(township_id = inference02$township_id, variable = variable, specification = spec,
         value = x, local_i = moran[, 1], moran_p = p, moran_q = p.adjust(p, "BH"),
         quadrant = case_when(z > 0 & lag_z > 0 ~ "High-high", z < 0 & lag_z < 0 ~ "Low-low",
                              z > 0 & lag_z < 0 ~ "High-low", TRUE ~ "Low-high"),
         gi_star = as.numeric(gi), gi_p = gi_p, gi_q = p.adjust(gi_p, "BH")) |>
    mutate(lisa_class = if_else(moran_p < .05, quadrant, "Not significant"),
           gi_class = case_when(gi_p >= .05 ~ "Not significant", gi_star > 0 ~ "Hot spot", TRUE ~ "Cold spot"))
}
local02 <- bind_rows(
  run_local02(tot_inference02$events, nb02, "Events", "Queen"),
  run_local02(tot_inference02$fatalities, nb02, "Reported fatalities", "Queen"),
  run_local02(tot_inference02$events, nb_rook02, "Events", "Rook"),
  run_local02(tot_inference02$precise_events, nb02, "Events", "Precision 1 only"))
stopifnot(nrow(local02) == 327L * 4L, all(is.finite(local02$gi_star)),
          all(between(local02$moran_p, 0, 1)), all(between(local02$gi_p, 0, 1)))
write_csv(local02, file.path(out02, "local-results.csv"))
set.seed(config02$seed)
global02 <- spdep::moran.mc(tot_inference02$events, lw02, nsim = config02$nsim,
                            alternative = "greater")
write_csv(tibble(statistic = as.numeric(global02$statistic), p_value = global02$p.value,
                 nsim = config02$nsim), file.path(out02, "global-moran.csv"))
write_csv(local02 |> group_by(variable, specification) |>
            summarise(lisa_p05 = sum(moran_p < .05), lisa_bh05 = sum(moran_q < .05),
                       gi_p05 = sum(gi_p < .05), gi_bh05 = sum(gi_q < .05), .groups = "drop"),
          file.path(out02, "local-significance.csv"))

# Build an explicit space-time graph and use spdep's Gi* implementation.
# Standardisation uses all mainland township-quarter bins as the reference.
# The conditional null holds the focal bin fixed and permutes other bin values.
# This is deliberately distinct from sfdep 0.2.5's slice-standardised routine.
run_ehsa02 <- function(nb, spec, count_column = "events") {
  q <- quarterly02 |> filter(township_id %in% inference02$township_id) |>
    arrange(quarter, township_id)
  cube <- sfdep::spacetime(q, inference02, .loc_col = "township_id", .time_col = "quarter")
  stopifnot(sfdep::is_spacetime_cube(cube), nrow(cube) == 327L * 19L)
  self_nb <- spdep::include.self(nb)
  n_loc <- nrow(inference02)
  graph <- lapply(seq_len(nrow(q)), function(index) {
    time <- (index - 1L) %/% n_loc
    location <- (index - 1L) %% n_loc + 1L
    current <- self_nb[[location]] + time * n_loc
    previous <- if (time > 0L) self_nb[[location]] + (time - 1L) * n_loc else integer()
    as.integer(sort(c(current, previous)))
  })
  class(graph) <- "nb"
  attr(graph, "region.id") <- paste(q$township_id, q$quarter, sep = "_")
  attr(graph, "sym") <- FALSE
  attr(graph, "self.included") <- TRUE
  lw <- spdep::nb2listw(graph, style = "W")
  stopifnot(all(vapply(seq_along(graph), function(i) i %in% graph[[i]], logical(1))),
            all(lengths(graph) > 1))
  set.seed(config02$seed)
  message("Space-time permutations: ", spec)
  gi <- spdep::localG_perm(q[[count_column]], lw, nsim = config02$nsim,
                           alternative = "two.sided", iseed = config02$seed,
                           no_repeat_in_row = TRUE)
  internals <- attr(gi, "internals")
  bins <- q |> select(quarter, township_id, events, fatalities) |>
    mutate(gi_star = as.numeric(gi), p_two = internals[, "Pr(z != E(Gi)) Sim"],
           q_bh = p.adjust(p_two, "BH"), specification = spec)
  trends <- bind_rows(lapply(split(bins, bins$township_id), function(d) {
    d <- arrange(d, quarter)
    mk <- mk02(d$gi_star)
    tibble(township_id = d$township_id[1], tau = mk[["tau"]], trend_p = mk[["p_value"]],
           hot_quarters = sum(d$gi_star > 0 & d$p_two < .05),
           cold_quarters = sum(d$gi_star < 0 & d$p_two < .05),
           final_gi = tail(d$gi_star, 1), final_bin_p = tail(d$p_two, 1),
           classification = classify_ehsa02(d$gi_star, d$p_two, mk[["tau"]], mk[["p_value"]]),
           bh_bin_class = classify_ehsa02(d$gi_star, d$q_bh, mk[["tau"]], mk[["p_value"]]))
  })) |>
    mutate(trend_q = p.adjust(trend_p, "BH"), specification = spec)
  list(bins = bins, trends = trends)
}
base_ehsa02 <- run_ehsa02(nb02, "Queen")
rook_ehsa02 <- run_ehsa02(nb_rook02, "Rook")
precision_ehsa02 <- run_ehsa02(nb02, "Precision 1 only", "precise_events")
bins02 <- bind_rows(base_ehsa02$bins, rook_ehsa02$bins, precision_ehsa02$bins)
ehsa02 <- bind_rows(base_ehsa02$trends, rook_ehsa02$trends, precision_ehsa02$trends)
stopifnot(nrow(bins02) == 327L * 19L * 3L, !anyNA(ehsa02$classification),
          all(is.finite(bins02$gi_star)), all(between(bins02$p_two, 0, 1)))
write_csv(bins02, file.path(out02, "space-time-gistar.csv"))
write_csv(ehsa02, file.path(out02, "ehsa-results.csv"))
write_csv(ehsa02 |> count(specification, classification, name = "townships"),
          file.path(out02, "ehsa-class-counts.csv"))

# Block permutations assess how much ordinary MK evidence relies on treating
# adjacent quarters as exchangeable. They remain sensitivity checks, not a
# guaranteed correction for every source of serial dependence.
message("Trend block sensitivity")
blocks02 <- bind_rows(lapply(split(base_ehsa02$bins, base_ehsa02$bins$township_id), function(d) {
  d <- arrange(d, quarter)
  tibble(township_id = d$township_id[1],
         lag1 = as.numeric(acf(d$gi_star, plot = FALSE, lag.max = 1)$acf[2]),
         block2_p = block_trend02(d$gi_star, 2L, seed = config02$seed),
         block3_p = block_trend02(d$gi_star, 3L, seed = config02$seed))
})) |>
  mutate(block2_q = p.adjust(block2_p, "BH"), block3_q = p.adjust(block3_p, "BH"))
write_csv(blocks02, file.path(out02, "trend-block-sensitivity.csv"))
saveRDS(list(townships = townships02, inference = inference02, totals = totals02,
             local = local02, bins = bins02, ehsa = ehsa02, blocks = blocks02),
        file.path(ex02, "data/processed/core-results.rds"))
source(file.path(ex02, "scan.R"), encoding = "UTF-8")
source(file.path(ex02, "visualise.R"), encoding = "UTF-8")
# Direct attribution travels with downloadable analytical data files.
attribution02 <- "ACLED (Armed Conflict Location & Event Data), course file accessed 2026-10-08; https://acleddata.com/; original township/time aggregation and statistics"
for (file in c("monthly-cube.csv", "quarterly-cube.csv", "township-totals.csv",
               "national-monthly.csv", "analytical-event-types.csv", "local-results.csv",
               "space-time-gistar.csv", "ehsa-results.csv", "redistribution-scan.csv")) {
  table <- read_csv(file.path(out02, file), show_col_types = FALSE)
  table$source <- attribution02
  write_csv(table, file.path(out02, file))
}
writeLines(capture.output(sessionInfo()), file.path(out02, "session-info.txt"))
packages02 <- c("sf", "sfdep", "spdep", "dplyr", "tidyr", "readr", "ggplot2", "Kendall", "digest", "knitr")
write_csv(tibble(package = packages02,
                 version = vapply(packages02, function(p) as.character(packageVersion(p)), character(1))),
          file.path(out02, "package-versions.csv"))
message("Take-home 2 analysis and figures complete.")
