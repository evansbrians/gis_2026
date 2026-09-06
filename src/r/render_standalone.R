# Render a standalone (non-module) .qmd to index.html, in place.
#
# For .qmd files that live alone in their own folder outside modules/
# (e.g. logistics/course_logistics.qmd), this renders normally and then
# renames the output to index.html in that same folder -- e.g.
# logistics/course_logistics.qmd -> logistics/index.html. The source
# .qmd itself is left untouched. (Lessons that share a module folder
# still use render_module()'s <lesson_name>/index.html convention,
# since those need a folder per lesson to avoid colliding.)
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

    quarto::quarto_render(.qmd_path)

    rendered_html <- fs::path_ext_set(.qmd_path, "html")
    index_path <- fs::path(fs::path_dir(.qmd_path), "index.html")

    if (fs::file_exists(index_path)) {
      fs::file_delete(index_path)
    }

    fs::file_move(rendered_html, index_path)

    cli::cli_inform("Wrote {.path {index_path}}")
  }
