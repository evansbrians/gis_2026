# Find every function a submission used and check it against the list the
# assignment permits, then apply the blanket policies that can cost points
# anywhere in a script.
#
# Counting only the named calls would miss most of what a student can reach
# for: `$`, `[[`, `!`, `:`, and the pipe are all functions, they all appear
# on the allowed lists, and a check that skipped them would let a student use
# the extraction operator a question was written to rule out. So the tokens
# are taken from R's own parser and every non-symbol terminal is mapped back
# to the name the problem set lists it under.
#
# Source via source("src/r/grading_functions.R").

library(tidyverse)

source("src/r/grading_db.R")

# How R's parser names each operator, and the name the allowed-function lists
# give it. Closing delimiters and punctuation are left out: they carry no
# meaning the opening token has not already recorded.
#
# Both pipes are here. The magrittr pipe arrives as a SPECIAL, like any
# %...% operator, and so was already counted; the native pipe has a token of
# its own, PIPE, and without a row here it was invisible to every check --
# never listed among the functions an answer used, and never tested against
# the assignment's allowed list.

parser_token_names <-
  tribble(
    ~token,          ~function_name,
    "'$'",           "$",
    "'@'",           "@",
    "'['",           "[...]",
    "LBB",           "[[...]]",
    "'('",           "(...)",
    "'{'",           "{...}",
    "LEFT_ASSIGN",   "<-",
    "RIGHT_ASSIGN",  "->",
    "EQ_ASSIGN",     "=",
    "EQ_SUB",        "=",
    "EQ",            "==",
    "NE",            "!=",
    "LT",            "<",
    "GT",            ">",
    "LE",            "<=",
    "GE",            ">=",
    "AND",           "&",
    "AND2",          "&&",
    "OR",            "|",
    "OR2",           "||",
    "NOT",           "!",
    "'+'",           "+",
    "'-'",           "-",
    "'*'",           "*",
    "'/'",           "/",
    "'^'",           "^",
    "':'",           ":",
    "'~'",           "~",
    "'?'",           "?",
    "PIPE",          "|>",
    "NS_GET",        "::",
    "NS_GET_INT",    ":::",
    "FUNCTION",      "function",
    "OP-LAMBDA",     "function",
    "IF",            "if",
    "ELSE",          "if",
    "FOR",           "for",
    "WHILE",         "while",
    "REPEAT",        "repeat",
    "NEXT",          "next",
    "BREAK",         "break"
  )

# Parse R code and return its parse data, or NULL when it will not parse. A
# submission that does not parse is a review flag, never a silent zero.

parse_data_of <-
  function(.code) {
    if (is.na(.code) || str_trim(.code) == "") return(NULL)

    parsed <-
      try(
        parse(
          text = .code,
          keep.source = TRUE
        ),
        silent = TRUE
      )

    if (inherits(parsed, "try-error")) return(NULL)

    utils::getParseData(parsed)
  }

# Every function a block of code calls, named as the allowed-function lists
# name them. A special (%...%) reports the literal operator it spells.

functions_used <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(character(0))

    terminals <- parse_data[parse_data$terminal, ]

    named <- terminals$text[terminals$token == "SYMBOL_FUNCTION_CALL"]

    specials <- terminals$text[terminals$token == "SPECIAL"]

    operators <-
      parser_token_names$function_name[
        match(terminals$token, parser_token_names$token)
      ]

    c(
      named,
      specials,
      operators
    ) %>%
      discard(is.na) %>%
      unique() %>%
      sort()
  }

# checks ------------------------------------------------------------------

# The functions a block of code used that the assignment does not permit.
# Matching is on the function's name alone: a student who writes dplyr::rename
# and a student who writes rename have used the same function, and the
# problem set's list is what decides whether they were allowed to.

unapproved_functions <-
  function(.code, .allowed, .parse_data = NULL) {
    setdiff(
      functions_used(.code, .parse_data),
      .allowed$function_name
    )
  }

# The parse-tree nodes that are whole function calls. The parser wraps a
# call's name in an expression of its own, so the call itself is that
# wrapper's parent, two steps up from the name token.

call_expressions <-
  function(.parse_data) {
    name_wrappers <-
      .parse_data$parent[.parse_data$token == "SYMBOL_FUNCTION_CALL"]

    .parse_data$parent[.parse_data$id %in% name_wrappers]
  }

# Whether a block of code extracts a column by position rather than by name,
# which the problem sets deduct for. Every `[[` index names an element, so a
# number there is always positional; inside single brackets only what follows
# the comma selects columns, since a number before it selects rows.
#
# An argument is not an index: slice_head(bird_counts, n = 5) passes a number
# to a function and reaches no bracket at all.

