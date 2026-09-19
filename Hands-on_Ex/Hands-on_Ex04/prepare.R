suppressPackageStartupMessages({library(sf);library(dplyr);library(readr)})
base4 <- "Hands-on_Ex/Hands-on_Ex04"
for(d in c("data","outputs","figures","cache")) dir.create(file.path(base4,d),recursive=TRUE,showWarnings=FALSE)
# Set COURSE_DATA_ZIP when reproducing from a different computer.
zip_path <- Sys.getenv("COURSE_DATA_ZIP",unset="")
if(nzchar(zip_path)) {
 entries <- unzip(zip_path,list=TRUE)$Name
 stopifnot(!any(grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))",entries)))
 wanted <- c("data/aspatial/Hunan_2012.csv","data/aspatial/Dictionary.xlsx",
             paste0("data/geospatial/Hunan.",c("shp","shx","dbf","prj","qpj")))
 stopifnot(all(wanted %in% entries))
 if(!all(file.exists(file.path(base4,wanted)))) unzip(zip_path,files=wanted,exdir=base4)
}
files <- list.files(file.path(base4,"data"),recursive=TRUE,full.names=TRUE)
stopifnot(length(files)==7)
manifest4 <- tibble(file=sub(paste0(base4,"/"),"",files,fixed=TRUE),md5=unname(tools::md5sum(files)))
manifest_path <- file.path(base4,"outputs/input-checksums.csv")
if(file.exists(manifest_path)) stopifnot(identical(read_csv(manifest_path,show_col_types=FALSE)$md5,manifest4$md5)) else write_csv(manifest4,manifest_path)
## ---- import-and-join
hunan_boundary <- st_read(file.path(base4,"data/geospatial/Hunan.shp"),quiet=TRUE)
hunan2012 <- read_csv(file.path(base4,"data/aspatial/Hunan_2012.csv"),show_col_types=FALSE)
stopifnot(!anyDuplicated(hunan_boundary$County),!anyDuplicated(hunan2012$County))
unmatched_boundary <- anti_join(st_drop_geometry(hunan_boundary),hunan2012,by="County")
unmatched_table <- anti_join(hunan2012,st_drop_geometry(hunan_boundary),by="County")
stopifnot(nrow(unmatched_boundary)==0,nrow(unmatched_table)==0)
hunan <- left_join(hunan_boundary,hunan2012,by="County",relationship="one-to-one")
stopifnot(nrow(hunan)==88,!anyNA(hunan$GDPPC),all(is.finite(hunan$GDPPC)),all(hunan$GDPPC>0),
 st_crs(hunan)$epsg==4326,!any(st_is_empty(hunan)),all(st_is_valid(hunan)))
# Preserve polygon order: neighbours and lag vectors use this exact order.
dictionary <- readxl::read_excel(file.path(base4,"data/aspatial/Dictionary.xlsx"))
gdppc_definition <- dictionary |> filter(Variable=="GDPPC")
audit4 <- tibble(check=c("Boundary rows","Indicator rows","Joined rows","Duplicate county keys",
 "Unmatched boundary keys","Unmatched indicator keys","Missing GDPPC","Invalid geometries","Empty geometries"),
 value=c(nrow(hunan_boundary),nrow(hunan2012),nrow(hunan),0,nrow(unmatched_boundary),nrow(unmatched_table),sum(is.na(hunan$GDPPC)),sum(!st_is_valid(hunan)),sum(st_is_empty(hunan))))
write_csv(audit4,file.path(base4,"outputs/input-audit.csv"))
write_csv(gdppc_definition,file.path(base4,"outputs/gdppc-definition.csv"))
## ---- end-import
print(audit4)
