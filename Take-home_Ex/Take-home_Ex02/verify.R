# Statistical and sample checks independent of visual layout.
source("Take-home_Ex/Take-home_Ex02/config.R", encoding = "UTF-8")
source(file.path(ex02, "methods.R"), encoding = "UTF-8")
read02 <- function(file) readr::read_csv(file.path(ex02, "outputs", file), show_col_types = FALSE)
monthly <- read02("monthly-cube.csv")
quarterly <- read02("quarterly-cube.csv")
totals <- read02("township-totals.csv")
local <- read02("local-results.csv")
bins <- read02("space-time-gistar.csv")
ehsa <- read02("ehsa-results.csv")
scan <- read02("redistribution-scan.csv")
stopifnot(nrow(monthly) == 18810, nrow(quarterly) == 6270, nrow(totals) == 330,
          sum(monthly$events) == 53899, sum(quarterly$events) == 53899,
          sum(monthly$fatalities) == sum(totals$fatalities),
          !anyDuplicated(monthly[c("month", "township_id")]),
          !anyDuplicated(quarterly[c("quarter", "township_id")]),
          nrow(local) == 1308, nrow(bins) == 18639, nrow(ehsa) == 981,
          all(local$moran_p[local$lisa_class != "Not significant"] < .05),
          all(local$gi_p[local$gi_class != "Not significant"] < .05),
          all(is.finite(bins$gi_star)), all(bins$p_two >= 0 & bins$p_two <= 1),
          all(ehsa$trend_q >= ehsa$trend_p - 1e-12),
          all(scan$search_adjusted_p > 0 & scan$search_adjusted_p <= 1),
          all(scan$recent_share > scan$early_share))

# Known chronological patterns test the class definitions rather than package
# agreement. A sign change in an early bin must not become a persistent class.
quiet <- rep(1, 19)
ns <- rep(.5, 19)
check02 <- function(gi, p, tau, trend_p, expected) {
  stopifnot(identical(classify_ehsa02(gi, p, tau, trend_p), expected))
}
check02(quiet, ns, 0, .8, "No pattern detected")
check02(quiet, c(rep(.5, 18), .01), .3, .02, "New hot spot")
check02(-quiet, c(rep(.5, 18), .01), -.3, .02, "New cold spot")
check02(quiet, c(rep(.5, 17), .01, .01), .3, .02, "Consecutive hot spot")
check02(quiet, rep(.01, 19), .3, .02, "Intensifying hot spot")
check02(-quiet, rep(.01, 19), -.3, .02, "Intensifying cold spot")
check02(quiet, rep(.01, 19), -.3, .02, "Diminishing hot spot")
check02(quiet, rep(.01, 19), 0, .8, "Persistent hot spot")
check02(quiet, c(rep(.01, 18), .5), -.3, .02, "Historical hot spot")
check02(quiet, c(.01, rep(.5, 17), .01), .3, .02, "Sporadic hot spot")
check02(c(-1, rep(1, 18)), c(.01, rep(.5, 17), .01), .3, .02, "New hot spot")
check02(c(-1, rep(1, 18)), c(.01, .01, rep(.5, 16), .01), .3, .02, "Oscillating hot spot")
check02(quiet, rep(.05, 19), .3, .02, "No pattern detected")
message("Verified sample reconciliation, cube keys, significance, scan direction and chronological class rules.")
