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

# Concatenate body text of R/webr chunks in a lesson's raw .qmd text,
# skipping `include = FALSE` setup/infrastructure chunks.

extract_code_chunks <-
  function(.lesson_text) {
    chunk_matches <-
      .lesson_text %>%
      str_match_all(
        "(?s)```\\{(?:r|webr)([^\\n]*)\\n(.*?)\\n```"
      ) %>%
      pluck(1)

    is_setup_chunk <- str_detect(chunk_matches[ , 2], "include\\s*=\\s*FALSE")

    chunk_matches[!is_setup_chunk, 3] %>%
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

# A function_name is "named" (c, read_csv, mean) if it's a plain
# identifier; anything else (+, <-, %>%, [...]) is an operator.

is_named_function <-
  function(.function_name) {
    str_detect(.function_name, "^[a-zA-Z._][a-zA-Z0-9._]*$")
  }

# Bracket-style operator entries stand in for a symbol that can't be
# searched for literally -- map each to the token to search for instead.

operator_detection_token <-
  function(.function_name) {
    case_when(
      .function_name == "(...)" ~ "(",
      .function_name == "[...]" ~ "[",
      .function_name == "[[...]]" ~ "[[",
      .function_name == "{...}" ~ "{",
      TRUE ~ .function_name
    )
  }

# Find which operator rows literally appear in code_text, longest
# token first and masked out as found, to avoid double-counting.

detect_operators <-
  function(code_text, operators) {
    ordered_operators <-
      operators %>%
      mutate(detection_token = operator_detection_token(function_name)) %>%
      arrange(desc(str_length(detection_token)))

    masked_text <- code_text
    found <- logical(nrow(ordered_operators))

    for (i in seq_len(nrow(ordered_operators))) {
      token <- ordered_operators$detection_token[i]

      if (str_detect(masked_text, fixed(token))) {
        found[i] <- TRUE
        masked_text <-
          str_replace_all(masked_text, fixed(token), str_dup(" ", str_length(token)))
      }
    }

    ordered_operators[found, ] %>%
      select(-detection_token)
  }

# Match a lesson's called functions/operators and bolded terms against
# the functions/glossary tables; unmatched candidates are dropped.

find_lesson_references <-
  function(.lesson_path, .db_path = course_db_path) {
    # Drop the "## Reference" section itself -- its generated
    # accordions shouldn't feed back into the search.

    split_text <-
      read_file(.lesson_path) %>%
      str_split_fixed("\\n## Reference", n = 2)

    lesson_text <- split_text[1, 1]

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

    all_functions <-
      tbl(con, "functions") %>%
      collect()

    named_matches <-
      all_functions %>%
      filter(is_named_function(function_name)) %>%
      filter(function_name %in% called_functions)

    operator_matches <-
      all_functions %>%
      filter(!is_named_function(function_name)) %>%
      detect_operators(code_text, operators = .)

    matched_terms <-
      tbl(con, "glossary") %>%
      collect() %>%
      filter(str_to_lower(term) %in% str_to_lower(bolded_terms))

    list(
      functions = bind_rows(named_matches, operator_matches),
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
