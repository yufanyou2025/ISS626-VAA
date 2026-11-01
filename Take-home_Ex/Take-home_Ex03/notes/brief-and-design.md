# Exercise 3: brief and analytical decisions

Brief: https://isss626-ay2026-27aug.netlify.app/take-home_ex03, accessed 1 November 2026; page modified 30 October 2026.

Due: **15 November 2026, 11:59 pm Singapore time**.

## Required outputs

- Quarto HTML technical report documenting an executable R workflow.
- Quarto revealjs executive summary: at most 10 substantive slides, excluding cover and contents.
- Existing-only and existing-plus-proposed spatial interaction tables with common origin/destination keys, attractions and distances.
- Origin market-potential table and destination observed-ridership/attraction table.
- Calibrated probabilistic spatial interaction model; fitted existing station volumes; scenario predictions for all stations; maps/graphics of catchment redistribution.
- Published report and slides; complete reproducible GitHub project; coursework links; links supplied through eLearn by the student.
- Interpretations no longer than 200 words per visual.

The handout's Submission Links paragraph says Exercise 2, while its title, objectives and tasks specify Exercise 3. It also retains peacekeeping/public-safety wording. This project uses Exercise 3 links and discusses transport service, safe access and planning implications. No instructor clarification or eLearn submission is claimed.

## Design principles

The question is how adding the specified Jurong Region Line (24 line-station labels) and Cross Island Line phase 1 (12 labels) reallocates station-access demand under a fixed market. This is a comparative infrastructure scenario, not a dated official opening forecast. Current official schedules must be distinguished from the brief's simplified 2030 framing.

Use physical station complexes rather than separate platforms/line codes. The seven existing interchange sites receive added lines; they do not become duplicate destinations. Observe that a train passenger's origin station is not their residential origin. A residential-origin Huff model must therefore be calibrated to aggregate station volumes; it cannot be presented as a disaggregate choice model estimated from linked household trips.

Use metre-based SVY21 / Singapore TM (EPSG:3414). State whether the origin market represents HDB dwellings, residents, or all trip-producing activity. Straight-line access distance is a proxy, not a measured walk or feeder-bus journey. Station attraction must be defined from explanatory information available for future stations, not copied from observed patronage.

Compare fitted results with simple baselines and examine spatial holdout error. Fixed-total scenario differences show reallocation within the model; they do not establish induced demand, train crowding, operating profit, or future housing growth. Sensitivity ranges are scenario ranges rather than confidence intervals.

## Work record

- 1 November 2026: read the current brief; fetched and integrated upstream coursework through f325a0b; inspected the supplied TrainStation_Sep2026.zip; assessed data availability and the calibration design.

Commits use actual work and normal timestamps.
