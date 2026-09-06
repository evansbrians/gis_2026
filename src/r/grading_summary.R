# Build the instructor's summary of a graded problem set: how the class did,
# where the points went by question, and by the kind of fault.
#
# The page is about the class. No student is named on it: an individual mark
# belongs in that student's graded file and in the scores csv.
#
# Usage from the project root:
#
#   source("src/r/grading_summary.R")
#
#   write_grade_summary(1)
#
# The page is written straight to html so it opens without a render step.
#
# One thing it deliberately does not do: split a single deduction across the
# reasons behind it. An answer's deduction is capped at what the answer is
# worth, and a re-marked answer carries one number a person chose, so the
# amount "for" each reason is not recoverable. Points are therefore reported
# against the question, where they are exact, and each fault is counted by
# the answers carrying it.
#
# Source via source("src/r/grading_summary.R").

library(tidyverse)

source("src/r/grading_pipeline.R")

# Where the summary is written.

grade_summary_path <-
  function(.problem_set) {
    file.path(
      problem_set_dir(.problem_set),
      str_c("problem_set_", .problem_set, "_summary.html")
    )
  }

# classification ----------------------------------------------------------

# The kind of fault a written reason describes, read from its wording. The
# reasons are written by hand in the dashboard as well as by the checks, so
# the wording is what there is to go on; anything unmatched is reported as
# "Other" rather than guessed at.

fault_classes <-
  tribble(
    ~fault,                          ~pattern,
    "Unapproved function",           "outside the list|Functions that you may use",
    "Unrequested global assignment", "Assigns a name the question did not ask for|no global assignments|names are assigned|global assignment",
    "File naming",                   "file name",
    "Style guide repair",            "removing comments|comments should not be removed|changing the code output|style guide|Code and comments|Indentation|line of code|one line|own line|prefix function|blank line|line break|assignment operator|leading and trailing|snake_case|hashtag|three or more arguments",
    "Column taken by position",      "numeric indices|column by position",
    "Incorrect answer",              "does not match an accepted approach|an accepted approach uses|which no accepted approach|does not answer|did not replicate|not functioning|returned a tibble|does not generate|Incorrect|subsets to|arranged|collapsed a single step|pipe at the end"
  )

reason_fault <-
  function(.reason) {
    map_chr(
      .reason,
      \(.one) {
        hit <-
          fault_classes$fault[
            map_lgl(
              fault_classes$pattern,
              \(.p) str_detect(.one, regex(.p, ignore_case = TRUE))
            )
          ]

        if (!length(hit)) "Other" else hit[1]
      }
    )
  }

# One row per reason printed on a graded answer, with the answer it sits on.

fault_rows <-
  function(.results) {
    slots <- .results$slots

    answers <-
      map_dfr(
        seq_len(nrow(slots)),
        \(.i) {
          slot <- slots[.i, ]

          if (slot$deduction <= 0) return(tibble())

          reasons <- split_reasons(slot, .results$bank)$charged

          if (!length(reasons)) reasons <- "Other"

          tibble(
            student_id = slot$student_id,
            question = slot$question,
            slot_id = slot$slot_id,
            points_off = slot$deduction,
            reason = reasons
          )
        }
      )

    naming <-
      .results$naming %>%
      filter(deduction > 0) %>%
      transmute(
        student_id,
        question,
        slot_id = NA_integer_,
        points_off = deduction,
        reason = map_chr(faults, \(.f) str_c(.f, collapse = " "))
      )

    bind_rows(answers, naming) %>%
      mutate(fault = reason_fault(reason))
  }

# html --------------------------------------------------------------------

escape_html <-
  function(.text) {
    .text %>%
      str_replace_all("&", "&amp;") %>%
      str_replace_all("<", "&lt;") %>%
      str_replace_all(">", "&gt;")
  }

# A data frame as an html table, numbers right-aligned.

html_table <-
  function(.data, .caption = NULL) {
    numeric_column <- map_lgl(.data, is.numeric)

    # A count column reads as a count, not as a mark.

    whole_column <-
      map_lgl(
        .data,
        \(.x) is.numeric(.x) && all(.x[!is.na(.x)] %% 1 == 0)
      )

    header <-
      str_c(
        "<th class=\"",
        if_else(numeric_column, "num", "txt"),
        "\">",
        escape_html(names(.data)),
        "</th>",
        collapse = ""
      )

    body <-
      map_chr(
        seq_len(nrow(.data)),
        \(.i) {
          cells <-
            map_chr(
              seq_along(.data),
              \(.j) {
                value <- .data[[.j]][.i]

                shown <-
                  if (is.numeric(value)) {
                    if (is.na(value)) {
                      ""
                    } else {
                      formatC(
                        value,
                        format = "f",
                        digits = if (whole_column[.j]) 0 else 2
                      )
                    }
                  } else {
                    escape_html(as.character(coalesce(value, "")))
                  }

                str_c(
                  "<td class=\"",
                  if (numeric_column[.j]) "num" else "txt",
                  "\">",
                  shown,
                  "</td>"
                )
              }
            )

          str_c("<tr>", str_c(cells, collapse = ""), "</tr>")
        }
      )

    str_c(
      if (is.null(.caption)) {
        ""
      } else {
        str_c("<h2>", escape_html(.caption), "</h2>")
      },
      "<table><thead><tr>", header, "</tr></thead><tbody>",
      str_c(body, collapse = ""),
      "</tbody></table>"
    )
  }

