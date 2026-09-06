# Serve the course reference GUI (src/reference/reference_gui.qmd) and show it
# in RStudio's Viewer pane.
#
# Two things make this necessary rather than just clicking "Run Document":
#
# 1. Quarto runs a shiny document by setting R's working directory to the
#    *project root* and then handing the document path to rmarkdown::run()
#    exactly as it was typed, so the path must be given relative to the project
#    root. RStudio's button passes only the file name, which fails with
#    "The file 'reference_gui.qmd' does not exist in the directory ...".
# 2. quarto serve runs in its own process, so it cannot reach the Viewer pane.
#    The RStudio session has to open the served URL itself.
#
# Usage (from the project root):
#
#   source("src/r/run_reference_gui.R")
#
#   gui <- run_reference_gui()
#
#   # When finished:
#
#   gui$kill()

run_reference_gui <-
  function(.qmd_path = "src/reference/reference_gui.qmd",
           .port = 4242) {
    purrr::walk(
      c("quarto", "processx", "curl", "rstudioapi", "shiny"),
      \(.package) {
        if (!requireNamespace(.package, quietly = TRUE)) {
          cli::cli_abort(
            'The {.package} package is required -- renv::install("{.package}").'
          )
        }
      }
    )

    if (!fs::file_exists(.qmd_path)) {
      cli::cli_abort(
        "No .qmd file at {.path {.qmd_path}} -- run this from the project root."
      )
    }

    app_url <- glue::glue("http://localhost:{.port}")

    reach <- purrr::possibly(curl::curl_fetch_memory, otherwise = NULL)

    server <-
      processx::process$new(
        quarto::quarto_path(),
        c("serve", .qmd_path, "--port", as.character(.port)),
        stdout = "|",
        stderr = "|"
      )

    cli::cli_inform("Rendering, then serving {.url {app_url}} ...")

    deadline <- Sys.time() + 180

    while (Sys.time() < deadline) {
      Sys.sleep(0.5)

      if (!server$is_alive()) {
        cli::cli_abort("quarto serve exited: {server$read_all_error()}")
      }

      if (!is.null(reach(app_url))) {
        if (rstudioapi::isAvailable()) {
          rstudioapi::viewer(app_url)
        } else {
          utils::browseURL(app_url)
        }

        cli::cli_inform("Stop the app with {.code gui$kill()}.")

        return(invisible(server))
      }
    }

    server$kill()
    cli::cli_abort("quarto serve did not start listening on port {.port}.")
  }
