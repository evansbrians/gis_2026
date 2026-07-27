# Search lesson content and build the Glossary/Functions accordion HTML
# for a lesson, sourced from course_reference.sqlite.

# Source via source("src/r/reference_lookup.R"). Requires RSQLite
# (install.packages("RSQLite") if missing).

library(tidyverse)
library(DBI)
library(RSQLite)
library(dbplyr)

# Path to the course reference database, relative to the project root.

course_db_path <- "src/reference/course_reference.sqlite"

# Open a read-only connection to the course reference database.

connect_course_db <-
  function(.db_path = course_db_path) {
    DBI::dbConnect(
      RSQLite::SQLite(),
      .db_path,
      flags = RSQLite::SQLITE_RO
    )
  }

# Concatenate the body text of every R/webr code chunk in a lesson's raw
# .qmd text -- used to search code without matching prose.

extract_code_chunks <-
  function(.lesson_text) {
    .lesson_text %>%
      str_match_all(
        "(?s)```\\{(?:r|webr)[^\\n]*\\n(.*?)\\n```"
      ) %>%
      pluck(1) %>%
      as_tibble(.name_repair = "unique") %>%
      pull(2) %>%
      str_c(collapse = "\n")
  }

# Strip R/webr code chunks from a lesson's raw .qmd text, leaving only
# the prose -- avoids matching bolded text inside code comments.

remove_code_chunks <-
  function(.lesson_text) {
    .lesson_text %>%
      str_remove_all(
        "(?s)```\\{(?:r|webr)[^\\n]*\\n.*?\\n```"
      )
  }

# Resolve the currently-rendering lesson's own path via Quarto/knitr;
# NULL outside of a render (pass .lesson_path explicitly instead).

detect_lesson_path <-
  function() {
    document_dir <- Sys.getenv("QUARTO_DOCUMENT_PATH", unset = NA)
    input_file <- knitr::current_input()

    if (is.na(document_dir) || is.null(input_file)) {
      return(NULL)
    }

    file.path(document_dir, input_file)
  }

# Match a lesson's called functions and bolded terms against the
# functions/glossary tables; unmatched candidates are dropped.

find_lesson_references <-
  function(.lesson_path = NULL, .db_path = course_db_path) {
    if (is.null(.lesson_path)) {
      .lesson_path <- detect_lesson_path()
    }

    if (is.null(.lesson_path)) {
      stop("Not rendering inside Quarto -- pass .lesson_path explicitly.")
    }

    lesson_text <- read_file(.lesson_path)

    code_text <- extract_code_chunks(lesson_text)
    prose_text <- remove_code_chunks(lesson_text)

    called_functions <-
      code_text %>%
      str_extract_all(
        "(?:[a-zA-Z0-9._]+::)?[a-zA-Z._][a-zA-Z0-9._]*(?=\\()"
      ) %>%
      unlist() %>%
      unique()

    bolded_terms <-
      prose_text %>%
      str_extract_all("(?<=\\*\\*)[^*]+(?=\\*\\*)") %>%
      unlist() %>%
      str_remove(" ?\\([^)]*\\)$") %>%
      str_trim() %>%
      unique()

    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    matched_functions <-
      tbl(con, "functions") %>%
      collect() %>%
      filter(function_name %in% called_functions)

    matched_terms <-
      tbl(con, "glossary") %>%
      collect() %>%
      filter(str_to_lower(term) %in% str_to_lower(bolded_terms))

    list(
      functions = matched_functions,
      terms = matched_terms
    )
  }

# Resolve .terms (a character vector or already-resolved tibble) to
# glossary rows, case-insensitive lookup by term name.

resolve_glossary_terms <-
  function(.terms, .db_path = course_db_path) {
    if (is.data.frame(.terms)) {
      return(.terms)
    }

    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    tbl(con, "glossary") %>%
      collect() %>%
      filter(str_to_lower(term) %in% str_to_lower(.terms))
  }

# Resolve .functions (a character vector or already-resolved tibble) to
# function rows, matched by function_name.

resolve_functions <-
  function(.functions, .db_path = course_db_path) {
    if (is.data.frame(.functions)) {
      return(.functions)
    }

    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    tbl(con, "functions") %>%
      collect() %>%
      filter(function_name %in% .functions)
  }

# Find the first lesson (by module, then lesson) each function_id is
# used in -- powers the cumulative table's "First lesson used" column.

first_lesson_used <-
  function(.function_ids, .db_path = course_db_path) {
    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    tbl(con, "function_usage") %>%
      filter(function_id %in% .function_ids) %>%
      left_join(
        tbl(con, "lessons"),
        by = "lesson_id"
      ) %>%
      collect() %>%
      arrange(module_number, lesson_id) %>%
      summarize(
        first_lesson_used = first(slug),
        .by = function_id
      )
  }

# Build the Glossary accordion block (button + panel, alphabetized
# bullets) matching the course's existing glossary panel format.

glossary_panel_html <-
  function(
    .terms,
    .button_label = "Glossary of terms (I am a button ... click me!)",
    .db_path = course_db_path
  ) {
    term_defs <- resolve_glossary_terms(.terms, .db_path)

    bullets <-
      term_defs %>%
      arrange(str_to_lower(term)) %>%
      mutate(bullet = glue::glue("-   **{term}**: {definition}")) %>%
      pull(bullet) %>%
      str_c(collapse = "\n")

    glue::glue(
      "<button class=\"accordion\">{.button_label}</button>",
      "",
      "::: panel",
      "",
      bullets,
      "",
      ":::",
      .sep = "\n"
    )
  }

# Build the Functions kable matching render_function_table()'s style;
# .cumulative = TRUE adds a "First lesson used" column.

function_table_kable <-
  function(
    .functions,
    .cumulative = FALSE,
    .db_path = course_db_path
  ) {
    function_defs <- resolve_functions(.functions, .db_path)

    if (.cumulative) {
      function_defs <-
        function_defs %>%
        left_join(
          first_lesson_used(function_defs$function_id, .db_path),
          by = "function_id"
        )

      display_table <-
        function_defs %>%
        arrange(package, function_name) %>%
        select(
          Package = package,
          Function = function_name,
          `First lesson used` = first_lesson_used,
          Definition = definition
        )

      table_align <- c("c", "c", "l", "l")
    } else {
      display_table <-
        function_defs %>%
        arrange(package, function_name) %>%
        select(
          Package = package,
          Function = function_name,
          Definition = definition
        )

      table_align <- c("c", "c", "l")
    }

    display_table %>%
      kableExtra::kable(align = table_align) %>%
      kableExtra::kable_styling(
        font_size = 12,
        bootstrap_options = "hover"
      )
  }
