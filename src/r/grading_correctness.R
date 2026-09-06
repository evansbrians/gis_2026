# Decide whether a student's answer is right from its code alone. No student
# code is ever executed.
#
# The answer's parse tree is reduced to the functions it calls and the
# constants it names, and compared to the same reduction of each of the key's
# accepted alternatives. This ignores layout, and ignores whether the student
# piped or nested, but notices a wrong column name or a wrong number.
#
# An answer that matches an alternative is correct. An answer that matches
# none is proposed as incorrect -- a deliberate choice: a working approach
# the key never anticipated is settled in the dashboard's review tab, not by
# running the code. Only an answer that cannot be compared at all (not
# located, or does not parse) is flagged for review with nothing deducted.
#
# Source via source("src/r/grading_correctness.R").

library(tidyverse)

source("src/r/grading_functions.R")

# signature ---------------------------------------------------------------

# Reduce a block of code to what it does rather than how it is written: the
# functions it calls, the strings it names, and the numbers it uses. Symbols
# are left out, so piping into a placeholder and naming the data outright
# reduce to the same thing.

# The pieces a signature is built from, with the token each came from kept
# beside it. answer_signature() collapses these; mismatch_description() needs
# the token to say what a piece is -- a string and a symbol are the same text
# once the quotes come off.

signature_pieces <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(NULL)

    terminals <- parse_data[parse_data$terminal, ]

    keep <-
      terminals$token %in%
        c(
          "SYMBOL_FUNCTION_CALL",
          "SPECIAL",
          "STR_CONST",
          "NUM_CONST",

          # The extraction and indexing operators. Which one an answer used
          # decides the class of what comes back, which is the distinction
          # 2.1 is built on and the one several questions are written to
          # test: bird_counts[["diet"]] returns a character vector and
          # bird_counts[, "diet"] returns a tibble. Without these tokens the
          # two reduce to the same signature and a subsetting answer passes
          # as an extraction answer.

          "'$'",
          "'@'",
          "'['",
          "LBB"
        )

    # The pipe carries no meaning the call order does not already carry, and
    # counting it would separate a piped answer from a nested one.
    #
    # `$` and `[[` are folded together, and the name of the column they reach
    # is dropped. The course's own distinction, from 2.1, is extraction
    # against subsetting: `x$diet` and `x[["diet"]]` are two spellings of one
    # extraction and both return a vector, while `x[, "diet"]` subsets and
    # returns a tibble. Keeping the spelling apart would have marked a
    # correct answer wrong wherever the key happened to use the other one.

    index_strings <- index_string_ids(parse_data)

    tibble(
      id = terminals$id[keep],
      token = terminals$token[keep],
      text = terminals$text[keep]
    ) %>%
      filter(!text %in% c("%>%", "|>")) %>%
      filter(!id %in% index_strings) %>%
      left_join(argument_names(parse_data), by = "id") %>%
      mutate(
        token = if_else(token == "LBB", "'$'", token),
        text = if_else(token == "'$'", "$", text),
        text = str_remove_all(text, "^[\"']|[\"']$")
      ) %>%
      distinct(token, text, .keep_all = TRUE) %>%
      select(token, text, argument)
  }

# Every node under the given ones, the given ones included.

descendant_ids <-
  function(.parse_data, .ids) {
    found <- .ids

    repeat {
      new <- setdiff(.parse_data$id[.parse_data$parent %in% found], found)

      if (!length(new)) return(found)

      found <- c(found, new)
    }
  }

# The argument each piece sits inside, for the pieces that sit inside a named
# one. A number carries no meaning on its own, so a reason that says `2` says
# nothing; `skip = 2` names the rule the student missed.

argument_names <-
  function(.parse_data) {
    empty <- tibble(id = integer(0), argument = character(0))

    if (!any(.parse_data$token == "EQ_SUB")) return(empty)

    named <-
      map_dfr(
        unique(.parse_data$parent[.parse_data$token == "EQ_SUB"]),
        \(.parent) {

          # A call's name, `=` and value are flat siblings, so the argument
          # is read by position: the node before each `=` names it and the
          # node after it holds the value. Reading them any other way hands
          # one argument's value to another argument's name.

          siblings <-
            .parse_data %>%
            filter(parent == .parent) %>%
            arrange(line1, col1)

          map_dfr(
            which(siblings$token == "EQ_SUB"),
            \(.i) {
              if (.i < 2 || .i >= nrow(siblings)) return(empty)

              if (siblings$token[.i - 1] != "SYMBOL_SUB") return(empty)

              tibble(
                id = siblings$id[.i + 1],
                argument = siblings$text[.i - 1]
              )
            }
          )
        }
      )

    if (!nrow(named)) return(empty)

    # A piece takes the nearest argument above it, so `na.rm` inside
    # `m = mean(count, na.rm = TRUE)` names itself rather than `m`.

    parent_of <- set_names(.parse_data$parent, .parse_data$id)

    name_of <- set_names(named$argument, named$id)

    nearest <-
      function(.id) {
        at <- .id

        while (!is.na(at) && at != 0) {
          hit <- name_of[as.character(at)]

          if (!is.na(hit)) return(unname(hit))

          at <- unname(parent_of[as.character(at)])
        }

        NA_character_
      }

    ids <- .parse_data$id[.parse_data$terminal]

    tibble(
      id = ids,
      argument = map_chr(ids, nearest)
    ) %>%
      filter(!is.na(argument))
  }

# The ids of the string constants that name a column inside `[` or `[[`.
#
# `x[["diet"]]` and `x$diet` name the same column, so the quoted name carries
# nothing the symbol does not; counting it would separate two spellings of
# one extraction. A string anywhere else in the answer -- a file path, a
# sheet name, a value tested against -- is untouched.

