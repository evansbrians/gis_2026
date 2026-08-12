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

# Split a lesson's raw .qmd text into its individual R/webr code chunks
# (each element is one chunk's full body, chunk options included).

extract_code_chunk_list <-
  function(.lesson_text) {
    .lesson_text %>%
      str_match_all(
        "(?s)```\\{(?:r|webr)[^\\n]*\\n(.*?)\\n```"
      ) %>%
      pluck(1) %>%
      as_tibble(.name_repair = "unique") %>%
      pull(2)
  }

# A chunk is "hidden" -- not meant to be taught or shown to students,
# e.g. a game's supporting/answer-key code, or backend housekeeping like
# unloadNamespace() -- if its code isn't echoed (echo: false) and/or its
# code and output are both suppressed (include: false), via Quarto's #|
# chunk-option syntax. Either option on its own is enough: if the code
# isn't shown, students never see the function call syntax at that spot,
# so it shouldn't count as "used" in the lesson -- regardless of whether
# the chunk's *output* (e.g. a rendered game) is still shown via
# results: asis. Its functions/operators shouldn't count as "used".

chunk_is_hidden <-
  function(.chunk_text) {
    has_echo_false <-
      str_detect(.chunk_text, "(?m)^[ \t]*#\\|[ \t]*echo:[ \t]*false[ \t]*$")

    has_include_false <-
      str_detect(.chunk_text, "(?m)^[ \t]*#\\|[ \t]*include:[ \t]*false[ \t]*$")

    has_echo_false | has_include_false
  }

# Concatenate the body text of every VISIBLE R/webr code chunk in a
# lesson's raw .qmd text -- used to search code without matching prose,
# and without matching hidden (echo: false + include: false) chunks.

extract_code_chunks <-
  function(.lesson_text) {
    chunks <- extract_code_chunk_list(.lesson_text)

    chunks[!chunk_is_hidden(chunks)] %>%
      str_c(collapse = "\n")
  }

# Strip full-line comments from extracted code text -- this includes
# plain R comments as well as Quarto/knitr chunk-option lines (e.g.
# "#| eval: false"). Neither is executed code, so punctuation inside
# them (":", "|", etc.) shouldn't be picked up as a "used" operator or
# a comment-only mention of a function name as a "called" function.

strip_comment_lines <-
  function(.code_text) {
    str_remove_all(.code_text, "(?m)^[ \t]*#.*$")
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
#
# Deliberately does NOT resolve the current file via
# Sys.getenv("QUARTO_DOCUMENT_PATH") -- during a real render that points
# at Quarto's internal staging copy of the document (the fully
# include-expanded version, with _setup.qmd's and _reference_section.qmd's
# own code chunks spliced in), not the lesson's own clean source file,
# which pollutes the scan with code that doesn't belong to the lesson.
#
# Also deliberately does NOT strip knitr::current_input()'s extension
# with a regex to get a slug for an exact match -- in practice that
# didn't reliably come back matchable (observed mismatch against the
# stored slug in a real render). Matching by prefix against the lessons
# table instead is robust to whatever knitr actually hands back.

find_lesson_references <-
  function(.lesson_path = NULL, .db_path = course_db_path) {
    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    if (is.null(.lesson_path)) {
      input_file <- knitr::current_input()

      if (is.null(input_file)) {
        stop("Not rendering inside Quarto -- pass .lesson_path explicitly.")
      }

      input_file <- str_trim(input_file)

      matched_lesson <-
        tbl(con, "lessons") %>%
        collect() %>%
        filter(str_starts(input_file, fixed(slug))) %>%
        arrange(desc(str_length(slug))) %>%
        slice(1)

      if (nrow(matched_lesson) == 0) {
        stop(
          glue::glue(
            "No lesson found in course_reference.sqlite matching current file '{input_file}'."
          )
        )
      }

      .lesson_path <- matched_lesson$file_path
    }

    lesson_text <- read_file(.lesson_path)

    code_text <-
      extract_code_chunks(lesson_text) %>%
      strip_comment_lines()

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
