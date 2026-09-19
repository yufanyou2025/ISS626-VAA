source("Hands-on_Ex/Hands-on_Ex04/prepare.R")
suppressPackageStartupMessages({library(spdep);library(tmap);library(ggplot2)})
## ---- contiguity
queen <- poly2nb(hunan,queen=TRUE,row.names=hunan$County)
rook <- poly2nb(hunan,queen=FALSE,row.names=hunan$County)
stopifnot(all(card(queen)>0),all(card(rook)>0))
## ---- centroids-and-distance
# Form centroids in metres, then transform back for great-circle distances in km.
hunan_projected <- st_transform(hunan,32649)
centres <- st_transform(st_centroid(st_geometry(hunan_projected)),4326)
coords4 <- st_coordinates(centres)
stopifnot(!anyDuplicated(as.data.frame(coords4)))
nearest1 <- knn2nb(knearneigh(coords4,k=1,longlat=TRUE),row.names=hunan$County)
nearest_dist <- unlist(nbdists(nearest1,coords4,longlat=TRUE))
threshold_km <- ceiling(max(nearest_dist))
fixed62 <- dnearneigh(coords4,0,62,longlat=TRUE,row.names=hunan$County)
knn6 <- knn2nb(knearneigh(coords4,k=6,longlat=TRUE),row.names=hunan$County)
knn6_symmetric <- make.sym.nb(knn6)
stopifnot(threshold_km<=62,all(card(fixed62)>0),all(card(knn6)==6))
# Reproduce the workbook's degree-coordinate centroids and default planar KNN
# only as a sensitivity check; never label degree distances as kilometres.
chapter_coords <- t(vapply(st_geometry(hunan),function(g) as.numeric(st_centroid(g)),numeric(2)))
chapter62 <- dnearneigh(chapter_coords,0,62,longlat=TRUE)
chapter6 <- knn2nb(knearneigh(chapter_coords,k=6,longlat=FALSE))
changed_links <- function(a,b) sum(vapply(seq_along(a),function(i) length(setdiff(a[[i]],b[[i]])),integer(1)))
sensitivity4 <- tibble(comparison=c("62 km: projected vs workbook centroids","6-NN: great-circle/projected centroids vs workbook planar degrees"),
 added_directed_links=c(changed_links(fixed62,chapter62),changed_links(knn6,chapter6)),
 removed_directed_links=c(changed_links(chapter62,fixed62),changed_links(chapter6,knn6)))
networks <- list(Queen=queen,Rook=rook,`1-NN`=nearest1,`62 km`=fixed62,`6-NN`=knn6,`6-NN symmetric union`=knn6_symmetric)
graph_summary <- bind_rows(lapply(names(networks),function(nm){nb<-networks[[nm]];degrees<-card(nb)
 tibble(method=nm,links=sum(degrees),mean_degree=mean(degrees),min_degree=min(degrees),max_degree=max(degrees),
 isolates=sum(degrees==0),components=n.comp.nb(make.sym.nb(nb))$nc,symmetric=is.symmetric.nb(nb,force=TRUE))}))
component62 <- n.comp.nb(fixed62)$comp.id
degree_table <- tibble(County=hunan$County,queen=card(queen),rook=card(rook),fixed62=card(fixed62),knn6=card(knn6),component62=component62)
## ---- inverse-distance
queen_dist <- nbdists(queen,coords4,longlat=TRUE)
stopifnot(all(unlist(queen_dist)>0))
idw <- lapply(queen_dist,function(d) 1/d)
idw_raw <- nb2listw(queen,glist=idw,style="B",zero.policy=FALSE)
idw_w <- nb2listw(queen,glist=idw,style="W",zero.policy=FALSE)
## ---- row-standardisation
queen_w <- nb2listw(queen,style="W",zero.policy=FALSE)
queen_b <- nb2listw(queen,style="B",zero.policy=FALSE)
weight_audit <- bind_rows(lapply(list(Queen_W=queen_w,Queen_B=queen_b,IDW_raw=idw_raw,IDW_W=idw_w),function(w){
 s<-vapply(w$weights,sum,numeric(1));tibble(min_row_sum=min(s),max_row_sum=max(s))}),.id="scheme")
