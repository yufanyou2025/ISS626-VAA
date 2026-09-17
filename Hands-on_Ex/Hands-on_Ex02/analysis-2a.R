source("Hands-on_Ex/Hands-on_Ex02/prepare.R")
set.seed(1234)
tmap_mode("plot")
png_plot("locations", {
  plot(st_geometry(mainland),col="#f1f3f4",border="grey75",main="Childcare centres in Singapore")
  plot(st_geometry(childcare[inside,]),add=TRUE,pch=16,cex=0.35,col="#176b87")
  mtext("ECDA Child Care Services | URA Master Plan 2019 | SVY21, metres",side=1,line=1,cex=.7)
})
## ---- nearest-neighbour
ce_analytical <- clarkevans.test(X,correction="none",alternative="clustered",method="asymptotic")
ce_mc <- clarkevans.test(X,correction="none",alternative="clustered",method="MonteCarlo",nsim=99)
local_tests <- lapply(patterns[c("CHOA CHU KANG","TAMPINES")],function(x)
  clarkevans.test(x,correction="none",alternative="two.sided",method="asymptotic"))
tests <- c(list("Singapore: analytical"=ce_analytical,"Singapore: Monte Carlo (99)"=ce_mc),local_tests)
ce_table <- bind_rows(lapply(names(tests),function(n) tibble(test=n,R=unname(tests[[n]]$statistic),p_value=tests[[n]]$p.value)))
write_csv(ce_table,file.path(base,"outputs/clark-evans.csv"))
## ---- bandwidths
bandwidths <- list(Diggle=bw.diggle(Xkm),CvL=bw.CvL(Xkm),Scott=bw.scott(Xkm),Likelihood=bw.ppl(Xkm))
bw_table <- bind_rows(lapply(names(bandwidths),function(n) tibble(method=n,
  sigma_x_km=as.numeric(bandwidths[[n]])[1],sigma_y_km=tail(as.numeric(bandwidths[[n]]),1))))
write_csv(bw_table,file.path(base,"outputs/bandwidths.csv"))
kdes <- lapply(bandwidths,function(b) density(Xkm,sigma=b,edge=TRUE,dimyx=256))
png_plot("bandwidths",{par(mfrow=c(2,2)); for(n in names(kdes)) plot(kdes[[n]],main=paste(n,"- centres/km^2"))},1800,1600)
sigma <- as.numeric(bandwidths$Diggle)
kernels <- c("gaussian","epanechnikov","quartic","disc")
png_plot("kernels",{par(mfrow=c(2,2)); for(k in kernels)
  plot(density(Xkm,sigma=sigma,kernel=k,edge=TRUE,dimyx=256),main=paste(k,"- centres/km^2"))},1800,1600)
## ---- fixed-adaptive
fixed <- density(Xkm,sigma=0.6,edge=TRUE,dimyx=256)
adaptive <- adaptive.density(Xkm,method="kernel",dimyx=256)
png_plot("fixed-adaptive",{par(mfrow=c(1,2)); plot(fixed,main="Fixed bandwidth: 600 m"); plot(adaptive,main="Adaptive bandwidth")},2000,1000)
## ---- raster-map
# Compute in metres and convert only intensity values to centres/km².
# Assigning EPSG:3414 to kilometre coordinates would misplace the raster.
kde_m <- density(X,sigma=sigma*1000,edge=TRUE,dimyx=256)
raster_kde <- rast(kde_m)
crs(raster_kde) <- "EPSG:3414"
raster_kde <- raster_kde * 1e6
names(raster_kde) <- "Centres_per_km2"
stopifnot(xmax(raster_kde)>50000, terra::same.crs(raster_kde,vect(mainland)),
  isTRUE(all.equal(as.vector(kde_m$v)*1e6,as.vector(kdes$Diggle$v),tolerance=1e-5)))
cartographic <- tm_shape(raster_kde) +
  tm_raster(col.scale=tm_scale_continuous(values="viridis"),col.legend=tm_legend(title="Centres per km^2")) +
  tm_shape(mainland) + tm_borders(col="white",lwd=0.25) +
  tm_title("Childcare concentration | Singapore") + tm_compass() + tm_scalebar() +
  tm_credits("ECDA Child Care Services; URA MP2019 | Diggle bandwidth; edge corrected") + tm_layout(frame=FALSE)
tmap_save(cartographic,file.path(base,"figures/kde-map.png"),width=2000,height=1400,units="px")
## ---- local-kde
local_kdes <- lapply(patterns,function(x) density(spatstat.geom::rescale(x,1000,"km"),sigma=bw.diggle,edge=TRUE,dimyx=256))
png_plot("local-points",{par(mfrow=c(2,2));for(n in names(patterns))plot(spatstat.geom::rescale(patterns[[n]],1000,"km"),main=paste(n,"(km)"))},1800,1600)
png_plot("local-kde",{par(mfrow=c(2,2));for(n in names(local_kdes))plot(local_kdes[[n]],main=paste(n,"- centres/km^2"))},1800,1600)
## ---- end-analysis-a
saveRDS(list(audit=audit,area_summary=area_summary,ce=ce_table,bandwidths=bw_table),file.path(base,"outputs/results-a.rds"))
## ---- interactive-map
# Simplification is for browser display only; analysis uses the full boundaries.
dir.create(file.path(base,"maps"),showWarnings=FALSE)
tmap_mode("view")
interactive_map <- tm_shape(st_simplify(mainland,dTolerance=20)) +
  tm_borders(col="grey60",lwd=0.5) +
  tm_shape(childcare[inside,"NAME"]) + tm_dots(col="#176b87",size=0.04,popup.vars="NAME")
htmlwidgets::saveWidget(tmap_leaflet(interactive_map),
  file.path(base,"maps/childcare-locations.html"),selfcontained=FALSE)
## ---- end-interactive
message("Exercise 2A analysis complete")
