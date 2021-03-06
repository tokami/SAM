##' Plot sam object 
##' @method plot sam
##' @param  x ...
##' @param  ... extra arguments (not possible to use add=TRUE --- please collect to a list of fits using e.g the c(...), and then plot that collected object)
##' @importFrom graphics par
##' @details ...
##' @export
plot.sam<-function(x, ...){
  dots <- list(...) 
  if("add" %in% names(dots) && dots$add==TRUE){stop("Not possible to use add=TRUE here --- please collect to a list of fits using c(...)")}
  op<-par(mfrow=c(3,1))
  ssbplot(x,...)
  fbarplot(x,...)
  recplot(x,...)
  par(op)
}

##' Plot samforecast object 
##' @method plot samforecast
##' @param  x ...
##' @param  ... extra arguments
##' @importFrom graphics par
##' @details ...
##' @export
plot.samforecast<-function(x, ...){
  op<-par(mfrow=c(3,1))
  ssbplot(x,...)
  fbarplot(x, drop=0,...)
  recplot(x,...)
  par(op)
}

##' Collect sam objects 
##' @method c sam
##' @param  ... sam fits to be combined 
##' @importFrom graphics par
##' @details ...
##' @export
c.sam<-function(...){
  ret<-list(...)
  class(ret)<-"samset"
  ret
}

##' Plot sam object 
##' @method plot samset
##' @param  x ...
##' @param  ... extra arguments
##' @importFrom graphics par
##' @details ...
##' @export
plot.samset<-function(x, ...){
  op<-par(mfrow=c(3,1))
  ssbplot(x,...)
  fbarplot(x,...)
  recplot(x,...)
  par(op)
}

##' Compute process residuals (single joint sample) 
##' @param fit the fitted object as returned from the sam.fit function
##' @param map map from original fit 
##' @param ... extra arguments (not currently used)
##' @return an object of class \code{samres}
##' @details ...
##' @importFrom TMB sdreport
##' @export
procres <- function(fit, map = fit$obj$env$map, ...){
  pp<-fit$pl
  attr(pp,"what") <- NULL
  pp$missing <- NULL
  fit.co<-sam.fit(fit$data, fit$conf, pp, run=FALSE, map = map)
  fit.co$obj$env$data$resFlag<-1
  fit.co$obj$retape()
  sdrep <- sdreport(fit.co$obj,fit$opt$par)  
  ages <- as.integer(colnames(fit.co$data$natMor))
  iF<-fit.co$conf$keyLogFsta[1,]
  if (exists(".Random.seed")){
    oldseed <- get(".Random.seed", .GlobalEnv)
    oldRNGkind <- RNGkind()
  }
  set.seed(123456)
  idx <- which(names(sdrep$value)=="resN")
  resN <- rmvnorm(1,mu=sdrep$value[idx], Sigma=sdrep$cov[idx,idx])
  resN <- matrix(resN, nrow=nrow(fit.co$pl$logN))
  resN <- data.frame(year=fit.co$data$years[as.vector(col(resN))],
                     fleet=1,
                     age=ages[as.vector(row(resN))],
                     residual=as.vector(resN))
  idx <- which(names(sdrep$value)=="resF")
  resF <- rmvnorm(1,mu=sdrep$value[idx], Sigma=sdrep$cov[idx,idx])
  resF <- matrix(resF, nrow=nrow(fit.co$pl$logF))
  resF <- data.frame(year=fit.co$data$years[as.vector(col(resF))],
                     fleet=2,
                     age=ages[iF[iF>=0]+1][as.vector(row(resF))],
                     residual=as.vector(resF))
  ret <- rbind(resN, resF)
  attr(ret, "fleetNames") <- c("Joint sample residuals log(N)", "Joint sample residuals log(F)")
  class(ret) <- "samres"
  if (exists("oldseed")){
    do.call("RNGkind",as.list(oldRNGkind))
    assign(".Random.seed", oldseed, .GlobalEnv)
  }
  return(ret)
}

