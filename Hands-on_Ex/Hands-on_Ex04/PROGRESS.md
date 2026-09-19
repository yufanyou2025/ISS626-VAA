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

## 19 September 2026 — Writing and interpretation

- Drafted the Quarto page in the chapter's section order and answered its interpretation questions.
- Used the computed Anxiang, Lengshuijiang and Pingjiang results to explain normalisation, self-inclusion and local contrasts.
- Added specific learning reflections, data limitations, sources and reproducible code, keeping the shared finance-inspired presentation.

## 19 September 2026 — Verification and publication preparation

- Rendered the exercise from a fresh R session with every numerical assertion passing.
- Checked 88 county results, 11 figures, all local page resources, search indexing and the Hands-on navigation.
- Verified desktop and mobile layouts, image loading, expandable code and the homepage link in a browser.
- Confirmed that previous exercise and Take-home report bodies are unchanged; only shared navigation was refreshed.
- Prepared source and rendered output for the existing GitHub/Vercel production workflow. The deployment's final status is recorded by GitHub rather than anticipated here.
