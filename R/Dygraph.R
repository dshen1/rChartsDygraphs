#' Plot an interactive dygraph chart
#' 
#' Some desc
#' @param data data.frame
#' @param x optional character string identifying column in the data for x-axis 
#' (TODO: support for vector). If not supplied, attempt is made to detect it 
#' from timeBased data columns or rownames
#' @param y optional character string identifying column in the data for y-axis 
#' series (TODO: support for vector)
#' @param y2 (not yet supported) optional character string identifying column 
#' in the data for secondary y-axis series (TODO: support for vector)
#' @param sync logical default FALSE. Set to TRUE and dygraph will react to 
#' highlights and redraws in other dygraphs on the same page. 
#' (TODO: supply vector of chartIds to sync this chart with)
#' @param ... further options passed to the dygraph options slot. 
#' See http://dygraphs.com/options.html
#' @param defaults logical. Should some dygraph options defaults be preloaded? 
#' Default is TRUE. Options supplied via ... will still override these defaults.
#' @param rebase either non-negative nonzero numeric or "percent" string. Default
#' NULL. If provided, the chart lends itself to comparison of growth rates of multiple
#' series expressed as indices starting from same base ("percent" starts from 0%).
#' Redrawn on each zoom/pan action.
#' @param ribbon character vector or list. Draw colorful ribbon in the background.
#'  Useful for highlighting specific events/periods. `colors` - character vector
#'  of colors with the same length as NROW(data). `height` and `pos` are numeric
#'  arguments from <0,1> interval specifying ribbon size and position relative 
#'  to the canvas. 
#' @param candlestick logical. Display OHLC data as candlesticks? 
#' Defaults to is.OHLC(data). Effort is made to detect OHLC columns by their names.
#' data must contain all of the four series. Redundant columns are discarded.
#' @param trades data.frame with columns c("Start", "End", "Side", "Base", "PL"). 
#' @param signals data.frame with at least 3 columns c("Date", "Price", ...). For custom arrows colors use \code{setattr(signals,"colors",list(c(up="#FFFFFF",down="#000000")))}, see examples.
#' @export
#' @import quantmod
#' @import data.table
#' @examples
#' library(quantmod); require(data.table)
#' getSymbols("SPY", from = "2001-01-01")
#' 
#' # candlestick
#' dygraph(data=SPY, legendFollow=T, candlestick=T)
#' dygraph(data=SPY, legendFollow=T) #autodetects is.OHLC(data)
#' 
#' # trade annotations (arrows)
#' data(trades)
#' dygraph(data=SPY[,"SPY.Close"], legendFollow=TRUE, trades=trades)
#' 
#' # relative performance
#' getSymbols("IBM", from = "2001-01-01", adjust=T)
#' dygraph(merge(IBM[,"IBM.Adjusted"], SPY[,"SPY.Adjusted"]), rebase="percent")
#' 
#' # color ribbon (highlight special events)
#' dydata=SPY[,"SPY.Close"]
#' colors = rep("transparent", NROW(dydata)) # must equal NROW(data)
#' colors[1000:1550] = "lightgreen" # accepts "#90EE90" representation too
#' colors[1700:2050] = "red"
#' colors[2060:2140] = "lightblue"
#' dygraph(data=dydata, ribbon=colors)
#' dygraph(data=dydata, ribbon=list(colors=colors, height=0.2, pos=0.1))
#' 
#' # dygraph on univariate data in data.frame
#' data <- data.frame(date = index(SPY), SPY = SPY[,"SPY.Close",drop=TRUE])
#' # calc indicators
#' setDT(data)[,`:=`(SPY.sma200 = TTR::SMA(SPY, 200), SPY.sma50 = TTR::SMA(SPY, 50))]
#' # dygraph + little more control and some commonly used options
#' dygraph(data = as.data.frame(data),
#'         x = "date",
#'         y = c("SPY","SPY.sma200","SPY.sma50"),
#'         logscale = FALSE,
#'         title = "my SPY price chart",
#'         xlabel = "time", 
#'         ylabel = "SPY price",
#'         colors = c("black","blue","red"),
#'         legendFollow = TRUE)
#' # populate signals SMA200/SMA50 cross
#' signals <- data[,.SD # prevent write to `data`
#'                 ][,sig:=ifelse(SPY.sma50>SPY.sma200, 1, ifelse(SPY.sma50<SPY.sma200, -1, NA_real_))
#'                   ][,sig:=zoo::na.locf(sig,na.rm=FALSE) # fill gaps with last sig
#'                     ][is.na(sig), sig:=0 # decode leading NA to 0
#'                       ][,sig_change:=sig!=c(0,sig[.I-1]) # check if signal changed
#'                         ][sig_change==FALSE, sig:=0 # skip signals when no change
#'                           ][,list(Date=date,Price=SPY,sig=c(0,sig[.I-1])) # apply 1 period lag
#'                             ]
#' # dygraph and signals
#' dygraph(data = as.data.frame(data),
#'         title = "SPY price + SMA200/SMA50 cross signal",
#'         colors = c("black","blue","red"),
#'         signals = signals,
#'         legendFollow = TRUE)
#' 
#' # refresh data for new signals
#' data <- data.frame(date = index(SPY), SPY = SPY[,"SPY.Close",drop=TRUE])
#' # calc indicators for multiple signals
#' setDT(data)[,`:=`(SPY.ema42 = TTR::EMA(SPY, 42), SPY.ema20 = TTR::EMA(SPY, 20),
#'                   SPY.ema200 = TTR::EMA(SPY, 200), SPY.ema50 = TTR::EMA(SPY, 50))]
#' # populate multiple signals
#' signals <- data[,.SD # prevent write to `data`
#'                 ][,`:=`(sig_fast=ifelse(SPY.ema20>SPY.ema42, 1, ifelse(SPY.ema20<SPY.ema42, -1, NA_real_)),
#'                         sig_slow=ifelse(SPY.ema50>SPY.ema200, 1, ifelse(SPY.ema50<SPY.ema200, -1, NA_real_)))
#'                   ][,`:=`(sig_fast=zoo::na.locf(sig_fast,na.rm=FALSE), # fill gaps with last sig
#'                           sig_slow=zoo::na.locf(sig_slow,na.rm=FALSE))
#'                     ][is.na(sig_fast), sig_fast:=0 # decode leading NA to 0
#'                       ][is.na(sig_slow), sig_slow:=0
#'                         ][,`:=`(sig_fast_change=sig_fast!=c(0,sig_fast[.I-1]), # check if signal changed
#'                                 sig_slow_change=sig_slow!=c(0,sig_slow[.I-1]))
#'                           ][sig_fast_change==FALSE, sig_fast:=0 # skip signals when no change
#'                             ][sig_slow_change==FALSE, sig_slow:=0
#'                               ][,list(Date=date,Price=SPY,sig_fast=c(0,sig_fast[.I-1]),sig_slow=c(0,sig_slow[.I-1])) # apply 1 period lag
#'                                 ]
#' # custom colors for arrows
#' setattr(signals,"colors",list(c(up = "#FFA500", down = "#8B5A00"),c(up = "#00F5FF", down = "#00868B")))
#' # dygraph and signals
#' dygraph(data = as.data.frame(data),
#'         colors = c("black",c("#8B5A00","#FFA500","#00868B","#00F5FF")),
#'         signals = signals,
#'         legendFollow = TRUE)
dygraph <- dgPlot <- dyPlot <- 
  dygraphPlot <- function(data, x, y, y2, 
                          sync=FALSE, 
                          defaults=TRUE, 
                          rebase=c(NULL, 100, "percent"),
                          ribbon=list(colors=NULL, height=1, pos=0),
                          candlestick=is.OHLC(data),
                          trades=NULL,
                          signals=NULL,
                          ...){
  
  myChart <- Dygraph$new()
  myChart$parseData(data, x, y, y2, as.candlestick=candlestick)
  if(defaults){
    myChart$setDefaults(...)
  }
  myChart$setOpts(...) # dygraph javascript options
  myChart$setTemplate(script = system.file("/libraries/dygraph/layouts/chart2.html"
                                         , package = "rChartsDygraphs"))
  myChart$setTemplate(afterScript = "<script></script>")
  if(sync){
    myChart$synchronize()
  }
  if(candlestick) {
    myChart$candlestick()
  }
  if(!missing(rebase)){
    myChart$setOpts(rebase=rebase)
  }
  if(!missing(ribbon)){
    if(!is.list(ribbon)) # allow for supplying a simple vector in the argument
      ribbon=list(colors=ribbon, height=1, pos=0)
    if(length(ribbon$colors) != NROW(data))
      stop("ribbon colors vector length ", length(ribbon$colors), 
           "not equal data length. Check arguments provided to dygraph().")
    r = ribbon$colors
    h = ribbon$height
    p = ribbon$pos
    rhex = rgb(t(col2rgb(r)), maxColorValue=255)
    rencodings = factor(rhex)
    rd = as.integer(rencodings) - 1
    pal = levels(rencodings)
    myChart$setOpts(ribbonData=rd, ribbon=list(palette=pal, height=h, position=p))
  }
  if(length(trades)){
    trades = as.data.table(trades)
    entries = trades[, list(Date=Start, Side=Side, E="Entry", Price=Base, PL=PL)]
    exits = trades[, list(Date=End, Side=Side, E="Exit", Price=Base*(1+PL), PL=PL)]
    ann = rbindlist(list(entries, exits))
    
    ann[, canvas:="#!Dygraph.Circles.ARROW!#"]
    ann[, rotation:=ifelse(Side=="Long", 
                           ifelse(E=="Entry", "up", "down"), 
                           ifelse(E=="Entry", "down", "up"))]
    ann[, fillStyle:=ifelse(E=="Entry", "white", ifelse(PL>=0, "green", "red"))]
    ann[, strokeStyle:="black"]
    ann[, x:= paste0("#!Date.parse('", Date, "')!#")]
    ann[, series:=1]
    ann[, text:=paste0("<p><strong>Price</strong> ", round(Price,2), "<br>",
        "</p>")]
    ann = ann[,c("series", "x", "canvas", "rotation","fillStyle", "strokeStyle",
                 "text"), with=F]
    myChart$setOpts(annotations=toJSONArray(ann, json=F))
    myChart$setOpts(annotationMouseOverHandler= "#!
      function(ann, point, dg, event) {
        var bubble = document.createElement('div');
        bubble.className = 'bubble';
        bubble.id = 'bubble' + ann.series + ann.x + i;
        bubble.innerHTML = ann.text;
        bubble.style.top = point.canvasy + 'px';
        bubble.style.left = point.canvasx + 'px';
        dg.graphDiv.appendChild(bubble);
        ann.div.title = '';
      }!#")
    myChart$setOpts(annotationMouseOutHandler= "#!
      function(ann, point, dg, event) {
        var bubble = document.getElementById('bubble' + ann.series + ann.x + i);
        if (bubble && bubble.parentNode) {
          bubble.parentNode.removeChild(bubble);
        }
      }!#")
    myChart$setTemplate(script=system.file("/libraries/dygraph/layouts/annotations.html"
                                           , package = "rChartsDygraphs"))
  }
  if(length(signals)){
    colors <- attr(signals,"colors")
    seriesSig <- function(colN, signals){
      if(is.null(colors)) colorsN <- c(up = "green", down = "red")
      else colorsN <- colors[[colN-2]]
      ann <- as.data.table(signals[,c(1,2,eval(colN)),with=FALSE])
      sig_org_name <- names(ann)[3]
      ann <- setnames(ann, sig_org_name, "sig")
      ann <- ann[!is.na(sig)][sig%in%c(1,-1)]
      ann[, canvas:="#!Dygraph.Circles.ARROW!#"]
      ann[sig==1,`:=`(rotation="up",fillStyle=colorsN[["up"]])][sig==-1, `:=`(rotation="down",fillStyle=colorsN[["down"]])]
      ann[, strokeStyle:="black"]
      ann[, x:= paste0("#!Date.parse('", Date, "')!#")]
      ann[, series:=1]
      ann[, text:=paste0("<p><strong>Price</strong> ", round(Price,2),"</br>",ifelse(sig_org_name=="sig","",paste0(sig_org_name,"</br>")),"<strong>signal</strong> ",ifelse(sig==1,"buy","sell"),"</p>")]
      ann[,c("series", "x", "canvas", "rotation","fillStyle", "strokeStyle","text"), with=FALSE]
    }
    ann <- rbindlist(lapply(3:ncol(signals), seriesSig, signals))
    
    myChart$setOpts(annotations=toJSONArray(ann, json=F))
    myChart$setOpts(annotationMouseOverHandler= "#!
      function(ann, point, dg, event) {
        var bubble = document.createElement('div');
        bubble.className = 'bubble';
        bubble.id = 'bubble' + ann.series + ann.x + i;
        bubble.innerHTML = ann.text;
        bubble.style.top = point.canvasy + 'px';
        bubble.style.left = point.canvasx + 'px';
        dg.graphDiv.appendChild(bubble);
        ann.div.title = '';
      }!#")
    myChart$setOpts(annotationMouseOutHandler= "#!
      function(ann, point, dg, event) {
        var bubble = document.getElementById('bubble' + ann.series + ann.x + i);
        if (bubble && bubble.parentNode) {
          bubble.parentNode.removeChild(bubble);
        }
      }!#")
    myChart$setTemplate(script=system.file("/libraries/dygraph/layouts/annotations.html", package = "rChartsDygraphs"))
  }
  return(myChart$copy())
}

Dygraph <- setRefClass('Dygraph', contains = 'rCharts'
                       , methods = list(
  initialize = function(){
    callSuper()
    LIB <<- get_lib(lib, package = "rChartsDygraphs")
    params <<- c(params, list(options = list(width=params$width, height=params$height)))
  },
  
  getPayload = function(chartId){
    list(chartParams = toJSON2(params), chartId = chartId, lib = basename(lib), liburl = LIB$url)
  },
  
  parseData = function(data, x, y, y2, as.candlestick){
    if(is.xts(data)) {
      t = index(data)
      data = cbind(t, as.data.frame(data))
    }
    if(missing(x)){ #TODO: detect using xts:::timeBased
      x <- names(data)[1]
    }
    if(missing(y)){
      y = setdiff(names(data), x)
    }
    
    # dygraphs.js requirement: data must be exactly 4 columns in specific order
    if(as.candlestick){
      pos = c(has.Op(data, which=TRUE), has.Cl(data, which=TRUE), 
              has.Hi(data, which=TRUE), has.Lo(data, which=TRUE))
      y = names(data)[pos]
    }
    
    data[[x]] <- paste0("#!new Date(", as.numeric(as.POSIXct(data[[x]])) * 1000, ")!#")
    data[y] = lapply(data[y], function(x) as.numeric(x)) # temp fix for logical values
    data <- data[,c(x, y)]
    params <<- modifyList(params, getLayer(x=x, data=data, y=y))
    setOpts(labels=c(x, y)) # because lodash drops column names
  },
  setDefaults = function(...){
    args = list(...)
    safe <- function(x) if (length(x)) x else FALSE
    
    # make floating legend more readable by default
    if(safe(args$legendFollow)){
      setOpts(labelsDivStyles=list(
        pointerEvents='none', # let mouse events fall through the legend div
        # borderRadius='10px',
        # boxShadow='4px 4px 4px #888',
        # background='none',
        backgroundColor='rgba(255, 255, 255, 0.5)'
      ))
    }

    if(!"rightGap" %in% names(args)){
      setOpts(rightGap=20) # makes it easier to highlight the right-most data point.
    }
  },
  setOpts = function(...){
    opts <- list(...)
    fix_dygraph_options <- function(x) {
      # dygraph colors parameter accepts JSON array only, no character string
      if(length(x$colors))
        x$colors <- as.list(x$colors)
      return(x)
    }
  
    params$options <<- modifyList(params$options, fix_dygraph_options(opts))
  },
  candlestick = function(){
    setOpts(plotter = "#!Dygraph.Plotters.candlePlotter!#")
  },
  synchronize = function(){
    setOpts(
      highlightCallback = "#!
        function(e, x, pts, row) {
          for (var j = 0; j < gs.length; j++) {
            gs[j].setSelection(row);
          }
        }!#",
      unhighlightCallback = "#!
        function(e, x, pts, row) {
          for (var j = 0; j < gs.length; j++) {
            gs[j].clearSelection();
          };
        }!#",
      drawCallback = "#!
        function(me, initial) {
          if (blockRedraw || initial) return;
          blockRedraw = true;
          var range = me.xAxisRange();
          var yrange = me.yAxisRange();
          for (var j = 0; j < gs.length; j++) {
            if (gs[j] == me) continue;
            gs[j].updateOptions( {
              dateWindow: range
              // valueRange: yrange // we don't want to sync along y-axis
            } );
          }
          blockRedraw = false;
        }!#"
      )
  })
)

#' Display multiple dygraphs
#' 
#' ...
#' 
#' @param ... list of dygraph objects to display
#' @export
layout_dygraphs <- function(...) {
  l = list(...)
  showCharts = if(length(l)==1 & is.list(l)) l[[1]] else l
  
  #get the divs for each of the charts as a string
  #this will be used by whisker.render later
  chartDivs <- paste(
    sapply(
      showCharts,function(rCh){
        return(paste(capture.output(rCh$print()),collapse="\n"))
      }
    ),
    collapse = "\n"
  )
  
  viewer = getOption("viewer")  #if not null then use RStudio viewer
  
  #if viewer is not null then 
  #we will need to either use http assets or copy js and css into same directory
  if (!grepl("^http", showCharts[[1]]$LIB$url) && !is.null(viewer)) {
    temp_dir = tempfile(pattern = 'rCharts')
    dir.create(temp_dir)
    suppressMessages(copy_dir_(
      showCharts[[1]]$LIB$url,
      file.path(temp_dir,showCharts[[1]]$LIB$name)
    ))
    tf <- file.path(temp_dir, "index.html")
    
    #get css and script files to add into head
    #will need to copy these files in directory to use with RStudio Viewer
    assets = get_assets(showCharts[[1]]$LIB, static = F, cdn = F)
    
    cat(
      whisker::whisker.render(
        readLines(
          system.file(
            "/libraries/dygraph/layouts/multi.html",
            package = "rChartsDygraphs")
        )
      ),
      file = tf)

    viewer(tf)
  } else {
    #if not using RStudio Viewer can use assets in rChartsDygraphs directory
    #or if using RStudio Viewer and non local (http assets)
    #  can use those without copying
    assets = get_assets(showCharts[[1]]$LIB, static = TRUE, cdn = FALSE)
    
    cat(
      whisker::whisker.render(
        readLines(
          system.file(
            "/libraries/dygraph/layouts/multi.html",
            package = "rChartsDygraphs")
        )
      ),
      file = tf <- tempfile(fileext = ".html")
    )
    if (!is.null(viewer)) {
      viewer(tf)
    } else {
      browseURL(tf)
    }
  }
}
