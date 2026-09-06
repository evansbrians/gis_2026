# Turn the three checks into points: what each answer earned, what the
# blanket policies cost, and what style credit the question added.
#
# Where an answer needs review nothing is deducted. A slot the pipeline could
# not settle keeps its points and carries a marker instead, so a question is
# never quietly marked down on a verdict no one has looked at.
#
# Whether a question expected an assignment is read from the key rather than
# hard-coded: if the key assigns a name in that slot the student may too, and
# otherwise a name in the global environment is a stray one.
#
# Source via source("src/r/grading_score.R").

library(tidyverse)

source("src/r/grading_db.R")
source("src/r/grading_style.R")

# The share of a question's points that following the style guide adds.

style_credit_rate <- 0.1

# rubric ------------------------------------------------------------------

# What each answer slot is worth. A question whose bullets are subquestions
# splits its points among them in order; a question with criteria, or with no
# bullets at all, puts all of its points on its single answer.

slot_points <-
  function(.template_slots, .rubric) {
    questions <-
      .rubric %>%
      filter(item_type == "question") %>%
      select(
        question = item_order,
        question_points = max_points,
        question_criterion = criterion
      )

    subquestions <-
      .rubric %>%
      filter(item_type == "subquestion") %>%
      transmute(
        question = item_order %/% 100L,
        answer_order = item_order %% 100L,
        slot_points = max_points,
        criterion
      )

    .template_slots %>%
      filter(slot_type == "answer") %>%
      left_join(questions, by = "question") %>%
      left_join(subquestions, by = c("question", "answer_order")) %>%
      mutate(
        slot_points = coalesce(slot_points, question_points)
      )
  }

# The criteria attached to a question that judges one answer several ways.

question_criteria <-
  function(.rubric) {
    .rubric %>%
      filter(item_type == "criterion") %>%
      transmute(
        question = item_order %/% 100L,
        criterion_order = item_order %% 100L,
        item_label,
        criterion,
        max_points
      )
  }

# The policies that can cost points anywhere in a submission.

grading_policies <-
  function(.rubric) {
    .rubric %>%
      filter(item_type == "policy") %>%
      select(
        item_label,
        criterion,
        deduction_pct
      )
  }

# criteria ----------------------------------------------------------------

# Decide one of the mechanically checkable criteria that questions 8 and 9
# attach to a single answer. A criterion whose wording this function does not
# recognize returns NA and becomes a review flag rather than a guess.

criterion_met <-
  function(.criterion, .unapproved, .depth, .assigns, .single_pipe) {
    wording <- str_to_lower(.criterion)

    if (str_detect(wording, "functions that you may use")) {
      return(length(.unapproved) == 0)
    }

    if (str_detect(wording, "no nested function calls")) {
      return(.depth <= 1)
    }

    if (str_detect(wording, "no global assignments|no names are assigned")) {
      return(length(.assigns) == 0)
    }

    if (str_detect(wording, "connected by a pipe|piped code block")) {
      return(.single_pipe)
    }

    NA
  }

# Score every criterion of every criterion-style question. The rubric's
# wording is carried under its own name: the slots already hold a "criterion"
# column for their subquestion text, and the two must not collide.

score_criteria <-
  function(.checks, .rubric) {
    criteria <-
      question_criteria(.rubric) %>%
      rename(criterion_text = criterion)

    if (!nrow(criteria)) return(tibble())

    .checks %>%
      filter(question %in% criteria$question) %>%
      select(
        student_id, slot_id, question, unapproved, depth, assigns,
        single_pipe
      ) %>%
      left_join(
        criteria,
        by = "question",
        relationship = "many-to-many"
      ) %>%
      mutate(
        met =
          pmap_lgl(
            list(
              criterion_text,
              unapproved,
              depth,
              assigns,
              single_pipe
            ),
            \(.text, .unapproved, .depth, .assigns, .single_pipe) {
              criterion_met(
                .text,
                .unapproved,
                .depth,
                .assigns,
                .single_pipe
              )
            }
          ),
        deduction =
          if_else(
            coalesce(met, TRUE),
            0,
            max_points
          )
      )
  }

# policies ----------------------------------------------------------------

# Which uses of a function outside the assignment's list are charged for.
#
# A function is charged once, at its first use in the submission, and every
# later use of that same function is free. Two different functions outside
# the list are two charges. Slots are read in the order the student meets
# them, by question and then by answer, so the charge lands on the first one.
#
# Returns one row per slot with the number of functions charged there.

unapproved_charges <-
  function(.checks) {
    charged <-
      .checks %>%
      select(student_id, slot_id, question, answer_order, unapproved) %>%
      unnest(unapproved) %>%
      arrange(student_id, question, answer_order) %>%
      distinct(student_id, unapproved, .keep_all = TRUE) %>%
      summarize(
        unapproved_charged = list(unapproved),
        .by = c(student_id, slot_id)
      )

    .checks %>%
      select(student_id, slot_id) %>%
      left_join(charged, by = c("student_id", "slot_id")) %>%
      mutate(
        unapproved_charged =
          map(unapproved_charged, \(.names) .names %||% character(0)),
        n_unapproved_charged = lengths(unapproved_charged)
      )
  }

