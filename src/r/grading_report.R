# Write one graded .qmd per student.
#
# The report follows the problem set: each question's own text, then the
# student's answer in a code chunk, with the marks above it. A deduction is a
# red paragraph beginning with the points lost; style credit is a blue
# paragraph when it was earned and a red one when it was not, followed by the
# reason. A single reason is a paragraph; several become a list.
#
# The document is written in Quarto's own markup: a mark is a fenced div, a
# set of reasons is a markdown list, the styles are a `css` chunk, and an
# answer is an `r` chunk that is not evaluated. There is no raw HTML in it.
# A student opens the file on their own machine, outside this project, so it
# does not have to fight the course stylesheet and does not carry a copy of
# it.
#
# Question 1 asks the student to name their file, so it has no answer to
# show. It is reported with its mark and nothing else.
#
# A NEEDS REVIEW flag is the grader's, not the student's: it lives in the
# dashboard and the review notes, and it never appears on a graded file. A
# flagged slot that has not been reviewed still shows no deduction.
#
# Source via source("src/r/grading_report.R").

library(tidyverse)

source("src/r/grading_problem_set.R")
source("src/r/grading_score.R")

# marks -------------------------------------------------------------------

# Points as they are written on a report: always signed, always two decimals.

format_points <-
  function(.points, .sign = "-") {
    str_c(.sign, formatC(abs(.points), format = "f", digits = 2))
  }

# A mark, as a fenced div carrying the class its colour is defined on.

marked_paragraph <-
  function(.text, .class) {
    str_c(
      "::: ", .class, "\n",
      .text, "\n",
      ":::"
    )
  }

# A mark and its reasons. One reason reads as a sentence; several become a
# markdown list under the mark, so the mark stays legible.

marked_block <-
  function(.lead, .reasons, .class) {
    reasons <- discard(.reasons, \(.reason) is.na(.reason) || .reason == "")

    if (!length(reasons)) return(marked_paragraph(.lead, .class))

    if (length(reasons) == 1) {
      return(marked_paragraph(str_c(.lead, " ", reasons[1]), .class))
    }

    marked_paragraph(
      str_c(
        .lead, "\n\n",
        str_c("* ", reasons, collapse = "\n")
      ),
      .class
    )
  }

# A function name as a mark writes it: in code font, and with parentheses
# only on a name a call can carry. An operator or a bracket form takes none,
# because `$()` is not something a student could have written.

function_label <-
  function(.names) {
    callable <-
      str_detect(.names, "^[a-zA-Z.][a-zA-Z0-9._]*$") &
        !str_detect(.names, "^\\.+$")

    str_c("`", .names, if_else(callable, "()", ""), "`")
  }

# sections ----------------------------------------------------------------

# Everything the checks found wrong with one answer, in the wording that
# goes onto the graded file.
#
# The dashboard shows this text in an editable box, so a reason is written
# here once and read in both places. An edit made there is stored on the
# slot as `override_note` and replaces this list.

deduction_reasons <-
  function(.slot) {

    # Every column is read through a default rather than indexed directly.
    # A run saved before a column existed does not carry it, and `.slot$x`
    # on a missing column is NULL, which turns the next `if` into "argument
    # is of length zero" -- an error that ends the dashboard session that
    # asked for the wording. `apply_overrides()` guards the same way.

    field <-
      function(.name, .default) {
        if (!has_name(.slot, .name)) return(.default)

        value <- .slot[[.name]]

        if (!length(value)) .default else value
      }

    reasons <- character(0)

    if (isTRUE(field("correctness_cost", 0) > 0)) {

      # check_correctness() writes the account of what differs while the key
      # is in scope. A run saved before that column existed falls back to the
      # sentence it used to print.

      described <- field("mismatch", NA_character_)

      reasons <-
        c(
          reasons,
          if (!is.na(described) && nzchar(described)) {
            described
          } else {
            "The answer does not match an accepted approach to this question."
          }
        )
    }

    unmet <- field("criteria_unmet", NA_character_)

    if (nzchar(coalesce(unmet, ""))) {
      reasons <- c(reasons, str_split_1(unmet, " \\| "))
    }

    # Only the first use of a function outside the list costs points, so a
    # later answer that uses the same function again carries no reason here.

    charged <- field("unapproved_charged", list(character(0)))[[1]]

    if (length(charged)) {
      reasons <-
        c(
          reasons,
          str_c(
            "Uses a function outside the list for this assignment: ",
            str_c(function_label(charged), collapse = ", "),
            "."
          )
        )
    }

    if (isTRUE(field("stray_assignment", FALSE))) {
      reasons <-
        c(reasons, "Assigns a name the question did not ask for.")
    }

    if (isTRUE(field("numeric_index", FALSE))) {
      reasons <-
        c(reasons, "Extracts a column by position rather than by name.")
    }

    reasons
  }

