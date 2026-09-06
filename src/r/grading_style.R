# Check a student's answer against the course style guide and name each
# violation with the wording already stored in grading_comments, so a graded
# report says the same thing the course has always said.
#
# Style credit is extra credit, so a rule is implemented here only where it
# can be decided without guessing. A rule this file cannot settle is left
# alone: the cost of missing a violation is a student keeping credit they did
# not quite earn, while the cost of inventing one is taking credit away for
# something they did correctly.
#
# Source via source("src/r/grading_style.R").

library(tidyverse)

source("src/r/grading_db.R")
source("src/r/grading_functions.R")

# Functions the guide exempts from the one-prefix-function-per-line rule.

prefix_line_exemptions <-
  c(
    "c",
    "aes",
    "mean",
    "n",
    "length",
    "sum"
  )

# The widest a line of code or comment may be.

style_line_width <- 80L

# helpers -----------------------------------------------------------------

# The character positions in a line that sit inside a string literal, so that
# a comma or a hashtag written inside quotes is never read as code.

string_mask <-
  function(.line) {
    characters <- str_split_1(.line, "")

    inside <- logical(length(characters))

    quote_character <- NA_character_

    for (i in seq_along(characters)) {
      this <- characters[i]

      escaped <- i > 1 && characters[i - 1] == "\\"

      if (!escaped && this %in% c("\"", "'")) {
        if (is.na(quote_character)) {
          quote_character <- this
          inside[i] <- TRUE
          next
        }

        if (identical(this, quote_character)) {
          quote_character <- NA_character_
          inside[i] <- TRUE
          next
        }
      }

      inside[i] <- !is.na(quote_character)
    }

    inside
  }

# A line with its string literals filled in and any trailing comment removed,
# which is the form the spacing rules are applied to. The filler is a letter
# rather than a space: blanking a literal would turn "CACH", ] into a comma
# with a space in front of it and report a violation that is not there.

code_of_line <-
  function(.line) {
    if (!nchar(.line)) return("")

    characters <- str_split_1(.line, "")

    masked <- string_mask(.line)

    quotes <- masked & characters %in% c("\"", "'")

    characters[masked & !quotes] <- "x"

    hash <- which(characters == "#" & !masked)

    if (length(hash)) characters <- characters[seq_len(hash[1] - 1)]

    str_c(characters, collapse = "")
  }

# Where a line's comment starts, or NA when it has none.

comment_start_of <-
  function(.line) {
    if (!nchar(.line)) return(NA_integer_)

    characters <- str_split_1(.line, "")

    hash <- which(characters == "#" & !string_mask(.line))

    if (!length(hash)) NA_integer_ else hash[1]
  }

# checks ------------------------------------------------------------------

# Every style violation in one block of code, as one row per violation with
# the line it was found on and the comment bank entry that describes it.

style_violations <-
  function(.code, .parse_data = NULL) {
    if (is.na(.code) || str_trim(.code) == "") return(empty_violations())

    lines <- str_split_1(.code, "\n")

    parse_data <- .parse_data %||% parse_data_of(.code)

    found <-
      bind_rows(
        line_violations(lines),
        call_violations(parse_data),
        block_violations(lines, parse_data),
        indentation_violations(lines, parse_data)
      )

    if (!nrow(found)) return(empty_violations())

    found %>%
      arrange(line, short_name) %>%
      distinct(
        short_name,
        line,
        .keep_all = TRUE
      )
  }

# The shape style_violations() returns when there is nothing to report.

empty_violations <-
  function() {
    tibble(
      short_name = character(0),
      line = integer(0),
      evidence = character(0)
    )
  }

# One row per violation found.

violation <-
  function(.short_name, .line, .evidence) {
    tibble(
      short_name = .short_name,
      line = as.integer(.line),
      evidence = str_trunc(str_squish(.evidence), 76)
    )
  }

# The rules that can be decided from a single line: spacing, width, and
# comments sharing a line with code.

