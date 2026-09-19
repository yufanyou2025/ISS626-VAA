# Exercise 4 progress

Dates record actual work, not a reconstructed timeline. All timestamps are Asia/Singapore; Git records the exact commit times.

## 19 September 2026 — Data preparation

- Reviewed Chapter 8 and identified its spatial-weight and spatial-lag tasks.
- Located the supplied ZIP and confirmed it contains the required Hunan inputs.
- Added a reproducible extraction/import workflow, explicit one-to-one county join, input checksums and validation checks.
- Checked the supplied dictionary: GDPPC is gross domestic product per capita, in RMB. It is not household income or aggregate GDP.

## 19 September 2026 — Analysis and figure preparation

- Reproduced 448 Queen links, 440 Rook links and 324 links under the 62-km definition.
- Checked graph components, directed versus symmetric KNN, kilometre distances, inverse-distance weights and row sums.
- Computed all four chapter lag/window measures and reconciled them against independent arithmetic for every county.
- Compared the chapter's centroid/KNN convention with projected centroids and great-circle distances. The 62-km graph is unchanged; 17 directed six-neighbour links are replaced.
- Generated and reviewed the county maps, connectivity graphs and matched-scale comparison figures.
