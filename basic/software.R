## Software installation instructions
## By: T. Hengl
## http://gsif.isric.org

## These examples based on the MRO version of R (Microsoft R Open 3.2.4)

## Check that all packages have been installed:
list.of.packages = c("GSIF", "plotKML", "nnet", "plyr", "ROCR", "randomForest", "plyr", "parallel", "psych", "mda", "h2o", "dismo", "grDevices", "snowfall", "hexbin", "lattice", "ranger", "xgboost", "doParallel", "caret", "RQGIS")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## (optional) install from R-Forge:
install.packages("GSIF", repos=c("http://R-Forge.R-project.org"), type="source", dependencies=TRUE)

## (optional) install from github:
library(devtools)
devtools::install_github("jannes-m/RQGIS")

## http://stackoverflow.com/questions/8229859/sourcing-an-r-script-from-github-for-global-session-use-from-within-a-wrapper
source_https <- function(url, ...) {
  # load package
  require(RCurl)
  # download:
  cat(getURL(url, followlocation = TRUE, cainfo = system.file("CurlSSL", "cacert.pem", package = "RCurl")), file = basename(url))
  source(basename(url))
}
source_https("https://raw.githubusercontent.com/cran/GSIF/master/R/OCSKGM.R")
OCSKGM

## Test rgdal package:
library(rgdal)
spnad83 <- readGDAL(system.file("pictures/erdas_spnad83.tif", package = "rgdal")[1])
str(spnad83)
## This is just a vector really:
#spnad83.tbl <- as.data.frame(spnad83)
library(raster)
plot(raster(spnad83))

## Vector maps:
install_github("edzer/sfr")
library(sf); library(plotKML)
data(eberg_zones)
class(eberg_zones)
eberg_zones.tbl <- st_as_sf(eberg_zones)
str(eberg_zones.tbl)

## GPKG
library(RSQLite)
data(eberg)
coordinates(eberg) <- ~X+Y
proj4string(eberg) <- CRS("+init=epsg:31467")
writeOGR(eberg, "eberg.gpkg", "eberg", "GPKG")
con <- dbConnect(RSQLite::SQLite(), dbname = "eberg.gpkg")
df <- dbGetQuery(con, 'select "soiltype" from eberg')
summary(as.factor(df$soiltype))
dbGetQuery(con, 'select * from gpkg_spatial_ref_sys')[3,"description"]

## Test GSIF package:
library(GSIF)
library(sp)
library(boot)
library(aqp)
library(plyr)
library(rpart)
library(splines)
library(gstat)
library(quantregForest)
library(plotKML)
demo(meuse, echo=FALSE)
omm <- fit.gstatModel(meuse, om~dist+ffreq, meuse.grid, method="quantregForest")
om.rk <- predict(omm, meuse.grid)
plotKML(om.rk)

library(leaflet)
library(htmlwidgets)
library(GSIF)
library(raster)
demo(meuse, echo=FALSE)
omm <- autopredict(meuse["om"], meuse.grid[c("dist","soil","ffreq")], method="ranger", auto.plot=FALSE, rvgm=NULL)
meuse.ll <- reproject(meuse["om"])
m = leaflet() %>% addTiles() %>% addRasterImage(raster(omm$predicted["om"]), colors = SAGA_pal[[1]][4:20]) %>% addCircles(lng = meuse.ll@coords[,1], lat = meuse.ll@coords[,2], color = c('black'), radius=meuse.ll$om)  
saveWidget(m, file="organicmater_predicted.html")

## SAGA GIS (https://sourceforge.net/projects/saga-gis/):
if(.Platform$OS.type == "windows"){
  saga_cmd = shortPathName(normalizePath("C:/SAGA-GIS/saga_cmd.exe"))
} else {
  saga_cmd = "/usr/local/bin/saga_cmd"
}  
system(paste(saga_cmd))

library(rgdal)
library(raster)
data("eberg_grid")
gridded(eberg_grid) <- ~x+y
proj4string(eberg_grid) <- CRS("+init=epsg:31467")
writeGDAL(eberg_grid["DEMSRT6"], "DEMSRT6.sdat", "SAGA")
system(paste(saga_cmd, 'ta_lighting 0 -ELEVATION "DEMSRT6.sgrd" -SHADE "hillshade.sgrd" -EXAGGERATION 2'))
plot(raster("hillshade.sdat"), col=SAGA_pal[[3]])

## GDAL (https://trac.osgeo.org/gdal/wiki/DownloadingGdalBinaries):
if(.Platform$OS.type == "windows"){
  gdal.dir <- shortPathName("C:/Program files/GDAL")
  gdal_translate <- paste0(gdal.dir, "/gdal_translate.exe")
  gdalwarp <- paste0(gdal.dir, "/gdalwarp.exe") 
} else {
  gdal_translate = "gdal_translate"
  gdalwarp = "gdalwarp"
}
system(paste(gdalwarp))
system(paste(gdalwarp, ' DEMSRT6.sdat DEMSRT6_ll.tif -t_srs \"+proj=longlat +datum=WGS84\"'))
plot(raster("DEMSRT6_ll.tif"))

## Add metadata to a GeoTiff:
data("eberg_grid")
gridded(eberg_grid) = ~ x+y
proj4string(eberg_grid) <- CRS("+init=epsg:31467")
 writeGDAL(eberg_grid["DEMSRT6"], "eberg_DEM.tif", options="COMPRESS=DEFLATE")
?eberg
system(paste0('gdal_edit.py -mo \"DESCRIPTION=elevation values from the SRTM DEM\" -mo \"DOWNLOAD_URL=http://geomorphometry.org/content/ebergotzen\" eberg_DEM.tif'))
system('gdalinfo eberg_DEM.tif')

## RQGIS (https://www.r-bloggers.com/rqgis-0-1-0-release/)
library(RQGIS)
env <- set_env()
find_algorithms("wetness index", name_only=TRUE, qgis_env=env)
args <- get_args_man(alg="saga:sagawetnessindex", options=TRUE, qgis_env=env)
args$DEM <- raster("DEMSRT6.sdat", layer=0)
## Output path:
args$TWI <- "twi.asc"
twi <- run_qgis(alg="saga:sagawetnessindex", params=args, load_output=args$TWI, qgis_env=env)
## visualize the result:
plotKML(twi, colour_scale=SAGA_pal[[1]])