## ---- lag-average
hunan$lag_average <- lag.listw(queen_w,hunan$GDPPC,zero.policy=FALSE)
## ---- lag-sum
hunan$lag_sum <- lag.listw(queen_b,hunan$GDPPC,zero.policy=FALSE)
## ---- window-average
queen_self <- include.self(queen)
self_w <- nb2listw(queen_self,style="W",zero.policy=FALSE)
hunan$window_average <- lag.listw(self_w,hunan$GDPPC,zero.policy=FALSE)
## ---- window-sum
self_b <- nb2listw(queen_self,style="B",zero.policy=FALSE)
hunan$window_sum <- lag.listw(self_b,hunan$GDPPC,zero.policy=FALSE)
hunan$idw_average <- lag.listw(idw_w,hunan$GDPPC,zero.policy=FALSE)
## ---- check-results
manual_average <- vapply(queen,function(j)mean(hunan$GDPPC[j]),numeric(1))
stopifnot(max(abs(manual_average-hunan$lag_average))<1e-8,
 max(abs(hunan$lag_sum-hunan$lag_average*card(queen)))<1e-7,
 max(abs(hunan$window_sum-hunan$lag_sum-hunan$GDPPC))<1e-7,
 max(abs(hunan$window_average-hunan$window_sum/(card(queen)+1)))<1e-7,
 max(abs(vapply(queen_w$weights,sum,numeric(1))-1))<1e-12,
 max(abs(vapply(idw_w$weights,sum,numeric(1))-1))<1e-12,
 sum(card(queen))==448,sum(card(rook))==440)
anxiang <- match("Anxiang",hunan$County)
anxiang_neighbours <- tibble(County=hunan$County[queen[[anxiang]]],GDPPC=hunan$GDPPC[queen[[anxiang]]],
 distance_km=queen_dist[[anxiang]],equal_weight=queen_w$weights[[anxiang]],raw_idw=idw[[anxiang]],normalised_idw=idw_w$weights[[anxiang]])
results4 <- st_drop_geometry(hunan) |> select(County,City,GDPPC,lag_average,lag_sum,window_average,window_sum,idw_average) |>
 mutate(neighbours=card(queen),difference=GDPPC-lag_average)
top_differences <- results4 |> arrange(desc(abs(difference))) |> head(6)
for(nm in c("graph_summary","degree_table","sensitivity4","weight_audit","anxiang_neighbours","results4","top_differences"))
 write_csv(get(nm),file.path(base4,"outputs",paste0(nm,".csv")))
saveRDS(list(hunan=hunan,networks=networks,queen_w=queen_w,idw_raw=idw_raw,idw_w=idw_w,
 self_w=self_w,self_b=self_b,coords=coords4),file.path(base4,"outputs/weights-and-results.rds"))
## ---- maps
tmap_mode("plot")
palette4 <- c("#f4eedb","#d5d5b3","#a9b699","#758d75","#466553","#203f35")
average_breaks <- c(0,15000,25000,40000,60000,100000)
stopifnot(max(hunan$GDPPC)<max(average_breaks))
map_variable <- function(column,title,breaks=average_breaks,legend="RMB per person") {
 labels <- paste0(format(head(breaks,-1),big.mark=",",trim=TRUE)," to <",format(tail(breaks,-1),big.mark=",",trim=TRUE))
 tm_shape(st_transform(hunan,32649))+tm_polygons(fill=column,
 fill.scale=tm_scale_intervals(style="fixed",breaks=breaks,labels=labels,values=palette4),
 fill.legend=tm_legend(title=legend),col="#fffdf7",lwd=.35)+tm_title(title,size=1.1)+
 tm_layout(frame=FALSE,legend.outside=TRUE)
}
save_map <- function(x,name,width=2200,height=1500) tmap_save(x,file.path(base4,"figures",paste0(name,".png")),width=width,height=height,units="px",dpi=180)
basemap4 <- tm_shape(hunan_projected)+tm_polygons(fill="#eee8d7",col="#6e776d",lwd=.5)+
 tm_text("NAME_3",size=.45)+tm_title("The 88 county-level units in the supplied Hunan layer")+tm_layout(frame=FALSE)