# The phrasings the course uses for a parsimony remark: a package prefix that
# was not needed, quotes around a name that reads without them, an
# exploratory step left in the submission. These are worth saying and are not
# worth a deduction on this assignment, so a line matching one of them is
# reported apart from the mark rather than folded into it.
#
# Kept as text because the remarks are written by hand in the dashboard and
# do not always quote the comment bank word for word.

costless_phrasings <-
  c(
    "not necessary to (use|specify|include|place|wrap|chain|reference)",
    "(was|were|are|is) not (necessary|required)",
    "exploratory steps",
    "could have been simplified",
    "more parsimonious",
    "reserving `%in%`",
    "does not need to be (referenced|selected)"
  )

# Whether a written remark is one of those.

costless_remark <-
  function(.lines) {
    str_detect(
      .lines,
      regex(str_c(costless_phrasings, collapse = "|"), ignore_case = TRUE)
    )
  }

# The functions outside the list that this answer uses and was not charged
# for, because the charge falls on the first use in the submission. Saying
# nothing here reads as though the function were allowed, so the answer names
# them and says why they cost nothing.
#
# Questions 7 to 9 ask the student to rewrite an operation using only the
# listed functions, and mark that requirement themselves. Where such a
# criterion went unmet the usage did cost points on this very answer, so the
# line is not written: it would tell the student nothing was taken off
# directly above a deduction that took it.

uncharged_functions <-
  function(.slot) {
    if (!has_name(.slot, "unapproved")) return(character(0))

    unmet <- coalesce(.slot$criteria_unmet %||% NA_character_, "")

    if (str_detect(unmet, "Functions that you may use")) return(character(0))

    used <- .slot$unapproved[[1]]

    charged <-
      if (has_name(.slot, "unapproved_charged")) {
        .slot$unapproved_charged[[1]]
      } else {
        character(0)
      }

    later <- setdiff(used, charged)

    if (!length(later)) return(character(0))

    str_c(
      str_c(function_label(later), collapse = " and "),
      " ",
      if (length(later) == 1) "is" else "are",
      " outside the list for this assignment. The points came off at the",
      " first use, so nothing further is taken off here."
    )
  }

# Remarks that cost nothing. A package attached where `::` would have done
# is worth saying and is not worth a deduction, so it is reported apart from
# the mark rather than folded into it.

parsimony_notes <-
  function(.slot, .bank = NULL) {
    if (!has_name(.slot, "unneeded_libraries")) return(character(0))

    packages <- .slot$unneeded_libraries[[1]]

    if (!length(packages)) return(character(0))

    bank <- .bank %||% grading_comment_bank()

    str_c(
      str_c("`library(", packages, ")`", collapse = " and "),
      " ",
      if (length(packages) == 1) "was" else "were",
      " not required. ",
      str_remove(
        grading_comment_text("library_extra", bank),
        "^It was not necessary to attach this package\\.\\s*"
      )
    )
  }

# A note written in the dashboard, one reason to a line.

override_reasons <-
  function(.slot) {
    if (!has_name(.slot, "override_note")) return(NULL)

    note <- .slot$override_note

    if (is.na(note) || !nzchar(str_trim(note))) return(NULL)

    note %>%
      str_split_1("\n") %>%
      str_trim() %>%
      discard(\(.line) .line == "")
  }

# Everything said about one answer, split by whether it costs anything.
#
# A slot that lost no points has nothing in the first group, so a remark
# written on it still reaches the student. Before this split those remarks
# were dropped: the deduction block was the only place a written note
# appeared, and it printed nothing when the deduction was zero.

split_reasons <-
  function(.slot, .bank = NULL) {
    written <- override_reasons(.slot)

    lines <- written %||% deduction_reasons(.slot)

    lines <- discard(lines, \(.line) is.na(.line) || str_trim(.line) == "")

    costless <- costless_remark(lines)

    # On a slot that lost no points, a remark a person wrote is advice and
    # the student should read it, while a proposal the checks made was
    # reversed in review and the student should not: telling them their
    # answer misses the key, under a heading saying it cost nothing, would
    # contradict the mark they were given.

    if (.slot$deduction <= 0) {
      if (is.null(written)) {
        return(
          list(
            charged = character(0),
            costless =
              c(
                uncharged_functions(.slot),
                parsimony_notes(.slot, .bank)
              )
          )
        )
      }

      costless[] <- TRUE
    }

    list(
      charged = lines[!costless],
      costless =
        c(
          lines[costless],
          uncharged_functions(.slot),
          parsimony_notes(.slot, .bank)
        )
    )
  }

