# Script for 2.4 Reshaping data frames tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Read rds file:

angola_ungulates_list <-
  read_rds("data/raw/angola_ungulates.rds")

# To explore this object, let's have a look at its reference tree:

lobstr::ref(angola_ungulates_list)

# Now you! In a single piped statement, read in `angola_ungulates.rds` and
# extract each of its list items to a name in your global environment.



# Print the names assigned to your global environment to see the result:

ls()

# Remove the name angola_ungulates_list from the global environment:

rm(angola_ungulates_list)

# bind rows ---------------------------------------------------------------

# Let's take a moment to look at the head of each of the datasets:

perissodactyla %>%
  slice_head()

artiodactyla %>%
  slice_head()

# Let's extract that column with `pull` and look at its unique values:

perissodactyla %>%
  pull(taxonomy) %>%
  unique()

artiodactyla %>%
  pull(taxonomy) %>%
  unique()

# The arguments that we supply are simply the names assigned to the data frames:

perissodactyla %>%
  bind_rows(artiodactyla)

# If we wanted `perissodactyla` to come after `artiodactyla`:

perissodactyla %>%
  bind_rows(artiodactyla, .)

# Now you! Combine the two data frames by row so that the rows of
# `perissodactyla` come first, but pipe `artiodactyla` into `bind_rows()`.



# Read in the list, bind the list items, and then globally assign to a name:

angola_ungulates <-
  read_rds("data/raw/angola_ungulates.rds") %>%
  bind_rows()

# Remove the names perissodactyla and artiodactyla from the global environment:

rm(perissodactyla, artiodactyla)

# Now you! Return a data frame of the iNaturalist observers who contributed to
# `angola_ungulates`, with one row for each observer.



# combine columns ---------------------------------------------------------

# We provide the name of the new column within quotes:

angola_ungulates %>%
  unite(
    col = "date",
    year:day,
    sep = "-"
  )

# Unite date columns and globally assign to the name
# angola_ungulates_date_fix:

angola_ungulates_date_fix <-
  angola_ungulates %>%
  unite(
    col = "date",
    year:day,
    sep = "-"
  )

# Unite genus and species columns and globally assign to the name
# angola_ungulates_spp_fix:

angola_ungulates_spp_fix <-
  angola_ungulates_date_fix %>%
  unite(
    col = "sci_name",
    genus:species,
    sep = " "
  )

# Remove the names angola_ungulates_spp_fix and angola_ungulates_date_fix
# from the global environment:

rm(angola_ungulates_spp_fix, angola_ungulates_date_fix)

# Now you! Some datasets record the time of sampling only to the month. Combine
# `year` and `month` in `angola_ungulates` into a single column named
# `year_month`, with a hyphen between the values.



# split columns -----------------------------------------------------------

# Let's look at the current state of our data:

angola_ungulates

# To split one column into several:

angola_ungulates %>%
  separate_wider_delim(
    cols = taxonomy,
    delim = "-",
    names =
      c(
        "class",
        "order",
        "family"
      )
  )

# Separate the taxonomy columns and globally assign a name:

angola_ungulates_taxonomy_fix <-
  angola_ungulates %>%
  separate_wider_delim(
    cols = taxonomy,
    delim = "-",
    names =
      c(
        "class",
        "order",
        "family"
      )
  )

# Complete in a single chained analysis and globally assign a name:

angola_ungulates <-

  # Read in the data:

  read_rds("data/raw/angola_ungulates.rds") %>%

  # Combine the datasets by row:

  bind_rows() %>%

  # Combine the date columns:

  unite(
    col = "date",
    year:day,
    sep = "-"
  ) %>%

  # Combine the scientific name columns:

  unite(
    col = "sci_name",
    genus:species,
    sep = " "
  ) %>%

  # Separate the taxonomy into multiple columns:

  separate_wider_delim(
    cols = taxonomy,
    delim = "-",
    names =
      c(
        "class",
        "order",
        "family"
      )
  )

# Remove the name angola_ungulates_taxonomy_fix from the global environment:

rm(angola_ungulates_taxonomy_fix)

# Now you! We united `genus` and `species` into `sci_name` earlier in this
# lesson. Split `sci_name` back into a `genus` column and a `species` column.



# split table by columns --------------------------------------------------

# Subset to observations of ungulates and globally assign the name
# observations:

observations <-
  angola_ungulates %>%
  select(date:user_login, sci_name)

# Subset to taxonomic information and globally assign the name taxonomy:

taxonomy <-
  angola_ungulates %>%
  select(
    sci_name,
    class:family,
    common_name
  )

# Let's verify this by extracting that column with `pull`:

taxonomy %>%
  pull(class) %>%
  unique()

# To address this, we can remove it with a negated selection:

taxonomy %>%
  select(!class)

# Subset to taxonomic information (but do not include class) and globally
# assign the name taxonomy (preferred):

taxonomy <-
  angola_ungulates %>%
  select(
    sci_name,
    order:family,
    common_name
  )

# Now you! Subset `angola_ungulates` to the observer, the scientific name, and
# the taxonomic family, in that order.



# remove duplicates -------------------------------------------------------

# To subset the rows to their unique combinations:

taxonomy %>%
  distinct()

# Subset to taxonomy columns, make distinct, and assign a name to the
# global environment:

taxonomy_distinct <-
  angola_ungulates %>%
  select(
    sci_name,
    order:family,
    common_name
  ) %>%
  distinct()

# combine by binding columns (usually unsafe) -----------------------------

# This is done with the dplyr function `bind_cols`:

observations %>%
  bind_cols(taxonomy)

# The function bind_cols() can be used to join if you are certain that the
# row orders of the two tables are equivalent:

observations %>%
  select(!sci_name) %>%
  bind_cols(taxonomy)

# But this is often unsafe!

observations %>%
  select(!sci_name) %>%
  bind_cols(
    taxonomy %>%
      arrange(sci_name)
  )

# combine by joining data frames (usually safe) ---------------------------

# A join is much safer than bind_cols!

observations %>%
  left_join(
    taxonomy_distinct,
    by = "sci_name"
  )

# ... but can also be unsafe if you are not careful!

observations %>%
  left_join(
    taxonomy,
    by = "sci_name"
  )

# Remove the name taxonomy from the global environment:

rm(taxonomy)

# Join the taxonomic family to each observation and globally assign a name:

families <-
  observations %>%
  select(sci_name) %>%
  left_join(
    taxonomy_distinct %>%
      select(sci_name, family),
    by = "sci_name"
  )

# reshape and summarize ---------------------------------------------------

# In 2.3 Grouped operations and summarizing we counted the records:

families %>%
  count(family)

# Now you! In a single piped statement, add the taxonomic information in
# `taxonomy_distinct` to `observations` and return the number of observations of
# each taxonomic `order`.



# pivot from long to wide form --------------------------------------------

# We often need to pivot from long-form data to wide-form data:

wide_families <-
  families %>%
  count(family) %>%
  pivot_wider(
    names_from = family,
    values_from = n
  )

# Now you! Count the observations of each scientific name in `families` and
# pivot the result to wide form, with one column per species.



# pivot from wide to long form --------------------------------------------

# When working with data supplied by others, the need to pivot from wide to
# long form is more common:

wide_families %>%
  pivot_longer(
    cols = Bovidae:Suidae,
    names_to = "family",
    values_to = "n"
  )

# Now you! Return `wide_families` to long form, naming the column that receives
# the family names `taxonomic_family` and the column that receives the counts
# `observations_n`.
