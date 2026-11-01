# Prepare official HDB origins and physical rail-station alternatives.
# Run from the ISS626-VAA project root; distances use SVY21 metres (EPSG:3414).
suppressPackageStartupMessages({library(sf); library(dplyr); library(readr); library(tidyr)})
root03 <- 'Take-home_Ex/Take-home_Ex03'
raw03 <- file.path(root03, 'data/raw')
processed03 <- file.path(root03, 'data/processed')
reference03 <- file.path(root03, 'data/reference')
output03 <- file.path(root03, 'outputs')
for (p in c(raw03, processed03, reference03, output03)) dir.create(p, recursive=TRUE, showWarnings=FALSE)
access_date03 <- '2026-11-01'
coordinate_revision03 <- '9f5972c71db8a529801eee9c527946a45a78e409'
bridge_revision03 <- '0e7da4ea27f6bcd74b13514dd0e371a0da6c91fb'
download03 <- function(url, target) {
  if (!file.exists(target)) utils::download.file(url, target, mode='wb', quiet=TRUE)
  if (!file.exists(target) || file.info(target)$size < 100) stop('Missing/empty input: ',target)
}
download_portal03 <- function(id, target) {
  if (!file.exists(target)) {
    poll <- jsonlite::fromJSON(paste0('https://api-open.data.gov.sg/v1/public/api/datasets/',id,'/poll-download'))
    if (is.null(poll$data$url)) stop('Official download unavailable for ',id)
    download03(poll$data$url,target)
  }
}
sources_spatial03 <- tibble::tribble(
  ~file, ~source_url, ~vintage, ~licence,
  'HDBExistingBuilding.geojson','https://data.gov.sg/datasets/d_16b157c52ed637edd6ba1232e026258d/view','Nov2025; portal updated21Jun2026','Singapore Open Data Licence1.0',
  'HDBPropertyInformation.csv','https://data.gov.sg/datasets/d_17f5382f26140b1fdae0ba2ef6239d2f/view','completions1937-2025; portal updated8Oct2026','Singapore Open Data Licence1.0',
  'TrainStation_Sep2026.zip','https://datamall.lta.gov.sg/content/dam/datamall/datasets/Geospatial/TrainStation_Sep2026.zip','Sep2026; operating choice set restricted to Jan2026 observed codes','Singapore Open Data Licence1.0',
  'operational_and_future_stations.csv',paste0('https://raw.githubusercontent.com/elliotwutingfeng/singapore_train_station_coordinates/',coordinate_revision03,'/operational_and_future_stations.csv'),coordinate_revision03,'Singapore Open Data Licence1.0; URA/LTA source per row',
  'hdb_street_codes.csv',paste0('https://raw.githubusercontent.com/mooofna/singapore-urban-heat/',bridge_revision03,'/data/reference/hdb_street_codes.csv'),bridge_revision03,'CC BY4.0 Maurice Heide, singapore-urban-heat; underlying HDB SGODL1.0')
download_portal03('d_16b157c52ed637edd6ba1232e026258d',file.path(raw03,'HDBExistingBuilding.geojson'))
download_portal03('d_17f5382f26140b1fdae0ba2ef6239d2f',file.path(raw03,'HDBPropertyInformation.csv'))
zip03 <- file.path(raw03,'TrainStation_Sep2026.zip')
if (!file.exists(zip03)) {
  supplied <- file.path(Sys.getenv('USERPROFILE'),'Desktop','TrainStation_Sep2026.zip')
  if (file.exists(supplied)) file.copy(supplied,zip03) else download03(sources_spatial03$source_url[3],zip03)
}
coordinate_file03 <- file.path(raw03,'operational_and_future_stations.csv')
download03(sources_spatial03$source_url[4],coordinate_file03)
bridge_file03 <- file.path(reference03,'hdb_street_codes.csv')
if (!file.exists(bridge_file03) && file.exists(file.path(raw03,'hdb_street_codes.csv'))) file.copy(file.path(raw03,'hdb_street_codes.csv'),bridge_file03)
download03(sources_spatial03$source_url[5],bridge_file03)
source_paths03 <- c(file.path(raw03,sources_spatial03$file[1:4]),bridge_file03)
sources_spatial03 <- sources_spatial03 |> mutate(access_date=access_date03,
  bytes=file.info(source_paths03)$size,
  sha256=vapply(source_paths03,function(p) digest::digest(file=p,algo='sha256'),character(1)))
expected_spatial_hashes03 <- c(
 '7c987511548de3a82da403cabca02702031e02ade8703a9e401417883dfeb702',
 'd528ea2d6fc3f57ab4c8199ed15ea5eaac0109fe659e09ef91910dfe417af2eb',
 'f6d745bfd3f23af5656f58cbc1cd264e8185f61ec38ac786406a9e2958b2b8f4',
 '021deb64c5847012c24e556f21af530d00cedf9b5d7e70853f56f6451e17611d',
 '4ec6e3c78297dd4a68d89c0f8b079dc6be16bb603d8546e20818adfcde79b677')
if (!identical(unname(sources_spatial03$sha256),expected_spatial_hashes03))
 stop('Spatial input snapshot changed. Obtain the pinned snapshot or review the audit and update analysis deliberately.')
write_csv(sources_spatial03,file.path(output03,'spatial-input-manifest.csv'))

# A street code is not a street name. Use the attributed bridge, retaining only
# well-supported mappings, and report exclusions instead of guessing addresses.
norm_street03 <- function(x) {
  x <- toupper(trimws(x)); x <- gsub('[[:punct:]]',' ',x)
  replacements <- c(ROAD='RD',STREET='ST',AVENUE='AVE',DRIVE='DR',CRESCENT='CRES',
                    BUKIT='BT',JALAN='JLN',LORONG='LOR',UPPER='UPP',NORTH='NTH',SOUTH='STH',
                    CENTRAL='CTRL',GARDENS='GDNS',PLACE='PL',COMMONWEALTH='C\'WEALTH',
                    KAMPONG='KG',TANJONG='TG',PARK='PK')
  for (word in names(replacements)) x<-gsub(paste0('\\b',word,'\\b'),replacements[[word]],x)
  gsub(' +',' ',trimws(x))
}
hdb_raw03 <- st_read(file.path(raw03,'HDBExistingBuilding.geojson'),quiet=TRUE)
stopifnot(st_crs(hdb_raw03)$epsg==4326L,!anyDuplicated(hdb_raw03$POSTAL_COD))
hdb_invalid03 <- sum(!st_is_valid(hdb_raw03))
hdb_sf03 <- st_transform(st_make_valid(hdb_raw03),3414)
property03 <- read_csv(file.path(raw03,'HDBPropertyInformation.csv'),show_col_types=FALSE,
  col_types=cols(blk_no=col_character(),.default=col_guess())) |>
  mutate(block=toupper(trimws(blk_no)),street_key=norm_street03(street))
stopifnot(!anyDuplicated(property03[c('block','street_key')]),all(is.finite(property03$total_dwelling_units)),all(property03$total_dwelling_units>=0))
bridge03 <- read_csv(bridge_file03,show_col_types=FALSE) |>
  mutate(street_key=norm_street03(street),
    accepted=(!is.na(vote_share)&method=='spatial'&vote_share>=.90) |
      (method=='block_sets'&jaccard>=.80&(jaccard-jaccard_runner_up)>=.50),
    accepted=accepted & !is.na(street_key) & nzchar(street_key))
stopifnot(!anyDuplicated(bridge03$st_cod))
# Independent official address verification resolves the one residential
# street excluded by the automated quality threshold. Verify all seven blocks,
# not just the code's first footprint (which can be a commercial building).
cantonment03 <- read_csv(file.path(reference03,'one-map-cantonment.csv'),show_col_types=FALSE,
  col_types=cols(.default=col_character()))
stopifnot(nrow(cantonment03)==7L,setequal(cantonment03$block,paste0('1',LETTERS[1:7])),
  all(cantonment03$st_cod=='CAN04Y'),all(norm_street03(cantonment03$road_name)=='CANTONMENT RD'),
  all(cantonment03$postal_code==paste0('085',match(cantonment03$block,paste0('1',LETTERS[1:7])),'01')))
bridge03 <- bridge03 |> mutate(accepted=accepted|st_cod=='CAN04Y',
  method=if_else(st_cod=='CAN04Y','official OneMap seven-block verification',method))
write_csv(bridge03 |> filter(!accepted),file.path(output03,'street-bridge-exclusions.csv'))
hdb_link03 <- hdb_sf03 |>
  mutate(block=toupper(trimws(BLK_NO))) |>
  left_join(bridge03 |> select(st_cod,street_key,accepted,method),by=c('ST_COD'='st_cod'),relationship='many-to-one') |>
  left_join(property03 |> select(block,street_key,street,residential,total_dwelling_units,year_completed,commercial,bldg_contract_town),
    by=c('block','street_key'),relationship='many-to-one')
eligible_property03 <- property03 |> filter(residential=='Y',total_dwelling_units>0,year_completed<=2025)
hdb_residential03 <- hdb_link03 |> filter(accepted,residential=='Y',total_dwelling_units>0,year_completed<=2025)
stopifnot(nrow(hdb_residential03)>9000,!anyDuplicated(hdb_residential03$POSTAL_COD))
hdb_origins03 <- suppressWarnings(st_point_on_surface(hdb_residential03)) |>
  transmute(origin_id=paste0('HDB_',POSTAL_COD),postal_code=POSTAL_COD,block,street,
    year_completed,dwelling_units=total_dwelling_units,town=bldg_contract_town,
    commercial,street_bridge_method=method)
hdb_xy03 <- st_coordinates(hdb_origins03); hdb_ll03 <- st_coordinates(st_transform(hdb_origins03,4326))
hdb_origins03$x <- hdb_xy03[,1]; hdb_origins03$y <- hdb_xy03[,2]
hdb_origins03$lon <- hdb_ll03[,1]; hdb_origins03$lat <- hdb_ll03[,2]
stopifnot(all(hdb_origins03$x>0),all(hdb_origins03$dwelling_units>0),!anyNA(hdb_origins03$street))
matched_keys03 <- st_drop_geometry(hdb_residential03) |> distinct(block,street_key)
excluded_property03 <- eligible_property03 |> anti_join(matched_keys03,by=c('block','street_key'))
write_csv(excluded_property03 |> select(blk_no,street,total_dwelling_units,year_completed),file.path(output03,'unmatched-residential-blocks.csv'))
audit_hdb03 <- tibble::tribble(~stage,~blocks,~dwelling_units,
  'HDB geometry footprints',nrow(hdb_raw03),NA_real_,
  'Property records: residential positive dwellings completed by2025',nrow(eligible_property03),sum(eligible_property03$total_dwelling_units),
  'Matched and retained HDB origins',nrow(hdb_origins03),sum(hdb_origins03$dwelling_units),
  'Eligible property records without accepted footprint match',nrow(excluded_property03),sum(excluded_property03$total_dwelling_units))
stopifnot(sum(hdb_origins03$dwelling_units)+sum(excluded_property03$total_dwelling_units)==sum(eligible_property03$total_dwelling_units))
write_csv(audit_hdb03,file.path(output03,'hdb-origin-audit.csv'))

# Use the observed month to define what was operating. Sep2026 footprint
# contents include depots, closed and unopened stations and cannot define it.
ridership03 <- file.path(raw03,'transport_node_train_202601.csv')
if (!file.exists(ridership03)) stop('Obtain Jan2026 official ridership input first; see data/README.md')
observed_codes03 <- sort(unique(read_csv(ridership03,show_col_types=FALSE,col_select=PT_CODE)$PT_CODE))
stopifnot(length(observed_codes03)==182L)
# Stevens appears as separate DT10 and TE11 codes in this source month; it is
# one physical station, so both observed series must be aggregated downstream.
observed_crosswalk03 <- tibble(observed_code=observed_codes03,
  station_id=if_else(observed_codes03 %in% c('DT10','TE11'),'DT10/TE11',observed_codes03))
observed_codes03 <- sort(unique(observed_crosswalk03$station_id))
coordinates03 <- read_csv(coordinate_file03,show_col_types=FALSE)
stopifnot(!anyDuplicated(coordinates03$station_code),all(coordinates03$lon>103.5 & coordinates03$lon<104.2),all(coordinates03$lat>1.1 & coordinates03$lat<1.6))
station_extract03 <- file.path(raw03,'TrainStation_Sep2026')
if (!dir.exists(station_extract03)) utils::unzip(zip03,exdir=station_extract03)
shape03 <- list.files(station_extract03,pattern='RapidTransitSystemStation.shp$',recursive=TRUE,full.names=TRUE)
stopifnot(length(shape03)==1L)
station_polygons03 <- st_read(shape03,quiet=TRUE) |> st_make_valid() |> st_transform(3414)
station_lookup03 <- st_drop_geometry(station_polygons03) |> mutate(shape_row=row_number()) |>
  select(shape_row,STN_NAM) |> separate_rows(STN_NAM,sep='\\s*/\\s*') |>
  mutate(station_code=trimws(STN_NAM))
code_lines03 <- function(codes) {
  prefix <- gsub('[0-9].*','',codes)
  line <- recode(prefix,CE='CC',CG='EW',PTC='PGLRT',STC='SKLRT',PE='PGLRT',PW='PGLRT',SE='SKLRT',SW='SKLRT',BP='BPLRT',.default=prefix)
  length(unique(line))
}
station_audit_rows03 <- list()
existing_stations03 <- bind_rows(lapply(observed_codes03,function(id) {
  codes <- strsplit(id,'/',fixed=TRUE)[[1]]
  c <- coordinates03[match(codes,coordinates03$station_code),]
  if (anyNA(c$station_code)) stop('Unmatched station code: ',id)
  stopifnot(length(unique(c$station_name))==1L)
  rows <- unique(station_lookup03$shape_row[station_lookup03$station_code %in% codes])
  if (length(rows)) {
    geom <- suppressWarnings(st_point_on_surface(st_union(st_geometry(station_polygons03[rows,]))))
    point_source <- 'LTA Sep2026 footprint interior point'
  } else {
    geom <- st_geometry(st_transform(st_as_sf(c[1,],coords=c('lon','lat'),crs=4326),3414))
    point_source <- 'Pinned URA/LTA coordinate fallback'
  }
  point<-st_sf(station_id=id,station_name=c$station_name[1],station_codes=paste(codes,collapse='/'),
    lines=code_lines03(codes),line_count=code_lines03(codes),is_new=FALSE,future_lines='',
    point_source=point_source,geometry=geom)
  reference<-st_transform(st_as_sf(c[1,],coords=c('lon','lat'),crs=4326),3414)
  station_audit_rows03[[id]] <<- tibble(station_id=id,station_name=c$station_name[1],codes=length(codes),
    footprint_features=length(rows),point_source=point_source,
    coordinate_difference_m=as.numeric(st_distance(point,reference)))
  point
}))

# Original brief scope:24 JRL station entries (not later Forest Hill), and
# CRL phase1 CR2–CR13 (not CR1 airport extension or CRL phase2).
future_entries03 <- coordinates03 |>
  filter((grepl('^J[ESW][0-9]+$',station_code)&station_code!='JS2A') | station_code %in% paste0('CR',2:13)) |>
  mutate(future_lines=if_else(grepl('^CR',station_code),'CRL','JRL'),
    station_id=station_code,station_codes=station_code,lines=1L,line_count=1L,is_new=TRUE,
    point_source='Pinned URA/LTA coordinate')
stopifnot(nrow(future_entries03)==36L,sum(future_entries03$future_lines=='JRL')==24L,sum(future_entries03$future_lines=='CRL')==12L,
  all(future_entries03$source %in% c('ura','lta')))
future_station_entries03 <- st_transform(st_as_sf(future_entries03,coords=c('lon','lat'),crs=4326,remove=FALSE),3414)
expanded_stations03 <- existing_stations03
future_station_entries03$merged_station_id <- future_station_entries03$station_id
for (i in seq_len(nrow(future_station_entries03))) {
  name <- future_station_entries03$station_name[i]
  hit <- match(name,existing_stations03$station_name)
  if (!is.na(hit)) {
    expanded_stations03$station_codes[hit] <- paste(expanded_stations03$station_codes[hit],future_station_entries03$station_codes[i],sep='/')
    expanded_stations03$lines[hit] <- expanded_stations03$lines[hit]+1L
    expanded_stations03$line_count[hit] <- expanded_stations03$lines[hit]
    expanded_stations03$future_lines[hit] <- future_station_entries03$future_lines[i]
    future_station_entries03$merged_station_id[i] <- existing_stations03$station_id[hit]
  }
}
new_future03 <- future_station_entries03 |> filter(!station_name %in% existing_stations03$station_name) |>
  select(all_of(names(st_drop_geometry(existing_stations03))))
expanded_stations03 <- bind_rows(expanded_stations03,new_future03)
stopifnot(nrow(existing_stations03)==181L,nrow(expanded_stations03)==210L,sum(expanded_stations03$is_new)==29L,
  !anyDuplicated(expanded_stations03$station_name),!anyDuplicated(expanded_stations03$station_id))
add_coordinates03 <- function(x) {
  xy<-st_coordinates(x); ll<-st_coordinates(st_transform(x,4326))
  x$x<-xy[,1]; x$y<-xy[,2]; x$lon<-ll[,1]; x$lat<-ll[,2]; x
}
existing_stations03 <- add_coordinates03(existing_stations03)
expanded_stations03 <- add_coordinates03(expanded_stations03)
future_station_entries03 <- add_coordinates03(future_station_entries03)
write_csv(bind_rows(station_audit_rows03),file.path(output03,'station-coordinate-audit.csv'))
write_csv(observed_crosswalk03 |> left_join(st_drop_geometry(existing_stations03) |> select(station_id,station_name),by='station_id',relationship='many-to-one'),file.path(output03,'observed-station-crosswalk.csv'))
write_csv(future_station_entries03 |> st_drop_geometry() |> select(station_code,station_name,future_lines,merged_station_id,source),file.path(output03,'future-station-scope.csv'))
spatial_audit03 <- tibble::tribble(~check,~value,
  'HDB source invalid polygons repaired',as.character(hdb_invalid03),
  'HDB street-code mappings accepted',as.character(sum(bridge03$accepted)),
  'HDB source codes missing from bridge',as.character(sum(!unique(hdb_raw03$ST_COD) %in% bridge03$st_cod)),
  'Matched eligible dwelling coverage',sprintf('%.4f',sum(hdb_origins03$dwelling_units)/sum(eligible_property03$total_dwelling_units)),
  'Official station footprint features',as.character(nrow(station_polygons03)),
  'Existing observed physical stations Jan2026',as.character(nrow(existing_stations03)),
  'Future line-station entries',as.character(nrow(future_station_entries03)),
  'Future entries merged with existing physical stations','7',
  'New physical station alternatives','29',
  'Expanded physical choice set','210',
  'Distance CRS','EPSG:3414; straight-line metres')
write_csv(spatial_audit03,file.path(output03,'spatial-preparation-audit.csv'))
for (item in c('hdb_origins','existing_stations','expanded_stations','future_station_entries')) {
  object <- get(paste0(item,'03'))
  stem <- gsub('_','-',item)
  saveRDS(object,file.path(processed03,paste0(stem,'.rds')))
  write_csv(st_drop_geometry(object),file.path(processed03,paste0(stem,'.csv')))
}
message('Spatial preparation complete: ',nrow(hdb_origins03),' HDB origins; ',nrow(existing_stations03),' existing and ',nrow(expanded_stations03),' expanded physical stations.')
