# Render module lessons to <lesson_name>/index.html.
#
# Each .qmd that sits directly in modules/<.module> is rendered in place,
# then its output is moved to modules/<.module>/<lesson_name>/index.html
# (the lesson folder is created if needed). Lesson .qmd files themselves
# stay flat within the module folder.
#
# Usage (from the project root):
#
#   source("src/r/render_module.R")
#
#   # Render every lesson in a module:
#
#   render_module("module_0")
#
#   # Render one or more specific lessons:
#
#   render_module(
#     "module_0",
#     .lessons = "0.2_environment_and_functions"
#   )

render_module <-
  function(.module, .lessons = NULL) {
    if (!requireNamespace("quarto", quietly = TRUE)) {
      cli::cli_abort(
        'The quarto package is required -- install.packages("quarto").'
      )
    }

    module_dir <- fs::path("modules", .module)

    if (!fs::dir_exists(module_dir)) {
      cli::cli_abort("No module directory at {.path {module_dir}}.")
    }

    qmd_paths <- fs::dir_ls(module_dir, glob = "*.qmd")

    if (!is.null(.lessons)) {
      qmd_paths <-
        qmd_paths[
          fs::path_ext_remove(
            fs::path_file(qmd_paths)
          ) %in% .lessons
        ]
    }

    if (length(qmd_paths) == 0) {
      cli::cli_abort("No matching .qmd files found in {.path {module_dir}}.")
    }

    qmd_paths |>
      purrr::walk(
        \(.qmd_path) {
          lesson_name <-
            fs::path_ext_remove(
              fs::path_file(.qmd_path)
            )

          quarto::quarto_render(.qmd_path)

          rendered_html <- fs::path_ext_set(.qmd_path, "html")
          index_path <- fs::path(module_dir, lesson_name, "index.html")

          fs::dir_create(
            fs::path(module_dir, lesson_name)
          )

          if (fs::file_exists(index_path)) {
            fs::file_delete(index_path)
          }

          fs::file_move(rendered_html, index_path)

          cli::cli_inform("Wrote {.path {index_path}}")
        }
      )
  }
