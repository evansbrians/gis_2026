# Script for 2.6 Tidy data tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Let's read in the data and have a look at the object:

weather <-
  read_csv("data/raw/messy_weather.csv")

# fixing the first violation of rule 1 ------------------------------------

# To move a set of columns into rows, we use the tidyr function `pivot_longer`:

weather %>%
  pivot_longer(
    march_1:march_31,
    names_to = "day",
    values_to = "value"
  )

# The `names_prefix = ` argument of `pivot_longer` removes a prefix:

weather_long <-
  weather %>%
  pivot_longer(
    march_1:march_31,
    names_to = "day",
    names_prefix = "march_",
    values_to = "value"
  )

# fixing the second violation of rule 1 -----------------------------------

# To combine several columns into one, we use the tidyr function `unite`:

weather_dated <-
  weather_long %>%
  unite(
    col = "date",
    year,
    month,
    day,
    sep = "-"
  )

# recognizing a violation of rule 2 ---------------------------------------

# Now you! The paragraph above states that the `variable` column records the
# names of three variables. Check that claim against `weather_dated`.



# fixing the violation of rule 2 ------------------------------------------

# For this we use the tidyr function `pivot_wider`:

weather_wide <-
  weather_dated %>%
  pivot_wider(
    names_from = variable,
    values_from = value
  )

# Now you! That accounting assumes every station contributed the same number of
# rows. Return the number of rows that each station contributes to
# `weather_wide`.



# returning to the third violation of rule 1 ------------------------------

# We split one column into several:

weather_split <-
  weather_wide %>%
  separate_wider_delim(
    temperature_min_max,
    delim = ":",
    names = c("temperature_min", "temperature_max")
  )

# fixing the violation of rule 3 ------------------------------------------

# We first select the columns that describe a station:

stations <-
  weather_split %>%
  select(
    station,
    longitude,
    latitude,
    elevation,
    state,
    name
  ) %>%
  distinct()

# The observation table records everything that was measured on a given day:

observations <-
  weather_split %>%
  select(
    station,
    date,
    precip,
    snow,
    temperature_min,
    temperature_max
  )

# Now you! Splitting the table into two did not sever the connection between
# them. In a single piped statement, attach the `name` of each station to the
# observation table, without carrying any other station column along with it.



# Now you! In a single piped statement, and without using any of the objects we
# assigned along the way:
# * Read in `messy_weather.csv`;
# * Stack the day columns into a `day` column and a `value` column, dropping the
#   "march_" prefix;
# * Build a `date` column, dropping the three columns that went into it;
# * Move the values of `variable` out into their own columns;
# * Split `temperature_min_max` into `temperature_min` and `temperature_max`;
# * Subset to the six columns of the observation table;
# * Assign the resultant object to your global environment with the name
#   `daily_weather`.



# tidying is not cleaning -------------------------------------------------

# The dplyr function `across` applies the same change to a selection of columns:

observations <-
  observations %>%
  mutate(
    across(precip:temperature_max, as.numeric)
  )

# working with the tidy data ----------------------------------------------

# Now that each variable has a column, a grouped summary is one statement:

observations %>%
  summarize(
    mean_min = mean(temperature_min, na.rm = TRUE),
    mean_max = mean(temperature_max, na.rm = TRUE),
    .by = station
  )

# We can now map each of them to an axis:

observations %>%
  left_join(
    stations %>%
      select(station, name),
    by = "station"
  ) %>%
  ggplot() +
  aes(
    x = temperature_min,
    y = temperature_max
  ) +
  geom_point(
    size = 1.5,
    alpha = 0.15
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    color = "#0072B2",
    linewidth = 1.2
  ) +
  facet_wrap(~ name) +
  labs(
    title = "Daily March temperatures, 2010 to 2020",
    x = "Minimum temperature (°C)",
    y = "Maximum temperature (°C)"
  ) +
  theme_bw()

# Now you! In a single piped statement, return the highest maximum temperature
# recorded at each station, labelled with the station's name rather than its
# code.



# saving the tidy data ----------------------------------------------------

# We can store them as a single list and write that list to a `.rds` file:

list(
  stations = stations,
  observations = observations
) %>%
  write_rds("data/processed/weather_tidy.rds")
