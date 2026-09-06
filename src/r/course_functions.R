# Functions used to build the HTML lesson pages themselves (as opposed to
# functions taught as course content -- see gis_functions.R for those).
# Sourced by every lesson via src/includes/_setup.qmd, which attaches
# tidyverse first, so tidyverse functions are called unqualified here.

# Render a lesson's "Functions" reference table from its own
# function_tables/*.csv (resolved against the rendering document rather than
# the project root, so it works under execute-dir: project):

render_function_table <-
  function(.csv_name, .align = c("c", "c", "l")) {
    Sys.getenv("QUARTO_DOCUMENT_PATH") %>%
      fs::path("function_tables", .csv_name) %>%
      read_csv() %>%
      kableExtra::kable(align = .align) %>%
      kableExtra::kable_styling(
        font_size = 12,
        bootstrap_options = "hover"
      )
  }

# Emit an interactive two-column matching game, paired by row order (.pairs
# needs `left` and `right` columns, or `mac`, `windows`, and `right` when
# .os_switch = TRUE). Call from a chunk with echo: false and results: asis.

matching_game <-
  function(.pairs,
           .id,
           .os_switch = FALSE) {

    # macOS modifier key-caps, as HTML entities so output stays plain ASCII:

    mac_symbols <-
      c(
        cmd = "&#8984;",
        command = "&#8984;",
        shift = "&#8679;",
        option = "&#8997;",
        opt = "&#8997;",
        alt = "&#8997;",
        ctrl = "&#8963;",
        control = "&#8963;"
      )

    # Wrap a "Cmd+Shift+N" string in <kbd> key-caps (.as_mac swaps modifier
    # names for their Mac symbols):

    kbd_tokens <-
      function(.combo, .as_mac = FALSE) {
        .keys <-
          .combo %>%
          str_split_1(fixed("+")) %>%
          str_trim()

        if (isTRUE(.as_mac)) {
          .keys <-
            mac_symbols[str_to_lower(.keys)] %>%
            coalesce(.keys) %>%
            unname()
        }

        str_c("<kbd>", .keys, "</kbd>", collapse = "")
      }

    # The pairs, ready for JSON:

    pair_list <-
      if (isTRUE(.os_switch)) {
        pmap(
          list(
            .pairs$mac,
            .pairs$windows,
            .pairs$right
          ),
          \(.mac, .win, .right) {
            list(
              left =
                list(
                  mac =
                    kbd_tokens(.mac, .as_mac = TRUE),
                  win = kbd_tokens(.win)
                ),
              right = .right
            )
          }
        )
      } else {
        map2(
          .pairs$left,
          .pairs$right,
          \(.left, .right) {
            list(
              left = .left,
              right = .right
            )
          }
        )
      }

    config_json <-
      list(
        id = .id,
        osSwitch = isTRUE(.os_switch),
        pairs = pair_list
      ) %>%
      jsonlite::toJSON(auto_unbox = TRUE)

    # Load matching_game.js once per rendered document -- the flag is keyed on
    # the document path, since knitr may share a session across documents:

    load_flag <-
      str_c(
        "matching_game_js_loaded_",
        Sys.getenv("QUARTO_DOCUMENT_PATH")
      )

    js_is_loaded <-
      load_flag %>%
      getOption() %>%
      isTRUE()

    if (!js_is_loaded) {
      cat('<script src="../../src/js/matching_game.js"></script>\n')

      list(TRUE) %>%
        set_names(load_flag) %>%
        options()
    }

    glue::glue(
      '
      <div class="matching-game" id="{.id}">
      <div class="matching-col matching-left" id="{.id}-left"></div>
      <div class="matching-col matching-right" id="{.id}-right"></div>
      <div style="clear: both;"></div>
      <button id="{.id}-check" class="parsons-btn parsons-btn-check"
        type="button">Check My Matches</button>
      <button id="{.id}-reset" class="parsons-btn parsons-btn-reset"
        type="button">Shuffle Again</button>
      <p id="{.id}-feedback" class="parsons-feedback"></p>
      </div>
      <script>
      window.matchingGames = window.matchingGames || [];
      window.matchingGames.push({config_json});
      </script>
      '
    ) %>%
      cat("\n", sep = "")
  }

