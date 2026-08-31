# Script for 2.2 Introduction to mutation tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Now you! In a single piped statement:
# * Read in the file `district_birds.rds`;
# * Extract the list item assigned to the name `captures`;
# * Subset `captures` to the columns `spp`, `sex`, `age`, `wing`, `tl`, `mass`,
#   `bp_cp`, and `fat`;
# * Assign the resultant object to your global environment with the name
#   `measures`.



# add or modify a column --------------------------------------------------

# I calculate the ratio between the `mass` and `wing` of each observation:

measures %>%
  mutate(mass_wing = mass / wing)

# You can verify this with the following calculation:

1:2 / 4:5

# I should note that naming the result is not required, but is worth doing:

measures %>%
  mutate(mass / wing)

# Notice what happens if we do not add a new column name:

measures %>%
  mutate(mass * 0.0353)

# To replace `mass` in the returned data frame:

measures %>%
  mutate(mass = mass * 0.0353)

# For example, let's add an `id`, which will basically just be the row number:

measures %>%
  mutate(
    id = 1:nrow(.)
  )

# This function generates a sequence of integer values:

measures %>%
  mutate(
    id = row_number()
  )

# We can specify the location of our new column:

measures %>%
  mutate(
    id = row_number(),
    .before = spp
  )

# mutate multiple columns -------------------------------------------------

# We could chain together multiple mutate statements:

measures %>%
  mutate(wing = wing / 10) %>%
  mutate(mass = mass * 0.0353)

# We simply separate each mutate argument with a comma:

measures %>%
  mutate(
    wing = wing / 10,
    mass = mass * 0.0353
  )

# We could conduct the calculation with a new `mutate` call:

measures %>%
  mutate(
    wing = wing / 10,
    mass = mass * 0.0353
  ) %>%
  mutate(mass_wing = mass / wing)

# Or, more parsimoniously, within the same mutate call:

measures %>%
  mutate(
    wing = wing / 10,
    mass = mass * 0.0353,
    mass_wing = mass / wing
  )

# The resultant `mass_wing` value is correct:

measures %>%
  mutate(
    mass_wing = mass / wing,
    wing = wing / 10,
    mass = mass * 0.0353
  )

# Now you! In a single `mutate()` call, convert `tl` from millimeters to
# centimeters and add a column named `mass_tl` that holds the ratio of `mass` to
# the converted `tl`.



# special case: na values -------------------------------------------------

# Let's look at the distribution of values in this column:

measures %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# replace na --------------------------------------------------------------

# We can replace `NA` values with the tidyr function `replace_na`:

measures %>%
  mutate(
    bp_cp = replace_na(bp_cp, "-")
  )

# After our mutation, I extract the column of interest with `pull`:

measures %>%
  mutate(
    bp_cp = replace_na(bp_cp, "-")
  ) %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# convert to na -----------------------------------------------------------

# Let's look again at the original distribution of `bp_cp`:

measures %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# We can use the dplyr function `na_if` to convert a value to `NA`:

measures %>%
  mutate(
    bp_cp = na_if(bp_cp, "U")
  ) %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# We could pipe the mutate statements together:

measures %>%
  mutate(
    bp_cp = replace_na(bp_cp, "-")
  ) %>%
  mutate(
    bp_cp = na_if(bp_cp, "U")
  ) %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# We can conduct both operations inside of the same `mutate` function:

measures %>%
  mutate(
    bp_cp = replace_na(bp_cp, "-"),
    bp_cp = na_if(bp_cp, "U")
  ) %>%
  pull(bp_cp) %>%
  table(useNA = "always")

# Now you! The `sex` column records "U" where the sex of a bird was unknown, but
# it also holds `NA` values. Record every unknown the same way: convert the `NA`
# values in `sex` to "U".



# add columns while dropping others ---------------------------------------

# We could do this in two steps -- mutate, then select:

measures %>%
  mutate(mass_wing = mass / wing) %>%
  select(spp, mass_wing)

# Setting `.keep = "none"` tells `mutate` to return only the columns:

measures %>%
  mutate(
    mass_wing = mass / wing,
    .keep = "none"
  )

# To carry `spp` along with our new column, we simply name it inside `mutate`:

measures %>%
  mutate(
    spp,
    mass_wing = mass / wing,
    .keep = "none"
  )

# We can also rename a column in the same step:

measures %>%
  mutate(
    species = spp,
    mass_wing = mass / wing,
    .keep = "none"
  )

# Compare `"used"` and `"unused"` on the same calculation:

measures %>%
  mutate(
    mass_wing = mass / wing,
    .keep = "used"
  )

# Compare `"used"` and `"unused"` on the same calculation:

measures %>%
  mutate(
    mass_wing = mass / wing,
    .keep = "unused"
  )
