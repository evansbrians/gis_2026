# Read the three files that define a problem set and turn them into the
# structures the grading pipeline works from:
#
#   problem_sets/problem_set_N/problem_set_N.qmd    question text, points,
#                                                   allowed functions
#   problem_sets/problem_set_N/problem_set_N.R      the blank template, whose
#                                                   comments delimit every
#                                                   answer slot
#   problem_sets/problem_set_N/problem_set_N_key.R  the accepted answers
#
# The blank template is the spine of the whole system. Its comment blocks are
# copied verbatim into every submission, so aligning a submission to the
# template is what separates a student's answer from the code the question
# supplied.
#
# Source via source("src/r/grading_problem_set.R").

library(tidyverse)

# Path to a problem set's parent folder.

problem_set_dir <-
  function(.problem_set) {
    file.path(
      "problem_sets",
      str_c("problem_set_", .problem_set)
    )
  }

# Path to one of a problem set's three defining files.

problem_set_file <-
  function(.problem_set, .suffix) {
    file.path(
      problem_set_dir(.problem_set),
      str_c(
        "problem_set_",
        .problem_set,
        .suffix
      )
    )
  }

# segments ----------------------------------------------------------------

# Reduce a comment to the text a reader would compare: no hashtags, no
# section-header dashes, no markdown emphasis, and no repeated whitespace.
# Alignment between the template, the key, and a submission is done on this
# form so that a student who re-wraps a comment still matches.

normalize_comment <-
  function(.lines) {
    .lines %>%
      str_remove("^\\s*#+") %>%
      str_c(collapse = " ") %>%
      str_remove_all("-{3,}") %>%
      str_remove_all("[`*_]") %>%
      str_squish() %>%
      str_to_lower()
  }

# Split an R script into runs of comment, code, and blank lines. A run ends
# wherever the kind of line changes, so each comment paragraph stands on its
# own and can be located independently in a submission.

line_runs <-
  function(.lines) {
    tibble(
      line = seq_along(.lines),
      text = .lines,
      kind =
        case_when(
          str_detect(.lines, "^\\s*$") ~ "blank",
          str_detect(.lines, "^\\s*#") ~ "comment",
          .default = "code"
        )
    ) %>%
      mutate(run = cumsum(coalesce(kind != lag(kind), TRUE))) %>%
      group_by(run, kind) %>%
      summarize(
        line_start = min(line),
        line_end = max(line),
        content = str_c(text, collapse = "\n"),
        .groups = "drop"
      ) %>%
      arrange(line_start)
  }

# Reduce an R script to its comment and code segments, with an empty code
# segment wherever the file leaves room for an answer. In the blank template
# a single blank line separates the paragraphs of one comment block, while a
# run of two or more marks a slot the student is expected to fill; a file
# that ends on a comment leaves a slot at its end.

script_segments <-
  function(.path, .slot_gap = 2L) {
    runs <- line_runs(read_lines(.path))

    if (!nrow(runs)) return(empty_segments())

    blank_gap <-
      runs$kind == "blank" &
        (runs$line_end - runs$line_start + 1L) >= .slot_gap &
        lag(runs$kind, default = "blank") == "comment"

    trailing <-
      seq_len(nrow(runs)) == nrow(runs) & runs$kind == "comment"

    inserted <-
      tibble(
        run = c(runs$run[blank_gap], runs$run[trailing] + 1) - 0.5,
        kind = "code",
        line_start =
          c(
            runs$line_start[blank_gap],
            runs$line_end[trailing] + 1L
          ),
        line_end = c(runs$line_start[blank_gap] - 1L, runs$line_end[trailing]),
        content = ""
      )

    runs %>%
      filter(kind != "blank") %>%
      bind_rows(inserted) %>%
      arrange(run) %>%
      mutate(
        normalized =
          if_else(
            kind == "comment",
            map_chr(str_split(content, "\n"), normalize_comment),
            NA_character_
          )
      )
  }

# The shape script_segments() returns, for a file with nothing in it.

empty_segments <-
  function() {
    tibble(
      run = numeric(0),
      kind = character(0),
      line_start = integer(0),
      line_end = integer(0),
      content = character(0),
      normalized = character(0)
    )
  }

# How much two normalized comments have in common, as the proportion of
# distinct words they share. Used only when an exact match fails.

comment_similarity <-
  function(.a, .b) {
    words_a <- unique(str_split_1(.a, " "))
    words_b <- unique(str_split_1(.b, " "))

    if (!length(words_a) || !length(words_b)) return(0)

    length(intersect(words_a, words_b)) / length(union(words_a, words_b))
  }

