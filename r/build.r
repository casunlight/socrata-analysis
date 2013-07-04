library(ggplot2)
library(plyr)
library(knitr)
library(scales)
library(reshape2)

if (!('socrata' %in% ls())) {
  socrata <- read.csv('../socrata.csv', stringsAsFactors = F)
  socrata$createdAt <- as.Date(as.POSIXct(socrata$createdAt, origin = '1970-01-01'))
}
for (Rmd in grep('[.]Rmd$', list.files(), value = T)){
  md <- sub('Rmd$', 'md', Rmd)
  knit(Rmd, md)
  break
}
