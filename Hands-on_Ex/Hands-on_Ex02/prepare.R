suppressPackageStartupMessages({library(sf); library(spatstat); library(tidyverse); library(terra); library(tmap)})
base <- "Hands-on_Ex/Hands-on_Ex02"
for (d in c("data", "cache", "figures", "outputs")) dir.create(file.path(base, d), recursive=TRUE, showWarnings=FALSE)
options(timeout=300)
sources <- tibble(
  dataset=c("Master Plan 2019 Subzone Boundary (No Sea)", "Child Care Services"),
  id=c("d_8594ae9ff96d0c708bc2af633048edfb", "d_5d668e3f544335f8028f546827b773b4"),
  file=c("subzones.geojson", "childcare.geojson"),
  coverage=c("September 2021 (Master Plan 2019)", "December 2021"),
  catalogue_updated=c("2025-12-03", "2026-04-18"))
for (i in seq_len(nrow(sources))) {
  dest <- file.path(base, "data", sources$file[i])
  if (!file.exists(dest)) {
    endpoint <- paste0("https://api-open.data.gov.sg/v1/public/api/datasets/", sources$id[i], "/poll-download")
    ok <- FALSE
    for (attempt in 1:4) {
      ok <- tryCatch({
        meta <- jsonlite::fromJSON(endpoint)
        stopifnot(meta$code == 0, nzchar(meta$data$url))
        download.file(meta$data$url, paste0(dest,".part"), mode="wb", quiet=TRUE)
        stopifnot(nrow(st_read(paste0(dest,".part"), quiet=TRUE)) > 0)
        file.rename(paste0(dest,".part"), dest)
      }, error=function(e) FALSE)
      if (isTRUE(ok)) break
      Sys.sleep(10)
    }
    if (!isTRUE(ok)) stop("Download failed: ", sources$dataset[i])
  }
}
manifest_path <- file.path(base,"outputs","data-manifest.csv")
if (!file.exists(manifest_path)) {
  sources <- sources |> mutate(source_url=paste0("https://data.gov.sg/datasets/",id,"/view"),
    downloaded=as.character(Sys.Date()), md5=unname(tools::md5sum(file.path(base,"data",file))))
  write_csv(sources,manifest_path)
}
recorded <- read_csv(manifest_path,show_col_types=FALSE)
current_md5 <- unname(tools::md5sum(file.path(base,"data",recorded$file)))
if (!identical(current_md5,recorded$md5))
  stop("Downloaded data differ from the recorded snapshot. Review source dates and regenerate the manifest explicitly before updating the analysis.")

## ---- preparation
subzones <- st_read(file.path(base,"data/subzones.geojson"), quiet=TRUE) |> st_zm() |> st_transform(3414)
childcare <- st_read(file.path(base,"data/childcare.geojson"), quiet=TRUE) |> st_zm() |> st_transform(3414)
invalid_polygons <- sum(!st_is_valid(subzones))
subzones <- st_make_valid(subzones)
mainland <- subzones |> filter(SUBZONE_N != "SOUTHERN GROUP",
  !PLN_AREA_N %in% c("WESTERN ISLANDS","NORTH-EASTERN ISLANDS"))
sg_boundary <- st_union(mainland)
window_sg <- as.owin(sg_boundary)
coords <- st_coordinates(childcare)
inside <- inside.owin(coords[,1],coords[,2],window_sg)
duplicate_coordinates <- sum(duplicated(as.data.frame(coords)))
# Distinct facilities can occupy the same building. Keep them, without jitter.
X <- ppp(coords[inside,1],coords[inside,2],window=window_sg,checkdup=FALSE)
Xkm <- spatstat.geom::rescale(X,1000,"km")
areas <- c("PUNGGOL","TAMPINES","CHOA CHU KANG","JURONG WEST")
windows <- setNames(lapply(areas,function(a) as.owin(st_union(filter(mainland,PLN_AREA_N==a)))),areas)
patterns <- lapply(windows,function(w) X[w])
audit <- tibble(measure=c("Imported subzones","Retained subzones","Invalid polygons repaired","Imported childcare centres",
  "Centres inside observation window","Centres outside window","Repeated coordinate rows"),
  value=c(nrow(subzones),nrow(mainland),invalid_polygons,nrow(childcare),npoints(X),sum(!inside),duplicate_coordinates))
write_csv(audit,file.path(base,"outputs/audit.csv"))
area_summary <- tibble(area=areas,centres=sapply(patterns,npoints),area_km2=sapply(windows,area.owin)/1e6) |>
  mutate(centres_per_km2=centres/area_km2)
write_csv(area_summary,file.path(base,"outputs/area-summary.csv"))
stopifnot(st_crs(childcare)$epsg==3414,st_crs(mainland)$epsg==3414,npoints(X)>0,
  all(sapply(patterns,npoints)>1),all(st_is_valid(mainland)))
saveRDS(mainland,file.path(base,"data/mpsz_cl.rds"))
## ---- end-preparation

png_plot <- function(name, code, width=1800,height=1200) {
  png(file.path(base,"figures",paste0(name,".png")),width=width,height=height,res=160)
  on.exit(dev.off())
  par(mar=c(4,4,3,1),cex=0.95)
  force(code)
}
writeLines(capture.output(sessionInfo()),file.path(base,"outputs/session-info.txt"))