line_violations <-
  function(.lines) {
    map_dfr(seq_along(.lines), \(.i) line_violations_of(.lines[.i], .i))
  }

# The rules one line of a submission can break, each as a test against that
# line. Naming the rules in a table keeps the wording, the test, and the
# comment bank's short name together, and adding a rule means adding a row.

line_violations_of <-
  function(.line, .number) {
    code <- code_of_line(.line)

    comment_at <- comment_start_of(.line)

    comment_body <-
      if (is.na(comment_at)) "" else str_sub(.line, comment_at + 1)

    before_comment <-
      if (is.na(comment_at)) {
        ""
      } else {
        str_sub(
          .line,
          1,
          comment_at - 1
        )
      }

    tibble(
      short_name =
        c(
          "line_width",
          "space_comment",
          "comment_line",
          "space_comma",
          "no_space_dollar",
          "no_space_paren",
          "space_infix",
          "pipe_new_line",
          "spell_out_logic"
        ),
      broken =
        c(
          # A line wider than the guide allows.

          nchar(.line) > style_line_width,

          # A hashtag with no space after it. A section header's run of
          # dashes and an empty comment line are both fine.

          !is.na(comment_at) && str_detect(comment_body, "^[^\\s#]"),

          # A comment sharing its line with code.

          !is.na(comment_at) && str_trim(before_comment) != "",

          # A comma with no space after it, or a space before it.

          str_detect(code, ",[^\\s]") || str_detect(code, "\\s,"),

          # A space around one of the high-precedence operators.

          str_detect(code, "\\s\\$|\\$\\s|\\s::|::\\s"),

          # A space just inside a bracket, or between a function's name and
          # its opening bracket.

          str_detect(code, "\\(\\s+\\S") ||
            str_detect(code, "\\S\\s+\\)") ||
            str_detect(code, "\\[\\s+\\S") ||
            str_detect(code, "[A-Za-z0-9._]\\s+\\("),

          # An assignment or comparison without a space on each side.
          # Arithmetic is left alone: a unary minus cannot be told apart.
          #
          # A lone `=` is included, whether it assigns or names an argument:
          # the guide asks for one leading and one trailing space either way.
          # The lookarounds keep it from firing on the `=` inside `==`, `<=`,
          # `>=` and `!=`, which the clauses above already cover.

          str_detect(code, "[^\\s<>=!]<-|<-[^\\s]") ||
            str_detect(code, "[^\\s<>=!]==|==[^\\s]") ||
            str_detect(code, "[^\\s%]%>%|%>%[^\\s]") ||
            str_detect(code, "[^\\s|]\\|>|\\|>[^\\s]") ||
            str_detect(code, "(?<![<>=!\\s])=(?!=)") ||
            str_detect(code, "(?<![<>=!])=(?!=)(?=\\S)"),

          # A pipe with code after it on the same line.

          str_detect(code, "%>%\\s*\\S") ||
            str_detect(code, "\\|>\\s*\\S"),

          # T or F standing in for TRUE or FALSE.

          str_detect(code, "(?<![A-Za-z0-9._])[TF](?![A-Za-z0-9._])")
        )
    ) %>%
      filter(broken) %>%
      transmute(
        short_name,
        line = as.integer(.number),
        evidence = str_trunc(str_squish(.line), 76)
      )
  }

# The rules that need the parse tree: argument counts, nesting, naming, and
# quoting.