##' Plot sam residuals 
##' @method plot samres 
##' @param x an object of type 'samres' as returned from residuals or procres.
##' @param type either "bubble" (default) or "summary"
##' @param ... extra arguments
##' @details ...
##' @importFrom graphics abline
##' @importFrom stats acf na.pass qqnorm
##' @export
##' @examples
##' \dontrun{
##' data(nscodData)
##' data(nscodConf)
##' data(nscodParameters)
##' fit <- sam.fit(nscodData, nscodConf, nscodParameters)
##' par(ask=FALSE)
##' plot(residuals(fit))
##' }
plot.samres<-function(x, type="bubble",...){
  if(type=="bubble"){
    add_legend <- function(x, ...) {
      opar <- par(fig=c(0, 1, 0, 1), oma=c(0, 0, 0, 0), 
                  mar=c(0, 0, 0, 0), new=TRUE)
      on.exit(par(opar))
      plot(0, 0, type='n', bty='n', xaxt='n', yaxt='n')
      zscale <- pretty(x$residual,min.n=4)
      uu<-par("usr")
      yy<-rep(uu[3]+.03*(uu[4]-uu[3]), length(zscale))
      xx<-seq(uu[1]+.10*(uu[2]-uu[1]),uu[1]+.4*(uu[2]-uu[1]), length=length(zscale))
      text(xx,yy,labels=zscale)
      colb <- ifelse(zscale<0, rgb(1, 0, 0, alpha=.5), rgb(0, 0, 1, alpha=.5))
      bs<-1
      if("bubblescale"%in%names(list(...))) bs <- list(...)$bubblescale
      points(xx,yy,cex=sqrt(abs(zscale))/max(sqrt(abs(zscale)), na.rm=TRUE)*5*bs, pch=19, col=colb)
    }
    neg.age <- (x$age < -1.0e-6)
    x$age[neg.age] <- mean(x$age[!neg.age],na.rm=TRUE)
    plotby(x$year, x$age, x$residual, by=attr(x,"fleetNames")[x$fleet], xlab="Year", ylab="Age", ...)
    add_legend(x, ...)
  } else if(type=="summary"){
      tmp <- xtabs( x$residual ~ x$year + x$age + x$fleet)
      nfleets <- dim(tmp)[3]
      op<-par(mfrow=rev(n2mfrow(3*nfleets)),mar=c(4,5,1,1))
      on.exit(par(op))
      fnames <- attr(x,"fleetNames")
      for(f in 1:nfleets){
          sel<-which(x$fleet==f)
          plot(factor(x$age[sel]),x$residual[sel])
          mtext(fnames[f],side=2,line=3) 
          tmp2 <- t(tmp[,,f])
          tmp2 <- rbind(tmp2, matrix(NA,nrow=nrow(tmp2),ncol=ncol(tmp2)))
          acf(as.vector(tmp2),na.action=na.pass,lag.max=dim(tmp)[2])
          qqnorm(x$residual[sel])
          abline(0,1)
      }
  } else stop(paste0("unknown type: ",type))
}

##' Print sam object 
##' @method print sam 
##' @param  x ...
##' @param  ... extra arguments
##' @details ...
##' @export
print.sam<-function(x, ...){
  cat("SAM model: log likelihood is", logLik.sam(x,...),"Convergence", ifelse(0==x$opt$convergence, "OK\n", "failed\n"))
}

##' Print samres object 
##' @method print samres 
##' @param  x ...
##' @param  ... extra arguments
##' @details ...
##' @export
print.samres<-function(x, ...){
  class(x)<-NULL
  print(as.data.frame(x))
}

##' Log likelihood of sam object 
##' @method logLik sam 
##' @param  object sam fitted object (result from sam.fit)
##' @param  ... extra arguments
##' @details ...
##' @export
logLik.sam<-function(object, ...){
  ret<- -object$opt$objective
  attr(ret,"df")<-length(object$opt$par)
  class(ret)<-"logLik"
  ret
}

