# Write the markdown review sheet and the score table for a graded problem
# set.
#
# The review sheet is organised by question rather than by student, so one
# criterion is held in mind at a time, and it lists only the answers that
# want a person's judgement: the ones the checks call wrong, and the ones the
# checks could not settle. Everything else is left out.
#
# Usage from the project root:
#
#   source("src/r/grading_review_notes.R")
#
#   write_review_notes(1)

library(tidyverse)

source("src/r/grading_pipeline.R")

# Where the review sheet and the score table are written.

review_notes_path <-
  function(.problem_set) {
    file.path(
      problem_set_dir(.problem_set),
      str_c("problem_set_", .problem_set, "_review.md")
    )
  }

review_scores_path <-
  function(.problem_set) {
    file.path(
      problem_set_dir(.problem_set),
      str_c("problem_set_", .problem_set, "_scores.csv")
    )
  }

# A fenced block, or a plain note when the student left the slot empty.

fenced_answer <-
  function(.answer) {
    if (is.na(.answer) || str_trim(.answer) == "") {
      return("*No answer given.*")
    }

    str_c("```r\n", str_trim(.answer), "\n```")
  }

# Why one answer is on the list, in as few words as carry the meaning.

review_because <-
  function(.slot) {
    reasons <- character(0)

    if (isTRUE(.slot$needs_review)) {
      reasons <- c(reasons, str_c("**Needs review** — ", .slot$reason))
    }

    if (.slot$verdict == "incorrect" && !isTRUE(.slot$needs_review)) {
      reasons <-
        c(reasons, "**Wrong** — does not match an accepted approach.")
    }

    if (.slot$n_unapproved > 0) {
      reasons <-
        c(
          reasons,
          str_c(
            "Functions outside the list: ",
            str_c(function_label(.slot$unapproved[[1]]), collapse = ", ")
          )
        )
    }

    if (isTRUE(.slot$stray_assignment)) {
      reasons <- c(reasons, "Assigns a name the question did not ask for.")
    }

    if (isTRUE(.slot$numeric_index)) {
      reasons <- c(reasons, "Takes a column by position rather than by name.")
    }

    if (nzchar(coalesce(.slot$criteria_unmet, ""))) {
      reasons <-
        c(
          reasons,
          str_c(
            "Criteria not met: ",
            str_replace_all(.slot$criteria_unmet, " \\| ", "; ")
          )
        )
    }

    if (!is.na(coalesce(.slot$repair_unfixed_names, NA_character_))) {
      if (nzchar(.slot$repair_unfixed_names)) {
        reasons <-
          c(
            reasons,
            str_c(
              "Style faults left unrepaired: ",
              str_replace_all(.slot$repair_unfixed_names, " \\| ", "; ")
            )
          )
      }
    }

    reasons
  }

# The style violations behind a lost style credit, in the comment bank's own
# words.

style_notes <-
  function(.slot) {
    found <- .slot$violations[[1]]

    if (!nrow(found)) return(character(0))

    found %>%
      distinct(short_name, .keep_all = TRUE) %>%
      pull(comment_text) %>%
      unique()
  }

# sections ----------------------------------------------------------------

# One question's section: what the key accepts, then each answer that wants
# looking at.

question_section <-
  function(.question, .slots, .key, .questions) {
    rows <-
      .slots %>%
      filter(question == .question) %>%
      filter(needs_review | verdict == "incorrect" | deduction > 0) %>%
      arrange(answer_order, student_id)

    if (!nrow(rows)) {
      return(
        str_c(
          "## Question ", .question, "\n\n",
          "*Nothing to check: every answer passed both checks cleanly.*"
        )
      )
    }

    parts <-
      map_chr(
        seq_len(nrow(rows)),
        \(.i) {
          slot <- rows[.i, ]

          expected <-
            .key %>%
            filter(slot_id == slot$slot_id) %>%
            pull(alternatives)

          key_block <-
            if (length(expected) && length(expected[[1]])) {
              str_c(
                "<details><summary>What the key accepts</summary>\n\n",
                str_c(
                  map_chr(expected[[1]], \(.a) str_c("```r\n", .a, "\n```")),
                  collapse = "\n\n"
                ),
                "\n\n</details>"
              )
            } else {
              ""
            }

          c(
            str_c(
              "### ", slot$student_id,
              " — Q", slot$question, ".", coalesce(slot$answer_order, 1L),
              "  (", formatC(slot$deduction, format = "f", digits = 2),
              " off ", formatC(slot$slot_points, format = "f", digits = 2), ")"
            ),
            str_c("- ", review_because(slot), collapse = "\n"),
            fenced_answer(slot$answer),
            key_block
          ) %>%
            discard(\(.piece) .piece == "") %>%
            str_c(collapse = "\n\n")
        }
      )

    stem <-
      .questions %>%
      filter(question == .question) %>%
      pull(stem) %>%
      first() %>%
      coalesce("")

    c(
      str_c("## Question ", .question),
      str_c("*", str_squish(str_remove_all(stem, "[*`]")), "*"),
      str_c(nrow(rows), " answer(s) to check."),
      str_c(parts, collapse = "\n\n---\n\n")
    ) %>%
      str_c(collapse = "\n\n")
  }