call_violations <-
  function(.parse_data) {
    if (is.null(.parse_data)) return(empty_violations())

    found <- list()

    single_quoted <-
      .parse_data[
        .parse_data$token == "STR_CONST" &
          str_starts(.parse_data$text, "'"),
      ]

    if (nrow(single_quoted)) {
      found <-
        c(
          found,
          list(
            violation(
              "double_quotes",
              single_quoted$line1[1],
              single_quoted$text[1]
            )
          )
        )
    }

    names_assigned <- assigned_names(NULL, .parse_data)

    bad_names <-
      names_assigned %>%
      keep(\(.name) !str_detect(.name, "^[a-z][a-z0-9_]*$"))

    if (length(bad_names)) {
      found <-
        c(
          found,
          list(
            violation(
              "snake_case_name",
              1,
              str_c(bad_names, collapse = ", ")
            )
          )
        )
    }

    calls <- call_expressions(.parse_data)

    for (id in unique(calls)) {
      children <- .parse_data[.parse_data$parent == id, ]

      opener <- children[children$token == "'('", ]

      if (!nrow(opener)) next

      name <- call_name_of(.parse_data, id)

      commas <- sum(children$token == "','")

      equals <- sum(children$token == "EQ_SUB")

      spans <- max(children$line2) > min(children$line1)

      arguments <- if (commas == 0 && nrow(children) <= 3) 0 else commas + 1

      numeric_only <-
        all(
          .parse_data$token[.parse_data$parent %in% children$id[
            children$token == "expr"
          ]] %in% c("NUM_CONST")
        )

      exempt_short_vector <-
        name %in% c("c", "list") && numeric_only && arguments <= 5

      # A call whose arguments run past one line opens with nothing after
      # the parenthesis. The comment bank has carried this rule as
      # `break_opening` from the start; nothing checked it until now.
      #
      # The guide's own "Good" example for splitting arguments keeps the
      # first one on the opening line, which contradicts it. Brian's lesson
      # code does not: across every code chunk in module 2 there are 223
      # calls opened with a bare `(` and none opened with an argument.

      if (spans) {
        trailing <-
          children[
            children$line1 == opener$line1 & children$col1 > opener$col1,
          ]

        if (nrow(trailing)) {
          found <-
            c(
              found,
              list(
                violation(
                  "break_opening",
                  opener$line1,
                  name
                )
              )
            )
        }
      }

      if (!spans && arguments >= 3 && !exempt_short_vector) {
        found <-
          c(
            found,
            list(
              violation(
                "three_arguments",
                opener$line1,
                name
              )
            )
          )
      }

      if (!spans && equals >= 2) {
        found <-
          c(
            found,
            list(
              violation(
                "multiple_equals",
                opener$line1,
                name
              )
            )
          )
      }
    }

    depth <- nesting_depth(NULL, .parse_data)

    if (depth > 2) {
      found <-
        c(
          found,
          list(
            violation(
              "nesting_depth",
              1,
              str_c("depth ", depth)
            )
          )
        )
    }

    bind_rows(found)
  }

# The name of the function a call expression invokes.

call_name_of <-
  function(.parse_data, .call_id) {
    wrappers <- .parse_data$id[.parse_data$parent == .call_id]

    name <-
      .parse_data$text[
        .parse_data$parent %in% wrappers &
          .parse_data$token == "SYMBOL_FUNCTION_CALL"
      ]

    if (!length(name)) NA_character_ else name[1]
  }

# The rules that look at how the lines of a block relate to each other: the
# break after an assignment operator, blank lines inside one statement, and
# more than one prefix function on a line.

