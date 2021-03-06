library(ggplot2)
library(reshape2)
library(lubridate)
library(scales)
library(plyr)
TODAY <- as.Date(Sys.time())

date.variables <- c('createdAt','publicationDate', 'rowsUpdatedAt', 'viewLastModified')
if (!('socrata.deduplicated' %in% ls())) {
  socrata.deduplicated <- read.csv('../socrata-deduplicated.csv')
  socrata.deduplicated <- subset(socrata.deduplicated, portal != 'opendata.socrata.com')

  .columns <- c('portal','id','publicationStage', 'publicationGroup', date.variables)
  s <- socrata.deduplicated[.columns]
  s$createdAt <- as.Date(as.POSIXct(s$createdAt, origin = '1970-01-01'))
  s$publicationDate <- as.Date(as.POSIXct(s$publicationDate, origin = '1970-01-01'))
  s$rowsUpdatedAt <- as.Date(as.POSIXct(s$rowsUpdatedAt, origin = '1970-01-01'))
  s$viewLastModified <- as.Date(as.POSIXct(s$viewLastModified, origin = '1970-01-01'))
  s$date <- s$createdAt
  s[is.na(s$date),'date'] <- s[is.na(s$createdAt),'publicationDate']
  s$publicationStage <- factor(s$publicationStage)
}

s$has.been.updated <- !is.na(s$rowsUpdatedAt) & s$publicationDate < s$rowsUpdatedAt

s.molten <- melt(s, measure.vars = c('rowsUpdatedAt','viewLastModified'), variable.name = 'update.type', value.name = 'update.date')
s.molten$update.date <- as.Date('1970-01-01') + lubridate::days(s.molten$update.date)
s.molten$days.since.update <- as.numeric(difftime(
  TODAY, s.molten$update.date, units = 'days'))
s.molten$update.type <- factor(s.molten$update.type,
  levels = c('rowsUpdatedAt', 'viewLastModified'))
levels(s.molten$update.type) <- c('rows','view')

p1 <- ggplot(s.molten) +
  aes(x = publicationDate, y = days.since.update, group = update.type,
    shape = update.type, color = publicationGroup) +
  facet_wrap(~ portal) + geom_point() +
  scale_x_date('Date of dataset publication') +
  scale_y_continuous('Days since the dataset has been updated') +
  scale_color_continuous('Publication group number', labels = comma) +
  ggtitle('How up-to-date are the datasets?')

"
s.molten$one.year <- difftime(s.molten$update.date, s.molten$publicationDate, units = 'weeks') > 52
p2 <- ggplot(s.molten) +
  aes(x = publicationDate, color = one.year,
    group = interaction(one.year, update.type),
    linetype = update.type) +
  geom_line(stat='bin')

s.daily <- ddply(s.molten, c('portal', 'update.date'), function(df) {
  df.subset <- subset(df, difftime(TODAY, df$publicationDate, units = 'weeks') > 52)
  c(prop.up.to.date = mean(df.subset$one.year))
})
s.daily$prop.up.to.date <- factor(s.daily$prop.up.to.date,
  levels = names(sort(s.daily$prop.up.to.date)))

p3 <- ggplot(s.daily) +
  aes(x = update.date, group = portal, y = prop.up.to.date) + geom_point()
"

s.window <- ddply(data.frame(weeks = 52:0), 'weeks', function(nweeks.df) {
  nweeks <- nweeks.df$weeks[1]

  ddply(s.molten, c('portal','update.type'), function(df.full) {
    df <- subset(df.full, difftime(TODAY, df.full$publicationDate, units = 'weeks') > nweeks)
    df$up.to.date <- difftime(TODAY, df$update.date, units = 'weeks') < nweeks
    df$up.to.date[is.na(df$up.to.date)] <- FALSE
    c(prop = sum(df$up.to.date) / nrow(df), count = nrow(df))
  })
})
p4 <- ggplot(s.window) + aes(x = weeks, y = prop, group = update.type, size = count) + geom_line() +
  ylab('Proportion datasets older than the cutoff that have been updated since the cutoff') +
  scale_size_continuous('Number of datasets in the portal') +
  ggtitle('How many old datasets have been updated recently, by portal?') +
  xlab('Cutoff (number of weeks before today)') + facet_wrap(~ portal)

# p6 <- ggplot(s.window[order(s.window$weeks, decreasing = TRUE),]) +
#   aes(x = count, y = prop, group = portal) + geom_path()

p6 <- ggplot(subset(s.window, weeks == 52)) +
  aes(x = count, y = prop, label = portal) + geom_text(alpha = 0.2) +
  xlab('Number of datasets on the portal') +
  ylab('Proportion of datasets older than a year that have been updated within the year') +
  facet_wrap(~ update.type)

p7 <- p6 + xlim(c(1,2000))