summary_styles <-
  "
<style>
body { font-family: system-ui, sans-serif; margin: 2em auto; max-width: 70em;
       color: #222222; line-height: 1.5; }
h1 { font-size: 1.6em; margin-bottom: 0; }
h2 { font-size: 1.15em; margin-top: 2em; border-bottom: 1px solid #cccccc;
     padding-bottom: 0.2em; }
p.lede { color: #5d5d70; margin-top: 0.3em; }
p.note { background-color: #ffffdd; border: 1px solid #999999;
         border-radius: 10px; padding: 0.75em; }
table { border-collapse: collapse; width: 100%; margin-top: 0.6em;
        font-size: 0.92em; }
th, td { padding: 0.28em 0.55em; border-bottom: 1px solid #e4e4e4; }
th { background-color: #f4f4f4; text-align: left; }
td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
tbody tr:hover { background-color: #f9f9f2; }
</style>
"

# the report --------------------------------------------------------------

# Write the summary and return its path.

write_grade_summary <-
  function(.problem_set, .results = NULL) {
    results <- .results %||% read_grading_results(.problem_set)

    faults <- fault_rows(results)

    grades <-
      tibble(
        Measure = c("Grade", "Points earned"),
        values =
          list(
            results$students$total,
            results$students$points_earned
          )
      ) %>%
      transmute(
        Measure,
        n = map_int(values, length),
        Mean = map_dbl(values, mean),
        Median = map_dbl(values, median),
        SD = map_dbl(values, sd),
        `Standard error` = map_dbl(values, \(.x) sd(.x) / sqrt(length(.x))),
        Lowest = map_dbl(values, min),
        Highest = map_dbl(values, max)
      )

    by_question <-
      results$questions %>%
      group_by(Question = question) %>%
      summarize(
        Worth = first(question_points),
        `Points off` = sum(deduction),
        `Mean off` = mean(deduction),
        `Most off` = max(deduction),
        Students = sum(deduction > 0),
        .groups = "drop"
      )

    fault_by_question <-
      faults %>%
      count(Fault = fault, Question = question) %>%
      pivot_wider(names_from = Question, values_from = n, values_fill = 0,
                  names_prefix = "Q") %>%
      arrange(Fault)

    fault_totals <-
      faults %>%
      group_by(Fault = fault) %>%
      summarize(
        Answers = n(),
        Students = n_distinct(student_id),
        `Points off on those answers` =
          sum(points_off[!duplicated(str_c(student_id, slot_id))]),
        .groups = "drop"
      ) %>%
      arrange(desc(Answers))

    unmatched <-
      faults %>%
      filter(fault == "Other") %>%
      count(Reason = reason, name = "Answers") %>%
      arrange(desc(Answers))

    page <-
      c(
        "<!doctype html><html><head><meta charset=\"utf-8\">",
        str_c(
          "<title>",
          escape_html(problem_set_title(.problem_set)),
          " summary</title>"
        ),
        summary_styles,
        "</head><body>",
        str_c("<h1>", escape_html(problem_set_title(.problem_set)), "</h1>"),
        str_c(
          "<p class=\"lede\">Grading summary, ",
          format(Sys.time(), "%e %B %Y, %H:%M"),
          ", from ", nrow(results$index), " submissions.</p>"
        ),
        str_c(
          "<p class=\"note\"><strong>This page reports the class, not the ",
          "student.</strong> Individual marks are in the graded files and in ",
          "<code>problem_set_", .problem_set, "_scores.csv</code>. ",
          "<strong>How to read the fault tables.</strong> ",
          "An answer's deduction is capped at what that answer is worth, and ",
          "a re-marked answer carries one number chosen by hand, so how much ",
          "of it was &ldquo;for&rdquo; each reason is not recoverable. Points ",
          "are therefore exact by question and by student, and each fault is ",
          "counted by the answers carrying it. An answer with two reasons is ",
          "counted under both.</p>"
        ),
        html_table(grades, "Grades"),
        html_table(by_question, "Points off by question"),
        html_table(fault_totals, "Faults, across the class"),
        html_table(
          fault_by_question,
          "Answers carrying each fault, by question"
        ),
        if (nrow(unmatched)) {
          html_table(unmatched, "Reasons the classifier could not place")
        } else {
          "<h2>Reasons the classifier could not place</h2><p>None.</p>"
        },
        "</body></html>"
      )

    path <- grade_summary_path(.problem_set)

    write_lines(page, path)

    cli::cli_alert_success("Wrote {.path {path}}.")

    path
  }