block_violations <-
  function(.lines, .parse_data) {
    found <- list()

    code_lines <- map_chr(.lines, code_of_line)

    non_blank <- which(str_trim(code_lines) != "")

    # An assignment whose value continues onto another line must break right
    # after the operator.

    for (i in non_blank) {
      after_arrow <- str_match(code_lines[i], "<-\\s*(\\S.*)$")[, 2]

      if (is.na(after_arrow)) next

      trailing <- str_trim(after_arrow)

      if (trailing == "") next

      # Only a value that does not finish on this line breaks the rule.

      unclosed <-
        str_count(trailing, "\\(") - str_count(trailing, "\\)")

      if (unclosed > 0 || str_detect(trailing, "%>%\\s*$")) {
        found <-
          c(
            found,
            list(
              violation(
                "line_assignment",
                i,
                .lines[i]
              )
            )
          )
      }
    }

    # A name assigned in the global environment with `=`. The parse tree
    # separates it from an `=` naming an argument, which is a different
    # token.

    if (!is.null(.parse_data)) {
      for (line in .parse_data$line1[.parse_data$token == "EQ_ASSIGN"]) {
        found <-
          c(
            found,
            list(
              violation(
                "assign_arrow",
                line,
                .lines[line]
              )
            )
          )
      }
    }

    # More than one prefix function on a line, ignoring the exempt ones.

    if (!is.null(.parse_data)) {
      named_calls <-
        .parse_data[.parse_data$token == "SYMBOL_FUNCTION_CALL", ] %>%
        filter(!text %in% prefix_line_exemptions)

      crowded <-
        named_calls %>%
        count(line1) %>%
        filter(n > 1)

      for (i in seq_len(nrow(crowded))) {
        line <- crowded$line1[i]

        found <-
          c(
            found,
            list(
              violation(
                "one_prefix_line",
                line,
                .lines[line]
              )
            )
          )
      }
    }

    bind_rows(found)
  }

# indentation -------------------------------------------------------------

# How far a line is indented, with a tab measured as one two-space stop.

indent_of <-
  function(.line) {
    leading <- str_extract(.line, "^[ \t]*")

    str_count(leading, " ") + 2L * str_count(leading, "\t")
  }

# The indentation rules the guide's examples settle outright: the line after
# a break at `<-` or at an opening parenthesis, the lines of a top-level pipe
# chain, the alignment of a closing parenthesis, and arguments sharing one
# start column. Course code indents a pipe chain nested inside an argument
# more than one way, so those chains are left alone.

