# googletrends-linker
provides a tool for extracting daily google Trends data by retrieving short time windows of data and linking them together

This script automates the pulling and construction of daily Google Trends data. Its inputs are a search term, start and end dates, and a region.  The outputs (in a subdirectory with the search term as its name) are a csv and an R data frame with dates and daily Google Trends scores.

The reason that this script is needed is twofold:
1. the trends interface switches to weekly reporting if series is too long
2. indexing to 100 within a data pull can compress variation (since no decimal places)

#  Notes:
* this breaks down if there are repeated zeroes in parts of the data (warning is given)
* the API also gives an error if it doesn't like how many pulls are made
* data isn't consistent across downloads due to sampling, which is annoying
