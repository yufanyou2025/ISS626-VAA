# HDB street-code bridge: attribution and licence

`hdb_street_codes.csv` is reproduced unchanged from Maurice Heide's **singapore-urban-heat** project, revision `0e7da4ea27f6bcd74b13514dd0e371a0da6c91fb`.

- Author/required attribution: **Maurice Heide, singapore-urban-heat**.
- [Exact source file](https://github.com/mooofna/singapore-urban-heat/blob/0e7da4ea27f6bcd74b13514dd0e371a0da6c91fb/data/reference/hdb_street_codes.csv).
- [Upstream data licence](https://github.com/mooofna/singapore-urban-heat/blob/0e7da4ea27f6bcd74b13514dd0e371a0da6c91fb/DATA_LICENSE.md).
- Licence: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
- Accessed 1 November 2026. SHA-256: `4ec6e3c78297dd4a68d89c0f8b079dc6be16bb603d8546e20818adfcde79b677`.

The upstream project explicitly includes the HDB street-code bridge among its licensed derived data. It derives from HDB Property Information and HDB Existing Building accessed from data.gov.sg, made available under the Singapore Open Data Licence version 1.0. The upstream bridge used OneMap to resolve street names; it redistributes no OneMap coordinates. These source terms continue to apply.

This coursework filters bridge rows by their supplied quality fields before joining the official HDB datasets. It does not change the reference CSV. The acceptance rules, exclusion table and resulting dwelling coverage are documented in `prepare-spatial.R` and `data/README.md`.