indentation_violations <-
  function(.lines, .parse_data) {
    found <- list()

    code_lines <- map_chr(.lines, code_of_line)

    trimmed <- str_trim(code_lines)

    non_blank <- which(trimmed != "")

    if (!length(non_blank)) return(empty_violations())

    indents <- map_int(.lines, indent_of)

    next_code <-
      function(.i) {
        after <- non_blank[non_blank > .i]

        if (!length(after)) NA_integer_ else after[1]
      }

    flag <-
      function(.short_name, .line) {
        found[[length(found) + 1]] <<-
          violation(.short_name, .line, .lines[.line])
      }

    # The line after a break at `<-` sits one stop further in.

    for (i in non_blank) {
      if (!str_detect(trimmed[i], "<-$")) next

      j <- next_code(i)

      if (is.na(j)) next

      if (indents[j] != indents[i] + 2) flag("indent_general", j)
    }

    # The line after a break at an opening parenthesis sits one stop further
    # in than the line that opened it, and so does the line after a break at
    # a named argument's `=`.

    for (i in non_blank) {
      if (!str_detect(trimmed[i], "\\($")) next

      j <- next_code(i)

      if (is.na(j)) next

      if (indents[j] != indents[i] + 2) flag("indent_first", j)
    }

    for (i in non_blank) {
      if (!str_detect(trimmed[i], "(?<![=<>!])=$")) next

      j <- next_code(i)

      if (is.na(j)) next

      if (indents[j] != indents[i] + 2) flag("indent_general", j)
    }

    # Every line of a top-level pipe chain sits at one stop. A chain is
    # checked when it starts a statement at the margin, or on the line after
    # the statement's assignment operator; the walk stops at a line that
    # opens a call, since the closer's own line restarts nothing checkable.

    for (i in non_blank) {
      if (!str_detect(trimmed[i], "%>%$")) next

      before <- non_blank[non_blank < i]

      previous <- if (length(before)) tail(before, 1) else NA_integer_

      starts_chain <-
        is.na(previous) || !str_detect(trimmed[previous], "%>%$")

      after_assignment <-
        indents[i] == 2 &&
          !is.na(previous) &&
          str_detect(trimmed[previous], "<-$") &&
          indents[previous] == 0

      if (!starts_chain || !(indents[i] == 0 || after_assignment)) next

      j <- next_code(i)

      while (!is.na(j)) {
        if (indents[j] != 2) flag("indent_pipe", j)

        if (!str_detect(trimmed[j], "%>%$")) break

        j <- next_code(j)
      }
    }

    # A closing parenthesis that ends a call spanning several lines takes a
    # line of its own, at the indentation of the line that opened it.

    openers <- list()

    for (i in non_blank) {
      characters <- str_split_1(code_lines[i], "")

      for (k in seq_along(characters)) {
        if (characters[k] == "(") {
          openers[[length(openers) + 1]] <-
            c(
              line = i,
              indent = indents[i]
            )
        }

        if (characters[k] == ")") {
          if (!length(openers)) next

          opened <- openers[[length(openers)]]

          openers[[length(openers)]] <- NULL

          if (opened[["line"]] == i) next

          preceding <- str_sub(code_lines[i], 1, k - 1)

          if (!str_detect(preceding, "^[\\s)]*$")) {
            flag("indent_closing", i)
          } else if (
            str_detect(preceding, "^\\s*$") &&
              indents[i] != opened[["indent"]]
          ) {
            flag("indent_closing", i)
          }
        }
      }
    }

    # Arguments given their own lines share one start column, a stop past the
    # line that opened the call. The first such argument is the break rule
    # above; this covers the rest. tribble() is exempt, since its rows are
    # aligned as a table.

    if (!is.null(.parse_data)) {
      calls <- call_expressions(.parse_data)

      for (id in unique(calls)) {
        name <- call_name_of(.parse_data, id)

        if (name %in% c("tribble", "matrix")) next

        children <-
          .parse_data[.parse_data$parent == id, ] %>%
          arrange(line1, col1)

        opener <- children[children$token == "'('", ]

        if (!nrow(opener)) next

        # A value that follows `=` is the argument's continuation, not an
        # argument of its own, so it is left to the break rule above.

        items <-
          children %>%
          mutate(previous_token = lag(token)) %>%
          filter(
            token == "SYMBOL_SUB" |
              (token == "expr" & !previous_token %in% "EQ_SUB"),
            line1 > opener$line1[1] | col1 > opener$col1[1]
          )

        if (!nrow(items)) next

        fresh <-
          items %>%
          filter(
            line1 != opener$line1[1],
            col1 == indents[line1] + 1
          )

        if (nrow(fresh) < 2) next

        expected <- indents[opener$line1[1]] + 3

        misplaced <-
          fresh %>%
          slice(-1) %>%
          filter(col1 != expected)

        for (line in unique(misplaced$line1)) {
          flag("indent_argument", line)
        }
      }
    }

    if (!length(found)) return(empty_violations())

    bind_rows(found)
  }

# report -----------------------------------------------------------------

# Runs of blank lines, read against the slot as it sits in the file.
#
# The guide asks for one blank line between code blocks and one between a
# code block and a comment, so two in a row is a violation wherever it
# appears. This is the one rule that cannot be read off the answer: an
# answer is stored trimmed, and trimming removes exactly the blank lines
# the rule is about. A student who left two blank lines after
# `library(tidyverse)` was passed as clean until this was added.
#
# Blank lines that run to the end of the file are not counted. The last
# slot ends at the last line of the file, so trailing newlines there are a
# property of the file rather than a gap the student left between blocks.

blank_run_violations <-
  function(.raw, .ends_file = FALSE) {
    if (is.na(.raw) || !nzchar(.raw)) return(empty_violations())

    lines <- str_split_1(.raw, "\n")

    blank <- str_trim(lines) == ""

    if (isTRUE(.ends_file)) {
      last_code <- which(!blank)

      keep_to <- if (length(last_code)) max(last_code) else 0L

      blank <- blank & seq_along(blank) <= keep_to
    }

    doubled <- which(blank & lag(blank, default = FALSE))

    if (!length(doubled)) return(empty_violations())

    tibble(
      short_name = "extra_blank",
      line = as.integer(doubled),
      evidence = NA_character_
    )
  }

