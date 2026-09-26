# Central Bangkok road-network input

Road data © OpenStreetMap contributors, available under the [Open Database License 1.0](https://www.openstreetmap.org/copyright). The two files in this directory are shared with that attribution and licence notice. They contain only OSM road geometry, IDs and `highway` classes, not fatality records.

- `overpass-2026-09-26.json` is the exact Overpass API response used here. The OSM database timestamp in the response is **2026-09-26T13:27:05Z**. It is 10,222,717 bytes, SHA-256 `065d3e0874a489ab61e416ad9e629cab421d75157346aadef8393263ac4cdeb8`.
- `bangkok-focus-roads.geojson` is derived with [`prepare-network.R`](../../prepare-network.R). It retains 23,848 line segments in EPSG:32647; each OSM way is split at shared node IDs so the graph can connect at recorded junctions. It is 9,484,887 bytes, SHA-256 `23241c1439a8bd885177636d531269e853fa329ceff23a61aa76faf17784d35f`.

The original Overpass request used `https://overpass-api.de/api/interpreter`, a bounding box of **13.676351, 100.463467, 13.766767, 100.556318** (south, west, north, east), and this query:

```text
[out:json][timeout:180];way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"](13.676351,100.463467,13.766767,100.556318);out geom;
```

The committed snapshot, rather than a fresh Overpass response, is the reproducible input. OSM changes continuously, so rerunning the query later should be treated as a different road data version. The extract is a 2026 reference network for deaths recorded in January–September 2024. It does not verify 2024 road alignments, traffic direction, travel speed or connectivity at elevated crossings. Service roads and paths are not included. The analysis uses the largest connected component and reports the distance used to match each included fatality location to a mapped line.
