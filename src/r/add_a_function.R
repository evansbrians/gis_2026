library(tidyverse)
library(DBI)
library(RSQLite)
library(dbplyr)

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    "src/reference/course_reference.sqlite"
  )

scale_shape_manual <-
  tibble(
    package = "ggplot2",
    function_name = "scale_shape_manual",
    definition = "Manually define the shapes of a geometry"
  )

rows_insert(
  tbl(con, "functions"),
  scale_shape_manual,
  conflict = "ignore",
  in_place = TRUE,
  copy = "inline"
)

DBI::dbDisconnect(con)