uses_numeric_index <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(FALSE)

    brackets <- parse_data[parse_data$token %in% c("'['", "LBB"), ]

    if (!nrow(brackets)) return(FALSE)

    any(
      map_lgl(
        seq_len(nrow(brackets)),
        \(.i) {
          siblings <-
            parse_data[parse_data$parent == brackets$parent[.i], ]

          # The index expressions are the bracket's siblings; a constant sits
          # one level inside each of them.

          constants <-
            parse_data[
              parse_data$parent %in% siblings$id[siblings$token == "expr"] &
                parse_data$token == "NUM_CONST",
            ]

          if (!nrow(constants)) return(FALSE)

          if (brackets$token[.i] == "LBB") return(TRUE)

          comma <- siblings[siblings$token == "','", ]

          if (!nrow(comma)) return(FALSE)

          any(constants$col1 > min(comma$col1))
        }
      )
    )
  }

# The names a block of code assigns into the global environment. A question
# that did not ask for an assignment and got one loses points, and several
# questions ask for an answer with no assignment at all.

assigned_names <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(character(0))

    assignments <-
      parse_data$parent[
        parse_data$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN")
      ]

    if (!length(assignments)) return(character(0))

    # The assigned name is the first thing in the assignment expression.

    map_chr(
      assignments,
      \(.parent) {
        siblings <-
          parse_data[parse_data$parent == .parent, ] %>%
          arrange(line1, col1)

        symbols <-
          siblings$id[siblings$token == "expr"] %>%
          head(1)

        if (!length(symbols)) return(NA_character_)

        leaf <-
          parse_data[
            parse_data$parent == symbols & parse_data$token == "SYMBOL",
          ]

        if (!nrow(leaf)) NA_character_ else leaf$text[1]
      }
    ) %>%
      discard(is.na) %>%
      unique()
  }

# Whether every step of a block of code is joined by a pipe, which questions
# 8 and 9 of problem set 1 require. A block that holds a single expression
# with no pipe in it fails; so does one that splits into several statements.

is_single_piped_block <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(FALSE)

    statements <-
      parse_data[parse_data$parent == 0 & parse_data$token == "expr", ]

    pipes <-
      parse_data$text[parse_data$token == "SPECIAL"] %>%
      str_detect("^%>%$|^\\|>$") %>%
      sum()

    nrow(statements) == 1 && pipes > 0
  }

# How deeply a block of code nests one call inside another. The style guide
# allows two levels and asks for a pipe beyond that; question 8 of problem
# set 1 asks for no nesting at all.

nesting_depth <-
  function(.code, .parse_data = NULL) {
    parse_data <- .parse_data %||% parse_data_of(.code)

    if (is.null(parse_data)) return(0L)

    calls <- call_expressions(parse_data)

    if (!length(calls)) return(0L)

    # Walk each call up to the root, counting the calls it sits inside.

    depth_of <-
      function(.id) {
        depth <- 1L

        current <- .id

        while (current > 0) {
          current <- parse_data$parent[parse_data$id == current][1]

          if (is.na(current)) break

          if (current %in% calls) depth <- depth + 1L
        }

        depth
      }

    max(map_int(calls, depth_of))
  }

# report ------------------------------------------------------------------

# Run every function and policy check over one problem set's answer slots.
# Given code is skipped: a question that supplied a `$` is not a student
# reaching for one.

# The packages an answer attaches that it did not need to.
#
# `library()` is on problem set 1's list of permitted functions, so attaching
# a package costs nothing. It is still worth saying: a function is reached
# with `::` unless the question asks for the package to be attached, and a
# question that asks for it says so in its own text.

questions_asking_to_attach <-
  function(.problem_set) {
    questions_from_qmd(.problem_set) %>%
      filter(str_detect(str_to_lower(stem), "attach|library")) %>%
      pull(question)
  }

libraries_attached <-
  function(.answer) {
    if (is.na(.answer)) return(character(0))

    attached <-
      str_match_all(.answer, "library\\(\\s*([A-Za-z][\\w.]*)\\s*\\)")

    unique(attached[[1]][, 2])
  }

check_functions <-
  function(.slots, .problem_set, .allowed = NULL) {
    allowed <- .allowed %||% assignment_allowed_functions(.problem_set)

    attach_questions <- questions_asking_to_attach(.problem_set)

    unapproved_here <-
      function(.answer, .parse_data) {
        unapproved_functions(
          .answer,
          allowed,
          .parse_data
        )
      }

    .slots %>%
      filter(slot_type == "answer") %>%
      mutate(
        parse_data = map(answer, parse_data_of),
        parses = !map_lgl(parse_data, is.null),
        used =
          map2(
            answer,
            parse_data,
            functions_used
          ),
        unapproved =
          map2(
            answer,
            parse_data,
            unapproved_here
          ),
        unneeded_libraries =
          map2(
            answer,
            question,
            \(.answer, .question) {
              if (.question %in% attach_questions) return(character(0))

              libraries_attached(.answer)
            }
          ),
        numeric_index =
          map2_lgl(
            answer,
            parse_data,
            uses_numeric_index
          ),
        assigns =
          map2(
            answer,
            parse_data,
            assigned_names
          ),
        single_pipe =
          map2_lgl(
            answer,
            parse_data,
            is_single_piped_block
          ),
        depth =
          map2_int(
            answer,
            parse_data,
            nesting_depth
          )
      ) %>%
      select(-parse_data)
  }
