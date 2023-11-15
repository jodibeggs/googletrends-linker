#  this script automates the pulling and construction of daily Google Trends data
#  inputs are the parameters set below (in "parameters to set")
#  outputs (in subdirectory with the search term as its name) are a csv and an R data frame with dates and daily Google Trends scores

#  note: this breaks down if there are repeated zeroes in parts of the data (warning is given)
#  the API also gives an error if it doesn't like how many pulls are made
#  data isn't consistent across downloads due to sampling, which is annoying
#  the reason that this script is needed is twofold:
#  1. the trends interface switches to weekly reporting if series is too long
#  2. indexing to 100 within a data pull can compress variation (since no decimal places)

rm(list=ls())

#  parameters to set:
datadirectory = ""
searchterm = ""
seriesdates = c("2022-10-01", "2023-04-20")  #  should be in YYYY-MM-DD
region = "US"  #  this needs to be consistent with the gtrendsR documentation

#  note that packages need to be installed
library(lubridate)
library(dplyr)
library(gtrendsR)
#  documentation for gtrendsR located at https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf
library(beepr)

print("Constructing Google Trends Data...")

#  other parameters:
#  this is the number of days (technically minus 1) in each data pull
sampledays = 30

setwd(datadirectory)
if (!file.exists(searchterm))
{
  dir.create(searchterm)
}
setwd(paste(datadirectory, "/", searchterm, sep=""))
seriesdates = as.Date(seriesdates)
trendscores = data.frame()

print(paste("Importing ", searchterm, " trend data...", sep=""))

currentdates = c(seriesdates[1], min(seriesdates[1] + sampledays, seriesdates[2]))
zerocount = 0
#  iterate through in chunks of sampledays + 1
while ((currentdates[1] < currentdates[2]) & (zerocount < 100))
{
  #  pull current google trends data object
  current = gtrends(
    keyword = searchterm,
    geo = region,
    time = paste(currentdates[1], " ", currentdates[2], sep=""),
    gprop = "web",
    category = 0,
    hl = "en-US",
    low_search_volume = FALSE,
    cookie_url = "http://trends.google.com/Cookies/NID",
    tz = 0,
    onlyInterest = TRUE
  )
  current = current[[1]]
  #  only add and move forward in time if there are no zeroes in endpoints
  if ((current$hits[1] != 0) & (current$hits[dim(current)[1]] != 0))
  {
    current$source = current$date[1]
    trendscores = rbind(trendscores, current)
    currentdates = c(currentdates[2], min(currentdates[2] + sampledays, seriesdates[2]))
  } else
  {
    zerocount = zerocount + 1
  }
}
#  provide a way to get out of a bad data quality situation rather than loop forever
#  could also adjust dates to avoid this issue
if (zerocount >= 100)
{
  print("Data might have issues due to zero scores...")
}
rm(zerocount)
rm(current)
rm(currentdates)
#  sort by date but make sure that, when data samples overlap, point from earlier source is first
#  this should have already been the case but doesn't hurt to make sure
trendscores = trendscores[order(trendscores$date, trendscores$source), ]

#  check for zeroes since they indicate poor data quality
test = trendscores[trendscores$hits==0, ]
print(paste("(there are ", dim(test)[1], " zeroes in the data)", sep=""))
rm(test)

trendscores$overlap = NA
trendscores$yesterday = lag(trendscores$date, 1)
trendscores$yesterdayscore = lag(trendscores$hits, 1)
#  note: these don't work as expected unless dplyr is loaded
#  put in overlap info where files intersect
replace = !is.na(trendscores$yesterday) & (trendscores$date==trendscores$yesterday)
trendscores$overlap[replace] = trendscores$yesterdayscore[replace]
rm(replace)

#  remove repeated dates
trendscores$overlaplead = lead(trendscores$overlap, 1)
trendscores = trendscores[is.na(trendscores$overlaplead), ]
#  note that overlap is the score from the earlier file

#  make helper file to deal with zero scores
helperdata = trendscores[trendscores$hits != 0, ]
helperdata$scorelag = lag(helperdata$hits, 1)
helperdata$pctchg = (helperdata$hits - helperdata$scorelag) / helperdata$scorelag
temp = helperdata[!is.na(helperdata$overlap), ]
temp$pctchg = (temp$overlap - temp$scorelag) / temp$scorelag
helperdata$pctchg[!is.na(helperdata$overlap)] = as.vector(temp$pctchg)
rm(temp)

#  make adjusted scores
temp = c(trendscores$hits[1])
for (i in 2:dim(helperdata)[1])
{
  temp = c(temp, temp[i-1] * (1 + helperdata$pctchg[i]))
}
rm(i)
helperdata$adjscore = temp
rm(temp)
helperdata = helperdata[ , c("date", "adjscore")]
trendscores = merge(trendscores, helperdata, by = c("date"), all.x=TRUE, all.y=FALSE, sort=TRUE)
trendscores$adjscore[trendscores$hits == 0] = 0
rm(helperdata)

trendscores = trendscores[, c("date", "adjscore")]
colnames(trendscores) = c("Date", "TrendScore")

print("Saving file...")

#  write data files so they can be used later
#  note that this will overwrite existing file for the same date range
outputfile = paste(searchterm, " ", seriesdates[1], "-", seriesdates[2], ".csv", sep = "")
write.table(trendscores, file = outputfile, append = FALSE, quote = FALSE, sep = ",",
            eol = "\n", na = "", dec = ".", row.names = FALSE,
            col.names = TRUE,
            fileEncoding = "")
rm(outputfile)
#  save R object as well
#  note that this will overwrite existing object for the same date range
savelist = c("trendscores")
outputfile = paste(searchterm, " ", seriesdates[1], "-", seriesdates[2], ".Rdata", sep = "")
save(list = savelist, file = outputfile)
rm(savelist)
rm(outputfile)

#  rm(trendscores)

beep()
