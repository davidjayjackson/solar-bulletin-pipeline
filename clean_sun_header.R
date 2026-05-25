library(tidyverse)
library(DBI)
library(RMySQL)      # swap for RMariaDB if using a MariaDB server
library(stringr)
library(knitr)
library(kableExtra)

DB_NAME <- Sys.getenv("SOLAR_DB",   "solar")
DB_HOST <- Sys.getenv("SOLAR_HOST", "localhost")
DB_USER <- Sys.getenv("SOLAR_USER", "root")
DB_PASS <- Sys.getenv("SOLAR_PASS", "dJj135790")

con <- dbConnect(
  RMySQL::MySQL(),
  dbname   = DB_NAME,
  host     = DB_HOST,
  user     = DB_USER,
  password = DB_PASS
)
# Grab sun_header table

sun_header <- tbl(con,"sun_header") |> collect()
observers <- sun_header |>
  select(Obs, name, updated,method) |>
  arrange(Obs, desc(updated)) |>
  slice_max(updated, by = Obs, n = 1, with_ties = FALSE)

dbWriteTable(con,"observers",observers,overwrite=TRUE)
dbListTables(con)