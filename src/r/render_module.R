# Render module lessons to <lesson_name>/index.html.
#
# Each .qmd that sits directly in modules/<.module> is rendered in place,
# then its output is moved to modules/<.module>/<lesson_name>/index.html
# (the lesson folder is created if needed). Lesson .qmd files themselves
# stay flat within the module folder.
#
# A render is isolated to the lessons named. Quarto builds a project context
# before it renders anything, and building it resolves the full markdown of
# every input file in the project, includes expanded. One broken
# `{{< include >}}` anywhere -- in another module, in a folder of retired
# drafts -- therefore stops a render of any lesson, which is how a stale
# path under module_3 came to break a render of 2.1.
#
# So each render is given a Quarto profile naming only the files being
# rendered. `project: render:` in that profile is what the project scan
# walks, so nothing else in the repository is read at all. The profile is
# written before the render and removed afterwards, and _quarto.yml is not
# touched.
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

# The profile a render runs under. Named for this file so a profile of
# Brian's own can never be the one that gets deleted.

render_profile_name <- "render_module_scope"

render_profile_path <-
  function(.profile = render_profile_name) {
    fs::path(stringr::str_c("_quarto-", .profile, ".yml"))
  }

# Write the profile that limits the project scan to these files.

write_render_profile <-
  function(.paths, .profile = render_profile_name) {
    path <- render_profile_path(.profile)

    if (fs::file_exists(path)) {
      cli::cli_abort(
        c(
          "A profile is already at {.path {path}}.",
          i = "An earlier render left it behind, or the name is in use.
               Delete it and try again."
        )
      )
    }

    c(
      "# Written by render_module() and deleted when it finishes. It limits",
      "# Quarto's project scan to the lessons being rendered, so a fault in",
      "# an unrelated file cannot stop this render.",
      "",
      "project:",
      "  render:",
      stringr::str_c("    - ", as.character(.paths))
    ) %>%
      readr::write_lines(path)

    path
  }

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
      # Accept lesson names with or without a trailing .qmd, so
      # .lessons = "0.3_values" and .lessons = "0.3_values.qmd" both work.
      # Note: a lesson name contains a dot, so we strip a trailing ".qmd"
      # rather than an "extension" -- fs::path_ext_remove() reduces
      # "0.3_values" to "0", because everything after the last dot is an
      # extension to it.
      .lessons <- stringr::str_remove(.lessons, "[.]qmd$")

      qmd_paths <-
        qmd_paths[
          stringr::str_remove(
            fs::path_file(qmd_paths),
            "[.]qmd$"
          ) %in% .lessons
        ]
    }

    if (length(qmd_paths) == 0) {
      cli::cli_abort("No matching .qmd files found in {.path {module_dir}}.")
    }

    # The profile is set here and put back however this function ends,
    # including on an error inside a render.

    previous_profile <- Sys.getenv("QUARTO_PROFILE", unset = NA)

    Sys.setenv(QUARTO_PROFILE = render_profile_name)

    on.exit(
      {
        if (is.na(previous_profile)) {
          Sys.unsetenv("QUARTO_PROFILE")
        } else {
          Sys.setenv(QUARTO_PROFILE = previous_profile)
        }

        path <- render_profile_path()

        if (fs::file_exists(path)) fs::file_delete(path)
      },
      add = TRUE
    )

    qmd_paths |>
      purrr::walk(
        \(.qmd_path) {
          lesson_name <-
            fs::path_ext_remove(
              fs::path_file(.qmd_path)
            )

          # One lesson at a time rather than the whole batch at once, so a
          # lesson that will not render stops only itself. Rendering a
          # module whose fourth lesson is broken still writes the first
          # three.

          profile_path <- write_render_profile(.qmd_path)

          quarto::quarto_render(.qmd_path)

          fs::file_delete(profile_path)

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
