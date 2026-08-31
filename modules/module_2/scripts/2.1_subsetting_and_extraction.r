# Script for 2.1 Introduction to subsetting and extraction tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Now you! Read in `"data/raw/district_birds.rds"` and assign the object to the
# name `bird_list`.



# extraction vs. subsetting -----------------------------------------------

# Extraction -- the tibble held in the list item:

bird_list[["birds"]]

# Subsetting -- a list that holds one item:

bird_list["birds"]

# extracting from a list --------------------------------------------------

# In this course, we will use `pluck` as our primary tool:

bird_list %>%
  pluck("birds")

# This is equivalent to using the `$` operator in base R:

bird_list$birds

# Each name that we supply specifies one level deeper:

bird_list %>%
  pluck("birds", "common_name")

# extracting from a data frame --------------------------------------------

# We can extract `common_name` from `"birds"` in `bird_list` using:

bird_list %>%
  pluck("birds") %>%
  pull(common_name)

# This is equivalent to:

bird_list %>%
  pluck("birds") %>%
  .$common_name

# The above, of course, is also equivalent to:

bird_list %>%
  pluck("birds", "common_name")

# The lesson expects this to fail -- see it for why:

# Using it on a list generates an error:

bird_list %>%
  pull(birds)

# extraction while reading in data ----------------------------------------

# Bind each list item to a name in the global environment:

bird_list %>%
  list2env(envir = .GlobalEnv)

# Now you!
# 1. Remove the names `bird_list`, `counts`, and `sites` from your global
#    environment.
# 2. Why is it not necessary to quote the names that you pass to `rm()`?



# extracting metadata -----------------------------------------------------

# We have used the extraction function `class` for this:

class(birds)

# Column names in a data frame are also a type of metadata:

names(birds)

# subset data frame columns -----------------------------------------------

# Let's take a look at the full `captures` data frame:

captures

# subset by column name ---------------------------------------------------

# To select a single column, we can provide the name of the column:

captures %>%
  select(band_number)

# We can select a vector of adjacent columns:

captures %>%
  select(band_number:age)

# We can select a vector of non-adjacent columns:

captures %>%
  select(band_number, age)

# We can combine adjacent and non-adjacent selections in a single call:

captures %>%
  select(
    capture_id,
    band_number:color_combo,
    wing:mass
  )

# remove columns ----------------------------------------------------------

# Here, we will remove the column `capture_id`:

captures %>%
  select(!capture_id)

# We can remove a range of adjacent columns with `:`:

captures %>%
  select(!capture_id:color_combo)

# To remove non-adjacent columns, we wrap our column names:

captures %>%
  select(
    !c(capture_id:visit_id, color_combo)
  )

# changing column names ---------------------------------------------------

# We can rename a column as we select it:

captures %>%
  select(
    band_number,
    color_combo,
    species = spp
  )

# Now you! Subset `captures` to the fields band number, spp, sex, wing, tl (tail
# length), and mass. Globally assign the resultant object to the name
# `measures`.



# subset rows by position -------------------------------------------------

# We use `slice` to subset the data frame to the row number:

measures %>%
  slice(1)

# We can slice adjacent rows by providing a range of row numbers:

measures %>%
  slice(1:5)

# For non-adjacent rows, we supply a vector of row numbers with `c`:

measures %>%
  slice(
    c(2, 3, 5)
  )

# `slice_head` returns rows from the top:

measures %>%
  slice_head(n = 5)

# The opposite of `slice_head` is `slice_tail`:

measures %>%
  slice_tail(n = 5)

# For example, to see the five lowest mass values in `measures`:

measures %>%
  arrange(mass) %>%
  slice_head(n = 5)

# `slice_min` does this in a single step:

measures %>%
  slice_min(mass, n = 5)

# `slice_max` returns the top five:

measures %>%
  slice_max(mass, n = 5)

# Asking for the three lowest masses returns four rows:

measures %>%
  slice_min(mass, n = 3)

# subset rows by condition ------------------------------------------------

# For example, we subset `measures`:

measures %>%
  filter(wing > 80)

# And where the value is greater than or equal to 80 mm:

measures %>%
  filter(wing >= 80)

# Here, we subset `birds` to rows where `species` is "GRCA":

birds %>%
  filter(species == "GRCA")

# filter & summary statistics ---------------------------------------------

# For example, we subset `measures`:

measures %>%
  filter(
    wing == max(wing, na.rm = TRUE)
  )

# filter with logical negation --------------------------------------------

# With the `!=` operator, we filter to values that are NOT equal:

birds %>%
  filter(diet != "omnivore")

# We can also use the logical negation operator itself, `!`:

birds %>%
  filter(!diet == "omnivore")

# The above works because the negation operator converts `TRUE` to `FALSE`:

!c(TRUE, FALSE)

# filter na values --------------------------------------------------------

# Notice that the logical test below does not work:

c(
  1,
  NA,
  2
) == NA

# Instead, we test whether a value is `NA` with the primitive `is.na` function:

c(
  1,
  NA,
  2
) %>%
  is.na()

# Below, I subset `measures` to where `tl` values are `NA`:

measures %>%
  filter(
    is.na(tl)
  )

# We can filter to values that are not `NA` using the negation operator, `!`:

measures %>%
  filter(
    !is.na(tl)
  )

# The following statement is therefore equivalent to filtering on `!is.na`:

measures %>%
  filter(tl == tl)

# filter by multiple conditions -------------------------------------------

# When we want to filter based on whether a given value:

measures %>%
  filter(wing > 80) %>%
  filter(wing < 90)

# Much more parsimoniously, separate filtering statements:

measures %>%
  filter(
    wing > 80 &
      wing < 90
  )

# Or, even more parsimoniously, simply separate the two filters with a comma:

measures %>%
  filter(
    wing > 80,
    wing < 90
  )

# Let's see what happens when we try to filter the data to Gray catbird:

birds %>%
  filter(
    species == "GRCA",
    species == "NOCA"
  )

# To address this, we can use the or operator, `|`:

birds %>%
  filter(
    species == "GRCA" |
      species == "NOCA"
  )

# More parsimoniously, use the `%in%` operator:

birds %>%
  filter(
    species %in% c("GRCA", "NOCA")
  )

# That gives us the same rows:

birds %>%
  filter(
    when_any(
      species == "GRCA",
      species == "NOCA"
    )
  )

# filter with a reference vector ------------------------------------------

# We can use the lubridate function `year` to subset the `visits` table:

visits %>%
  filter(
    year(date) == 2018
  )

# This is our reference vector, and we assign it to the name `visit_ids_2018`:

visit_ids_2018 <-
  visits %>%
  filter(
    year(date) == 2018
  ) %>%
  pull(visit_id)

# We can then subset `captures`:

captures %>%
  filter(visit_id %in% visit_ids_2018)

# Now you! Subset the `birds` data frame to species that are NOT represented in
# the `captures` data frame (Note: The foreign key in this table is `spp`).



# Here we filter on wing length and species in a single call:

measures %>%
  filter(
    wing > 80,
    wing < 90,
    spp == "GRCA"
  )

# subset to unique rows ---------------------------------------------------

# For example, we can `select` the `spp` field and then remove duplicate rows:

measures %>%
  select(spp) %>%
  distinct()

# You can skip `select` altogether:

measures %>%
  distinct(spp)

# We can then use `pull` to extract a vector of data:

measures %>%
  distinct(spp) %>%
  pull()

# We can explore this using `distinct`:

captures %>%
  drop_na(sex, bp_cp) %>%
  distinct(sex, bp_cp) %>%
  arrange(sex, bp_cp)