# Emit a js-parsons drag-and-drop problem: .code holds the answer cards in
# order and .distractors the cards that do not belong. Call from a chunk with
# echo: false and results: asis.

parsons_problem <-
  function(.id,
           .code,
           .distractors = character(),
           .unordered = FALSE,
           .answer_noun = "items") {

    # Every card, escaped for HTML and packed into a JS string:

    code_json <-
      c(.code, str_c(.distractors, " #distractor")) %>%
      str_replace_all(fixed("&"), "&amp;") %>%
      str_replace_all(fixed("<"), "&lt;") %>%
      str_replace_all(fixed(">"), "&gt;") %>%
      str_c(collapse = "\n") %>%
      jsonlite::toJSON(auto_unbox = TRUE)

    # The registration fields, in the order parsons_init.js reads them:

    config_lines <-
      c(
        glue::glue('  id: "{.id}"'),
        if (isTRUE(.unordered)) {
          c(
            "  unordered: true",
            glue::glue('  answerNoun: "{.answer_noun}"')
          )
        },
        glue::glue("  maxDistractors: {length(.distractors)}"),
        glue::glue("  code: {code_json}")
      ) %>%
      str_c(collapse = ",\n")

    # The button label follows how the answer is graded:

    check_label <-
      if (isTRUE(.unordered)) "Check My Answer" else "Check My Order"

    glue::glue(
      '
      <div class="parsons-problem">
      <div id="{.id}-trash" class="sortable-code"></div>
      <div id="{.id}-sortable" class="sortable-code"></div>
      <div style="clear: both;"></div>
      <button id="{.id}-check" class="parsons-btn parsons-btn-check" type="button">{check_label}</button>
      <button id="{.id}-reset" class="parsons-btn parsons-btn-reset" type="button">Shuffle Again</button>
      <p id="{.id}-feedback" class="parsons-feedback"></p>
      </div>

      <script>
      window.parsonsProblems = window.parsonsProblems || [];
      window.parsonsProblems.push({{
      {config_lines}
      }});
      </script>
      '
    ) %>%
      cat("\n", sep = "")
  }

# dataset descriptions --------------------------------------------------------

# Course datasets live in the `datasets` and `dataset_usage` tables of the
# reference database, keyed by `dataset_name` -- a file name for a single-file
# dataset ("chickadees.csv"), or a base name for a multi-file one ("census").

# Path to the course reference database, relative to the project root.
# src/r/reference_lookup.R defines this same constant -- keep them in sync.

course_db_path <- "src/reference/course_reference.sqlite"

# Open a read-only connection to the course reference database:

connect_dataset_db <-
  function(.db_path = course_db_path) {
    DBI::dbConnect(
      RSQLite::SQLite(),
      .db_path,
      flags = RSQLite::SQLITE_RO
    )
  }

# Look up course dataset descriptions by name, returned in .dataset order and
# named by dataset. An unrecognized name is an error rather than a silent NA,
# so a typo gets caught while the lesson renders.

get_dataset_description <-
  function(.dataset,
           .db_path = course_db_path) {

    con <- connect_dataset_db(.db_path)

    on.exit(DBI::dbDisconnect(con))

    described <-
      tbl(con, "datasets") %>%

      # Let the database do the subsetting:

      filter(dataset_name %in% !!.dataset) %>%
      collect()

    unmatched <- setdiff(.dataset, described$dataset_name)

    if (length(unmatched) > 0) {
      cli::cli_abort(
        "No dataset named {.val {unmatched}} in {.file {(.db_path)}}."
      )
    }

    tibble(dataset_name = .dataset) %>%
      left_join(described, by = "dataset_name") %>%
      pull(description, name = dataset_name)
  }

# Render a module's "About this week's data" entries as markdown -- one bolded,
# alphabetized entry per dataset, separated by blank lines. Supply .module,
# .dataset, or both; call from a chunk with echo: false and output: asis.

