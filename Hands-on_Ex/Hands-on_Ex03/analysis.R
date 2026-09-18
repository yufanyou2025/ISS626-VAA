source("Hands-on_Ex/Hands-on_Ex03/prepare.R")
suppressPackageStartupMessages({library(sparr);library(stpp);library(tmap);library(ggplot2)})
set.seed(1234)
cache_key <- digest::digest(list(manifest$md5,tools::md5sum(file.path(base,"prepare.R")),as.character(packageVersion("sparr")),as.character(packageVersion("stpp"))))
cached <- function(name,expr) {
 key <- digest::digest(list(cache_key,deparse(substitute(expr))))
 path <- file.path(base,"cache",paste0(name,".rds"))
 if(file.exists(path)){old<-readRDS(path);if(identical(old$key,key))return(old$value)}
 message("Computing ",name)
 value<-force(expr);saveRDS(list(key=key,value=value),path);value
}
png_plot <- function(name,expr,width=1800,height=1200) {
 png(file.path(base,"figures",paste0(name,".png")),width=width,height=height,res=150)
 on.exit(dev.off());par(mar=c(4,4,3,2));force(expr)
}
## ---- locations
tmap_mode("plot")
overview <- tm_shape(study)+tm_polygons(fill="#eee9dc")+
 tm_shape(fire_sf)+tm_dots(fill="#9b462d",size=.035)+
 tm_title("MODIS fire detections | Bangka, 2023")+tm_scalebar(position=c("left","bottom"))+tm_compass(position=c("right","top"))+
 tm_layout(frame=FALSE)
tmap_save(overview,file.path(base,"figures/fire-locations.png"),width=1800,height=1400,units="px")
png_plot("monthly-locations",{par(mfrow=c(3,4),mar=c(1,1,3,1));for(m in 1:12){
 plot(st_geometry(study),col="#eee9dc",border="#77776b",main=paste(month.abb[m],"|",monthly$count[m],"detections"))
 plot(st_geometry(fire_sf[fire_sf$Month_num==m,]),add=TRUE,pch=16,cex=.4,col="#9b462d")}},2000,1800)
counts_plot <- ggplot(monthly,aes(factor(month_name,levels=month.abb),count))+
 geom_col(fill="#344b45",width=.65)+geom_text(aes(label=count),vjust=-.4,size=3.5)+
 labs(x=NULL,y="Satellite detections",title="A pronounced late-year concentration",subtitle="Bangka main island | MODIS, January-December 2023")+
 theme_minimal(base_size=13)+theme(panel.grid.major.x=element_blank())
ggsave(file.path(base,"figures/monthly-counts.png"),counts_plot,width=10,height=5,dpi=180)
## ---- monthly-kde
month_kde <- cached("monthly",spattemp.density(month_ppp,verbose=FALSE))
png_plot("monthly-kde",{par(mfrow=c(2,3));for(m in 7:12)
 plot(month_kde,m,override.par=FALSE,fix.range=TRUE,main=paste("Joint density |",month.abb[m]))},2000,1400)
## ---- daily-kde
day_kde <- cached("daily",spattemp.density(day_ppp,verbose=FALSE))
days <- c(196,227,258,288,319,349)
png_plot("daily-kde",{par(mfrow=c(2,3));for(d in days)
 plot(day_kde,d,override.par=FALSE,fix.range=TRUE,main=paste("Joint density | day",d))},2000,1400)
## ---- bootstrap-bandwidth
set.seed(1234)
boot_bw <- cached("bootstrap",BOOT.spattemp(day_ppp,verbose=TRUE))
improved <- cached("improved",spattemp.density(day_ppp,h=boot_bw[1],lambda=boot_bw[2],verbose=FALSE))
png_plot("improved-kde",{par(mfrow=c(2,3));for(d in days)
 plot(improved,d,override.par=FALSE,fix.range=TRUE,main=paste("Bootstrap KDE | day",d))},2000,1400)
bandwidths <- tibble(method=c("Month defaults","Day defaults","Bootstrap day"),
 spatial_m=c(month_kde$h,day_kde$h,improved$h),temporal=c(month_kde$lambda,day_kde$lambda,improved$lambda),time_unit=c("month","day","day"))
