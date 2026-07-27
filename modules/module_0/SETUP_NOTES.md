# module_0 setup (superseded — see root `_quarto.yml`)

This file originally described `module_0` as its own standalone Quarto
project with its own `_quarto.yml` and its own `_extensions/` copy.
That's no longer the case: the "universal root" reorg folded
`_extensions/`, `data/`, and `scripts/` up into shared top-level
folders, and `module_0` now shares the single root `_quarto.yml` with
every other module (`execute-dir: project`, so R code paths are
root-relative, e.g. `source("src/r/course_functions.R")` rather than
`source("../../src/r/course_functions.R")`).

One addition made to the root `_quarto.yml` as part of converting all
four preliminary lessons to this format: the `live-html` format now
preloads `dplyr`/`purrr`/`%>%`/etc. into the webr WASM session via

```yaml
format:
  live-html:
    webr:
      packages: [tidyverse]
```

This is what lets `{webr}` chunks in 0.1/0.3/0.4 call `filter()`,
`pluck()`, `str_c()`, `%>%`, etc. without an explicit `library()` call
inside the sandboxed session.

## webexercises one-time setup (still applies, unchanged)

Still need, once:

```r
install.packages("webexercises")
```

`src/includes/webex.css` and `src/includes/webex.js` should already
exist from when `0.2_values.qmd` was first prototyped -- if you're
setting this up fresh, generate them with:

```r
webexercises::add_to_quarto(
  quarto_dir = tempdir(),
  include_dir = "include"
)
```

then move the two resulting files into `src/includes/`.

## Rendering

None of `0.1`–`0.4` have been rendered end-to-end since this last
round of conversion (no Quarto CLI available in the environment this
work was done in). From the `gis_2026` project root:

```bash
quarto preview modules/module_0/0.1_intro_to_r_and_rstudio.qmd --to live-html --no-watch-inputs --no-browse
```

(repeat per file). Same caveat as always about `{webr}` cell
state-sharing across a page being assumed, not independently verified
here.