##' Extract fixed coefficients of sam object 
##' @method coef sam 
##' @param  object sam fitted object (result from sam.fit)
##' @param  ... extra arguments
##' @details ...
##' @importFrom stats coef
##' @export
coef.sam <- function(object, ...){
  ret <- object$sdrep$par.fixed
  attr(ret,"cov") <- object$sdrep$cov.fixed
  attr(ret,"sd") <- sqrt(diag(object$sdrep$cov.fixed))
  class(ret)<-"samcoef"
  ret
}

##' Print samcoef object 
##' @method print samcoef 
##' @param  x ...
##' @param  ... extra arguments
##' @details ...
##' @export
print.samcoef<-function(x, ...){
  y<-as.vector(x)
  names(y)<-names(x)
  print(y)
}


##' Extract number of observations from sam object 
##' @method nobs sam 
##' @param object sam fitted object (result from sam.fit)
##' @param ... extra arguments
##' @importFrom stats nobs
##' @details ...
##' @export
nobs.sam<-function(object, ...){
  as.integer(object$data$nobs)
}

##' Extract residuals from sam object 
##' @method residuals sam 
##' @param object sam fitted object (result from sam.fit)
##' @param discrete logical if model contain discrete observations  
##' @param ... extra arguments for TMB's oneStepPredict
##' @importFrom stats residuals
##' @importFrom TMB oneStepPredict
##' @details ...
##' @export
residuals.sam<-function(object, discrete=FALSE, ...){
  cat("One-observation-ahead residuals. Total number of observations: ", nobs(object), "\n")  
  res <- oneStepPredict(object$obj, observation.name="logobs", data.term.indicator="keep", discrete=discrete,...)
  cat("One-observation-ahead residuals. Done\n")  
  ret <- cbind(object$data$aux, res)
  attr(ret,"fleetNames") <- attr(object$data, "fleetNames")
  class(ret)<-"samres"
  ret
}

##' Summary of sam object 
##' @method summary sam 
##' @param object sam fitted object (result from sam.fit)
##' @param ... extra arguments 
##' @details ...
##' @export
summary.sam<-function(object, ...){
  dots<-list(...)  
  ret <- cbind(round(rectable(object,...)), round(ssbtable(object)), round(fbartable(object),3))
  add <- 0
  if(!is.null(dots$lagR)){
    if(dots$lagR==TRUE){
      add <- 1
    }
  }
  colnames(ret)[1] <- paste("R(age ", object$conf$minAge+add, ")", sep="") 
  colnames(ret)[4] <- "SSB"
  colnames(ret)[7] <- paste("Fbar(",object$conf$fbarRange[1], "-", object$conf$fbarRange[2], ")", sep="")
  ret
}

##' Simulate from a sam object 
##' @method simulate sam 
##' @param object sam fitted object (result from sam.fit)
##' @param nsim number of response lists to simulate. Defaults to 1.
##' @param seed random number seed
##' @param full.data logical, should each inner list contain a full list of data. Defaults to TRUE  
##' @param ... extra arguments
##' @importFrom stats simulate
##' @details ...
##' @return returns a list of lists. The outer list has length \code{nsim}. Each inner list contains simulated values of \code{logF}, \code{logN}, and \code{obs} with dimensions equal to those parameters.
##' @export
simulate.sam<-function(object, nsim=1, seed=NULL, full.data=TRUE, ...){
  if(!is.null(seed)) set.seed(seed)
  est <- unlist(object$pl)
  if(full.data){
    ret <- replicate(nsim, 
    	c(object$data[names(object$data)!="logobs"],#all the old data
    	object$obj$simulate(est)["logobs"])#simulated observations
    	, simplify=FALSE)
    ret<-lapply(ret, function(x){attr(x,"fleetNames") <- attr(object$data,"fleetNames");x})
  }else{
  	ret <- replicate(nsim, object$obj$simulate(est), simplify=FALSE)
  }
  ret
}