write_csv(bandwidths,file.path(base,"outputs/bandwidths.csv"))
## ---- daily-animation
# Weekly frames sample the full daily estimate; retain the common density scale.
frame_days <- seq(10,352,by=7)
frames <- lapply(frame_days,function(d){
 p<-file.path(base,"cache",sprintf("frame-%03d.png",d));png(p,width=800,height=760,res=110)
 plot(improved,d,fix.range=TRUE,main=paste("Bangka |",as.Date("2023-01-01")+d-1),xlab="Easting (m)",ylab="Northing (m)");dev.off();p
})
animated <- magick::image_animate(magick::image_join(lapply(frames,magick::image_read)),fps=4)
magick::image_write(animated,file.path(base,"figures/daily-kde.gif"))
## ---- space-time-k
# Use the observed study polygon, simplified only for expensive pairwise edge weights.
# A 100 m coastal buffer avoids clipping near-coast points after simplification.
k_region <- st_simplify(st_buffer(study,100),dTolerance=100)
stopifnot(all(lengths(st_intersects(fire_sf,k_region))>0))
ring <- st_geometry(k_region)[[1]][[1]]
k_region <- st_sfc(st_polygon(list(ring)),crs=32748)
stopifnot(is.matrix(ring),ncol(ring)==2)
fire_stpp <- as.3dpoints(data.frame(x=coords[,1],y=coords[,2],t=as.integer(fire_sf$DayofYear)))
png_plot("space-time-points",{plot(fire_stpp,ring,pch=19,mark=FALSE)})
# The whole 2023 interval must contain all observations; c(150,250) does not.
stik <- cached("stik",STIKhat(fire_stpp,s.region=ring,t.region=c(1,365),
 dist=seq(1000,30000,by=1000),times=seq(1,60,by=2),infectious=TRUE))
# plotK manages its own graphics device; supply a file device explicitly.
saved_device <- options(device=function(...) png(file.path(base,"figures/workbook-k-contour.png"),width=1800,height=1200,res=150))
plotK(stik,n=20,L=TRUE,type="contour",main="Centred space-time K")
dev.off();options(saved_device)
ratio <- stik$Khat/stik$Ktheo
k_display <- expand.grid(spatial_km=stik$dist/1000,lag_days=stik$times)
k_display$excess <- as.vector(stik$Khat-stik$Ktheo)/1e6
k_plot <- ggplot(k_display,aes(spatial_km,lag_days))+
 geom_raster(aes(fill=excess))+geom_contour(aes(z=excess),colour="#273d34",bins=8,linewidth=.3)+
 scale_fill_gradient(low="#faf7ee",high="#49675a",name="K excess\n(km^2 days)")+
 labs(x="Spatial distance u (km)",y="Temporal lag v (days)",title="More space-time neighbours than a uniform reference",
 subtitle="Estimated K minus pi*u^2*v | isotropic edge correction",
 caption="Descriptive departure, not a significance test | Bangka MODIS detections, 2023")+
 theme_minimal(base_size=13)+theme(panel.grid=element_blank())
ggsave(file.path(base,"figures/space-time-k.png"),k_plot,width=10,height=6.5,dpi=180)
write_csv(as.data.frame(as.table(ratio)) |> mutate(spatial_m=rep(stik$dist,length(stik$times)),lag_days=rep(stik$times,each=length(stik$dist))) |> select(spatial_m,lag_days,ratio=Freq),file.path(base,"outputs/k-ratio.csv"))
k_audit <- tibble(original_area_km2=as.numeric(st_area(study))/1e6,k_area_km2=as.numeric(st_area(k_region))/1e6,
 area_change_percent=100*(as.numeric(st_area(k_region))/as.numeric(st_area(study))-1),vertices=nrow(ring),retained=nrow(fire_stpp))
write_csv(k_audit,file.path(base,"outputs/k-window.csv"))
## ---- save-results
results <- list(audit=audit,monthly=monthly,bandwidths=bandwidths,k_audit=k_audit,
 day_range=range(fire_sf$DayofYear),k_ratio_range=range(ratio,finite=TRUE),
 autumn_share=sum(monthly$count[8:11])/nrow(fire_sf))
stopifnot(nrow(fire_sf)==741,nrow(boundary)==297,sum(monthly$count)==741,
 all(is.finite(ratio)),all(bandwidths$spatial_m>0),all(bandwidths$temporal>0))
saveRDS(results,file.path(base,"outputs/results.rds"))
writeLines(capture.output(sessionInfo()),file.path(base,"outputs/session-info.txt"))
message("Exercise 3 analysis complete")