# The deduction paragraph for one answer slot, or nothing when the slot lost
# no points.

deduction_block <-
  function(.slot, .bank = NULL) {
    if (.slot$deduction <= 0) return(character(0))

    marked_block(
      format_points(.slot$deduction, "-"),
      split_reasons(.slot, .bank)$charged,
      "deduction"
    )
  }

# The paragraph for the remarks that cost nothing, or nothing when there are
# none.

notes_block <-
  function(.slot, .bank = NULL) {
    notes <- split_reasons(.slot, .bank)$costless

    if (!length(notes)) return(character(0))

    marked_block("No points removed.", notes, "no_points_removed")
  }

# The style paragraph for a question: the credit it was worth, in blue when
# it was earned and red when it was not, with the guide's own wording for
# whatever went wrong.
#
# The style-repair question is the exception. Its marks are already awarded
# for the styling, so listing the rules a second time under a lost credit
# repeats what the deduction has just said. The credit is still printed where
# it was earned, because it is points the student has to be able to account
# for.

style_block <-
  function(.question_row, .slots, .bank) {
    credit <- style_credit_rate * .question_row$question_points

    if (any(.slots$is_repair) && !.question_row$style_clean) {
      return(character(0))
    }

    if (.question_row$style_clean) {
      return(
        marked_paragraph(
          str_c(
            "[",
            format_points(credit, "+"),
            "] Code styling"
          ),
          "style_earned"
        )
      )
    }

    reasons <-
      .slots$violations %>%
      bind_rows() %>%
      distinct(short_name, .keep_all = TRUE) %>%
      pull(comment_text)

    marked_block(
      str_c(
        "[",
        format_points(0, "+"),
        "] Code styling."
      ),
      reasons,
      "style_lost"
    )
  }

# The heading a question's section carries: its number and what it earned,
# style credit included. A heading that left the credit out did not add up to
# the total in the score summary, which counts it.

question_heading <-
  function(.question_row) {
    str_c(
      "## Question ",
      .question_row$question,
      " -- ",
      formatC(
        .question_row$earned + .question_row$style_credit,
        format = "f",
        digits = 2
      ),
      " / ",
      formatC(
        .question_row$question_points,
        format = "f",
        digits = 2
      )
    )
  }

# The section for the question that asks the student to rename the file. It
# has no answer to show and no code to style, so it reports the name that was
# submitted and whatever was wrong with it.

naming_section <-
  function(.question_row, .question_text, .file_name) {
    faults <- .question_row$faults[[1]] %||% character(0)

    mark <-
      if (length(faults)) {
        marked_block(format_points(.question_row$deduction, "-"), faults,
                     "deduction")
      } else {
        character(0)
      }

    c(
      question_heading(.question_row),
      .question_text,
      str_c(
        "Submitted as `",
        .file_name,
        "`"
      ),
      mark
    ) %>%
      str_c(collapse = "\n\n")
  }

# A student's answer, as an R chunk that is shown rather than run. It is not
# evaluated: a graded report has to render on the student's own machine,
# where the data folder and the answers to the earlier questions may not be
# there, and an answer that is wrong is often an answer that errors.

code_fence <-
  function(.answer) {
    body <-
      if (is.na(.answer) || str_trim(.answer) == "") {
        "# no answer given"
      } else {
        str_trim(.answer)
      }

    str_c(
      "```{r}\n",
      "#| eval: false\n\n",
      body,
      "\n```"
    )
  }

# One question's whole section: its text, then every answer in it.

question_section <-
  function(.question_row, .question_text, .slots, .bank) {
    header <- question_heading(.question_row)

    answers <-
      map_chr(
        seq_len(nrow(.slots)),
        \(.i) {
          slot <- .slots[.i, ]

          label <-
            if (is.na(slot$criterion)) {
              character(0)
            } else {
              str_c(
                "**",
                slot$criterion,
                "**"
              )
            }

          # The answer first, then what was said about it. A student reads
          # their own code and then the marking of it, rather than a
          # deduction for code they have not reached yet.

          c(
            label,
            code_fence(slot$answer),
            deduction_block(slot, .bank),
            notes_block(slot, .bank)
          ) %>%
            str_c(collapse = "\n\n")
        }
      )

    c(
      header,
      .question_text,
      str_c(answers, collapse = "\n\n"),
      style_block(
        .question_row,
        .slots,
        .bank
      )
    ) %>%
      str_c(collapse = "\n\n")
  }

