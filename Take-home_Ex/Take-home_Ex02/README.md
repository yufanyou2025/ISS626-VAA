# Take-home Exercise 2 — Myanmar conflict geography

Study window: **1 January 2021–30 September 2025**. Geography: **MIMU v9.4 townships**. Due: **25 October 2026, 11:59 pm Singapore time**.

## Current progress

The assignment specification and senior examples have been reviewed. The required boundary input is downloaded locally and validated. Conflict analysis is awaiting the original ACLED file supplied through eLearn. The technical report and executive summary are not yet complete or published.

- [Specification and methodological decisions](notes/brief-and-design.md)
- [Input instructions and restrictions](data/README.md)
- [Shared parameters](config.R)
- [Executable boundary validation](prepare-boundaries.R)
- [Boundary checks](outputs/boundary-audit.csv)
- [Township neighbour checks](outputs/township-neighbour-audit.csv)
- [Pinned input hashes](outputs/boundary-manifest.csv)

## Run the completed preparation step

Open `ISS626-VAA.Rproj` and run from the project root:

```r
# Install once if needed:
# install.packages(c("sf", "spdep", "dplyr", "readr", "digest"))
source("Take-home_Ex/Take-home_Ex02/prepare-boundaries.R", encoding = "UTF-8")
```

The script stops if the downloaded content differs from the validated snapshot. Boundary inputs remain in ignored local directories. The outputs contain audit information and names, not geometry or conflict records.

## Remaining deliverables

1. Inspect and audit the supplied ACLED input, then aggregate events and reported fatalities.
2. Run local association and quarterly EHSA, assess sensitivity, and retain only a useful value-added extension.
3. Write and render the HTML technical report and reveal.js executive summary (at most 10 content slides).
4. Verify the report, slides, restricted-data exclusion and public links; update coursework navigation and publish through the existing GitHub/Vercel workflow.
5. Prepare the reproducibility package and submission links. eLearn submission remains with the student unless separately requested and completed.

Progress commits record actual completed work with normal timestamps.
