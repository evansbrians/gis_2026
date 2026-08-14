# Render a standalone (non-module) .qmd to <doc_name>/index.html.
#
# For .qmd files that live outside modules/ (e.g.
# logistics/course_logistics.qmd), mirroring render_module()'s
# <lesson_name>/index.html convention: the .qmd is rendered in place,
# then its output is moved into a sibling folder named after it. The
# source .qmd itself is left untouched.
#
# Usage (from the project root):
#
#   source("src/r/render_standalone.R")
#
#   render_standalone("logistics/course_logistics.qmd")

render_standalone <-
  function(.qmd_path) {
    if (!requireNamespace("quarto", quietly = TRUE)) {
      cli::cli_abort(
        'The quarto package is required -- install.packages("quarto").'
      )
    }

    .qmd_path <- fs::path(.qmd_path)

    if (!fs::file_exists(.qmd_path)) {
      cli::cli_abort("No .qmd file at {.path {.qmd_path}}.")
    }

    doc_dir <- fs::path_dir(.qmd_path)
    doc_name <- fs::path_ext_remove(fs::path_file(.qmd_path))

    quarto::quarto_render(.qmd_path)

    rendered_html <- fs::path_ext_set(.qmd_path, "html")
    index_path <- fs::path(doc_dir, doc_name, "index.html")

    fs::dir_create(
      fs::path(doc_dir, doc_name)
    )

    if (fs::file_exists(index_path)) {
      fs::file_delete(index_path)
    }

    fs::file_move(rendered_html, index_path)

    cli::cli_inform("Wrote {.path {index_path}}")
  }