# Which question each comment run belongs to, from the section headers the
# template and every submission carry ("# question 4 ------").

question_of_comments <-
  function(.content) {
    matches <- str_match(.content, "^\\s*#\\s*question\\s+(\\d+)\\s*-")

    vctrs::vec_fill_missing(
      as.integer(matches[, 2]),
      direction = "down"
    )
  }

# Group a question's unmatched template comments into the runs that fall
# between two matched anchors, reporting for each run the target line range
# it has to lie inside. Anchors outside the question are unbounded.

unmatched_gaps <-
  function(.rows, .matched, .target_start, .target_end) {
    missing_rows <- .rows[is.na(.matched[.rows])]

    if (!length(missing_rows)) return(list())

    split(missing_rows, cumsum(c(TRUE, diff(missing_rows) != 1L))) %>%
      map(
        \(.run) {
          before <- .rows[.rows < min(.run) & !is.na(.matched[.rows])]
          after <- .rows[.rows > max(.run) & !is.na(.matched[.rows])]

          list(
            rows = .run,
            after =
              if (length(before)) {
                .target_end[.matched[max(before)]]
              } else {
                0L
              },
            before =
              if (length(after)) {
                .target_start[.matched[min(after)]]
              } else {
                .Machine$integer.max
              }
          )
        }
      ) %>%
      unname()
  }

# Walk the template's comment runs in order and locate each one in a target
# file, never searching backwards. Returns one row per template comment run
# with the matched target row, or NA where the comment could not be found.
#
# The search is confined to the question the comment belongs to. Several
# prompts ("# Answer:") repeat across questions, so a comment a student
# deleted would otherwise be matched to the identical comment in a later
# question, silently shifting every slot after it.

align_to_template <-
  function(.template_segments, .target_segments, .threshold = 0.6) {
    template_comments <-
      .template_segments %>%
      filter(kind == "comment") %>%
      mutate(question = question_of_comments(content))

    # "# Or:" separates the key's alternative answers within a single slot.
    # It is never a template prompt, so it must not be able to claim one.

    target_comments <-
      .target_segments %>%
      filter(kind == "comment") %>%
      mutate(question = question_of_comments(content)) %>%
      filter(!str_detect(content, "^\\s*#\\s*[Oo]r:?\\s*$"))

    matched <- rep(NA_integer_, nrow(template_comments))

    exactness <- rep(NA_character_, nrow(template_comments))

    for (question in unique(template_comments$question)) {
      wanted_rows <- which(template_comments$question %in% question)

      pool <- which(target_comments$question %in% question)

      cursor <- 0L

      for (i in wanted_rows) {
        wanted <- template_comments$normalized[i]

        candidates <- pool[target_comments$line_start[pool] > cursor]

        if (!length(candidates)) next

        hit <- candidates[target_comments$normalized[candidates] == wanted][1]

        if (!is.na(hit)) {
          exactness[i] <- "exact"
        } else {
          scores <-
            map_dbl(
              target_comments$normalized[candidates],
              \(.candidate) comment_similarity(wanted, .candidate)
            )

          if (max(scores) >= .threshold) {
            hit <- candidates[which.max(scores)]
            exactness[i] <- "fuzzy"
          }
        }

        if (is.na(hit)) next

        matched[i] <- hit

        cursor <- target_comments$line_end[hit]
      }

      # A prompt the student rewrote entirely matches nothing by text. When
      # the comments left over between two anchors line up one for one with
      # the template's, pair them by position -- recorded as such, so the
      # pipeline can treat the slot as needing a look.

      claimed <- matched[!is.na(matched)]

      gaps <-
        unmatched_gaps(
          wanted_rows,
          matched,
          target_comments$line_start,
          target_comments$line_end
        )

      for (gap in gaps) {
        free <-
          setdiff(
            pool[
              target_comments$line_start[pool] > gap$after &
                target_comments$line_start[pool] < gap$before
            ],
            claimed
          )

        if (length(free) != length(gap$rows)) next

        matched[gap$rows] <- free

        exactness[gap$rows] <- "positional"

        claimed <- c(claimed, free)
      }
    }

    tibble(
      template_index = seq_len(nrow(template_comments)),
      question = template_comments$question,
      template_line = template_comments$line_start,
      template_text = template_comments$content,
      normalized = template_comments$normalized,
      target_row = matched,
      match_type = exactness,
      target_start = target_comments$line_start[matched],
      target_end = target_comments$line_end[matched]
    )
  }