# Comments that are not separated from code by a blank line.
#
# The guide asks for one blank line between a code block and a comment. The
# opposite fault -- more than one blank line -- is what blank_run_violations()
# finds, and until now it was the only one of the pair with a checker, so a
# comment written hard against its code passed while the same comment with an
# extra blank line was flagged.
#
# Both directions count: a comment sitting directly above the code it
# describes, and a comment sitting directly below the code above it.
# Consecutive comment lines are one comment and are left alone, so a
# multi-line comment block is reported once, at its first line.
#
# The raw text is needed rather than the trimmed answer, because the blank
# lines are the subject.

comment_spacing_violations <-
  function(.raw) {
    if (is.na(.raw) || !nzchar(.raw)) return(empty_violations())

    lines <- str_split_1(.raw, "\n")

    kind <-
      case_when(
        str_trim(lines) == "" ~ "blank",
        str_detect(lines, "^\\s*#") ~ "comment",
        .default = "code"
      )

    # A comment line that opens a comment block, and one that closes it.

    opens <- kind == "comment" & (lag(kind) != "comment" | is.na(lag(kind)))

    closes <- kind == "comment" & (lead(kind) != "comment" | is.na(lead(kind)))

    touched <-
      (opens & !is.na(lag(kind)) & lag(kind) == "code") |
        (closes & !is.na(lead(kind)) & lead(kind) == "code")

    # Report the block once, at the line the block opens on.

    block_start <- cumsum(opens) * (kind == "comment")

    flagged <- unique(block_start[touched & block_start > 0])

    if (!length(flagged)) return(empty_violations())

    tibble(
      short_name = "blank_line_code",
      line = as.integer(which(opens)[flagged]),
      evidence = str_trunc(str_squish(lines[which(opens)[flagged]]), 76)
    )
  }

# Run the style check over every answer slot, attaching the comment bank's
# wording to each violation found.

check_style <-
  function(.slots, .bank = NULL) {
    bank <- .bank %||% grading_comment_bank()

    described <-
      function(.answer, .raw, .ends_file) {
        bind_rows(
          style_violations(.answer),
          blank_run_violations(.raw, .ends_file),
          comment_spacing_violations(.raw)
        ) %>%
          left_join(
            bank %>% select(short_name, comment_text),
            by = "short_name"
          )
      }

    .slots %>%
      filter(slot_type == "answer") %>%
      mutate(
        violations =
          pmap(
            list(
              answer,
              raw_answer %||% answer,
              ends_file %||% FALSE
            ),
            described
          ),
        violation_count = map_int(violations, nrow),
        style_clean = violation_count == 0
      )
  }

# The distinct reasons a slot lost its style credit, in the comment bank's
# words and in the order the guide presents them.

style_reasons <-
  function(.violations) {
    if (!nrow(.violations)) return(character(0))

    .violations %>%
      distinct(short_name, .keep_all = TRUE) %>%
      arrange(line) %>%
      pull(comment_text)
  }

# the style-repair question ------------------------------------------------

# Every problem set closes by handing the student a poorly formatted code
# block and asking them to repair a stated number of violations. Comparing
# the code's output cannot grade that: the output is the same whether or not
# a single space was added. The answer has to be inspected instead, one named
# violation at a time.
#
# The ten checks below are the ten faults planted in problem set 1's block, in
# the order the style guide presents them. Each returns TRUE when the fault is
# still there.

style_repair_checks <-
  function() {
    list(
      space_comment = "A hashtag is not followed by a space.",
      blank_line_code =
        "A comment is not separated from the code by a blank line.",
      snake_case_name = "The assigned name is not snake_case.",
      assignment_arrow = "A global name is assigned with `=` rather than `<-`.",
      assignment_spacing =
        "The assignment operator is missing a surrounding space.",
      pipe_spacing = "The pipe is missing a leading space.",
      line_assignment = "There is no line break after the assignment operator.",
      three_arguments = "Three arguments share a line.",
      space_comma = "A comma is not followed by a space.",
      comment_line = "A comment shares its line with code."
    )
  }

