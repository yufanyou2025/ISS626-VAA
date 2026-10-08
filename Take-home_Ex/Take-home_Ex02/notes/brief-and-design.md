# Take-home Exercise 2: specification and study design

Brief checked on 8 October 2026: <https://isss626-ay2026-27aug.netlify.app/take-home_ex02.html> (modified 2 October 2026).

## Required submission

| Requirement | Planned deliverable |
|---|---|
| Myanmar, 1 January 2021–30 September 2025, township level | ACLED events aggregated against MIMU township boundaries v9.4 |
| Geospatial preparation and balanced space-time cube | Executable R scripts, sequential sample audit, monthly and quarterly counts |
| Local association, clusters and outliers | Local Moran's I and Getis–Ord Gi*, with significant areas distinguished |
| EHSA and Mann–Kendall on space-time Gi* | Quarterly space-time analysis, trends, classes and case-study histories |
| Interpretations | At most 200 words per main visual; at most 250 per EHSA cluster |
| Technical report | Quarto HTML, published on the existing Vercel coursework site |
| Executive summary | Quarto reveal.js; at most 10 content slides, excluding cover and contents |
| Reproducibility | Complete project on GitHub, input instructions, hashes, parameters, seeds and versions |
| Coursework links | Report, executive summary and GitHub links in the website navigation and home page |
| Final submission | Required links entered through eLearn by the student; receipt retained |
| Deadline | 25 October 2026, 11:59 pm, Asia/Singapore |

The two references to passenger trips and hexagons conflict with the objectives, study area and specified inputs. This project uses armed-conflict events and Myanmar townships. No independent-authorship declaration is stated on the public brief. The eLearn submission form still needs checking for any additional declaration.

## Research questions

1. Where are reported armed-conflict events concentrated, and which townships contrast with their neighbours?
2. Which concentrations persist, intensify or emerge between 2021 and September 2025?
3. Where did the share of nationwide recorded conflict increase between comparable early and recent windows?

The third question is addressed with a Bernoulli spatial scan of early versus recent event labels. Equal 21-month windows and conditioning on national totals distinguish geographical redistribution from countrywide escalation. Circular candidates are tested against maximum statistics from 999 whole-search simulations. Related conflict events, reporting change and circle design remain limitations. Reported fatalities are a secondary burden measure in the core LMSA rather than a claim about civilian mortality risk.

## Decisions to verify against the supplied data

- **Observation:** an ACLED coded event, not a person, battle campaign or independently verified unique incident. Distinct event IDs at the same place and date are not automatically duplicates.
- **Primary subset:** Battles, Explosions/Remote violence and Violence against civilians. This is an explicit armed-conflict subset. It excludes protests, riots and strategic developments; it is narrower than ACLED's complete political-violence definition. Audit all supplied categories before confirming this choice.
- **Secondary variable:** reported fatalities, with missing values distinguished from reported zero. These are uncertain estimates; no civilian-fatality interpretation unless supported by the fields.
- **Geography:** all 330 v9.4 townships in descriptive outputs. Join coordinates against the boundary layer; compare ACLED administrative names without silently overriding coordinates. Investigate multiple matches, unmatched points and low geographic precision. Do not invent a nearest-township assignment.
- **CRS:** WGS84 for source coordinates, a Myanmar-centred Albers equal-area CRS for spatial operations. Myanmar spans more than one UTM zone. Area denominators, if used, measure events per area rather than exposure-adjusted risk.
- **Time:** 57 complete calendar months for descriptive detail and 19 complete quarters for primary EHSA. This avoids comparing nine months of 2025 with a full earlier year. Missing township-period combinations become zero recorded events only after coverage is checked.
- **Neighbours:** Queen contiguity with a documented 10 m snapping tolerance; rook sensitivity. Three island townships have no Queen neighbours. Retain them in descriptive counts and the full cube, and mark spatial inference unavailable unless a defensible separate neighbourhood is adopted. Do not connect them to the mainland without justification.
- **LMSA:** no self-neighbour for Local Moran; self included for Gi*. Conditional permutations and p < .05, with BH adjustment shown as a robustness check. State the null model and distinguish a high-value cluster from a high-low outlier.
- **EHSA:** include present and previous quarter in the space-time neighbourhood; retain the calculated space-time Gi* series. Run Mann–Kendall on that series, not on raw event counts or unrelated spatial-only scores. Explain the classification rule, trend significance and the treatment of persistent clusters separately.
- **Gi* reference:** the explicit graph uses `spdep::localG_perm()` over all 6,213 mainland township-quarter bins, including the focal bin, with conditional two-sided permutations and normalised combined weights. This fixed reference differs from sfdep 0.2.5's slice standardisation. The cube structure still uses sfdep. National temporal changes can contribute to EHSA; the scan separately conditions on window totals.
- **Uncertainty:** compare Queen/rook and temporal aggregation where useful. Inspect serial dependence before treating ordinary Mann–Kendall p-values as reliable. A trend in relative spatial concentration is not automatically growth in absolute violence.

