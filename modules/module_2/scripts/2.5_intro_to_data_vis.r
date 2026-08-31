# Script for 2.5 Introduction to data visualization with ggplot2 tutorial

# setup -------------------------------------------------------------------

library(tidyverse)

# Chickadee captures:

chickadees <-
  read_csv("data/raw/chickadees.csv")

# plotting data -----------------------------------------------------------

# Because data is the first argument of `ggplot`, it can also be piped in:

chickadees %>%

  # Initialize the plot with the data:

  ggplot()

# aesthetic mappings ------------------------------------------------------

# Aesthetic mappings are supplied with the ggplot2 function `aes`:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass
  )

# scatterplot -------------------------------------------------------------

# To create a scatterplot, we want to add point geometries to our plot:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass
  ) +

  # Add geometries:

  geom_point()

# We can add another geometry to the plot, a line of best fit:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass
  ) +

  # Add geometries:

  geom_point() +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE
  )

# We could color the points and the line by species:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass
  ) +

  # Add geometries:

  geom_point(
    aes(color = spp)
  ) +
  geom_smooth(
    aes(color = spp),
    method = "lm",
    formula = y ~ x,
    se = FALSE
  )

# We can simplify our argument above by specifying the color aesthetic:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point() +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE
  )

# We can further emphasize the trends by making the fitted lines wider:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  )

# scales: numeric range ---------------------------------------------------

# We can use `summary` to figure that out:

summary(chickadees)

# Setting `expand = c` ensures that each axis stops at our chosen values:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  )

# scales: colors ----------------------------------------------------------

# To begin, I could choose colors by name:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    "Species",
    values = c("orange", "green")
  )

# With this picture, I have chosen to go with a color:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    values = c("#595B18", "#CA621E")
  )

# brewed colors -----------------------------------------------------------

# To use an RColorBrewer palette:

scale_color_brewer(palette = "Dark2")

# colors that everyone can see --------------------------------------------

# I will take the blue and the vermillion from it:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    values = c("#0072B2", "#D55E00")
  )

# facets ------------------------------------------------------------------

# We will keep our points and lines colored by species and add a facet:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    values = c("#0072B2", "#D55E00")
  ) +

  # Divide the plot into facets:

  facet_wrap(~ sex)

# Let's explore the sex variable:

chickadees %>%
  count(sex)

# We can use `factor` to change this variable to a factor:

chickadees %>%
  mutate(
    sex =
      factor(
        sex,
        levels = c("F", "M"),
        labels = c("Female", "Male")
      )
  )

# Let's see how it looks now when we plot it:

chickadees %>%

  # Convert sex to factor:

  mutate(
    sex =
      factor(
        sex,
        levels = c("F", "M"),
        labels = c("Female", "Male")
      )
  ) %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    values = c("#0072B2", "#D55E00")
  ) +

  # Divide the plot into facets:

  facet_wrap(~ sex)

# labels ------------------------------------------------------------------

# We change it by supplying a title:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    "Species",
    values = c("#0072B2", "#D55E00")
  ) +

  # Divide the plot into facets:

  facet_wrap(~ sex) +

  # Add labels:

  labs(
    title = "Wing length and mass of Black-capped and Carolina chickadees",
    x = "Wing length (mm)",
    y = "Mass (g)"
  )

# themes ------------------------------------------------------------------

# I usually use this as a starting point for my plots:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    "Species",
    values = c("#0072B2", "#D55E00")
  ) +

  # Divide the plot into facets:

  facet_wrap(~ sex) +

  # Add labels:

  labs(
    title = "Wing length and mass of Black-capped and Carolina chickadees",
    x = "Wing length (mm)",
    y = "Mass (g)"
  ) +

  # Modify the theme:

  theme_bw()

# Let's make our tick labels larger:

chickadees %>%

  # Initialize the plot with the data:

  ggplot() +

  # Map data to visual elements:

  aes(
    x = wing,
    y = mass,
    color = spp
  ) +

  # Add geometries:

  geom_point(
    size = 2.75,
    alpha = 0.25
  ) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1.5
  ) +

  # Define scale elements:

  scale_y_continuous(
    limits = c(7, 13),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    limits = c(50, 70),
    expand = c(0, 0)
  ) +
  scale_color_manual(
    "Species",
    values = c("#0072B2", "#D55E00")
  ) +

  # Divide the plot into facets:

  facet_wrap(~ sex) +

  # Add labels:

  labs(
    title = "Wing length and mass of Black-capped and Carolina chickadees",
    x = "Wing length (mm)",
    y = "Mass (g)"
  ) +

  # Modify the theme:

  theme_bw() +
  theme(
    axis.text =
      element_text(size = 12)
  )
