# Bring course_reference.sqlite up to what the grading pipeline needs, then
# seed it from the problem set .qmd files.
#
# Two things are added:
#
#   rubric_items.parent_item_id   links a scored bullet to its question
#   allowed_functions             the functions each assignment permits
#
# Both steps are safe to re-run: the schema change is skipped when it is
# already there, and each assignment's seeded rows are replaced rather than
# appended.
#
# Run from the project root:
#
#   source("src/r/grading_db_setup.R")
#
#   setup_grading_db()
#
#   seed_grading_db(1:2)

library(tidyverse)
library(DBI)
library(RSQLite)

source("src/r/grading_db.R")
source("src/r/grading_problem_set.R")

# schema ------------------------------------------------------------------

# Add the column and table the grading pipeline reads, if they are not
# already present.

setup_grading_db <-
  function(.db_path = grading_db_path) {
    connection <- connect_grading_db(.db_path, .write = TRUE)

    on.exit(DBI::dbDisconnect(connection))

    # rubric_items was built to hold questions and policies only, and SQLite
    # cannot widen a CHECK constraint in place, so the table is rebuilt. The
    # rebuild also adds the parent link a scored bullet needs.

    ddl <-
      DBI::dbGetQuery(
        connection,
        "select sql from sqlite_master where name = 'rubric_items'"
      )$sql[1]

    if (!str_detect(ddl, "subquestion")) {
      DBI::dbExecute(connection, "pragma foreign_keys = off")

      DBI::dbBegin(connection)

      # Views built on rubric_items cannot survive the table being dropped,
      # so they are recreated from their own definitions afterwards.

      dependent_views <-
        DBI::dbGetQuery(
          connection,
          "select name, sql from sqlite_master
           where type = 'view' and sql like '%rubric_items%'"
        )

      walk(
        dependent_views$name,
        \(.view) {
          DBI::dbExecute(connection, str_glue("drop view {.view}"))
        }
      )

      DBI::dbExecute(
        connection,
        "create table rubric_items_rebuilt (
           item_id          integer primary key autoincrement,
           assignment_id    integer not null
                              references assignments(assignment_id)
                              on delete cascade,
           item_type        text not null
                              check (item_type in ('question', 'policy',
                                                   'subquestion',
                                                   'criterion')),
           item_order       integer not null,
           item_label       text not null,
           criterion        text not null,
           max_points       real,
           deduction_pct    real,
           deduction_points real,
           deduction_note   text,
           parent_item_id   integer references rubric_items(item_id),
           unique (assignment_id, item_label)
         )"
      )

      carried <-
        intersect(
          DBI::dbListFields(connection, "rubric_items"),
          DBI::dbListFields(connection, "rubric_items_rebuilt")
        ) %>%
        str_c(collapse = ", ")

      DBI::dbExecute(
        connection,
        str_glue(
          "insert into rubric_items_rebuilt ({carried})
           select {carried} from rubric_items"
        )
      )

      DBI::dbExecute(connection, "drop table rubric_items")

      DBI::dbExecute(
        connection,
        "alter table rubric_items_rebuilt rename to rubric_items"
      )

      walk(dependent_views$sql, \(.sql) DBI::dbExecute(connection, .sql))

      DBI::dbCommit(connection)

      DBI::dbExecute(connection, "pragma foreign_keys = on")

      cli::cli_alert_success(
        "Rebuilt {.field rubric_items} for scored bullets."
      )
    }

    DBI::dbExecute(
      connection,
      "create table if not exists allowed_functions (
         allowed_id    integer primary key autoincrement,
         assignment_id integer not null references assignments(assignment_id),
         function_id   integer not null references functions(function_id),
         sort_order    integer,
         unique (assignment_id, function_id)
       )"
    )

    # The empty-argument primitive is listed in every problem set but was
    # never entered in the functions table.

    DBI::dbExecute(
      connection,
      "insert or ignore into functions (package, function_name, definition)
       values ('.Primitive', '(...)',
               'Group an expression or supply a function call''s arguments.')"
    )

    invisible(.db_path)
  }

# seeding -----------------------------------------------------------------

# Match a problem set's allowed-function list to rows in the functions table.
# A listed function the table does not hold would silently drop out of the
# check, letting a submission use it for free, so it stops the run instead.

# The two pipes are interchangeable, so a list that permits one permits the
# other.
#
# The problem sets name `magrittr::%>%`, because that is the pipe the lessons
# use, and until now the native pipe was invisible to the grader anyway: R's
# parser gives `|>` a token of its own, which grading_functions.R did not map
# to a function name. With that fixed, a student who wrote `|>` would have
# been charged for a function the list does not carry -- a deduction created
# by repairing a blind spot rather than by anything the student did. Brian's
# decision, 5 September 2026: approve it wherever `%>%` is approved.
#
# Doing it here rather than in the database keeps it true after a re-seed,
# which rebuilds each list from the problem set's own text.

allow_both_pipes <-
  function(.resolved, .known) {
    if (!"%>%" %in% .resolved$function_name) return(.resolved)

    if ("|>" %in% .resolved$function_name) return(.resolved)

    native <- .known %>% filter(function_name == "|>")

    if (!nrow(native)) return(.resolved)

    .resolved %>%
      bind_rows(
        native %>%
          mutate(sort_order = max(.resolved$sort_order, na.rm = TRUE) + 1L)
      )
  }