dataset_markdown <-
  function(.dataset = NULL,
           .module = NULL,
           .db_path = course_db_path) {

    if (is.null(.dataset) && is.null(.module)) {
      cli::cli_abort("Supply {.arg .dataset}, {.arg .module}, or both.")
    }

    con <- connect_dataset_db(.db_path)

    on.exit(DBI::dbDisconnect(con))

    # A module's own file list and note, or the shared defaults:

    entries <-
      if (is.null(.module)) {
        tbl(con, "datasets") %>%
          collect() %>%
          mutate(note = NA_character_)
      } else {
        tbl(con, "module_datasets") %>%
          filter(module_number == !!.module) %>%
          collect()
      }

    if (!is.null(.dataset)) {
      unmatched <- setdiff(.dataset, entries$dataset_name)

      if (length(unmatched) > 0) {
        cli::cli_abort(
          "No dataset named {.val {unmatched}} in {.file {(.db_path)}}."
        )
      }

      entries <-
        entries %>%
        filter(dataset_name %in% .dataset)
    }

    if (nrow(entries) == 0) {
      cli::cli_abort(
        "No datasets are recorded for module {.val {(.module)}}."
      )
    }

    entries %>%
      mutate(
        file_list =
          coalesce(files, dataset_name) %>%
          str_split(fixed(", ")) %>%
          map_chr(
            \(.files) {
              str_c("[", .files, "]{.mono}", collapse = ", ")
            }
          ),
        label =
          case_when(
            !is.na(display_name) ~
              str_c("**", display_name, "** (", file_list, ")"),
            !is.na(files) ~
              str_c("**[", dataset_name, "]{.mono}** (", file_list, ")"),
            .default =
              str_c("**[", dataset_name, "]{.mono}**")
          ),
        note = str_c(" ", note),
        note = replace_na(note, ""),
        entry = str_c(label, ": ", description, note)
      ) %>%
      arrange(
        coalesce(display_name, dataset_name) %>%
          str_to_lower()
      ) %>%
      pull(entry) %>%
      str_c(collapse = "\n\n")
  }

# lesson metadata -------------------------------------------------------------

# A lesson's "Data for this lesson" section is generated from the reference
# database rather than written by hand, so a variable is described in exactly
# one place. `datasets` holds the description of each file, `dataset_tables`
# the list items inside a list file, and `dataset_variables` every documented
# column. `dataset_aliases` lets a lesson name a single file ("iris.rds") that
# the database stores as part of a larger dataset ("iris").

# Resolve the names a lesson uses into dataset rows, keeping the caller's
# spelling for display. An unrecognized name is an error rather than a silent
# omission, so a typo gets caught while the lesson renders.

resolve_datasets <-
  function(.dataset,
           .db_path = course_db_path) {

    con <- connect_dataset_db(.db_path)

    on.exit(DBI::dbDisconnect(con))

    aliases <-
      tbl(con, "dataset_aliases") %>%
      collect()

    named <-
      tibble(requested = .dataset) %>%
      left_join(aliases, by = join_by(requested == alias))

    resolved <-
      tbl(con, "datasets") %>%
      collect() %>%
      inner_join(
        named,
        by = "dataset_id",
        suffix = c("", "_alias")
      )

    by_name <-
      tbl(con, "datasets") %>%
      collect() %>%
      filter(dataset_name %in% !!.dataset) %>%
      mutate(
        requested = dataset_name,
        files_alias = NA_character_
      )

    found <-
      bind_rows(resolved, by_name) %>%
      distinct(requested, .keep_all = TRUE) %>%
      mutate(files = coalesce(files_alias, files))

    unmatched <- setdiff(.dataset, found$requested)

    if (length(unmatched) > 0) {
      cli::cli_abort(
        "No dataset named {.val {unmatched}} in {.file {(.db_path)}}."
      )
    }

    tibble(requested = .dataset) %>%
      left_join(found, by = "requested")
  }

# Pick the entries a lesson asked for out of a per-dataset selection. `.spec`
# is either a bare vector (one dataset in play) or a list named by dataset.

lesson_selection <-
  function(.spec,
           .dataset) {

    if (is.null(.spec)) {
      return(NULL)
    }

    if (!is.list(.spec)) {
      if (length(.dataset) > 1) {
        cli::cli_abort(
          "Name the dataset each selection belongs to when {.arg .dataset} has more than one entry."
        )
      }

      .spec <- set_names(list(.spec), .dataset)
    }

    unmatched <- setdiff(names(.spec), .dataset)

    if (length(unmatched) > 0) {
      cli::cli_abort(
        "{.val {unmatched}} {?is/are} not in {.arg .dataset}."
      )
    }

    .spec
  }

# Render one bulleted variable entry per row:

variable_bullets <-
  function(.variables) {

    .variables %>%
      mutate(
        bullet =
          str_c("* [", variable, "]{.mono}, ", type, ": ", description)
      ) %>%
      pull(bullet) %>%
      str_flatten("\n")
  }

# Render a lesson's "Data for this lesson" entries as markdown. Supply the file
# names the lesson uses; add .tables or .variables to describe only part of a
# dataset. Call from a chunk with echo: false and output: asis.

lesson_metadata <-
  function(.dataset,
           .tables = NULL,
           .variables = NULL,
           .db_path = course_db_path) {

    con <- connect_dataset_db(.db_path)

    on.exit(DBI::dbDisconnect(con))

    datasets <- resolve_datasets(.dataset, .db_path)

    table_spec <- lesson_selection(.tables, .dataset)

    variable_spec <- lesson_selection(.variables, .dataset)

    all_tables <-
      tbl(con, "dataset_tables") %>%
      collect()

    all_variables <-
      tbl(con, "dataset_variables") %>%
      collect()

    entries <-
      map_chr(
        seq_len(nrow(datasets)),
        \(.row) {
          this <- datasets[.row, ]

          file_list <-
            coalesce(this$files, this$requested) %>%
            str_split_1(fixed(", ")) %>%
            str_c("[", ., "]{.mono}", collapse = ", ")

          label <-
            if (str_detect(coalesce(this$files, ""), fixed(", "))) {
              str_c("**[", this$requested, "]{.mono}** (", file_list, ")")
            } else {
              str_c("**", file_list, "**")
            }

          tables <-
            all_tables %>%
            filter(dataset_id == this$dataset_id) %>%
            arrange(sort_order)

          keep_tables <- table_spec[[this$requested]]

          if (!is.null(keep_tables)) {
            missing_tables <- setdiff(keep_tables, tables$table_name)

            if (length(missing_tables) > 0) {
              cli::cli_abort(
                "{.val {missing_tables}} {?is/are} not a list item of {.val {(this$requested)}}."
              )
            }

            tables <-
              tables %>%
              filter(table_name %in% keep_tables) %>%
              arrange(match(table_name, keep_tables))
          }

          variables <-
            all_variables %>%
            filter(dataset_id == this$dataset_id) %>%
            arrange(sort_order)

          keep_variables <- variable_spec[[this$requested]]

          if (!is.null(keep_variables)) {
            missing_variables <- setdiff(keep_variables, variables$variable)

            if (length(missing_variables) > 0) {
              cli::cli_abort(
                "{.val {missing_variables}} {?is/are} not a variable of {.val {(this$requested)}}."
              )
            }

            variables <-
              variables %>%
              filter(variable %in% keep_variables) %>%
              arrange(match(variable, keep_variables))
          }

          # A list item's own header already introduces its bullets, so only a
          # knowingly partial list needs a sentence saying so.

          field_lead <-
            function(.partial, .word) {
              if (!.partial && is.null(keep_variables)) {
                return(NULL)
              }

              str_c("Relevant ", .word, " include:")
            }

          flat <-
            variables %>%
            filter(is.na(table_name))

          body <-
            if (nrow(tables) > 0) {
              map_chr(
                tables$table_name,
                \(.table) {
                  rows <-
                    variables %>%
                    filter(table_name == .table)

                  detail <-
                    tables %>%
                    filter(table_name == .table)

                  header <- str_c("[", .table, "]{.mono}")

                  if (!is.na(detail$description)) {
                    header <- str_c(header, ": ", detail$description)
                  }

                  if (nrow(rows) == 0) {
                    return(header)
                  }

                  c(
                    header,
                    field_lead(as.logical(detail$partial_fields), "fields"),
                    variable_bullets(rows)
                  ) %>%
                    str_flatten("\n\n")
                }
              ) %>%
                str_flatten("\n\n")
            } else if (nrow(flat) > 0) {
              full_lead <-
                str_c("The data include the following ", this$field_word, ":")

              c(
                field_lead(as.logical(this$partial_fields), this$field_word) %||% full_lead,
                variable_bullets(flat)
              ) %>%
                str_flatten("\n\n")
            } else {
              NULL
            }

          c(str_c(label, ": ", this$metadata_description), body) %>%
            str_flatten("\n\n")
        }
      )

    str_flatten(entries, "\n\n")
  }