# document ----------------------------------------------------------------

# The stylesheet the marks are rendered with, kept in the document so a
# graded report opens correctly wherever it is sent. Quarto runs a `css`
# chunk through to the document's own stylesheet, so no raw HTML is needed.
#
# A css chunk takes its options in a css comment, `/*| ... */`, not in the
# `#| ` an r chunk uses: knitr picks the comment marker from the engine, and
# `#|` inside a css chunk stops the render with "The chunk options should
# start with '/*| '".

report_styles <-
  function() {
    "
```{css}
/*| echo: false */

.deduction         { color: #c0392b; font-weight: 600; }
.style_earned      { color: #1f4fd8; font-weight: 600; }
.style_lost        { color: #c0392b; font-weight: 600; }
.no_points_removed { color: #5d5d70; font-weight: 600; }

.deduction li, .style_lost li, .no_points_removed li {
  color: #444444;
  font-weight: 400;
}

.score_summary {
  border: 1px solid #999999;
  border-radius: 10px;
  padding: 0.75em;
  margin-bottom: 1em;
  background-color: #ffffdd;
}
```
"
  }

# The whole graded document for one student.

# The extra-credit line, or nothing when none was awarded.

bonus_line <-
  function(.total) {
    if (!has_name(.total, "bonus") || coalesce(.total$bonus, 0) <= 0) {
      return(NULL)
    }

    str_c(
      "Extra credit: ",
      format_points(.total$bonus, "+"),
      " -- ",
      .total$bonus_reason
    )
  }

graded_document <-
  function(.student_id,
           .problem_set,
           .scored_slots,
           .scored_questions,
           .questions,
           .bank,
           .file_name = NA_character_,
           .bonus = NULL) {
    theirs <- .scored_slots %>% filter(student_id == .student_id)

    question_rows <-
      .scored_questions %>%
      filter(student_id == .student_id) %>%
      arrange(question)

    total <-
      score_students(
        .scored_questions %>% filter(student_id == .student_id),
        .bonus
      )

    sections <-
      map_chr(
        seq_len(nrow(question_rows)),
        \(.i) {
          row <- question_rows[.i, ]

          text <-
            .questions$markdown[.questions$question == row$question] %>%
            head(1) %>%
            coalesce("") %>%
            question_markdown_for_report()

          answers <-
            theirs %>%
            filter(question == row$question) %>%
            arrange(answer_order)

          if (!nrow(answers)) {
            return(
              naming_section(
                row,
                text,
                submitted_file_name(.file_name, .problem_set)
              )
            )
          }

          question_section(
            row,
            text,
            answers,
            .bank
          )
        }
      )

    c(
      str_c(
        "---\ntitle: \"",
        problem_set_title(.problem_set),
        "\"\nsubtitle: \"",
        str_to_title(str_replace(.student_id, "_", ", ")),
        "\"\nformat: html\n---"
      ),
      report_styles(),
      "::: score_summary",
      str_c(
        "**Total: ",
        formatC(
          total$total,
          format = "f",
          digits = 2
        ),
        " / ",
        formatC(
          total$points_possible,
          format = "f",
          digits = 2
        ),
        "**"
      ),
      str_c(
        "Points earned: ",
        formatC(
          total$points_earned,
          format = "f",
          digits = 2
        ),
        " -- Style credit: ",
        format_points(total$style_credit, "+")
      ),
      bonus_line(total),
      ":::",
      sections
    ) %>%
      discard(is.null) %>%
      str_c(collapse = "\n\n")
  }

# Write a graded report for every student, returning the paths written.

write_graded_reports <-
  function(.problem_set,
           .index,
           .scored_slots,
           .scored_questions,
           .output_dir = NULL,
           .bank = NULL,
           .bonus = NULL) {
    bank <- .bank %||% grading_comment_bank()

    questions <- questions_from_qmd(.problem_set)

    output_dir <-
      .output_dir %||%
      file.path(
        problem_set_dir(.problem_set),
        str_c(
          "problem_set_",
          .problem_set,
          "_graded"
        )
      )

    dir.create(
      output_dir,
      showWarnings = FALSE,
      recursive = TRUE
    )

    map_chr(
      seq_len(nrow(.index)),
      \(.i) {
        path <- file.path(output_dir, .index$graded_name[.i])

        graded_document(
          .index$student_id[.i],
          .problem_set,
          .scored_slots,
          .scored_questions,
          questions,
          bank,
          .index$file_name[.i],
          .bonus
        ) %>%
          write_lines(path)

        path
      }
    )
  }