##' Plot sam object 
##' @method plot samypr
##' @param  x ...
##' @param  ... extra arguments 
##' @importFrom graphics par title
##' @details ...
##' @export
plot.samypr<-function(x, ...){
  par(mar=c(5.1,4.1,4.1,5.1))
  plot(x$fbar, x$yield, type='l', xlab=x$fbarlab, ylab='Yield per recruit', ...)
  lines(c(x$fmax,x$fmax), c(par('usr')[1],x$yield[x$fmaxIdx]), lwd=3, col='red')
  lines(c(x$f01,x$f01), c(par('usr')[1],x$yield[x$f01Idx]), lwd=3, col='blue')  
  ssbscale <- max(x$yield)/max(x$ssb)

  lines(x$fbar, ssbscale*x$ssb, lty='dotted')
  ssbtick <- pretty(x$ssb)
  ssbat <- ssbtick*ssbscale
  axis(4,at=ssbat, labels=ssbtick)
  mtext('SSB per recruit', side=4, line=2)

  lines(c(x$f35,x$f35), c(par('usr')[1],x$ssb[x$f35Idx]*ssbscale), lwd=3, col='green')

  title(eval(substitute(expression(F[max]==fmax~ ~ ~ ~ ~F[0.10]==f01~ ~ ~ ~ ~F[0.35*SPR]==f35), 
                        list(fmax=round(x$fmax,2), f01=round(x$f01,2), f35=round(x$f35,2)))))
}


##' Print samypr object 
##' @method print samypr 
##' @param  x an object as returned from the ypr function
##' @param  ... extra arguments
##' @details ...
##' @export
print.samypr <- function(x, ...){
  idx <- c(x$fmaxIdx, x$f01Idx, x$f35Idx)
  ret <- cbind(x$fbar[idx],x$ssb[idx],x$yield[idx])
  rownames(ret) <- c("Fmax", "F01", "F35")
  colnames(ret) <- c("Fbar", "SSB", "Yield")
  print(ret)
}

##' Print samforecast object 
##' @method print samforecast 
##' @param  x an object as returned from the forecast function
##' @param  ... extra arguments
##' @details ...
##' @export
print.samforecast<-function(x, ...){
  print(attr(x,"tab"))
}

##' Print samset object 
##' @method print samset 
##' @param  x a list of sam models
##' @param  ... extra arguments
##' @details ...
##' @importFrom stats logLik
##' @export 
print.samset<-function(x,...){
  if("jitflag"%in%names(attributes(x))){  
    fit<-attr(x,"fit")
    maxabsdiff <- apply(abs(do.call(cbind, lapply(x, function(f)unlist(f$pl)-unlist(fit$pl)))),1,max)
    maxlist <- relist(maxabsdiff, fit$pl)
    ret <- as.data.frame(unlist(lapply(maxlist,function(x)if(length(x)>0)max(x) else NULL)))
    fbar <- max(unlist(lapply(x, function(f)abs(fbartable(f)[,1]-fbartable(fit)[,1]))))
    ssb <- max(unlist(lapply(x, function(f)abs(ssbtable(f)[,1]-ssbtable(fit)[,1]))))
    rec <- max(unlist(lapply(x, function(f)abs(rectable(f)[,1]-rectable(fit)[,1]))))
    catch <- max(unlist(lapply(x, function(f)abs(catchtable(f)[,1]-catchtable(fit)[,1]))))
    logLik <- max(abs(unlist(lapply(x, logLik))-logLik(fit)))
    ret <- rbind(ret, ssb=ssb,  fbar=fbar, rec=rec, catch=catch, logLik=logLik)
    names(ret) <- "max(|delta|)" 
    print(ret)
  }else{
    print.default(x,...)
  }
}
