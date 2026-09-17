source("Hands-on_Ex/Hands-on_Ex02/prepare.R")
## ---- simulation-envelopes
# Homogeneous Poisson CSR: intensity estimated separately within each window.
# Default fix.n=FALSE allows simulated point counts to vary, as in Chapter 5.
spec <- list(G=list(fun=Gest,nsim=999,correction="rs"),
             F=list(fun=Fest,nsim=999,correction="rs"),
             K=list(fun=Kest,nsim=99,correction="isotropic"),
             L=list(fun=Lest,nsim=99,correction="isotropic"))
envelopes <- list()
summary_rows <- list()
for (a in c("CHOA CHU KANG","TAMPINES")) {
  x <- patterns[[a]]
  for (f in names(spec)) {
    cfg <- spec[[f]]
    set.seed(1234 + match(a,areas)*10 + match(f,names(spec)))
    message(a," / ",f," / ",cfg$nsim," simulations")
    e <- envelope(x,fun=cfg$fun,nsim=cfg$nsim,nrank=1,global=FALSE,
      correction=cfg$correction,verbose=FALSE,savefuns=TRUE)
    key <- paste(a,f,sep="_")
    envelopes[[key]] <- e
    valid <- is.finite(e$obs)&is.finite(e$lo)&is.finite(e$hi)&e$r>0
    above <- valid & e$obs>e$hi
    below <- valid & e$obs<e$lo
    crossings <- e$r[above|below]
    summary_rows[[key]] <- tibble(area=a,function_name=f,simulations=cfg$nsim,
      correction=cfg$correction,pointwise_alpha=2/(cfg$nsim+1),
      above_points=sum(above),below_points=sum(below),
      first_departure_m=if(length(crossings))min(crossings) else NA_real_,
      last_departure_m=if(length(crossings))max(crossings) else NA_real_)
    write_csv(as.data.frame(e),file.path(base,"outputs",paste0(gsub(" ","-",key),".csv")))
  }
}
## ---- envelope-plots
for(f in names(spec)) {
  png_plot(paste0("envelope-",f),{
    par(mfrow=c(1,2))
    for(a in c("CHOA CHU KANG","TAMPINES")) {
      e <- envelopes[[paste(a,f,sep="_")]]
      limits <- range(e$r[is.finite(e$obs)&is.finite(e$lo)&is.finite(e$hi)])
      if(f=="K") plot(e, . - pi*r^2 ~ r,main=paste(a,"| K(r) - pi*r^2"),xlab="Distance (m)",ylab="Centred K (m^2)",xlim=limits)
      else if(f=="L") plot(e, . - r ~ r,main=paste(a,"| L(r) - r"),xlab="Distance (m)",ylab="Centred L (m)",xlim=limits)
      else plot(e,main=paste(a,"|",f,"function"),xlab="Distance (m)",ylab=paste0(f,"(r)"),xlim=limits)
    }
  },2000,1000)
}
## ---- end-analysis-b
summary_b <- bind_rows(summary_rows)
write_csv(summary_b,file.path(base,"outputs/envelope-summary.csv"))
saveRDS(envelopes,file.path(base,"cache/envelopes.rds"))
saveRDS(list(summary=summary_b,areas=area_summary),file.path(base,"outputs/results-b.rds"))
message("Exercise 2B analysis complete")
