# Rebuild the pinned, shareable road extract from the Overpass JSON snapshot.
# Run from the repository root. The Overpass snapshot is committed with the project.
source_path <- "Take-home_Ex/Take-home_Ex01/data/network/overpass-2026-09-26.json"
target_path <- "Take-home_Ex/Take-home_Ex01/data/network/bangkok-focus-roads.geojson"
if (!file.exists(source_path)) stop("Missing Overpass snapshot: ", source_path)
if (!requireNamespace("jsonlite", quietly = TRUE) || !requireNamespace("sf", quietly = TRUE))
  stop("Install jsonlite and sf first")
source_hash <- digest::digest(file = source_path, algo = "sha256")
if (source_hash != "065d3e0874a489ab61e416ad9e629cab421d75157346aadef8393263ac4cdeb8")
  stop("Overpass snapshot hash differs from the pinned input")
snapshot <- jsonlite::fromJSON(source_path, simplifyVector = FALSE)
ways <- Filter(function(x) identical(x$type, "way") && length(x$nodes) > 1L &&
                 length(x$nodes) == length(x$geometry), snapshot$elements)
all_nodes <- unlist(lapply(ways, `[[`, "nodes"), use.names = FALSE)
shared_nodes <- names(which(table(all_nodes) > 1L))
geometries <- list()
way_ids <- character()
road_classes <- character()
start_nodes <- character()
end_nodes <- character()
for (way in ways) {
  nodes <- as.character(unlist(way$nodes, use.names = FALSE))
  coords <- do.call(rbind, lapply(way$geometry, function(p) c(p$lon, p$lat)))
  if (any(!is.finite(coords))) next
  cuts <- sort(unique(c(1L, which(nodes %in% shared_nodes), length(nodes))))
  if (length(cuts) < 2L) next
  for (i in seq_len(length(cuts) - 1L)) {
    a <- cuts[i]; b <- cuts[i + 1L]
    piece <- coords[a:b, , drop = FALSE]
    if (a == b || all(piece[1, ] == piece[nrow(piece), ])) next
    geometries[[length(geometries) + 1L]] <- sf::st_linestring(piece)
    way_ids <- c(way_ids, as.character(way$id))
    road_classes <- c(road_classes, way$tags$highway)
    start_nodes <- c(start_nodes, nodes[a])
    end_nodes <- c(end_nodes, nodes[b])
  }
}
network <- sf::st_sf(way_id = way_ids, road_class = road_classes,
                     start_node = start_nodes, end_node = end_nodes,
                     geometry = sf::st_sfc(geometries, crs = 4326))
network <- network[as.numeric(sf::st_length(sf::st_transform(network, 32647))) > 0.01, ]
network <- sf::st_transform(network, 32647)
dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
sf::st_write(network, target_path, delete_dsn = TRUE, quiet = TRUE)
cat("Source ways:", length(ways), "\nNetwork edges:", nrow(network),
    "\nNetwork kilometres:", sum(as.numeric(sf::st_length(network))) / 1000, "\n")