## Report narrative

Working title: **Myanmar's changing conflict geography: concentration, persistence and emerging pressure**.

The report will move from an auditable sample to the national picture, significant local clusters/outliers, changing patterns and cautious implications for peacebuilding and humanitarian preparedness. Each main visual should answer a named question. Code folds will show the executable R workflow; prose will explain why each major decision was made.

The finance background is useful for separating frequency from severity and discussing scarce-resource allocation. No investment analogy is needed to explain civilian harm.

## Reading the senior examples

- [Khant Min Naing](https://is415-geospatial-with-khant.netlify.app/take-home_ex/take-home_ex02/take-home_ex02.html): clear overview of methods, progression from local patterns to EHSA, and discussion of results.
- [Matthew Ho](https://is415-gaa-matthew-ho.netlify.app/takehomeex/takehomeex2/the2.html): explicit wrangling checks, preservation of zero-count areas, and explanation of time horizons.

These are examples of communication and workflow, not sources for Myanmar findings. Their dengue setting, geographic assumptions and numerical results are not reused.

## Input and publication restrictions

The supplied ACLED file was found in the local coursework folder. Its schema, sample exclusions and hash are documented in the input instructions and output audits. The analytical sample contains 53,899 events. Results are computed from the original input, not inferred from other students' work.

The [MIMU layer](https://geonode.themimu.info/layers/geonode%3Ammr_polbnda_adm3_250k_mimu_1) is labelled v9.4 and dated 18 June 2023. Its metadata restricts use in online platforms without written agreement. [MIMU terms](https://themimu.info/mimu-terms-conditions), sections 2.2, 2.3 and 5.2, also restrict geospatial dataset redistribution and embedding. Keep the downloaded boundary files and any geometry-bearing derivatives local; do not put them in Git, a submission ZIP, downloadable resources or an interactive web map. The scope of static analytical map publication should be confirmed against course permission or instructor guidance before publishing maps.

[ACLED's EULA](https://acleddata.com/eula), section 3.1, permits transformative non-commercial materials that cannot recreate the underlying data. Raw events, event locations and event-level intermediates stay local. Statistical summaries and original analytical figures must carry attribution; follow the [attribution policy](https://acleddata.com/attributionpolicy), including access date, filters and transformations. The required academic reference is Raleigh, Kishi and Linke (2023), <https://doi.org/10.1057/s41599-023-01559-4>.

## Verification before handoff

Reconcile sample counts; check IDs, coordinates, duplicates, geometry, graph components and cube completeness. Tie every prose number to computed outputs. Verify p-value columns and the installed sfdep implementation rather than assuming package defaults. Check word/slide limits, figure attribution, folded code, local links, browser behaviour and mobile layout. Push source and rendered files only after relevant checks, then verify the public deployment. Package required tracked files without .git or restricted inputs. Do not claim an eLearn submission without a verified receipt.