# What the blanket policies cost a question. Each is a share of the
# question's own points. The unapproved-function policy is charged once per
# function across the whole submission, at its first use.

score_policies <-
  function(.checks, .rubric, .key_assigns) {
    policies <- grading_policies(.rubric)

    rate_of <-
      function(.pattern) {
        found <-
          policies$deduction_pct[str_detect(policies$criterion, .pattern)]

        if (!length(found)) 0 else found[1] / 100
      }

    unapproved_rate <- rate_of("Functions that you may use")

    assignment_rate <- rate_of("assignments other than those specified")

    index_rate <- rate_of("numeric column indexing")

    .checks %>%
      left_join(.key_assigns, by = "slot_id") %>%
      left_join(
        unapproved_charges(.checks),
        by = c("student_id", "slot_id")
      ) %>%
      mutate(
        n_unapproved = lengths(unapproved),
        stray_assignment =
          !key_assigns_here & lengths(assigns) > 0,
        unapproved_cost =
          n_unapproved_charged * unapproved_rate * question_points,
        assignment_cost =
          if_else(
            stray_assignment,
            assignment_rate * question_points,
            0
          ),
        index_cost =
          if_else(
            numeric_index,
            index_rate * question_points,
            0
          )
      )
  }

# Which slots the key itself assigns a name in. A question that asked for an
# assignment cannot penalize a student for making one.

key_assignment_slots <-
  function(.key_slots) {
    .key_slots %>%
      mutate(
        key_assigns_here =
          map_lgl(
            alternatives,
            \(.alternatives) {
              .alternatives %>%
                map_int(\(.code) length(assigned_names(.code))) %>%
                any()
            }
          )
      ) %>%
      select(slot_id, key_assigns_here)
  }

# the naming question -----------------------------------------------------

# Every problem set opens by asking the student to rename the script file to
# problem_set_N_[last name]_[first name].R in snake_case, and that question
# has no answer slot because the answer is the file name itself.
#
# Blackboard prepends its own bookkeeping, so only the part the student
# supplied is judged, minus the "-1" a resubmission collects.

naming_faults <-
  function(.file_name, .problem_set, .name_source) {
    given <-
      .file_name %>%
      str_remove("\\.[Rr]$") %>%
      str_extract(
        str_c(
          "problem_set[_ ]*",
          .problem_set,
          "[_ ]*(.+)$"
        ),
        1
      ) %>%
      coalesce("") %>%
      str_remove("-\\d+$")

    faults <- character(0)

    if (given == "") {
      return("The file was not renamed as the question asked.")
    }

    if (str_detect(given, "[^a-z0-9_]")) {
      faults <-
        c(
          faults,
          str_c(
            "The file name is not snake_case: it holds ",
            "characters other than lowercase letters and underscores (",
            given,
            ")."
          )
        )
    }

    if (identical(.name_source, "reversed")) {
      faults <-
        c(faults, "The file name gives the first name before the last name.")
    }

    faults
  }

# Score the naming question for every student.

score_naming_question <-
  function(.index, .problem_set, .rubric) {
    points <-
      .rubric %>%
      filter(item_type == "question", item_order == 1) %>%
      pull(max_points)

    if (!length(points)) return(tibble())

    .index %>%
      mutate(
        question = 1L,
        question_points = points[1],
        faults =
          pmap(
            list(file_name, name_source),
            \(.file, .source) naming_faults(
                                .file,
                                .problem_set,
                                .source
                              )
          ),
        deduction =
          if_else(
            lengths(faults) > 0,
            points[1] / 2,
            0
          ),
        earned = question_points - deduction,
        style_clean = TRUE,
        needs_review = FALSE,
        style_credit = 0
      ) %>%
      select(
        student_id, question, question_points, deduction, earned,
        style_clean, needs_review, style_credit, faults
      )
  }

# scoring -----------------------------------------------------------------

# Bring every check together into one row per answer slot, with the points it
# earned and the reasons it lost any.

