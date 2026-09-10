# Reading the analysis

This guide explains the completed code without requiring you to write it. Read it alongside the report and expand the R sections when helpful.

## 1. Start with the event, not the map

The file records fatalities. It has no crash identifier, so 530 mapped records cannot be called 530 unique crashes. Several records share a location, and some share both a location and confirmed-death date.

The title says 2024, but the actual dates end in September. The report therefore uses January–September and never fills October–December with zeroes.

## 2. Follow the preparation table

The starting count is 12,762. Removing 24 identical rows leaves 12,738. Of these, 9,498 have no usable coordinate pair. Of the 3,240 located records, 530 fall inside the six-province boundary.

These are sequential removals, so each record is counted only once. Missing locations are not invented.

The coordinate headers are reversed in the input. The analysis keeps the original fields and derives correctly named longitude and latitude fields, then transforms them to UTM 47N so distances are measured in metres.

## 3. Separate count, intensity, and risk

The monthly chart counts records by confirmed-death month. The KDE estimates records per square kilometre across the nine-month observation period. Neither gives the probability that an individual traveller will die.

A risk comparison would require a suitable denominator, such as journeys or vehicle distance, together with a defensible observation model.

## 4. Understand the uniform comparison

The L-function asks about neighbouring pairs over a range of distances. The simulation comparison puts 530 independent uniform points inside the same polygon 199 times.

The observed maximum deviation exceeds every simulated maximum, giving p = 1/200 = 0.005. This rejects the uniform-location model. It does not distinguish true interaction from the effect of more roads or greater activity in some places.

## 5. Read the sensitivity result carefully

The inhomogeneous diagnostic tries to account for changing intensity. The answer changes with the smoothing bandwidth. At 3 km, one low-intensity point has a large inverse weight, making the diagnostic unstable.

Negative sections of a curve without a calibrated envelope do not demonstrate significant regularity. The report therefore leaves residual interaction unresolved.

## 6. Connect evidence to decisions

The broad concentration can guide case-file checks and site review. It cannot by itself justify a particular road redesign or enforcement policy. Missing geocodes are also a planning issue: a sparse area on the map may reflect poor recording.

The strongest practical next step combines location verification with crash identifiers and independent road/exposure data.

## Useful references

- [Assignment](https://isss626-ay2026-27aug.netlify.app/take-home_ex01)
- [Course lesson on spatial point patterns](https://isss626-ay2026-27aug.netlify.app/lesson/Lesson02/Lesson02-SPPA.html)
- [sf introduction](https://r-spatial.github.io/sf/articles/sf1.html)
- [spatstat resources](https://spatstat.org/)

