# Unpack a problem set's submissions, work out whose each one is, and split
# every script into the answer slots the template defines.
#
# Blackboard writes a submission as
#
#   <lastfirst>_<student id>_<attempt id>_<the name the student gave>.R
#
# and the name the student gave is not always the name they were asked for:
# some bracket it, some reverse it, and a resubmission picks up a "-1". The
# concatenated prefix Blackboard supplies is the tiebreaker.
#
# Source via source("src/r/grading_submissions.R").

library(tidyverse)

source("src/r/grading_problem_set.R")

# Where a problem set's submissions are unpacked to.

submissions_dir <-
  function(.problem_set) {
    file.path(
      problem_set_dir(.problem_set),
      str_c(
        "problem_set_",
        .problem_set,
        "_submissions"
      )
    )
  }

# Blackboard's download, wherever it was left. Older problem sets name it
# after the problem set and newer ones just "submissions".

submissions_archive <-
  function(.problem_set) {
    candidates <-
      file.path(
        problem_set_dir(.problem_set),
        c(
          str_c(
            "problem_set_",
            .problem_set,
            "_submissions.zip"
          ),
          "submissions.zip"
        )
      )

    found <- candidates[file.exists(candidates)]

    if (!length(found)) {
      cli::cli_abort(
        "No submissions archive for problem set {.val {(.problem_set)}}."
      )
    }

    found[1]
  }

# Unpack the archive, keeping only the R scripts. Blackboard includes a .txt
# receipt for every submission, which is of no use here.

unpack_submissions <-
  function(.problem_set, .overwrite = FALSE) {
    target <- submissions_dir(.problem_set)

    if (dir.exists(target) && !.overwrite) return(target)

    unzip(
      submissions_archive(.problem_set),
      exdir = target
    )

    target %>%
      list.files(full.names = TRUE) %>%
      str_subset("\\.[Rr]$", negate = TRUE) %>%
      walk(file.remove)

    target
  }

# names -------------------------------------------------------------------

# Reduce a name fragment to comparable letters: no brackets, no separators,
# no case.

name_letters <-
  function(.text) {
    .text %>%
      str_to_lower() %>%
      str_remove_all("[^a-z]")
  }

# Work out a submission's last and first name. The student's own file name
# supplies the two words; Blackboard's concatenated prefix settles which is
# which, since it is always the last name followed by the first. When the
# prefix confirms neither ordering the student's order is kept and the row is
# marked for review.

student_of_file <-
  function(.file_name, .problem_set) {
    stem <- str_remove(.file_name, "\\.[Rr]$")

    prefix <- name_letters(str_extract(stem, "^[^_]+"))

    given <-
      stem %>%
      str_extract(
        str_c(
          "problem_set[_ ]*",
          .problem_set,
          "[_ ]*(.+)$"
        ),
        group = 1
      ) %>%
      coalesce("") %>%
      str_remove("-\\d+$")

    words <-
      given %>%
      str_split("[_ ]+") %>%
      pluck(1) %>%
      map_chr(name_letters) %>%
      keep(\(.word) .word != "")

    if (length(words) < 2) {
      return(
        tibble(
          file_name = .file_name,
          last_name = coalesce(words[1], prefix),
          first_name = NA_character_,
          name_source = "unresolved"
        )
      )
    }

    # Try the student's order first, then the reverse, against the prefix.

    forward <- str_c(words[1], words[length(words)])

    backward <- str_c(words[length(words)], words[1])

    resolved <-
      case_when(
        str_detect(prefix, fixed(forward)) ~ "given",
        str_detect(prefix, fixed(backward)) ~ "reversed",
        .default = "unconfirmed"
      )

    ordered <-
      if (resolved == "reversed") rev(words) else words

    tibble(
      file_name = .file_name,
      last_name = ordered[1],
      first_name = ordered[length(ordered)],
      name_source = resolved
    )
  }

# The file name as the student sees it, with the LMS bookkeeping removed.
#
# Canvas prepends a concatenated name and two of its own ids
# (allarishi_109245_28108845_) to every download, and adds "-1" to a
# resubmission. None of that is the student's doing, and a graded report that
# quotes it back at them is quoting Canvas rather than their answer to the
# question that asked them to name the file.
#
# The part the student supplied begins at "problem_set_N", which is what the
# naming check already judges. A file that was never renamed has no such
# part, so the LMS prefix is stripped on its own and whatever the student
# called the file is shown -- which is the point, because that is the case
# where the naming question was failed and the name is the evidence.

submitted_file_name <-
  function(.file_name, .problem_set) {
    if (is.na(.file_name)) return(NA_character_)

    extension <- coalesce(str_extract(.file_name, "\\.[Rr]$"), "")

    stem <- str_remove(.file_name, "\\.[Rr]$")

    own <-
      str_extract(
        stem,
        str_c("problem_set[_ ]*", .problem_set, ".*$")
      )

    kept <-
      if (is.na(own)) {
        str_remove(stem, "^[A-Za-z0-9]+_\\d+_\\d+_")
      } else {
        own
      }

    str_c(str_remove(kept, "-\\d+$"), extension)
  }

# The name a graded report is written under.

graded_file_name <-
  function(.problem_set, .last_name, .first_name) {
    str_c(
      "problem_set_",
      .problem_set,
      "_",
      .last_name,
      "_",
      .first_name,
      "_graded.qmd"
    )
  }

# submissions -------------------------------------------------------------

# Every submission for a problem set, one row per student, with the student's
# resolved name and the path to their script.

submission_index <-
  function(.problem_set, .overwrite = FALSE) {
    folder <- unpack_submissions(.problem_set, .overwrite)

    files <- list.files(folder, pattern = "\\.[Rr]$")

    if (!length(files)) {
      cli::cli_abort("No R scripts in {.path {folder}}.")
    }

    files %>%
      map_dfr(\(.file) student_of_file(.file, .problem_set)) %>%
      mutate(
        path = file.path(folder, file_name),
        student_id =
          str_c(
            last_name,
            "_",
            first_name
          ),
        graded_name =
          graded_file_name(
            .problem_set,
            last_name,
            first_name
          )
      ) %>%
      arrange(last_name, first_name)
  }

# Every answer a student gave, one row per template slot. Slots the aligner
# could not locate carry found = FALSE and become a review flag rather than a
# zero.

submission_slots <-
  function(.problem_set, .index = NULL) {
    index <- .index %||% submission_index(.problem_set)

    template <- script_segments(problem_set_file(.problem_set, ".R"))

    map_dfr(
      seq_len(nrow(index)),
      \(.i) {
        slots_from_file(
          index$path[.i],
          .problem_set,
          template
        ) %>%
          mutate(
            student_id = index$student_id[.i],
            submission_path = index$path[.i],
            .before = 1
          )
      }
    ) %>%
      mutate(
        answer = str_trim(content),

        # The untrimmed slot, which is what the blank-line rules have to be
        # read against: trimming removes the very blank lines they are about.

        raw_answer = raw_content
      )
  }
