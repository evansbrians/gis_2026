# Database helpers for the course reference GUI (src/reference/reference_gui.qmd).
# Reads are lazy dbplyr queries; writes go through DBI so that they do not
# depend on the dbplyr `rows_*()` copy semantics, which change between versions.
# Every function takes an open DBI connection as its first argument.

# connection --------------------------------------------------------------

# Path to course_reference.sqlite, from the project root or from src/reference:

reference_db_path <-
  function() {
    c("src/reference/course_reference.sqlite", "course_reference.sqlite") %>%
      keep(fs::file_exists) %>%
      first()
  }

# Open a read-write connection to the course reference database:

reference_connect <-
  function(.path = reference_db_path()) {
    con <-
      DBI::dbConnect(
        RSQLite::SQLite(),
        .path
      )
    DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
    con
  }

# reading -----------------------------------------------------------------

# Read a table or view into a tibble:

read_reference <-
  function(.con, .table) {
    tbl(.con, .table) %>%
      collect()
  }

# Row counts for every table the GUI edits:

reference_counts <-
  function(.con) {
    c(
      "functions",
      "glossary",
      "datasets",
      "grading_comments",
      "assignments",
      "rubric_items",
      "lessons"
    ) %>%
      set_names() %>%
      map_int(
        \(.table) {
          tbl(.con, .table) %>%
            summarize(n = n()) %>%
            pull(n)
        }
      )
  }

# writing -----------------------------------------------------------------

# Append rows to a table (omit the primary key -- SQLite assigns it):

append_reference <-
  function(.con, .table, .values) {
    DBI::dbAppendTable(.con, .table, .values)
  }

# The primary key of the row that was just appended:

last_reference_id <-
  function(.con) {
    DBI::dbGetQuery(.con, "SELECT last_insert_rowid() AS id") %>%
      pull(id)
  }

# Update the one row of a table whose key column matches .values[[.by]]:

update_reference <-
  function(.con, .table, .values, .by) {
    edited <-
      .values %>%
      select(!all_of(.by))

    DBI::dbExecute(
      .con,
      str_c(
        "UPDATE ", .table,
        " SET ", str_flatten_comma(str_c(names(edited), " = ?")),
        " WHERE ", .by, " = ?"
      ),
      params =
        c(
          as.list(edited),
          as.list(.values[[.by]])
        ) %>%
        unname()
    )
  }

# Delete every row of a table whose key column holds .id:

delete_reference <-
  function(.con, .table, .key, .id) {
    DBI::dbExecute(
      .con,
      str_c("DELETE FROM ", .table, " WHERE ", .key, " = ?"),
      params = list(.id)
    )
  }

# Delete a row along with every link to it held in .usage_tables:

delete_with_usage <-
  function(.con, .table, .usage_tables, .key, .id) {
    walk(
      .usage_tables,
      \(.usage_table) {
        delete_reference(.con, .usage_table, .key, .id)
      }
    )

    delete_reference(.con, .table, .key, .id)
  }

# Delete an assignment, its rubric items, and their grading-comment links:

delete_assignment <-
  function(.con, .assignment_id) {
    DBI::dbExecute(
      .con,
      "DELETE FROM rubric_item_comments
       WHERE item_id IN
         (SELECT item_id FROM rubric_items WHERE assignment_id = ?)",
      params = list(.assignment_id)
    )

    delete_reference(.con, "rubric_items", "assignment_id", .assignment_id)
    delete_reference(.con, "assignments", "assignment_id", .assignment_id)
  }

# usage links -------------------------------------------------------------

# Lesson ids currently linked to one function or glossary term:

usage_lessons <-
  function(.con, .table, .key, .id) {
    tbl(.con, .table) %>%
      filter(.data[[.key]] == !!.id) %>%
      pull(lesson_id)
  }

# Replace the set of lessons linked to one function or glossary term:

sync_usage <-
  function(.con, .table, .key, .id, .lesson_ids) {
    delete_reference(.con, .table, .key, .id)

    new_links <-
      tibble(lesson_id = as.integer(.lesson_ids)) %>%
      mutate("{.key}" := as.integer(.id), .before = lesson_id)

    if (nrow(new_links) > 0) {
      append_reference(.con, .table, new_links)
    }
  }
