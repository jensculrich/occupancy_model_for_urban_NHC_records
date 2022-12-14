### Generate species ranges
# jcu; started nov 29, 2022

# Use data from historical to present day to determine the range of each species
# Then, identify which grid cells are intersecting the range for each species.
# We will pass back the range data to prep_data_x.R, and then sub in 0's
# in the binary indicator array for whether or not a species was sampled at a site
# in a given time period, so that max obs = 0 for a site outside the species range.

library(tidyverse)
library(sf)

get_species_ranges <- function(
  urban_grid,
  site_name_vector,
  n_sites,
  species_vector,
  n_species,
  min_year_for_species_ranges
){
 
  species_ranges <- vector(mode = "list", length = n_species)
  
  crs <- "+proj=utm +zone=10 +ellps=GRS80 +datum=NAD83"
  
  # read occurrence data
  # this is occurrence data from all time records, not just from the study time span 
  df <- read.csv("./data/data_unfiltered.csv") 
  
  for(i in 1:n_species){
    
    species_name <- species_vector[i]
    
    # filter to records for species from decided time frame
    filtered <- df %>%
      filter(species == species_name,
             year > min_year_for_species_ranges) %>%
      dplyr::select(decimalLatitude, decimalLongitude)
    
    # project the filtered data
    filtered_prj <- st_as_sf(filtered,
                             coords = c("decimalLongitude", "decimalLatitude"), 
                             crs = 4326) %>% 
      st_transform(., crs = crs)
    
    # create a convex hull around the filtered occurrence records
    ch <- st_convex_hull(st_union(filtered_prj)) 
    
    # now determine which sites overlap with the ch
    # and add indicator that the site is in the range
    intersect <- as.data.frame(urban_grid[ch,] %>%
                                 mutate(in_range = 1))
    # join back with all sites
    intersecting_range <- left_join(urban_grid, intersect) 
    # replace NAs with indicator for site outside range = 0
    intersecting_range$in_range[is.na(intersecting_range$in_range)] <- 0
    
    species_ranges[[i]] <- intersecting_range$in_range
    
  }
  
  # test plot
  #plot(urban_grid$geometry)
  #plot(ch, col = alpha("skyblue", 0.5), add = TRUE)
  #plot(filtered_prj$geometry, col = alpha("black", 0.25), pch=19, add=TRUE)
  #legend("topright",
  #       legend = c("sites", "range"),
  #       fill = c("white", alpha("skyblue", 0.5)),       # Color of the squares
  #       border = "black") # Color of the border of the squares
  #title(main = "Inferred range for Copestylum mexicanum")
    
  # now see which sites (that are being included) overlap with the range
  
  ## --------------------------------------------------
  # Return stuff
  return(species_ranges)
    
}
