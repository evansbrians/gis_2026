# GIS in R final exam: Your weird new boss counts caterpillars

# 1 -----------------------------------------------------------------------

# Please start by saving your R script as
# `final_exam_[your last name]_[your first name].R`, using snake case.

# Note: You will submit this script file as your exam.

# 2 -----------------------------------------------------------------------

# Attach the sf, tidyterra, tmap, and tidyverse packages, in that order:



# Set your tmap mode to "view":



# 3 -----------------------------------------------------------------------

# Prepare the following objects. Globally assign only the names requested.

# `nlcd_key`: Retain `id` and `name` from `nlcd_key.csv`, rename `name` to
# `land_cover`, and globally assign the result:



# `lc`: Read `classified_lc.tif`, globally assign the result, and use
# `nlcd_key` as its category table:



# `dem`: Prepare `data/raw/final_exam_data/dem_dc_10m.tif` as a layer named
# `elevation` with the CRS and grid of `lc`. Calculate the mean elevation of
# the source cells that contribute to each output cell:



# 4 -----------------------------------------------------------------------

# Use iteration to read and preprocess all four files. Each resulting object
# should retain the geometry and a single field named `name`, derived from
# `NAME`, and should use EPSG 32618. Suppress the printing of each file's
# metadata.
#
# Globally assign the four objects to `metro_stops`, `national_parks`,
# `streets`, and `wards`:



# 5 -----------------------------------------------------------------------

# Read and preprocess `Urban_Forestry_Street_Trees.csv`, then globally assign
# the result to `trees`. The finished object should:
#
# * Use the four fields `GENUS_NAME`, `DBH`, `X`, and `Y`, renamed
#   `genus`, `dbh`, `longitude`, and `latitude`
# * Exclude records with a missing value or a genus recorded as "No" or
#   "Other"
# * Include only trees with a diameter greater than 30 centimeters, without
#   retaining `dbh`
# * Classify Quercus as "oak", Acer as "maple", and every other genus as
#   "other"
# * Be a simple features POINT object in EPSG 32618 that contains only trees
#   within `wards`



# 6 -----------------------------------------------------------------------

# A tibble data frame with one row for each ward, fields giving the numbers
# of oaks and maples, and a field named `total` giving the number of trees
# across all classes. Do not include the count of the "other" class as a
# separate field, and sort the result by ward:



# A ggplot bar plot of the number of trees in each ward, divided into facets
# by tree class. Give the axes informative labels:



# 7 -----------------------------------------------------------------------

# Generate a ggplot map of the wards in which fill color represents the
# number of trees per square kilometer. Include an informative legend title:



# 8 -----------------------------------------------------------------------

# Return a tibble data frame with one row for each ward and a field named
# `parkland_ha` giving the area of National Park Service land within it, in
# hectares. Sort the result by ward. Where park features overlap, count the
# shared area only once:



# 9 -----------------------------------------------------------------------

# Return a tibble data frame giving the number of trees on National Park
# Service land and on other land. Classify the groups as "National Park
# Service" and "other":



# Retain the trees that do not fall within any National Park Service feature
# and globally assign the result to `trees_no_nps`:



# Provide an interactive map of `trees_no_nps` in which fill color represents
# tree class and nearby points are clustered:



# 10 ----------------------------------------------------------------------

# Merge the classes of `lc` into "water" (11), "developed" (21 through 24),
# "forest" (41 through 43), and "other" (all remaining classes). Code the
# merged classes 1 through 4, respectively. Attach a category table whose
# label field is named `general_class`, and globally assign the raster to
# `general_lc`:



# `forest`: A globally assigned raster in which forest cells have the value
# 1 and all other cells are NA:



# `forest_distance`: A globally assigned raster giving the distance in meters
# to the nearest forest cell. Name its layer `distance_m`, and retain values
# only within `wards`:



# A ggplot map of `forest_distance` with an informative legend title:



# `trees_no_forests`: A globally assigned simple features object containing
# the trees in `trees_no_nps` that are more than 100 meters from the nearest
# forest cell. Do not retain the extracted distance as a field:



# Set the seed to 2026 and use a random sample of 1,000 non-NA cells from
# `forest_distance` to estimate the median distance to forest across the
# wards:



# 11 ----------------------------------------------------------------------

# Identify the patches in `forest`, treating cells that touch at a corner as
# connected, and globally assign the result to `forest_patches`:



# Return a tibble data frame with fields giving the number of patches, the
# area of the largest patch in hectares, and the number of patches that are
# at least 10 hectares:



# 12 ----------------------------------------------------------------------

# Calculate slope from `dem`, in degrees, and globally assign the result to
# `slope`:



# Return the mean slope of each class in `general_lc`:



# Generate a raster in which the value of each cell is the proportion of
# forest cells within its centered 7 × 7 window. Name its layer
# `forest_cover` and globally assign the raster to `forest_cover`:



# 13 ----------------------------------------------------------------------

# Generate `tree_counts`, a globally assigned raster on the grid of `lc` that
# contains the number of trees in `trees_no_forests`. Cells with no trees
# should have the value 0. Aggregate the raster by a factor of two using the
# sum, name its layer `trees`, and mask it to `wards`:



# Generate `street_points`, a globally assigned simple features object
# containing the distinct vertices of named streets. Do not retain the
# street name:



# Generate `sampling_points` by adding the number of trees, slope, and
# forest cover at each candidate point. Retain points with at least five
# trees and a slope of less than 10 degrees, then globally assign the result:



# 14 ----------------------------------------------------------------------

# Globally assign the sampling points near these stations to
# `sampling_metro`:
#
# * Congress Heights
# * Eastern Market
# * Fort Totten
# * Minnesota Ave
# * Tenleytown-AU
# * Woodley Park-Zoo Adams Morgan
#
# The result should:
#
# * Contain only points within 1 km of a listed station and retain
#   the station name
# * Include fields giving the numbers of oaks and maples from
#   `trees_no_forests` within 30 meters of each point
# * Include a field named `class` that combines "oak" or "no oak" with
#   "maple" or "no maple", separated by a comma and a space
# * Include the two points with the most trees for each combination of
#   Metro station and class, ignoring ties



# Generate an interactive map on an Esri.WorldImagery basemap in which fill
# color represents `class`:



# extra credit 1 ----------------------------------------------------------

# Return the length, in kilometers, of a path that begins at the Eastern
# Market Metro station and connects its sampling points in order of their
# distance from the station:



# extra credit 2 ----------------------------------------------------------

# Generate a raster of 100 × 100 m cells covering `wards` in which each cell
# contains the number of oaks in `trees`, including zeros where no oaks
# occur, and globally assign it to `oak_counts`:



# Use that raster to generate a kernel density surface of oaks per square
# kilometer with a Gaussian kernel and a bandwidth of 300 meters, then
# globally assign it to `oak_density`:



# Provide a ggplot map of `oak_density`:



# Return the name of the ward that contains its peak:

