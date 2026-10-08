# All scripts run from the ISS626-VAA repository root.
ex02 <- "Take-home_Ex/Take-home_Ex02"
config02 <- list(
  start = as.Date("2021-01-01"),
  end = as.Date("2025-09-30"),
  access_date = as.Date("2026-10-08"),
  # Country-centred equal-area projection; Myanmar spans multiple UTM zones.
  crs = "+proj=aea +lat_1=10 +lat_2=28 +lat_0=19 +lon_0=96 +datum=WGS84 +units=m +no_defs",
  # Armed-conflict subset, not a synonym for all ACLED political disorder.
  event_types = c("Battles", "Explosions/Remote violence", "Violence against civilians"),
  spatial_snap_m = 10,
  alpha = .05,
  nsim = 999L,
  seed = 6262026L,
  boundary_url = paste0(
    "https://geonode.themimu.info/geoserver/wfs?service=WFS&version=1.0.0&",
    "request=GetFeature&typeName=geonode%3Ammr_polbnda_adm3_250k_mimu_1&outputFormat=SHAPE-ZIP"),
  boundary_layer = "mmr_polbnda_adm3_250k_mimu_1"
)
