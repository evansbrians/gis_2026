# Serve the grading dashboard (src/reference/grading_dashboard.qmd) and show
# it in RStudio's Viewer pane.
#
# This mirrors run_reference_gui.R, and for the same two reasons: quarto runs
# a shiny document with the working directory set to the project root and the
# document path taken as typed, so the path has to be given from the root;
# and quarto serve runs in its own process, so the RStudio session has to
# open the served URL itself.
#
# It also refuses to hand back a server it did not start. An earlier
# `quarto serve` that outlived its R session goes on answering on its port,
# and a launcher that waits for "something answers at this address" will
# happily attach to it: the new process dies on the port collision, the
# Viewer opens the old process's stale render, and every edit afterwards
# appears to have no effect. Serving on a port nothing is answering on is
# what stops that.
#
# Usage (from the project root):
#
#   source("src/r/grading_pipeline.R")
#
#   grade_problem_set(1)
#
#   source("src/r/run_grading_dashboard.R")
#
#   dashboard <- run_grading_dashboard(1)
#
#   # When finished:
#
#   dashboard$kill()

# Whether anything is already answering on a port.

dashboard_port_free <-
  function(.port, .timeout = 1) {
    handle <- curl::new_handle(connecttimeout = .timeout, timeout = .timeout)

    answer <-
      purrr::possibly(curl::curl_fetch_memory, otherwise = NULL)(
        glue::glue("http://localhost:{.port}"),
        handle = handle
      )

    is.null(answer)
  }

# The first port from .from upward that nothing is answering on.

dashboard_free_port <-
  function(.from = 4243, .tries = 20) {
    for (port in seq(.from, .from + .tries)) {
      if (dashboard_port_free(port)) return(port)
    }

    cli::cli_abort(
      "Ports {.val {(.from)}} to {.val {(.from + .tries)}} are all in use."
    )
  }

run_grading_dashboard <-
  function(.problem_set = 1,
           .qmd_path = "src/reference/grading_dashboard.qmd",
           .port = NULL) {
    purrr::walk(
      c(
        "quarto",
        "processx",
        "curl",
        "rstudioapi",
        "shiny",
        "DT"
      ),
      \(.package) {
        if (!requireNamespace(.package, quietly = TRUE)) {
          cli::cli_abort(
            'The {(.package)} package is required --
             renv::install("{(.package)}").'
          )
        }
      }
    )

    if (!fs::file_exists(grading_results_path(.problem_set))) {
      cli::cli_abort(
        c(
          "Problem set {.val {(.problem_set)}} has not been graded.",
          i = "Call {.code grade_problem_set({(.problem_set)})} first."
        )
      )
    }

    if (!fs::file_exists(.qmd_path)) {
      cli::cli_abort(
        "No .qmd file at {.path {(.qmd_path)}} --
         run this from the project root."
      )
    }

    # A port the caller named has to be free; otherwise find one.

    if (is.null(.port)) {
      .port <- dashboard_free_port()
    } else if (!dashboard_port_free(.port)) {
      cli::cli_abort(
        c(
          "Something is already answering on port {.val {(.port)}}.",
          i = "It is most likely an earlier {.code quarto serve} that outlived
               its R session, and it will keep serving its own stale render.",
          i = "Find it with {.code lsof -ti tcp:{(.port)}} and stop it with
               {.code kill $(lsof -ti tcp:{(.port)})}, or call this function
               without {.arg .port} to use the next free one."
        )
      )
    }

    app_url <- glue::glue("http://localhost:{.port}")

    reach <- purrr::possibly(curl::curl_fetch_memory, otherwise = NULL)

    # Everything quarto prints goes to a file beside the document, both
    # streams together.
    #
    # Held in a file rather than a pipe because of how this fails when it
    # fails: an error while the app is running kills the shiny session after
    # the page has already answered, so the launcher has returned and
    # nothing is left to read the pipe. The file is still there afterwards.

    log_path <-
      fs::path(fs::path_dir(.qmd_path), "quarto_serve.log")

    if (fs::file_exists(log_path)) fs::file_delete(log_path)

    # The problem set is handed to the document in the environment rather
    # than chosen from a picker inside it: a quarto shiny document takes no
    # arguments, and one grading session is one problem set.

    server <-
      processx::process$new(
        quarto::quarto_path(),
        c(
          "serve",
          .qmd_path,
          "--port",
          as.character(.port)
        ),
        env =
          c(
            "current",
            GRADING_PROBLEM_SET = as.character(.problem_set)
          ),
        stdout = log_path,
        stderr = "2>&1"
      )

    cli::cli_inform(
      c(
        "Rendering, then serving {.url {app_url}} ...",
        i = "Output is being written to {.path {log_path}}."
      )
    )

    deadline <- Sys.time() + 180

    while (Sys.time() < deadline) {
      Sys.sleep(0.5)

      if (!server$is_alive()) {
        cli::cli_abort(
          c(
            "quarto serve exited before it started listening.",
            i = "What it printed is in {.path {log_path}}."
          )
        )
      }

      if (!is.null(reach(app_url))) {
        if (rstudioapi::isAvailable()) {
          rstudioapi::viewer(app_url)
        } else {
          utils::browseURL(app_url)
        }

        cli::cli_inform(
          c(
            "v" = "Serving {.url {app_url}} from this session.",
            "i" = "Stop the app with {.code dashboard$kill()}."
          )
        )

        return(invisible(server))
      }
    }

    server$kill()

    cli::cli_abort("quarto serve did not start listening on port {(.port)}.")
  }
