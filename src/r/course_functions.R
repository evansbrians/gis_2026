# Functions used to build the HTML lesson pages themselves (as opposed to
# functions taught as course content -- see gis_functions.R for those).
# Sourced by every lesson .qmd via:
#   source("src/r/course_functions.R")

# Render a lesson's "Functions" reference table from its per-lesson
# function_tables/*.csv file. Used inside the Reference > Functions
# accordion of every lesson.
#
# function_tables/ stays local to each module (it is not part of the
# shared top-level data/scripts consolidation), so this resolves the path
# against the currently-rendering document's own directory via Quarto's
# QUARTO_DOCUMENT_PATH environment variable rather than the R session's
# working directory (which is the project root under execute-dir: project).

render_function_table <-
  function(.csv_name, .align = c("c", "c", "l")) {
    file.path(
      Sys.getenv("QUARTO_DOCUMENT_PATH"),
      "function_tables",
      .csv_name) |>
      read_csv() |>
      kableExtra::kable(align = .align) |>
      kableExtra::kable_styling(
        font_size = 12,
        bootstrap_options = "hover"
      )
  }
