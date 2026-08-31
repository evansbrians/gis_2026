# Script for 2.3 Grouped operations and summarizing tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Now you! In a single piped statement:
# * Read in the file `district_birds.rds`;
# * Extract the list item assigned to the name `captures`;
# * Subset `captures` to the columns `spp`, `sex`, `wing`, and `mass`;
# * Assign the resultant object to your global environment with the name
#   `measures`.



# group a mutation --------------------------------------------------------

# Below, we calculate mean mass of the capture records in `measures`:

measures %>%
  mutate(
    mean_mass =
      mean(mass, na.rm = TRUE)
  )

# Let's supply `spp` to the `.by = ` argument:

measures %>%
  mutate(
    mean_mass =
      mean(mass, na.rm = TRUE),
    .by = spp
  )

# With that column, we can compare the mass in each capture record:

measures %>%
  mutate(
    mean_mass =
      mean(mass, na.rm = TRUE),
    mass_index = mass / mean_mass,
    .by = spp
  )

# Now you! Add a column named `wing_index` that contains each capture record's
# wing length divided by the mean wing length of its species. Every row of
# `measures` should be maintained.



# group a filter ----------------------------------------------------------

# We subset `measures` to the records:

measures %>%
  filter(
    mass > mean(mass, na.rm = TRUE)
  )

# We can see that this omitted small species:

measures %>%
  filter(
    mass > mean(mass, na.rm = TRUE),
    .by = spp
  )

# We subset `measures` to the capture record with the greatest mass:

measures %>%
  slice_max(
    mass,
    n = 1,
    by = spp
  )

# Now you! Subset `measures` to the longest-winged capture record of each `sex`,
# maintaining all four columns.



# summarize ---------------------------------------------------------------

# It is worth committing this to memory!:

summary(measures)

# For example, let's calculate the mean and standard deviation of wing length:

measures %>%
  summarize(
    mean_wing =
      mean(wing, na.rm = TRUE),
    sd_wing =
      sd(wing, na.rm = TRUE)
  )

# We can add that with the dplyr function `n`, which is a row counter:

measures %>%
  summarize(
    n = n(),
    mean_wing =
      mean(wing, na.rm = TRUE),
    sd_wing =
      sd(wing, na.rm = TRUE)
  )

# To do so, let's use the tidyr function `drop_na`:

measures %>%
  drop_na(wing) %>%
  summarize(
    n = n(),
    mean_wing = mean(wing),
    sd_wing = sd(wing)
  )

# summarize by group ------------------------------------------------------

# We can produce a summary of `wing` for each species by supplying `.by = spp`:

measures %>%
  drop_na(wing) %>%
  summarize(
    n = n(),
    mean_wing = mean(wing),
    sd_wing = sd(wing),
    .by = spp
  )

# We can group by more than one variable by supplying them:

measures %>%
  summarize(
    n = n(),
    .by = c(spp, sex)
  )

# Now you! In a single `summarize()` call, return the number of capture records
# and the mean mass of each `sex`. Values that are missing from `mass` should be
# excluded from the mean.



# count the records in each group -----------------------------------------

# When a count is the only thing that we want, the statement reduces to:

measures %>%
  summarize(
    n = n(),
    .by = spp
  )

# We supply `count` with the variables to group:

measures %>%
  count(spp)

# `count` accepts more than one grouping variable:

measures %>%
  count(spp, sex)

# when to use group_by() --------------------------------------------------

# The lesson expects this to fail -- see it for why:

# The `.by = ` argument cannot do this:

measures %>%
  summarize(
    n = n(),
    .by =
      c(
        spp,
        sex = replace_na(sex, "U")
      )
  )

# The `group_by` function builds its grouping variables:

measures %>%
  group_by(
    spp,
    sex = replace_na(sex, "U")
  ) %>%
  summarize(
    n = n(),
    .groups = "drop"
  )

# We can build the column with `mutate` and then group by it with `.by = `:

measures %>%
  mutate(
    sex = replace_na(sex, "U")
  ) %>%
  summarize(
    n = n(),
    .by = c(spp, sex)
  )

# We can also rename a grouping variable as we group:

measures %>%
  group_by(species = spp) %>%
  summarize(n = n())

# when more than one step uses the grouping -------------------------------

# That is a grouped `filter` followed by a grouped `summarize`:

measures %>%
  group_by(spp) %>%
  filter(
    mass < mean(mass, na.rm = TRUE)
  ) %>%
  summarize(n = n())

# The `.by = ` argument returns the same counts:

measures %>%
  filter(
    mass < mean(mass, na.rm = TRUE),
    .by = spp
  ) %>%
  summarize(
    n = n(),
    .by = spp
  )

# remove the grouping when you are finished -------------------------------

# We count the captures of each species and sex:

measures %>%
  group_by(spp, sex) %>%
  summarize(n = n()) %>%
  slice_max(
    n,
    n = 1,
    with_ties = FALSE
  )

# The `.groups = "drop"` argument of `summarize` removes the grouping:

measures %>%
  group_by(spp, sex) %>%
  summarize(
    n = n(),
    .groups = "drop"
  ) %>%
  slice_max(
    n,
    n = 1,
    with_ties = FALSE
  )

# The dplyr function `ungroup` removes a grouping at any point in a pipe:

measures %>%
  group_by(spp, sex) %>%
  summarize(n = n()) %>%
  ungroup() %>%
  slice_max(
    n,
    n = 1,
    with_ties = FALSE
  )
