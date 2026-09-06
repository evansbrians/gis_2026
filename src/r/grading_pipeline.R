# Run a problem set from its submissions archive to a folder of graded .qmd
# files, and keep the results so the dashboard can read them back.
#
# Usage from the project root:
#
#   source("src/r/grading_pipeline.R")
#
#   results <- grade_problem_set(1)
#
#   write_graded_reports(1, results$index, results$slots, results$questions)
#
# Or in one step:
#
#   results <- grade_problem_set(1, .write_reports = TRUE)
#
# Grading a problem set does not run any student code: each answer is judged
# by its code alone, compared to the key's accepted alternatives, and the
# submissions are only read.
#
# Source via source("src/r/grading_pipeline.R").

library(tidyverse)

source("src/r/grading_db.R")
source("src/r/grading_problem_set.R")
source("src/r/grading_submissions.R")
source("src/r/grading_functions.R")
source("src/r/grading_correctness.R")
source("src/r/grading_style.R")
source("src/r/grading_score.R")
source("src/r/grading_report.R")

# Where a run's results are kept between the pipeline and the dashboard.

grading_results_path <-
  function(.problem_set) {
    file.path(
      problem_set_dir(.problem_set),
      str_c(
        "problem_set_",
        .problem_set,
        "_grading.rds"
      )
    )
  }

# Run every check over every submission and score the result.

grade_problem_set <-
  function(.problem_set,
           .write_reports = FALSE,
           .save = TRUE,
           .bonus = NULL) {
    cli::cli_h1("Problem set {.val {(.problem_set)}}")

    index <- submission_index(.problem_set)

    cli::cli_alert_info("{nrow(index)} submission{?s}.")

    template <- template_slots(.problem_set)

    key <- key_slots(.problem_set)

    rubric <- grading_rubric(.problem_set)

    allowed <- assignment_allowed_functions(.problem_set)

    bank <- grading_comment_bank()

    bonus <- .bonus

    slots <- submission_slots(.problem_set, index)

    unlocated <- sum(!slots$found)

    if (unlocated) {
      cli::cli_alert_warning(
        "{unlocated} answer slot{?s} could not be located and will be flagged."
      )
    }

    cli::cli_alert_info("Checking functions.")

    functions <-
      check_functions(
        slots,
        .problem_set,
        allowed
      )

    cli::cli_alert_info("Checking answers against the key.")

    correctness <-
      check_correctness(slots, key)

    cli::cli_alert_info("Checking style.")

    style <- check_style(slots, bank)

    scored_slots <-
      score_slots(
        correctness,
        functions,
        style,
        template,
        rubric,
        key
      )

    naming <-
      score_naming_question(
        index,
        .problem_set,
        rubric
      )

    scored_questions <-
      bind_rows(
        naming,
        score_questions(scored_slots)
      ) %>%
      arrange(student_id, question)

    students <- score_students(scored_questions, bonus)

    cli::cli_alert_success(
      "Scored {nrow(students)} student{?s};
       {sum(students$questions_flagged)} question{?s} flagged for review."
    )

    results <-
      list(
        problem_set = .problem_set,
        graded_at = Sys.time(),
        index = index,
        template = template,
        key = key,
        rubric = rubric,
        allowed = allowed,
        bank = bank,
        bonus = bonus,
        slots = scored_slots,
        questions = scored_questions,
        naming = naming,
        students = students
      )

    if (.save) saveRDS(results, grading_results_path(.problem_set))

    if (.write_reports) {
      paths <-
        write_graded_reports(
          .problem_set,
          index,
          scored_slots,
          scored_questions,
          .bank = bank,
          .bonus = bonus
        )

      cli::cli_alert_success("Wrote {length(paths)} graded report{?s}.")

      results$reports <- paths
    }

    results
  }

# Read back a saved run.

read_grading_results <-
  function(.problem_set) {
    path <- grading_results_path(.problem_set)

    if (!file.exists(path)) {
      cli::cli_abort(
        "No saved run for problem set {.val {(.problem_set)}} --
         call {.code grade_problem_set({(.problem_set)})} first."
      )
    }

    readRDS(path)
  }

# Apply the overrides the dashboard collected and save the run again. An
# override clears the review marker on the slot it settles.

# The style-credit overrides a run carries, with anything in this save added
# to them. A blank entry removes an override rather than storing an empty
# one, so a credit put back to what the checks decided stops being an
# override at all.

