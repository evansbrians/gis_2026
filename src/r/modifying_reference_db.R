# Modify the glossary and function definitions 

# setup -------------------------------------------------------------------

library(tidyverse)
library(DBI)
library(RSQLite)
library(dbplyr)

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    "src/reference/course_reference.sqlite"
  )

# explore -----------------------------------------------------------------

# Look up a term in the glossary:

tbl(con, "glossary") %>%
  filter(term == "R session") %>%
  collect()

tbl(con, "glossary") %>%
  filter(term == "Console pane") %>%
  collect()

# Look up a function definition:

tbl(con, "functions") %>%
  filter(function_name == "st_buffer") %>%
  collect()

# glossary updates --------------------------------------------------------

## update a term ----------------------------------------------------------

# R session:

r_session_updated <-
  tibble(
    term = "R session",
    definition = "A running R process and its current state."
  )

rows_update(
  tbl(con, "glossary"),
  r_session_updated,
  by = "term",
  in_place = TRUE,
  copy = "inline",
  unmatched = "ignore"
)

# Console pane:

console_pane_updated <-
  tibble(
    term = "Console pane",
    definition = "A pane of RStudio used for interactively running R commands and viewing their output."
  )

rows_update(
  tbl(con, "glossary"),
  console_pane_updated,
  by = "term",
  in_place = TRUE,
  copy = "inline",
  unmatched = "ignore"
)

## add a term -------------------------------------------------------------

environment_pane <-
  tibble(
    term = "Environment pane",
    definition = "A pane of RStudio used for viewing and managing objects in the current R session and reviewing previously executed commands."
  )

output_pane <-
  tibble(
    term = "Output pane",
    definition = "A pane of RStudio used for managing files and packages and viewing plots, help documentation, and web-based output."
  )

rows_insert(
  tbl(con, "glossary"),
  environment_pane,
  conflict = "ignore",
  in_place = TRUE,
  copy = "inline"
)

rows_insert(
  tbl(con, "glossary"),
  output_pane,
  conflict = "ignore",
  in_place = TRUE,
  copy = "inline"
)

tbl(con, "glossary") %>%
  filter(term == "Environment pane") %>%
  collect()

tbl(con, "glossary") %>%
  filter(term == "Output pane") %>%
  collect()

DBI::dbDisconnect(con)

