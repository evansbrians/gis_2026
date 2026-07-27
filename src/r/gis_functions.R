# General-purpose GIS-in-R course utility functions, taught/used as course
# content (not infrastructure for building the lesson pages -- see
# course_functions.R for that).
#
# Consolidated from modules/module_3/scripts/source_script.R and
# modules/module_5/scripts/source_script.r, which had drifted into two
# near-identical copies of the same three functions. This file is now the
# canonical version.
#
# Note: module_3/scripts/source_script.R still exists alongside lesson 3.2,
# since that lesson uses the file itself -- by name -- as a live teaching
# example of what a source script is. That local copy was left as-is rather
# than pointed at this file, so the pedagogical narrative in 3.2 stays
# accurate. If you want 3.2 (and 5.2) to source from here instead, that's a
# small follow-up edit to their source() calls.

# Clean object names:

clean_names <-
  function(df) {
    df |>
      set_names(
        names(df) |>
          str_replace_all("[:blank:]", "_") |>
          str_replace_all("([a-z])([A-Z]){1}", "\\1_\\2") |>
          tolower()
      )
  }

# Get an EPSG code from lonlat data (from Lovelace, chapter 7,
# https://geocompr.robinlovelace.net/reproj-geo-data.html):

lonlat_to_utm <-
  function(lonlat) {
    utm <-
      (floor((lonlat[1] + 180) / 6) %% 60) + 1
    if (lonlat[2] > 0) {
      utm + 32600
    } else {
      utm + 32700
    }
  }

# A shared ggplot2 theme:

universal_plot_theme <-
  function() {
    theme_bw() %+replace%
      theme(
        plot.title = element_text(size = 16),
        axis.title = element_text(size = 14),
        axis.text = element_text(size = 12),
        strip.text = element_text(size = 14),
        complete = TRUE
      )
  }
