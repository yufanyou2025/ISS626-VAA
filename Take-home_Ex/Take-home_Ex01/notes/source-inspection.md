# Source inspection — 10 September 2026

These notes distinguish observations from unresolved meanings. They are preparation aids, not findings for the report.

## What was verified

The Kaggle ZIP contains one CSV with 12,762 rows and 13 English field names. Values include Thai text. The publisher describes fatality records for 2024 (B.E. 2567), rather than a file of uniquely identified crashes. No dedicated person ID or crash ID appears among the fields.

The first data row contains `confirmed_death_date = 11/01/2567`, `acc_lat = 99.857347`, and `acc_long = 9.182572`. A later inspected row contains `acc_lat = 104.01363` and `acc_long = 14.567701`. These examples suggest the coordinate labels are reversed. This is not proof that all rows use the same order or that the source datum is WGS84. Check the values and locations before adopting a treatment.

The date column names confirmed death, not accident occurrence. The publisher's year statement supports a Buddhist Era convention, but parsing and actual temporal coverage must be checked in your own workflow.

## Field guide

The descriptions below follow the header names; they are not an official data dictionary.

| Field | Apparent meaning or question to resolve |
|---|---|
| `age` | Age; confirm units and missing/unknown conventions |
| `sex` | Sex label; observed examples include ชาย (male) and หญิง (female) |
| `nationality` | Nationality; blank in the inspected examples |
| `person_district` | District associated with the person; confirm whether residence |
| `person_province` | Province associated with the person; do not assume crash location |
| `confirmed_death_date` | Confirmed-death date; distinguish from crash date |
| `acc_sub_district` | Accident subdistrict according to the header; verify source definition |
| `acc_district` | Accident district according to the header; verify source definition |
| `province_of_death` | Province of death; do not silently relabel as accident province |
| `acc_lat` | Labelled latitude, but inspected values look like longitude |
| `acc_long` | Labelled longitude, but inspected values look like latitude |
| `cause_code` | Cause code; requires authoritative coding definitions before interpretation |
| `vehicle_type` | Vehicle/road-user category; examples include รถจักรยานยนต์ (motorcycle) and คนเดินเท้า (pedestrian) |

## Questions still unresolved

- Does every row represent one distinct deceased person? How was integration across the three sources performed?
- Which spatial fields represent crash location rather than residence or place of death?
- What coordinate reference system and location precision does the source use?
- How should identical rows or coordinates be understood without unique identifiers?
- Are all months represented, and is the extract complete for the intended population?
- What terms permit redistribution of the underlying records?

Use the source description, course material, and official documentation to resolve these questions. Record remaining uncertainty rather than assuming definitions.

## Sources

- [Kaggle dataset](https://www.kaggle.com/datasets/pornsakkamchan/thailand-road-accident-fatalities-2024), version 1 and local metadata snapshot.
- [geoBoundaries metadata](https://www.geoboundaries.org/api/current/gbOpen/THA/ADM1/), local metadata snapshot and pinned GeoJSON.
- [NSO six-province definition](https://catalogapi.nso.go.th/api/doc/department/D10/SD10_04/SD10_04_265_1.pdf?preview=1), a candidate study-window reference for the student's consideration.