style_overrides_kept <-
  function(.results, .overrides) {
    kept <-
      .results$style_overrides %||%
      tibble(
        student_id = character(0),
        question = integer(0),
        style_credit = numeric(0)
      )

    if (!has_name(.overrides, "new_style_credit")) return(kept)

    incoming <-
      .overrides %>%
      filter(!is.na(new_style_credit)) %>%
      transmute(
        student_id,
        question = as.integer(question),
        style_credit = new_style_credit
      ) %>%
      distinct(student_id, question, .keep_all = TRUE)

    if (!nrow(incoming)) return(kept)

    kept %>%
      anti_join(incoming, by = c("student_id", "question")) %>%
      bind_rows(incoming)
  }

# Replace the computed style credit wherever one was set by hand.

apply_style_overrides <-
  function(.questions, .overrides) {
    if (is.null(.overrides) || !nrow(.overrides)) return(.questions)

    .questions %>%
      left_join(
        .overrides %>% rename(style_credit_set = style_credit),
        by = c("student_id", "question")
      ) %>%
      mutate(
        style_credit = coalesce(style_credit_set, style_credit),
        style_overridden = !is.na(style_credit_set)
      ) %>%
      select(-style_credit_set)
  }

# Carry the review decisions of an earlier run onto a fresh grade.
#
# grade_problem_set() rebuilds every proposal from the submissions, so a
# re-grade after a fix to the checks would otherwise discard the deductions
# and notes already settled in the dashboard. The decisions are keyed on
# (student_id, slot_id), which survives a re-grade because a slot's id comes
# from the blank template rather than from the run, so they can simply be
# replayed.
#
# Only slots a person actually decided are carried: a slot is reviewed when
# its deduction was set in the dashboard, or when a note was written on it.
# Everything else is left as the fresh grade proposes it, which is the point
# of re-grading.
#
# The carried run is saved as it is built, so nothing further is called:
#
#   fresh <- grade_problem_set(1, .save = FALSE)
#   fresh <- carry_review_forward(fresh, read_grading_results(1))

carry_review_forward <-
  function(.results, .previous) {
    slots <- .previous$slots

    decided <-
      if (is.null(slots) || !nrow(slots)) {
        NULL
      } else {
        slots %>%
          filter(
            coalesce(reviewed, FALSE) |
              (!is.na(override_note) & nzchar(override_note))
          )
      }

    style <- .previous$style_overrides

    if (!NROW(decided) && !NROW(style)) return(.results)

    # The credits set by hand go back on the run before the slot decisions
    # are applied, because apply_overrides() rescores the questions and the
    # students from them and then saves what it has built. Restoring them
    # after that call would leave them out of the saved run.

    .results$style_overrides <- style

    # Extra credit was awarded outside the submission, so a re-grade of the
    # submission has no way to rediscover it.

    .results$bonus <- .results$bonus %||% .previous$bonus

    carried <-
      if (NROW(decided)) {
        apply_overrides(
          .results,
          decided %>%
            transmute(
              student_id,
              slot_id,
              question,
              new_deduction =
                if_else(coalesce(reviewed, FALSE), deduction, NA_real_),
              new_note =
                if_else(
                  !is.na(override_note) & nzchar(override_note),
                  override_note,
                  NA_character_
                )
            )
        )
      } else {
        rescore_style_only(.results)
      }

    cli::cli_alert_success(
      "Carried {NROW(decided)} reviewed slot{?s} and {NROW(style)}
       style override{?s} forward from the previous run."
    )

    carried
  }

# Re-apply the style credits and save, for a run with nothing else carried.

rescore_style_only <-
  function(.results) {
    .results$questions <-
      apply_style_overrides(
        .results$questions,
        .results$style_overrides
      )

    .results$students <- score_students(.results$questions, .results$bonus)

    saveRDS(.results, grading_results_path(.results$problem_set))

    .results
  }

