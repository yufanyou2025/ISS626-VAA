# Take-home Exercise 3: submission handoff

## Required deliverables

- Technical report: `technical-report.qmd`, rendered as HTML.
- Executive summary: `executive-summary.qmd`, rendered with Quarto reveal.js, with no more than 10 content slides plus a cover and a contents slide.
- Complete reproducible Quarto project on GitHub, including modular R code, source documentation, audit tables and the two interaction data frames.
- Coursework website links to the report, slides and repository.

## Status

Analysis and local rendering are complete. All 24 numerical checks passed. Local browser checks confirmed seven figures, a working 210-marker OpenStreetMap explorer, the Exercise 9-to-Exercise 3 menu path, mobile layout and all 12 slides without clipping or console errors. Eight visual interpretations contain 49-64 words each. Full interaction tables contain 341,004 existing-network pairs and 395,640 expanded-network pairs, with unique pair keys, preserved origin weights and per-origin probabilities summing to one. Evidence is in `outputs/model-verification.csv`, `outputs/browser-checks-local.json` and `outputs/submission-checks.json`.

The public report, slides, interactive map, full interaction downloads, GitHub source and Exercise 9 menu path were verified without signing in on **1 November 2026**. Vercel reports successful deployment of analytical release `7fa2561bbe991d4308128d8a48a5d25b6312aa46`. Public browser evidence is in `outputs/browser-checks-public.json`, with deployment status in `outputs/deployment-status.json`. The final package revision is recorded in `PACKAGE_REVISION.txt` inside the ZIP and in its adjacent manifest. No eLearn submission has occurred.

| Item | Verified address |
|---|---|
| Technical report | https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex03/technical-report.html |
| Executive summary | https://iss-626-vaa.vercel.app/Take-home_Ex/Take-home_Ex03/executive-summary.html |
| GitHub source | https://github.com/yufanyou2025/ISS626-VAA/tree/master/Take-home_Ex/Take-home_Ex03 |
| Coursework home | https://iss-626-vaa.vercel.app/ |

The current brief's reference to updating Exercise 2 links and its peace-keeping wording appear carried over from the preceding assignment. This work is labelled Exercise 3 and interprets the policy discussion around safe, accessible and sustainable urban transport.

## Local package

After the final intended revision is committed, run `python Take-home_Ex/Take-home_Ex03/package_submission.py`. It creates `Singapore_Rail_Takehome3_Project.zip` in the parent Geospatial analytics folder, with top-level folder `ISS626-VAA`. The ZIP contains the complete tracked project and rendered website, plus five explicitly whitelisted, licensed raw source snapshots. `PACKAGE_REVISION.txt` identifies the committed source revision; the adjacent `.manifest.json` records the ZIP hash and each supplemental input's source, licence and SHA-256. The package script refuses uncommitted tracked changes, missing deliverables or input-hash mismatches, then verifies every ZIP member's CRC and every packaged source hash.

The five supplemental raw files are the frozen HDB building GeoJSON, HDB property CSV, LTA September 2026 station ZIP, pinned URA/LTA station-coordinate CSV, and LTA January 2026 station-volume CSV obtained through its documented public archive. These are covered by the Singapore Open Data Licence. The sixth primary input, the CC-BY street-code bridge with attribution, is already tracked in `data/reference/`, together with the small official address-verification reference. Raw snapshots stay out of Git and the published site but are included in this local ZIP so later changes to upstream data do not prevent reproduction. Caches, unused exploratory downloads, API credentials and temporary download metadata are excluded. With R, the listed packages and Quarto installed, the analysis can run from the ZIP without downloading source data; interactive basemap tiles still need internet access.

## Before submitting through eLearn

Open the final public report, slides and GitHub addresses above, then enter the required links in the Exercise 3 submission activity and retain the receipt. Check the activity for any additional declarations. The assignment deadline is **15 November 2026, 11:59 pm Singapore time**. The local ZIP is a supplementary handoff; it does not replace the required published links or constitute an eLearn upload.