score_slots <-
  function(.correctness, .functions, .style, .template_slots, .rubric,
           .key_slots) {
    points <- slot_points(.template_slots, .rubric)

    joined <-
      .correctness %>%
      select(student_id, slot_id, question, answer_order, answer, found,
             verdict, reason, signature, parses,
             any_of(c("mismatch", "submission_path", "line_start",
                      "line_end"))) %>%
      left_join(
        .functions %>%
          select(student_id, slot_id, used, unapproved, unneeded_libraries,
                 numeric_index, assigns, single_pipe, depth),
        by = c("student_id", "slot_id")
      ) %>%
      left_join(
        .style %>%
          select(student_id, slot_id, violations, violation_count,
                 style_clean),
        by = c("student_id", "slot_id")
      ) %>%
      left_join(
        points %>%
          select(
            slot_id,
            slot_points,
            question_points,
            question_criterion,
            criterion
          ),
        by = "slot_id"
      )

    criteria_questions <- unique(question_criteria(.rubric)$question)

    scored <-
      joined %>%
      score_policies(.rubric, key_assignment_slots(.key_slots)) %>%
      mutate(
        # A question that hands over a badly formatted block and asks for it
        # to be repaired cannot be graded by comparison: the code reduces to
        # the same signature whether or not anything was fixed. It is graded
        # on how many of the stated faults remain, each worth an equal share
        # of the question.

        is_repair = map_lgl(question_criterion, style_repair_question),
        repair_faults =
          pmap(
            list(answer, is_repair),
            \(.answer, .repair) {
              if (.repair) style_repair_faults(.answer) else NULL
            }
          ),
        repair_unfixed = map_int(repair_faults, \(.f) sum(.f$unfixed) %||% 0L),
        repair_total = map_int(repair_faults, \(.f) nrow(.f) %||% 0L),
        correctness_cost =
          case_when(
            is_repair ~ slot_points * repair_unfixed / pmax(repair_total, 1),
            question %in% criteria_questions ~ 0,
            verdict == "incorrect" ~ slot_points,
            .default = 0
          ),

        # The repair check is deterministic, so it never needs a second look.

        needs_review =
          !is_repair & (verdict == "review" | !found | !parses)
      )

    criteria_costs <-
      score_criteria(scored, .rubric) %>%
      group_by(student_id, slot_id) %>%
      summarize(
        criteria_cost = sum(deduction),
        criteria_unmet =
          str_c(criterion_text[!coalesce(met, TRUE)], collapse = " | "),
        criteria_unknown = any(is.na(met)),
        .groups = "drop"
      )

    scored %>%
      left_join(criteria_costs, by = c("student_id", "slot_id")) %>%
      mutate(
        criteria_cost = coalesce(criteria_cost, 0),
        criteria_unknown = coalesce(criteria_unknown, FALSE),
        needs_review = needs_review | criteria_unknown,

        # A flagged answer is never marked down on the verdict that flagged
        # it. What it can still cost is what the checks proved outright: a
        # function outside the list, a name the question did not ask for, a
        # column taken by position. Those hold however the answer is finally
        # judged, and the review marker stands beside them.

        correctness_cost =
          if_else(
            needs_review,
            0,
            correctness_cost
          ),
        repair_unfixed_names =
          map_chr(
            repair_faults,
            \(.f) {
              if (is.null(.f)) return(NA_character_)

              str_c(.f$description[.f$unfixed], collapse = " | ")
            }
          ),
        criteria_cost =
          if_else(
            needs_review,
            0,
            criteria_cost
          ),
        raw_cost =
          correctness_cost + criteria_cost + unapproved_cost +
            assignment_cost + index_cost,
        deduction = pmin(raw_cost, slot_points),
        earned = slot_points - deduction,

        # Set when a person has confirmed the mark in the dashboard. The
        # pipeline never sets it: everything here is a proposal.

        reviewed = FALSE
      )
  }

# Roll the slots up to one row per question, adding the style credit. Style
# credit is all or nothing: a question earns it when every answer in it
# follows the guide.

score_questions <-
  function(.scored_slots) {
    .scored_slots %>%
      group_by(student_id, question) %>%
      summarize(
        question_points = first(question_points),
        deduction = min(sum(deduction), first(question_points)),
        earned =
          first(question_points) -
            min(sum(deduction), first(question_points)),
        style_clean = all(style_clean),
        needs_review = any(needs_review),
        .groups = "drop"
      ) %>%
      mutate(
        style_credit =
          if_else(
            style_clean,
            style_credit_rate * question_points,
            0
          )
      )
  }

# One row per student: the total earned, the style credit added, and how many
# questions still carry a review marker.

score_students <-
  function(.scored_questions, .bonus = NULL) {
    awarded <- bonus_points(.bonus)

    .scored_questions %>%
      group_by(student_id) %>%
      summarize(
        points_possible = sum(question_points),
        points_earned = sum(earned),
        style_credit = sum(style_credit),
        questions_flagged = sum(needs_review),
        .groups = "drop"
      ) %>%
      left_join(awarded, by = "student_id") %>%
      mutate(
        bonus = coalesce(bonus, 0),
        bonus_reason = bonus_reason,
        total = points_earned + style_credit + bonus
      ) %>%
      arrange(student_id)
  }

# Extra credit awarded outside the problem set itself, one row to a student.
# It is carried on the run rather than folded into an answer, because it was
# not earned on any answer: nothing in the submission accounts for it.

bonus_points <-
  function(.bonus) {
    empty <-
      tibble(
        student_id = character(0),
        bonus = numeric(0),
        bonus_reason = character(0)
      )

    if (is.null(.bonus) || !nrow(.bonus)) return(empty)

    .bonus %>%
      group_by(student_id) %>%
      summarize(
        bonus = sum(points),
        bonus_reason = str_c(unique(reason), collapse = "; "),
        .groups = "drop"
      )
  }