# slots -------------------------------------------------------------------

# Turn the template into the list of positions a student fills in. Reading
# the template's segments in order, each comment run is a prompt and the code
# run that follows it is either code the question supplied (non-empty in the
# template) or an answer slot (empty in the template).

template_slots <-
  function(.problem_set) {
    script_segments(problem_set_file(.problem_set, ".R")) %>%
      mutate(
        question = question_of_comments(content),

        # align_to_template() numbers the template's comment runs among
        # themselves, so a slot records its prompt by that same numbering.

        comment_index = cumsum(kind == "comment"),
        prompt =
          if_else(
            kind == "code",
            lag(content),
            NA_character_
          ),
        prompt_index =
          if_else(
            kind == "code",
            comment_index,
            NA_integer_
          )
      ) %>%
      filter(kind == "code", !is.na(question)) %>%

      # Blank lines inside a block of supplied code split it into several
      # runs. They are one slot, so fold every code run that shares a prompt
      # back together.

      group_by(question, prompt_index) %>%
      summarize(
        prompt = first(prompt),
        content = str_c(content[content != ""], collapse = "\n\n"),
        .groups = "drop"
      ) %>%
      mutate(
        slot_type =
          if_else(
            content == "",
            "answer",
            "given"
          )
      ) %>%
      group_by(question) %>%
      mutate(answer_order = cumsum(slot_type == "answer")) %>%
      ungroup() %>%
      mutate(
        answer_order =
          if_else(
            slot_type == "answer",
            answer_order,
            NA_integer_
          ),
        slot_id = row_number()
      ) %>%
      select(
        slot_id,
        question,
        slot_type,
        answer_order,
        prompt,
        prompt_index,
        given_code = content
      )
  }

# Pull the content a target file placed in each template slot. The template's
# comment runs bound every slot, so the material for slot i is whatever sits
# between the comment that introduces it and the next template comment.

slots_from_file <-
  function(.path, .problem_set, .template_segments = NULL) {
    template <-
      .template_segments %||%
      script_segments(problem_set_file(.problem_set, ".R"))

    target <- script_segments(.path)

    alignment <- align_to_template(template, target)

    slots <- template_slots(.problem_set)

    target_lines <- read_lines(.path)

    map_dfr(
      seq_len(nrow(slots)),
      \(.i) {
        prompt_index <- slots$prompt_index[.i]

        this <- alignment[alignment$template_index == prompt_index, ]

        if (!nrow(this) || is.na(this$target_row)) {
          return(
            tibble(
              slot_id = slots$slot_id[.i],
              found = FALSE,
              match_type = NA_character_,
              content = NA_character_,
              line_start = NA_integer_,
              line_end = NA_integer_,
              ends_file = FALSE
            )
          )
        }

        # The slot ends where the next located template comment begins, or at
        # the end of the file when this is the last prompt.

        later <-
          alignment %>%
          filter(
            template_index > prompt_index,
            !is.na(target_start)
          )

        stop_at <-
          if (nrow(later)) {
            min(later$target_start) - 1L
          } else {
            length(target_lines)
          }

        span <- seq_len(0)

        if (this$target_end < stop_at) {
          span <- (this$target_end + 1L):stop_at
        }

        # Where the answer sits in the student's own file. The dashboard
        # reads it back to show the lines around an answer, because a
        # comment a student wrote above their code often lands outside the
        # slot and cannot be judged from the answer alone.

        tibble(
          slot_id = slots$slot_id[.i],
          found = TRUE,
          match_type = this$match_type,
          content = str_c(target_lines[span], collapse = "\n"),
          line_start = if (length(span)) as.integer(min(span)) else NA_integer_,
          line_end = if (length(span)) as.integer(max(span)) else NA_integer_,
          ends_file = stop_at >= length(target_lines)
        )
      }
    ) %>%
      left_join(slots, by = "slot_id") %>%
      mutate(
        # Kept before the trim below. The blank-line rules are read against
        # this: right-trimming removes exactly the trailing blank lines the
        # guide is about.

        raw_content = coalesce(content, ""),
        content = str_trim(coalesce(content, ""), side = "right")
      )
  }