# Whether a comment sits directly above code with no blank line between.

comment_touches_code <-
  function(.lines) {
    kinds <-
      case_when(
        str_detect(.lines, "^\\s*$") ~ "blank",
        str_detect(.lines, "^\\s*#") ~ "comment",
        .default = "code"
      )

    any(kinds == "comment" & lead(kinds) == "code", na.rm = TRUE)
  }

# Whether a global name is assigned with `=`. An `=` naming an argument
# inside a call is a different token and does not count.

assigns_with_equals <-
  function(.parse_data) {
    if (is.null(.parse_data)) return(FALSE)

    any(.parse_data$token == "EQ_ASSIGN")
  }

# The assignment operators a block uses at the top level, with the line and
# column each sits at. Both spellings are found, so a check does not miss a
# fault merely because the student wrote `=` where the guide wants `<-`.

assignment_operators <-
  function(.parse_data) {
    if (is.null(.parse_data)) return(tibble())

    .parse_data %>%
      filter(token %in% c("LEFT_ASSIGN", "EQ_ASSIGN")) %>%
      select(token, text, line1, col1, col2)
  }

# Whether an assignment operator is missing a space on either side.

assignment_spacing_fault <-
  function(.lines, .parse_data) {
    operators <- assignment_operators(.parse_data)

    if (!nrow(operators)) return(FALSE)

    any(
      map_lgl(
        seq_len(nrow(operators)),
        \(.i) {
          line <- .lines[operators$line1[.i]]

          at <- operators$col1[.i]

          before <- str_sub(line, at - 1, at - 1)

          after <- str_sub(line, operators$col2[.i] + 1, operators$col2[.i] + 1)

          before != " " || (after != " " && after != "")
        }
      )
    )
  }

# Whether an assignment whose value runs onto a later line failed to break
# straight after the operator.

assignment_break_fault <-
  function(.lines, .parse_data) {
    operators <- assignment_operators(.parse_data)

    if (!nrow(operators)) return(FALSE)

    any(
      map_lgl(
        seq_len(nrow(operators)),
        \(.i) {
          line <- .lines[operators$line1[.i]]

          trailing <- str_trim(str_sub(line, operators$col2[.i] + 1))

          if (trailing == "") return(FALSE)

          # The value continues past this line when the statement does.

          statement <-
            .parse_data %>%
            filter(
              line1 <= operators$line1[.i],
              line2 > operators$line1[.i]
            )

          nrow(statement) > 0
        }
      )
    )
  }

# Which of the planted violations a student's repair still carries.

style_repair_faults <-
  function(.code) {
    checks <- style_repair_checks()

    if (is.na(.code) || str_trim(.code) == "") {
      return(
        tibble(
          check = names(checks),
          description = unlist(checks, use.names = FALSE),
          unfixed = TRUE
        )
      )
    }

    lines <- str_split_1(.code, "\n")

    parse_data <- parse_data_of(.code)

    found <- style_violations(.code, parse_data)

    carries <- function(.rule) .rule %in% found$short_name

    code_lines <- map_chr(lines, code_of_line)

    tibble(
      check = names(checks),
      description = unlist(checks, use.names = FALSE),
      unfixed =
        c(
          carries("space_comment"),
          comment_touches_code(lines),
          carries("snake_case_name"),
          assigns_with_equals(parse_data),
          assignment_spacing_fault(lines, parse_data),
          any(str_detect(code_lines, "[^\\s%]%>%")),
          assignment_break_fault(lines, parse_data),
          carries("three_arguments"),
          carries("space_comma"),
          carries("comment_line")
        )
    )
  }

# Whether a question is the one that asks for a block to be repaired, and how
# many faults it says are in it.

style_repair_question <-
  function(.criterion) {
    if (is.na(.criterion)) return(FALSE)

    str_detect(
      str_to_lower(.criterion),
      "violations? of the .?course style guide"
    )
  }
