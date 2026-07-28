# Functions used to build the HTML lesson pages themselves (as opposed to
# functions taught as course content -- see gis_functions.R for those).
# Sourced by every lesson .qmd via:
#   source("src/r/course_functions.R")

# Render a lesson's "Functions" reference table from its per-lesson
# function_tables/*.csv file. Used inside the Reference > Functions
# accordion of every lesson.
#
# function_tables/ stays local to each module (it is not part of the
# shared top-level data/scripts consolidation), so this resolves the path
# against the currently-rendering document's own directory via Quarto's
# QUARTO_DOCUMENT_PATH environment variable rather than the R session's
# working directory (which is the project root under execute-dir: project).

render_function_table <-
  function(.csv_name, .align = c("c", "c", "l")) {
    file.path(
      Sys.getenv("QUARTO_DOCUMENT_PATH"),
      "function_tables",
      .csv_name) |>
      read_csv() |>
      kableExtra::kable(align = .align) |>
      kableExtra::kable_styling(
        font_size = 12,
        bootstrap_options = "hover"
      )
  }

# Build an interactive two-column "matching game" exercise (behaviour in
# src/js/matching_game.js; styling in the .matching-* rules of
# src/css/custom_style.scss).
#
# Call it from a single chunk with `#| echo: false` and `#| results: asis`. It
# emits only the game widget -- the two columns, the Check/Shuffle buttons, and
# the registration <script> -- and loads matching_game.js once per rendered
# document. It deliberately does NOT emit a prompt or a now_you box: write the
# question text yourself (e.g. as a numbered list item in a now_you block) and
# put this chunk directly beneath it, so the game numbers in with the other
# questions.
#
# Arguments:
#   .pairs     A data frame of the pairings. Two shapes are accepted:
#              * Plain:     columns `left` and `right` (HTML allowed in either).
#              * OS switch: set .os_switch = TRUE and supply columns `mac`,
#                           `windows`, and `right`. Each shortcut string is
#                           split on "+" and each key wrapped in <kbd>, and a
#                           macOS / Windows-Linux toggle is shown above the game.
#   .id        Unique element id (also used to derive the child element ids).
#   .os_switch Whether to render the operating-system toggle (default FALSE).
#
# Correct pairing is by row order: the first `right` is the answer to the first
# left item, and so on. The right column is shuffled for the student on load.
matching_game <-
  function(.pairs,
           .id,
           .os_switch = FALSE) {

    # macOS modifier names -> their key-cap symbols, written as HTML entities so
    # the output stays plain ASCII and is not sensitive to the render locale.
    .mac_symbol <-
      function(.key) {
        .symbols <-
          c(cmd = "&#8984;", command = "&#8984;",
            shift = "&#8679;",
            option = "&#8997;", opt = "&#8997;", alt = "&#8997;",
            ctrl = "&#8963;", control = "&#8963;")
        .hit <- .symbols[stringr::str_to_lower(.key)]
        if (is.na(.hit)) .key else unname(.hit)
      }

    # Wrap a "Cmd+Shift+N" style string in <kbd> key-caps. For the macOS column
    # (.as_mac = TRUE), modifier names are shown as their Mac symbols.
    kbd_tokens <-
      function(.combo, .as_mac = FALSE) {
        .keys <-
          .combo |>
          stringr::str_split_1(stringr::fixed("+")) |>
          stringr::str_trim()
        if (isTRUE(.as_mac)) {
          .keys <- purrr::map_chr(.keys, .mac_symbol)
        }
        stringr::str_c("<kbd>", .keys, "</kbd>", collapse = "")
      }

    # Assemble the list of pairs for JSON serialisation
    if (isTRUE(.os_switch)) {
      pair_list <-
        purrr::pmap(
          list(.pairs$mac, .pairs$windows, .pairs$right),
          function(.mac, .win, .right) {
            list(
              left = list(
                mac = kbd_tokens(.mac, .as_mac = TRUE),
                win = kbd_tokens(.win)
              ),
              right = .right
            )
          }
        )
    } else {
      pair_list <-
        purrr::map2(
          .pairs$left,
          .pairs$right,
          function(.left, .right) list(left = .left, right = .right)
        )
    }

    config_json <-
      list(
        id = .id,
        osSwitch = isTRUE(.os_switch),
        pairs = pair_list
      ) |>
      jsonlite::toJSON(auto_unbox = TRUE)

    # Load matching_game.js once per rendered document. The flag is keyed on the
    # document path so it still emits once per file even if the knitr session is
    # shared across documents.
    .load_flag <-
      stringr::str_c(
        "matching_game_js_loaded_",
        Sys.getenv("QUARTO_DOCUMENT_PATH")
      )
    if (!isTRUE(getOption(.load_flag))) {
      cat('<script src="../../src/js/matching_game.js"></script>\n')
      .opt <- list(TRUE)
      names(.opt) <- .load_flag
      options(.opt)
    }

    stringr::str_c(
      '<div class="matching-game" id="', .id, '">\n',
      '<div class="matching-col matching-left" id="', .id, '-left"></div>\n',
      '<div class="matching-col matching-right" id="', .id, '-right"></div>\n',
      '<div style="clear: both;"></div>\n',
      '<button id="', .id, '-check" class="parsons-btn parsons-btn-check" type="button">Check My Matches</button>\n',
      '<button id="', .id, '-reset" class="parsons-btn parsons-btn-reset" type="button">Shuffle Again</button>\n',
      '<p id="', .id, '-feedback" class="parsons-feedback"></p>\n',
      "</div>\n",
      "<script>\n",
      "window.matchingGames = window.matchingGames || [];\n",
      "window.matchingGames.push(", config_json, ");\n",
      "</script>\n"
    ) |>
      cat()
  }