# The key records more than one acceptable answer for several slots,
# separated by a comment line that begins with "Or". Split a key slot into
# its alternatives and drop the bookkeeping comments that introduce them.
#
# The separator often carries a note explaining what the alternative is --
# "# Or (because with the skip argument, empty rows are skipped by default):",
# "# Or you could have used %in% when subsetting the metro stops:" -- so the
# line is matched on how it begins rather than on being exactly "# Or:". An
# earlier version anchored the end of the line, which silently left annotated
# separators in place: the slot never split, its one alternative held the code
# of every listed answer at once, and a student who wrote any single one of
# them did not match it.
#
# "Or" is matched case-sensitively and on a word boundary, because a question
# prompt wrapped onto a new line can begin with a lowercase "or" (problem set
# 3 has "#   or Virginia;"), and that is prose rather than a separator.

key_alternatives <-
  function(.content) {
    if (is.na(.content) || str_trim(.content) == "") return(character(0))

    .content %>%
      str_split("(?m)^\\s*#\\s*Or\\b[^\\n]*$") %>%
      pluck(1) %>%
      map_chr(
        \(.alternative) {
          .alternative %>%
            str_remove("(?m)^\\s*#\\s*Answer:?\\s*$") %>%
            str_trim()
        }
      ) %>%
      keep(\(.alternative) .alternative != "")
  }

# The key, as one row per slot with a list column of accepted answers.

key_slots <-
  function(.problem_set) {
    problem_set_file(.problem_set, "_key.R") %>%
      slots_from_file(.problem_set) %>%
      mutate(alternatives = map(content, key_alternatives))
  }

# Add an accepted alternative to one slot of the key file, under the "# Or:"
# separator that key_alternatives() reads back.

append_key_alternative <-
  function(.problem_set, .slot_id, .code) {
    path <- problem_set_file(.problem_set, "_key.R")

    slot <-
      key_slots(.problem_set) %>%
      filter(slot_id == .slot_id)

    if (!nrow(slot) || !slot$found || is.na(slot$line_start)) {
      cli::cli_abort(
        "Slot {(.slot_id)} could not be located in {.file {path}}."
      )
    }

    # The slot content is right-trimmed, so its last line is the slot's last
    # non-blank line in the file:

    at <-
      slot$line_start +
        length(str_split_1(slot$content, "\n")) -
        1L

    read_lines(path) %>%
      append(
        c(
          "",
          "# Or:",
          "",
          str_split_1(.code, "\n")
        ),
        after = at
      ) %>%
      write_lines(path)

    invisible(path)
  }

# qmd ---------------------------------------------------------------------

# The functions a problem set permits, read from the accordion panel in its
# .qmd. Entries are written either as ".Primitive, name" or "package::name";
# both are normalized to a package and a function name. The empty-argument
# primitive is spelled "()" in some problem sets and "(...)" in others.

allowed_functions_from_qmd <-
  function(.problem_set) {
    lines <- read_lines(problem_set_file(.problem_set, ".qmd"))

    opens <-
      str_which(
        lines,
        fixed("Functions that you may use in this assignment</button>")
      )

    if (!length(opens)) {
      cli::cli_abort(
        "No allowed-function accordion in problem set {.val {(.problem_set)}}."
      )
    }

    closes <- str_which(lines, "^:::\\s*$")

    stop_at <- closes[closes > opens[1]][2]

    entries <-
      str_match(lines[opens[1]:stop_at], "^\\*\\s+`(.+)`\\s*$")[, 2] %>%
      discard(is.na)

    tibble(entry = entries) %>%
      mutate(
        package =
          if_else(
            str_detect(entry, "^\\.Primitive,"),
            ".Primitive",
            str_extract(entry, "^[^:]+")
          ),
        function_name =
          if_else(
            str_detect(entry, "^\\.Primitive,"),
            str_remove(entry, "^\\.Primitive,\\s*"),
            str_remove(entry, "^[^:]+::")
          ),
        function_name =
          if_else(
            function_name == "()",
            "(...)",
            function_name
          ),
        sort_order = row_number()
      )
  }

# Every scored question in a problem set, with the points it carries and the
# markdown that states it. Question text runs from the numbered line to the
# next question or to the end of the enclosing div, with the spy-icon hint
# blocks removed -- a graded report shows the question, not the hints.

# The problem set's own title, taken from the .qmd's front matter. A graded
# report carries it rather than the student's name: the student knows whose
# paper it is, and the assignment is what a file in their folder has to be
# recognisable by.

problem_set_title <-
  function(.problem_set) {
    lines <- read_lines(problem_set_file(.problem_set, ".qmd"))

    found <- str_match(lines, '^title:\\s*"?(.*?)"?\\s*$')[, 2]

    title <- found[!is.na(found)]

    if (!length(title)) {
      return(str_c("Problem set ", .problem_set))
    }

    title[1]
  }