apply_overrides <-
  function(.results, .overrides) {
    if (!nrow(.overrides)) return(.results)

    # A note saved earlier must survive a later save that leaves the note
    # box empty, so the column is created once and then only added to. The
    # same guard lets a run saved by an older version of the pipeline, which
    # carried neither column, be reviewed without being re-graded.

    carried <- .results$slots

    if (!has_name(carried, "override_note")) {
      carried <- carried %>% mutate(override_note = NA_character_)
    }

    if (!has_name(carried, "reviewed")) {
      carried <- carried %>% mutate(reviewed = FALSE)
    }

    updated <-
      carried %>%
      left_join(
        .overrides %>%
          select(
            student_id,
            slot_id,
            new_deduction,
            new_note
          ),
        by = c("student_id", "slot_id")
      ) %>%
      mutate(
        deduction = coalesce(new_deduction, deduction),
        earned = slot_points - deduction,
        override_note = coalesce(new_note, override_note),
        needs_review = needs_review & is.na(new_deduction),
        reviewed = reviewed | !is.na(new_deduction)
      ) %>%
      select(-new_deduction, -new_note)

    .results$slots <- updated

    # The naming question has no answer slot, so its row is carried across
    # rather than recomputed -- rescoring the slots alone would drop it and
    # the totals would fall short by its points.

    # Style credit is a property of a question rather than of one answer, and
    # score_questions() recomputes it from the answers every time, so an
    # override cannot live on the questions table -- it would be wiped by the
    # next save. It is kept beside the run and re-applied here.

    .results$style_overrides <-
      style_overrides_kept(.results, .overrides)

    .results$questions <-
      bind_rows(
        .results$naming,
        score_questions(updated)
      ) %>%
      arrange(student_id, question) %>%
      apply_style_overrides(.results$style_overrides)

    .results$students <- score_students(.results$questions, .results$bonus)

    saveRDS(.results, grading_results_path(.results$problem_set))

    .results
  }

# The accepted answer as it will sit in the key: no carriage returns, no
# trailing whitespace, no outer blank lines, and the block's shared
# indentation removed.

accepted_answer_code <-
  function(.answer) {
    lines <-
      .answer %>%
      str_remove_all("\r") %>%
      str_split_1("\n") %>%
      str_trim(side = "right")

    filled <- which(lines != "")

    lines <- lines[min(filled):max(filled)]

    # Remove the indentation the whole block shares:

    pad <-
      lines[lines != ""] %>%
      str_extract("^ *") %>%
      nchar() %>%
      min()

    lines %>%
      str_sub(pad + 1) %>%
      str_c(collapse = "\n")
  }

# Accept one student's unexpected answer: add it to the key file as a new
# alternative, and mark this and every matching unreviewed proposal on the
# same slot correct. Future runs read the key file, so the acceptance holds
# without further bookkeeping.

accept_alternative <-
  function(.results, .student_id, .slot_id) {
    slot <-
      .results$slots %>%
      filter(
        student_id == .student_id,
        slot_id == .slot_id
      )

    if (!nrow(slot)) return(.results)

    code <- accepted_answer_code(slot$answer[1])

    key_row <- which(.results$key$slot_id == .slot_id)

    alternatives <- .results$key$alternatives[[key_row]]

    # Already accepted: nothing to add and nothing left to flip.

    if (isTRUE(signature_matches(code, alternatives))) return(.results)

    append_key_alternative(
      .results$problem_set,
      .slot_id,
      code
    )

    .results$key$alternatives[[key_row]] <- c(alternatives, code)

    accepted <- answer_signature(code)

    updated <-
      .results$slots %>%
      mutate(
        flipped =
          slot_id == .slot_id &
            verdict == "incorrect" &
            !reviewed &
            map_lgl(
              answer,
              \(.answer) {
                isTRUE(answer_signature(.answer) == accepted)
              }
            ),
        signature = signature | flipped,
        verdict =
          if_else(
            flipped,
            "correct",
            verdict
          ),
        reason =
          if_else(
            flipped,
            NA_character_,
            reason
          ),
        raw_cost =
          if_else(
            flipped,
            raw_cost - correctness_cost,
            raw_cost
          ),
        correctness_cost =
          if_else(
            flipped,
            0,
            correctness_cost
          ),
        deduction =
          if_else(
            flipped,
            pmin(raw_cost, slot_points),
            deduction
          ),
        earned = slot_points - deduction,
        reviewed = reviewed | flipped
      ) %>%
      select(!flipped)

    .results$slots <- updated

    .results$questions <-
      bind_rows(
        .results$naming,
        score_questions(updated)
      ) %>%
      arrange(student_id, question) %>%
      apply_style_overrides(.results$style_overrides)

    .results$students <- score_students(.results$questions, .results$bonus)

    saveRDS(.results, grading_results_path(.results$problem_set))

    .results
  }
