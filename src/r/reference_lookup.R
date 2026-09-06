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
# (each element is one chunk's full body, chunk options included). A chunk
# inside a list item is indented, so both fences may carry leading whitespace
# -- the pattern is anchored to a line start and allows it. Without that, the
# closing fence is missed and the match runs on to the next unindented one,
# pulling the prose in between (`:::` fences included) into the code text.

extract_code_chunk_list <-
  function(.lesson_text) {
    .lesson_text %>%
      str_match_all(
        "(?sm)^[ \\t]*```\\{(?:r|webr)[^\\n]*\\n(.*?)\\n[ \\t]*```"
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
        "(?sm)^[ \\t]*```\\{(?:r|webr)[^\\n]*\\n.*?\\n[ \\t]*```"
      )
  }

# A function_name is "named" (c, read_csv, mean) if it's a plain
# identifier; anything else (+, <-, %>%, [...]) is an operator.

is_named_function <-
  function(.function_name) {
    str_detect(.function_name, "^[a-zA-Z._][a-zA-Z0-9._]*$")
  }

# A lesson bolds a term in the form its sentence needs, which is often not
# the form the glossary stores: "**vertices**" against "Vertex",
# "**Shapefiles**" against "Shapefile", "**false easting**" against "False
# eastings". Matching on the literal string drops those terms from the
# accordion without any sign that it has happened, so both sides are reduced
# to a common form first, one word at a time.
#
# A gerund rule is deliberately absent. "Easting", "northing", "string",
# "grouping" and "mapping" are all nouns in this course, and a rule that
# strips "-ing" turns each of them into nonsense. The one gerund that has to
# match a glossary entry is carried by the glossary's own "X or Y"
# convention instead (see glossary_aliases() below).

irregular_singulars <-
  c(
    vertices = "vertex",
    indices  = "index",
    matrices = "matrix",
    analyses = "analysis",
    axes     = "axis",
    bases    = "basis"
  )

singularize_word <-
  function(.word) {
    lower <- str_to_lower(.word)

    unname(
      case_when(
        lower %in% names(irregular_singulars) ~ irregular_singulars[lower],
        str_detect(lower, "ies$") & str_length(lower) > 4 ~
          str_replace(lower, "ies$", "y"),
        str_detect(lower, "(ss|sh|ch|x|z)es$") ~ str_remove(lower, "es$"),
        str_detect(lower, "s$") &
          !str_detect(lower, "(ss|is|us)$") &
          str_length(lower) > 3 ~ str_remove(lower, "s$"),
        TRUE ~ lower
      )
    )
  }

normalize_term <-
  function(.text) {
    if (length(.text) == 0) return(character(0))

    .text %>%
      str_squish() %>%
      str_split(" ") %>%
      map_chr(\(.words) str_c(singularize_word(.words), collapse = " "))
  }

# A glossary term written as "X or Y" ("Line or Linestring", "Dissolve or
# Dissolving") records one definition under two names. Each name is matched
# on its own, so a lesson that bolds either one reaches the same entry.

glossary_aliases <-
  function(.terms) {
    tibble(term = .terms) %>%
      mutate(alias = str_split(term, " or ")) %>%
      unnest(alias) %>%
      mutate(alias = normalize_term(str_trim(alias)))
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

    # A call written as units::set_units() is extracted with its package
    # prefix, and the functions table stores the bare name, so the
    # namespaced form is kept alongside the name it resolves to. Without
    # this, a function that a lesson only ever calls with :: is absent from
    # the accordion.

    called_functions <-
      code_text %>%
      str_extract_all(
        "(?:[a-zA-Z0-9._]+::)?[a-zA-Z._][a-zA-Z0-9._]*(?=\\()"
      ) %>%
      unlist() %>%
      c(str_remove(., "^[a-zA-Z0-9._]+::")) %>%
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

    glossary_terms <-
      tbl(con, "glossary") %>%
      collect()

    matched_aliases <-
      glossary_aliases(glossary_terms$term) %>%
      filter(alias %in% normalize_term(bolded_terms))

    matched_terms <-
      glossary_terms %>%
      filter(term %in% matched_aliases$term)

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
    .button_label = "Glossary of terms",
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

# Every function/term used across a module's own lessons; .cumulative
# also rolls in every earlier module (the module-intro "through this
# module" view).

find_module_references <-
  function(.module_number, .cumulative = TRUE, .db_path = course_db_path) {
    con <- connect_course_db(.db_path)
    on.exit(DBI::dbDisconnect(con))

    functions_view <-
      if (.cumulative) {
        "module_functions_cumulative"
      } else {
        "module_functions"
      }

    glossary_view <-
      if (.cumulative) {
        "module_glossary_cumulative"
      } else {
        "module_glossary"
      }

    matched_functions <-
      tbl(con, functions_view) %>%
      filter(module_number == .module_number) %>%
      collect()

    matched_terms <-
      tbl(con, glossary_view) %>%
      filter(module_number == .module_number) %>%
      collect()

    list(
      functions = matched_functions,
      terms = matched_terms
    )
  }