resolve_allowed_functions <-
  function(.problem_set, .db_path = grading_db_path) {
    listed <- allowed_functions_from_qmd(.problem_set)

    known <-
      grading_query(
        "select function_id, package, function_name from functions",
        NULL,
        .db_path
      )

    resolved <-
      listed %>%
      left_join(known, by = c("package", "function_name")) %>%
      allow_both_pipes(known)

    missing <- resolved %>% filter(is.na(function_id))

    if (nrow(missing)) {
      cli::cli_abort(
        c(
          "Problem set {.val {(.problem_set)}} allows {nrow(missing)}
           function{?s} that {.field functions} does not hold:",
          set_names(
            str_c(
              missing$package,
              "::",
              missing$function_name
            ),
            "*"
          )
        )
      )
    }

    resolved
  }

# Replace one assignment's allowed-function rows.

seed_allowed_functions <-
  function(.problem_set, .db_path = grading_db_path) {
    assignment_id <- assignment_id_of(.problem_set, .db_path)

    rows <-
      resolve_allowed_functions(.problem_set, .db_path) %>%
      transmute(
        assignment_id = assignment_id,
        function_id,
        sort_order
      )

    connection <- connect_grading_db(.db_path, .write = TRUE)

    on.exit(DBI::dbDisconnect(connection))

    DBI::dbExecute(
      connection,
      "delete from allowed_functions where assignment_id = ?",
      params = list(assignment_id)
    )

    DBI::dbAppendTable(
      connection,
      "allowed_functions",
      rows
    )

    nrow(rows)
  }

# Replace one assignment's scored bullets. A bullet is a "subquestion" when
# the question has one answer slot per bullet and a "criterion" when several
# bullets judge a single answer; subscores_from_qmd() decides which from the
# blank template.

seed_rubric_subitems <-
  function(.problem_set, .db_path = grading_db_path) {
    assignment_id <- assignment_id_of(.problem_set, .db_path)

    questions <-
      grading_rubric(.problem_set, .db_path) %>%
      filter(item_type == "question")

    bullets <-
      subscores_from_qmd(.problem_set) %>%
      left_join(
        questions %>% select(
                        question = item_order,
                        parent_item_id = item_id
                      ),
        by = "question"
      )

    orphaned <- bullets %>% filter(is.na(parent_item_id))

    if (nrow(orphaned)) {
      cli::cli_abort(
        "Problem set {.val {(.problem_set)}} scores bullets under
         question{?s} {.val {unique(orphaned$question)}}, which the rubric
         does not list."
      )
    }

    rows <-
      bullets %>%
      transmute(
        assignment_id = assignment_id,
        item_type = bullet_type,
        item_order = question * 100L + bullet_order,
        item_label =
          str_c(
            "Q",
            question,
            ".",
            bullet_order
          ),
        criterion,
        max_points = points,
        parent_item_id
      )

    connection <- connect_grading_db(.db_path, .write = TRUE)

    on.exit(DBI::dbDisconnect(connection))

    DBI::dbExecute(
      connection,
      "delete from rubric_items
       where assignment_id = ?
         and item_type in ('subquestion', 'criterion')",
      params = list(assignment_id)
    )

    DBI::dbAppendTable(
      connection,
      "rubric_items",
      rows
    )

    nrow(rows)
  }

# Seed every problem set that carries the scored markup, reporting what each
# one contributed.

seed_grading_db <-
  function(.problem_sets, .db_path = grading_db_path) {
    setup_grading_db(.db_path)

    seed_one <-
      function(.problem_set) {
        functions <- seed_allowed_functions(.problem_set, .db_path)

        bullets <- seed_rubric_subitems(.problem_set, .db_path)

        cli::cli_alert_success(
          "Problem set {.val {(.problem_set)}}: {functions} allowed
           function{?s}, {bullets} scored bullet{?s}."
        )

        tibble(
          problem_set = .problem_set,
          allowed_functions = functions,
          scored_bullets = bullets
        )
      }

    map_dfr(.problem_sets, seed_one)
  }

# Check that a seeded assignment adds up: its questions must sum to the total
# the assignments table records, and each question's bullets must sum to the
# question. A mismatch is a fault in the problem set, not in a submission.

audit_rubric_totals <-
  function(.problem_set, .db_path = grading_db_path) {
    rubric <- grading_rubric(.problem_set, .db_path)

    declared <-
      grading_query(
        "select total_points from assignments where assignment_id = ?",
        list(assignment_id_of(.problem_set, .db_path)),
        .db_path
      )$total_points[1]

    questions <- rubric %>% filter(item_type == "question")

    bullets <-
      rubric %>%
      filter(item_type %in% c("subquestion", "criterion"))

    by_question <-
      bullets %>%
      group_by(parent_item_id) %>%
      summarize(
        bullet_total = sum(max_points),
        .groups = "drop"
      ) %>%
      right_join(
        questions %>%
          select(
            item_id,
            item_label,
            max_points
          ),
        by = c("parent_item_id" = "item_id")
      ) %>%
      mutate(
        agrees = is.na(bullet_total) | near(bullet_total, max_points)
      )

    list(
      problem_set = .problem_set,
      declared_total = declared,
      question_total = sum(questions$max_points),
      totals_agree = near(sum(questions$max_points), declared),
      questions = by_question,
      disagreements = by_question %>% filter(!agrees)
    )
  }