# The style-credit section: who lost it, on which question, and why.

style_section <-
  function(.slots, .questions) {
    lost <-
      .slots %>%
      filter(!style_clean) %>%
      arrange(student_id, question, answer_order)

    if (!nrow(lost)) return("## Style credit\n\n*Every answer was clean.*")

    per_student <-
      .questions %>%
      group_by(student_id) %>%
      summarize(
        credit = sum(style_credit),
        possible = sum(question_points) * style_credit_rate,
        .groups = "drop"
      ) %>%
      arrange(desc(credit))

    table_rows <-
      str_c(
        "| ", per_student$student_id,
        " | ", formatC(per_student$credit, format = "f", digits = 2),
        " | ", formatC(per_student$possible, format = "f", digits = 2),
        " |"
      )

    detail <-
      map_chr(
        seq_len(nrow(lost)),
        \(.i) {
          slot <- lost[.i, ]

          str_c(
            "- **", slot$student_id, "**, Q", slot$question, ".",
            coalesce(slot$answer_order, 1L), ": ",
            str_c(style_notes(slot), collapse = " ")
          )
        }
      )

    c(
      "## Style credit",
      str_c(
        "Style credit is ",
        format(style_credit_rate * 100),
        "% of a question's points, added when every answer in that question ",
        "follows the guide."
      ),
      str_c(
        c(
          "| Student | Earned | Possible |",
          "| --- | ---: | ---: |",
          table_rows
        ),
        collapse = "\n"
      ),
      "### Where it was lost",
      str_c(detail, collapse = "\n")
    ) %>%
      str_c(collapse = "\n\n")
  }

# The summary table at the top.

summary_section <-
  function(.students, .slots) {
    counts <-
      .slots %>%
      group_by(student_id) %>%
      summarize(
        wrong = sum(verdict == "incorrect" & !needs_review),
        flagged = sum(needs_review),
        .groups = "drop"
      )

    rows <-
      .students %>%
      left_join(counts, by = "student_id") %>%
      arrange(desc(total))

    body <-
      str_c(
        "| ", rows$student_id,
        " | ", formatC(rows$points_earned, format = "f", digits = 2),
        " | ", formatC(rows$style_credit, format = "f", digits = 2),
        " | **", formatC(rows$total, format = "f", digits = 2),
        "** | ", rows$wrong,
        " | ", rows$flagged,
        " |"
      )

    c(
      "## Scores",
      str_c(
        c(
          "| Student | Earned | Style | Total | Wrong | Flagged |",
          "| --- | ---: | ---: | ---: | ---: | ---: |",
          body
        ),
        collapse = "\n"
      )
    ) %>%
      str_c(collapse = "\n\n")
  }

# document ----------------------------------------------------------------

# Write the review sheet and the score table.

write_review_notes <-
  function(.problem_set, .results = NULL) {
    run <- .results %||% read_grading_results(.problem_set)

    questions <- questions_from_qmd(.problem_set)

    slots <- run$slots

    header <-
      c(
        str_c("# Problem set ", .problem_set, ": grading review"),
        str_c(
          "Generated ", format(Sys.time(), "%d %B %Y, %H:%M"), " from ",
          nrow(run$index),
          " submissions. Every mark below is a proposal, not a decision."
        ),
        c(
          "**Wrong** — the answer does not match any of the key's accepted",
          "approaches, and the points are deducted. An approach the key does",
          "not list can be settled by reversing the deduction here.",
          "",
          "**Needs review** — the answer could not be compared (it was not",
          "located, or does not parse), so **nothing is deducted** and the",
          "answer is waiting on you.",
          "",
          "Blanket policies (a function outside the list, a stray assignment,",
          "a column taken by position) are charged even on a flagged answer,",
          "because those are proved outright."
        ) %>%
          str_c(collapse = "\n")
      )

    sections <-
      map_chr(
        sort(unique(slots$question)),
        \(.q) question_section(.q, slots, run$key, questions)
      )

    c(
      str_c(header, collapse = "\n\n"),
      summary_section(run$students, slots),
      "# Answers to check",
      str_c(sections, collapse = "\n\n"),
      style_section(slots, run$questions)
    ) %>%
      str_c(collapse = "\n\n") %>%
      write_lines(review_notes_path(.problem_set))

    run$students %>%
      arrange(student_id) %>%
      mutate(across(where(is.numeric), \(.x) round(.x, 2))) %>%
      write_csv(review_scores_path(.problem_set))

    cli::cli_alert_success(
      "Wrote {.path {review_notes_path(.problem_set)}} and
       {.path {review_scores_path(.problem_set)}}."
    )

    invisible(review_notes_path(.problem_set))
  }