save_map(basemap4,"county-basemap",2000,1800)
save_map(map_variable("GDPPC","GDP per capita, 2012"),"gdppc",1700,1600)
save_map(tmap_arrange(map_variable("GDPPC","Own county GDP per capita"),map_variable("lag_average","Queen-neighbour mean"),ncol=2),"lag-average")
sum_breaks <- pretty(range(c(hunan$GDPPC,hunan$lag_sum,hunan$window_sum)),n=5)
save_map(tmap_arrange(map_variable("GDPPC","Own county GDP per capita",sum_breaks,"Sum of per-capita values"),
 map_variable("lag_sum","Sum across Queen neighbours",sum_breaks,"Sum of per-capita values"),ncol=2),"lag-sum")
save_map(tmap_arrange(map_variable("lag_average","Neighbours only"),map_variable("window_average","Own county plus neighbours"),ncol=2),"window-average")
save_map(tmap_arrange(map_variable("lag_sum","Neighbours only",sum_breaks,"Sum of per-capita values"),
 map_variable("window_sum","Own county plus neighbours",sum_breaks,"Sum of per-capita values"),ncol=2),"window-sum")
png_graph <- function(name,expr,width=2200,height=1450){png(file.path(base4,"figures",paste0(name,".png")),width=width,height=height,res=170);on.exit(dev.off());force(expr)}
draw_nb <- function(nb,title,col="#426653") {plot(st_geometry(hunan),border="#aaa797",col="#f8f5ed",main=title);plot(nb,coords4,add=TRUE,col=col,pch=19,cex=.4,length=.04)}
png_graph("contiguity",{par(mfrow=c(1,2),mar=c(1,1,3,1));draw_nb(queen,"Queen: shared edge or vertex");draw_nb(rook,"Rook: shared edge")})
png_graph("distance",{par(mfrow=c(1,2),mar=c(1,1,3,1));draw_nb(nearest1,"One nearest neighbour");draw_nb(fixed62,"All neighbours within 62 km")})
png_graph("distance-overlay",{par(mar=c(1,1,3,1));draw_nb(fixed62,"62 km links with first-neighbour links overlaid",col="#777c70");plot(nearest1,coords4,add=TRUE,col="#a17832",length=.06);legend("bottomleft",legend=c("62 km","First neighbour"),col=c("#777c70","#a17832"),lty=1,bty="n")},1600,1700)
png_graph("knn6",{par(mar=c(1,1,3,1));draw_nb(knn6,"Six nearest neighbours: directed links")},1600,1700)
diagnostic_plot <- ggplot(results4,aes(GDPPC,lag_average))+geom_abline(slope=1,intercept=0,linetype="dashed",colour="#b08e51")+
 geom_point(colour="#315747",alpha=.8,size=2)+labs(x="Own GDP per capita (RMB)",y="Queen-neighbour mean (RMB)",
 title="Own county and neighbouring GDP per capita",subtitle="Dashed line: equality, not a fitted regression")+theme_minimal(base_size=13)
ggsave(file.path(base4,"figures/own-vs-neighbours.png"),diagnostic_plot,width=9,height=6,dpi=180)
writeLines(capture.output(sessionInfo()),file.path(base4,"outputs/session-info.txt"))
print(graph_summary);print(weight_audit);print(anxiang_neighbours);print(top_differences);print(sensitivity4)
message("Exercise 4: all numerical checks passed")