questions_from_qmd <-
  function(.problem_set) {
    lines <- read_lines(problem_set_file(.problem_set, ".qmd"))

    starts <-
      str_which(lines, "^(\\d+)\\\\\\.\\s*\\[\\[[0-9.]+\\]\\]\\{\\.score\\}")

    if (!length(starts)) {
      cli::cli_abort(
        "No {.code {{.score}}} markup in problem set {.val {(.problem_set)}}."
      )
    }

    ends <- c(starts[-1] - 1L, length(lines))

    map2_dfr(
      starts,
      ends,
      \(.start, .end) {
        header <- lines[.start]

        parts <-
          str_match(
            header,
            "^(\\d+)\\\\\\.\\s*\\[\\[([0-9.]+)\\]\\]\\{\\.score\\}\\s*(.*)$"
          )

        body <- strip_hint_blocks(lines[.start:.end])

        tibble(
          question = as.integer(parts[, 2]),
          points = as.numeric(parts[, 3]),
          stem = parts[, 4],
          markdown = str_c(trim_to_question(body), collapse = "\n")
        )
      }
    )
  }

# Cut a question's markdown where the question ends. The span from one
# numbered question to the next runs past the div that encloses it and on
# into the prose between sections, so it stops at whichever comes first: the
# fence that closes the enclosing div, or the next section heading. Fenced
# code blocks are stepped over, since a question's given code may hold
# anything.

trim_to_question <-
  function(.lines) {
    in_fence <- FALSE

    for (i in seq_along(.lines)) {
      if (str_detect(.lines[i], "^\\s*```")) {
        in_fence <- !in_fence
        next
      }

      if (in_fence || i == 1) next

      if (str_detect(.lines[i], "^:::+\\s*$|^#{1,6}\\s")) {
        return(.lines[seq_len(i - 1)])
      }
    }

    .lines
  }

# Rewrite a question's markdown for a graded report: drop the numbering and
# the scoring spans the problem set's own stylesheet renders, state each
# bullet's points in words instead, and neutralize the given code blocks so
# they are shown rather than run.

question_markdown_for_report <-
  function(.markdown) {
    .markdown %>%
      str_remove("^\\d+\\\\\\.\\s*") %>%
      str_remove_all("\\[\\[[0-9.]+\\]\\]\\{\\.score\\}\\s*") %>%
      str_replace_all(
        "\\[\\[([0-9.]+)\\]\\]\\{\\.subscore\\}\\s*",
        "(\\1 points) "
      ) %>%
      str_replace_all("(?m)^(\\s*)```\\{r[^\\n]*\\}", "\\1```r") %>%
      str_trim()
  }

# Drop every "::: mysecret" div from a block of markdown. Hints belong to the
# problem set, not to a graded report.

strip_hint_blocks <-
  function(.lines) {
    depth <- 0L

    keep <- logical(length(.lines))

    for (i in seq_along(.lines)) {
      opens_hint <- str_detect(.lines[i], "^:::+\\s*mysecret\\s*$")

      if (opens_hint) depth <- depth + 1L

      keep[i] <- depth == 0L

      if (depth > 0L && !opens_hint && str_detect(.lines[i], "^:::+\\s*$")) {
        depth <- depth - 1L
      }
    }

    .lines[keep]
  }

# The scored bullets beneath each question. Whether a bullet is a separate
# answer or one of several criteria applied to a single answer is decided by
# the template: when a question's bullet count matches its answer-slot count
# the bullets are subquestions, and otherwise they are criteria.

subscores_from_qmd <-
  function(.problem_set) {
    questions <- questions_from_qmd(.problem_set)

    slots <- template_slots(.problem_set)

    map_dfr(
      seq_len(nrow(questions)),
      \(.i) {
        bullets <-
          questions$markdown[.i] %>%
          str_split("\n") %>%
          pluck(1) %>%
          str_match(
            "^\\*\\s*\\[\\[([0-9.]+)\\]\\]\\{\\.subscore\\}\\s*(.*)$"
          )

        rows <- which(!is.na(bullets[, 1]))

        if (!length(rows)) return(tibble())

        n_answers <-
          sum(
            slots$question == questions$question[.i] &
              slots$slot_type == "answer"
          )

        tibble(
          question = questions$question[.i],
          bullet_order = seq_along(rows),
          points = as.numeric(bullets[rows, 2]),
          criterion = str_squish(bullets[rows, 3]),
          bullet_type =
            if (length(rows) == n_answers) "subquestion" else "criterion"
        )
      }
    )
  }