index_string_ids <-
  function(.parse_data) {
    brackets <- .parse_data[.parse_data$token %in% c("'['", "LBB"), ]

    if (!nrow(brackets)) return(integer(0))

    map(
      seq_len(nrow(brackets)),
      \(.i) {
        siblings <- .parse_data[.parse_data$parent == brackets$parent[.i], ]

        .parse_data$id[
          .parse_data$parent %in% siblings$id[siblings$token == "expr"] &
            .parse_data$token == "STR_CONST"
        ]
      }
    ) %>%
      unlist() %>%
      unique()
  }

answer_signature <-
  function(.code, .parse_data = NULL) {
    pieces <- signature_pieces(.code, .parse_data)

    if (is.null(pieces)) return(NA_character_)

    pieces$text %>%
      sort() %>%
      str_c(collapse = "")
  }

# How a piece is written when a reason names it.

piece_label <-
  function(.token, .text, .argument = NA_character_) {
    case_when(
      .token == "NUM_CONST" & !is.na(.argument) ~
        str_c("`", .argument, " = ", .text, "`"),
      .token == "NUM_CONST" ~ str_c("the number ", .text),
      .token == "STR_CONST" & !is.na(.argument) ~
        str_c("`", .argument, ' = "', .text, '"`'),
      .token == "STR_CONST" ~ str_c('"', .text, '"'),
      .token == "'['" ~ "`[...]`",
      .token == "LBB" ~ "`[[...]]`",
      .token %in% c("'$'", "'@'", "SPECIAL") ~ str_c("`", .text, "`"),
      .default = str_c("`", .text, "()`")
    )
  }

# A short account of how an answer differs from the accepted approach it is
# closest to.
#
# Written from the comparison itself rather than from any reading of what the
# student meant: the pieces the key has and the answer does not, and the
# pieces the answer has and the key does not. Where the difference is only in
# how the data were reached -- `$` against `[[...]]` against `[...]` -- that
# is the whole finding, and it is the one this course cares most about,
# because it decides what class comes back.
#
# The closest alternative is the one sharing the most pieces, so a key with
# several accepted approaches is compared against the one the student came
# nearest to rather than against the first in the file.

mismatch_description <-
  function(.code, .alternatives) {
    generic <- "The answer does not match an accepted approach to this question."

    if (!length(.alternatives)) return(generic)

    answer <- signature_pieces(.code)

    if (is.null(answer)) return(generic)

    labelled <-
      function(.pieces) {
        if (is.null(.pieces) || !nrow(.pieces)) return(character(0))

        piece_label(.pieces$token, .pieces$text, .pieces$argument)
      }

    answer_labels <- labelled(answer)

    scored <-
      map(
        .alternatives,
        \(.alt) {
          key_labels <- labelled(signature_pieces(.alt))

          list(
            missing = setdiff(key_labels, answer_labels),
            extra = setdiff(answer_labels, key_labels),
            shared = length(intersect(key_labels, answer_labels))
          )
        }
      )

    closest <-
      scored[[which.max(map_dbl(scored, \(.s) .s$shared))]]

    listed <-
      function(.items) str_c(unique(.items), collapse = ", ")

    if (length(closest$missing) && length(closest$extra)) {
      return(
        str_c(
          "The answer uses ", listed(closest$extra),
          " where an accepted approach uses ", listed(closest$missing), "."
        )
      )
    }

    if (length(closest$missing)) {
      return(
        str_c(
          "The answer does not use ", listed(closest$missing),
          ", which an accepted approach uses."
        )
      )
    }

    if (length(closest$extra)) {
      return(
        str_c(
          "The answer uses ", listed(closest$extra),
          ", which no accepted approach uses."
        )
      )
    }

    generic
  }

# Whether an answer reduces to the same thing as any of the key's accepted
# alternatives.

signature_matches <-
  function(.code, .alternatives) {
    if (!length(.alternatives)) return(NA)

    signature <- answer_signature(.code)

    if (is.na(signature)) return(FALSE)

    signature %in% map_chr(.alternatives, answer_signature)
  }

# verdicts ----------------------------------------------------------------

# One verdict per slot, from the comparison alone.

signature_verdict <-
  function(.signature, .parses, .found) {
    case_when(
      !.found | !.parses | is.na(.signature) ~ "review",
      .signature ~ "correct",
      .default = "incorrect"
    )
  }

# Why a slot needs looking at, in the words a graded report will show.

review_reason <-
  function(.signature, .parses, .found) {
    case_when(
      !.found ~ "the answer could not be located in the submission",
      !.parses ~ "the answer does not parse",
      is.na(.signature) ~ "the key lists no accepted alternatives",
      .default = NA_character_
    )
  }

# Compare every answer slot of every student to the key.

check_correctness <-
  function(.slots, .key_slots) {
    .slots %>%
      filter(slot_type == "answer") %>%
      left_join(
        .key_slots %>%
          select(slot_id, alternatives),
        by = join_by(slot_id)
      ) %>%
      mutate(
        signature =
          map2_lgl(
            answer,
            alternatives,
            signature_matches
          ),
        parses = map_lgl(answer, \(.a) !is.null(parse_data_of(.a))),

        # Why the answer did not match, written while the key is still in
        # scope. The report and the dashboard both read it from here.

        mismatch =
          pmap_chr(
            list(answer, alternatives, signature),
            \(.answer, .alternatives, .signature) {
              if (isTRUE(.signature) || is.na(.signature)) return(NA_character_)

              mismatch_description(.answer, .alternatives)
            }
          ),
        verdict =
          signature_verdict(
            signature,
            parses,
            found
          ),
        reason =
          review_reason(
            signature,
            parses,
            found
          )
      )
  }
