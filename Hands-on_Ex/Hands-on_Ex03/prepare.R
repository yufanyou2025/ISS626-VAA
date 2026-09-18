options(timeout=300)
suppressPackageStartupMessages({library(sf);library(dplyr);library(readr);library(lubridate);library(spatstat.geom)})
base <- "Hands-on_Ex/Hands-on_Ex03"
for(d in c("data","outputs","figures","cache")) dir.create(file.path(base,d),recursive=TRUE,showWarnings=FALSE)
mirror <- "https://raw.githubusercontent.com/Hungthq/ISSS626-GAA/f7a95396d1088cb7356e3677a574ef20c28b62a0/data/geospatial/"
files <- c("modis_2023_Indonesia.csv",paste0("Kepulauan_Bangka_Belitung.",c("shp","dbf","shx","prj")))
urls <- c("https://firms.modaps.eosdis.nasa.gov/data/country/modis/2023/modis_2023_Indonesia.csv",paste0(mirror,files[-1]))
for(i in seq_along(files)) if(!file.exists(file.path(base,"data",files[i])))
  download.file(urls[i],file.path(base,"data",files[i]),mode="wb",quiet=TRUE)
manifest <- data.frame(file=files,url=urls,accessed=as.character(Sys.Date()),md5=unname(tools::md5sum(file.path(base,"data",files))))
mf <- file.path(base,"outputs/data-manifest.csv")
if(file.exists(mf)) stopifnot(identical(read_csv(mf,show_col_types=FALSE)$md5,manifest$md5)) else write_csv(manifest,mf)
boundary_raw <- st_read(file.path(base,"data/Kepulauan_Bangka_Belitung.shp"),quiet=TRUE)
fire_raw <- read_csv(file.path(base,"data/modis_2023_Indonesia.csv"),show_col_types=FALSE)
## ---- prepare-study
# The workbook's stated extent covers Bangka, not the eastern Belitung island.
boundary <- boundary_raw |> filter(!grepl("Belitung",WADMKK,ignore.case=TRUE)) |>
  st_zm() |> st_transform(32748) |> st_make_valid()
components <- st_cast(st_union(boundary),"POLYGON")
study <- components[which.max(st_area(components))]
boundary <- boundary[lengths(st_intersects(st_point_on_surface(boundary),study))>0,]
window <- as.owin(study)
fire_2023 <- fire_raw |> filter(acq_date>=as.Date("2023-01-01"),acq_date<=as.Date("2023-12-31"))
fire_sf_all <- st_as_sf(fire_2023,coords=c("longitude","latitude"),crs=4326,remove=FALSE) |> st_transform(32748)
keep <- lengths(st_intersects(fire_sf_all,study))>0
fire_sf <- fire_sf_all[keep,] |> mutate(DayofYear=yday(acq_date),Month_num=month(acq_date))
coords <- st_coordinates(fire_sf)
month_ppp <- ppp(coords[,1],coords[,2],window=window,marks=fire_sf$Month_num,checkdup=FALSE)
day_ppp <- ppp(coords[,1],coords[,2],window=window,marks=fire_sf$DayofYear,checkdup=FALSE)
monthly <- tibble(month=1:12,month_name=month.abb,count=tabulate(fire_sf$Month_num,nbins=12))
audit <- tibble(measure=c("Imported boundary features","Bangka boundary features","Indonesia detections","Retained detections","Outside study window","Repeated XY coordinates","Repeated XY-day records","Window area km2"),
 value=c(nrow(boundary_raw),nrow(boundary),nrow(fire_raw),nrow(fire_sf),sum(!keep),sum(duplicated(coords)),sum(duplicated(cbind(coords,fire_sf$DayofYear))),area.owin(window)/1e6))
write_csv(audit,file.path(base,"outputs/audit.csv"))
write_csv(monthly,file.path(base,"outputs/monthly-counts.csv"))
stopifnot(st_crs(fire_sf)$epsg==32748,all(st_is_valid(study)),all(inside.owin(coords[,1],coords[,2],window)))
print(audit);print(monthly);print(st_geometry_type(study))
## ---- end-preparation
