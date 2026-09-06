# Read the grading tables out of course_reference.sqlite: the rubric for an
# assignment, the functions that assignment permits, and the comment bank the
# reports quote.
#
# Source via source("src/r/grading_db.R").

library(tidyverse)
library(DBI)
library(RSQLite)

grading_db_path <- "src/reference/course_reference.sqlite"

# Open the course reference database. Reading is the common case, so the
# connection is read-only unless a caller asks to write.

connect_grading_db <-
  function(.db_path = grading_db_path, .write = FALSE) {
    DBI::dbConnect(
      RSQLite::SQLite(),
      .db_path,
      flags =
        if (.write) RSQLite::SQLITE_RW else RSQLite::SQLITE_RO
    )
  }

# Run a query against the database and return a tibble, closing the
# connection whether or not the query succeeded.

grading_query <-
  function(.sql, .params = NULL, .db_path = grading_db_path) {
    connection <- connect_grading_db(.db_path)

    on.exit(DBI::dbDisconnect(connection))

    DBI::dbGetQuery(
      connection,
      .sql,
      params = .params
    ) %>%
      as_tibble()
  }

# The assignment_id for a problem set number.

assignment_id_of <-
  function(.problem_set, .db_path = grading_db_path) {
    found <-
      grading_query(
        "select assignment_id from assignments where assignment_name = ?",
        list(str_c("problem_set_", .problem_set)),
        .db_path
      )

    if (!nrow(found)) {
      cli::cli_abort(
        "No assignment row for problem set {.val {(.problem_set)}}."
      )
    }

    found$assignment_id[1]
  }

# Everything an assignment's rubric says: its questions, the bullets beneath
# them, and the blanket policies that can cost points anywhere.

grading_rubric <-
  function(.problem_set, .db_path = grading_db_path) {
    grading_query(
      "select
         item_id,
         parent_item_id,
         item_type,
         item_order,
         item_label,
         criterion,
         max_points,
         deduction_pct,
         deduction_points,
         deduction_note
       from rubric_items
       where assignment_id = ?
       order by item_type, item_order",
      list(assignment_id_of(.problem_set, .db_path)),
      .db_path
    )
  }

# The functions an assignment permits, as package and name.

assignment_allowed_functions <-
  function(.problem_set, .db_path = grading_db_path) {
    grading_query(
      "select
         f.function_id,
         f.package,
         f.function_name,
         a.sort_order
       from allowed_functions a
       join functions f on f.function_id = a.function_id
       where a.assignment_id = ?
       order by a.sort_order",
      list(assignment_id_of(.problem_set, .db_path)),
      .db_path
    )
  }

# The comment bank, which supplies the wording a graded report shows for
# every style violation and best-practice note.

grading_comment_bank <-
  function(.db_path = grading_db_path) {
    grading_query(
      "select comment_id, short_name, comment_class, comment_subclass,
              comment_text
       from grading_comments
       order by comment_class, comment_subclass, short_name",
      NULL,
      .db_path
    )
  }

# One comment's text, by its short name. A short name the bank does not hold
# is a mistake in the checker, not in a submission, so it stops the run.

grading_comment_text <-
  function(.short_name, .bank = NULL) {
    bank <- .bank %||% grading_comment_bank()

    found <- bank$comment_text[bank$short_name == .short_name]

    if (!length(found)) {
      cli::cli_abort("No grading comment named {.val {(.short_name)}}.")
    }

    found[1]
  }
