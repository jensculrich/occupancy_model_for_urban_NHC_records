### Generate species ranges
# jcu; started nov 29, 2022

# Use data from historical to present day to determine the range of each species
# Then, identify which grid cells are intersecting the range for each species.
# We will pass back the range data to prep_data.R, and then sub in 0's
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
  min_year_for_species_ranges,
  taxon,
  make_range_plot
){
  
  species_ranges <- vector(mode = "list", length = n_species)
  
  # USA_Contiguous_Albers_Equal_Area_Conic
  crs <- 5070
  
  # read occurrence data
  # this is occurrence data from all time records, not just from the study time span 
  # read the occurrence data for the given taxon
  # read either the syrphidae data or the bombus data
  if(taxon == "syrphidae"){
    df <- read.csv(paste0("./data/occurrence_data/", taxon, "_data_all.csv"))
  } else {
    df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
  }
  
  df <- df %>%
    
    # filter out records with high location uncertainty (threshold at 10km)
    # assuming na uncertainty (large portion of records) is under threshold
    mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
    filter(coordinateUncertaintyInMeters < 10000) %>%
    
    # filter any ranges to core range if desired
    # filter out B. impatiens from it's recently expanding introduced range (Looney et al.)
    # (filter out occurrences west of 100 Longitude)
    filter(decimalLatitude < 50) # remove any points from alaska (or untagged with state name but from alaska)
    
  
  if(taxon == "bombus"){
    df <- df %>% 
      filter(!(species == "impatiens" & decimalLongitude < -100)) %>%
      filter(!(species == "perplexus" & decimalLongitude < -100)) %>%
      filter(!(species == "pensylvanicus" & decimalLongitude < -120)) %>%
      filter(!(species == "pensylvanicus" & ((state.prov %in% c("Idaho", "Montana", "North Dakota")))))  %>%
      filter(!(species == "affinis" & (!(state.prov %in% 
                                           c("Minnesota", "Iowa", "Wisconsin", "Illinois",
                                             "Indiana", "Ohio", "West Virginia", "Virginia"))))) %>%
      filter(!(species == "vosnesenskii" & (!(state.prov %in% c("California", "Oregon", 
                                            "Washington", "Idaho", "Nevada")))))
  }
  
  # make the df into a spatial file
  #df$decimalLongitude <- na_if(df$decimalLongitude, '')
  #df$decimalLatitude <- na_if(df$decimalLatitude, '')
  
  df <- df %>% 
    filter(!is.na(decimalLongitude)) %>%
    filter(!is.na(decimalLatitude))
  
  urban_grid <- urban_grid %>% rename("geometry" = ".")
  
  
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
    
    
    # determine intersection or no intersection (1, or 0)
    intersect <- unlist(replace(st_intersects(urban_grid$geometry, ch), 
                                !sapply(st_intersects(urban_grid$geometry, ch), length),0))
    
    # join back with all sites
    intersecting_range <- cbind(urban_grid, intersect) 
    
    species_ranges[[i]] <- intersecting_range$intersect
    
    
    ##--------------------------------------------------------------------------
    # make plots
    
    # I went in here manually to make the plots for the subset of species ranges that were trimmed by hand
    
    if(make_range_plot == TRUE){
      
      library(tigris) # get state shapefile
      # spatial data - state shapefile
      states <- tigris::states() %>%
        #filter(NAME %in% c("California", "Oregon", "Washington", "Arizona", "Nevada"))
        # lower 48 + DC
        filter(REGION != 9) %>%
        filter(!NAME %in% c("Alaska", "Hawaii"))
      states_trans <- states  %>% 
        st_transform(., crs) # USA_Contiguous_Albers_Equal_Area_Conic
      
      ## B affinis
      
      # to make plot must grab ch from species using code above^
      
      # get 'out of core range' affinis points
      #df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
      
      # filtered points for affinis
      #temp <- df %>%
        
        # filter out records with high location uncertainty (threshold at 10km)
        # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
      #  filter(coordinateUncertaintyInMeters < 10000) %>%
        
      #  filter(species == "affinis") %>%
      #  filter((!(state.prov %in% c("Minnesota", "Iowa", "Wisconsin", "Illinois",
      #                              "Indiana", "Ohio", "West Virginia", "Virginia"))))
      
      # make the df into a spatial file
      #temp$decimalLongitude <- na_if(temp$decimalLongitude, '')
      #temp$decimalLatitude <- na_if(temp$decimalLatitude, '')
      
      #temp <- temp %>% 
      #  filter(!is.na(decimalLongitude)) %>%
      #  filter(!is.na(decimalLatitude))
      
      #species_name <- species_vector[i]
      
      # filter to records for species from decided time frame
      #filtered_2 <- temp %>%
      #  filter(species == species_name,
      #         year > min_year_for_species_ranges) %>%
      #  dplyr::select(decimalLatitude, decimalLongitude)
      
      # project the filtered data
      #filtered_prj_2 <- st_as_sf(filtered_2,
      #                           coords = c("decimalLongitude", "decimalLatitude"), 
      #                           crs = 4326) %>% 
      #  st_transform(., crs = crs)
      
      ## B impatiens
      
      # to make plot must grab ch from species using code above^
      
      # get 'out of core range' impatiens points
      #df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
      
      # filtered points for impatiens
      #temp <- df %>%
      
      # filter out records with high location uncertainty (threshold at 10km)
      # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
      #  filter(coordinateUncertaintyInMeters < 10000) %>%
      
      #  filter(species == "impatiens") %>%
      #  filter(decimalLongitude < -100)
      
      # make the df into a spatial file
      #temp$decimalLongitude <- na_if(temp$decimalLongitude, '')
      #temp$decimalLatitude <- na_if(temp$decimalLatitude, '')
      
      #temp <- temp %>% 
      #  filter(!is.na(decimalLongitude)) %>%
      #  filter(!is.na(decimalLatitude))
      
      #species_name <- species_vector[17]
      
      # filter to records for species from decided time frame
      #filtered_2 <- temp %>%
      #  filter(species == species_name,
      #         year > min_year_for_species_ranges) %>%
      #  dplyr::select(decimalLatitude, decimalLongitude)
      
      # project the filtered data
      #filtered_prj_2 <- st_as_sf(filtered_2,
      #                           coords = c("decimalLongitude", "decimalLatitude"), 
      #                           crs = 4326) %>% 
       # st_transform(., crs = crs)
      
      ## B vosnesenskii
      
      # to make plot must grab ch from species using code above^
      
      # get 'out of core range' points
      #df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
      
      # filtered points for vosnesenskii
      #temp <- df %>%
      
      # filter out records with high location uncertainty (threshold at 10km)
      # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
       # filter(coordinateUncertaintyInMeters < 10000) %>%
      
       # filter(species == "vosnesenskii") %>%
       # filter((!(state.prov %in% c("California", "Oregon", "Washington", "Idaho",
             #                       "Nevada"))))
      
      # make the df into a spatial file
      #temp$decimalLongitude <- na_if(temp$decimalLongitude, '')
      #temp$decimalLatitude <- na_if(temp$decimalLatitude, '')
      
      #temp <- temp %>% 
      #  filter(!is.na(decimalLongitude)) %>%
      #  filter(!is.na(decimalLatitude))
      
      #species_name <- species_vector[32]
      
      # filter to records for species from decided time frame
      #filtered_2 <- temp %>%
       # filter(species == species_name,
       #        year > min_year_for_species_ranges) %>%
       # dplyr::select(decimalLatitude, decimalLongitude)
      
      # project the filtered data
      #filtered_prj_2 <- st_as_sf(filtered_2,
       #                          coords = c("decimalLongitude", "decimalLatitude"), 
       #                          crs = 4326) %>% 
       #st_transform(., crs = crs)
      
      ## B perplexus
      
      # to make plot must grab ch from species using code above^
      
      # get 'out of core range' points
      #df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
      
      # filtered points for perplexus
      #temp <- df %>%
        
        # filter out records with high location uncertainty (threshold at 10km)
        # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
       # filter(coordinateUncertaintyInMeters < 10000) %>%
        
       # filter(species == "perplexus") %>%
       # filter(decimalLongitude < -100)
      
      # make the df into a spatial file
      #temp$decimalLongitude <- na_if(temp$decimalLongitude, '')
      #temp$decimalLatitude <- na_if(temp$decimalLatitude, '')
      
      #temp <- temp %>% 
      #  filter(!is.na(decimalLongitude)) %>%
      #  filter(!is.na(decimalLatitude))
      
      #species_name <- species_vector[24]
      
      # filter to records for species from decided time frame
      #filtered_2 <- temp %>%
      #  filter(species == species_name,
      #         year > min_year_for_species_ranges) %>%
      #  dplyr::select(decimalLatitude, decimalLongitude)
      
      # project the filtered data
      #filtered_prj_2 <- st_as_sf(filtered_2,
       #                          coords = c("decimalLongitude", "decimalLatitude"), 
        #                         crs = 4326) %>% 
        #st_transform(., crs = crs)
      
      ## B pensylvanicus
      
      # to make plot must grab ch from species using code above^
      
      # get 'out of core range' points
      #df <- read.csv(paste0("./data/occurrence_data/bbna_private/bbna_trimmed.csv"))
      
      # filtered points for perplexus
      #temp <- df %>%
      
      # filter out records with high location uncertainty (threshold at 10km)
      # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
      # filter(coordinateUncertaintyInMeters < 10000) %>%
      
        #filter(!(species == "pensylvanicus" & decimalLongitude > -120)) 
        
     # temp2 <- df %>%
        
        # filter out records with high location uncertainty (threshold at 10km)
        # assuming na uncertainty (large portion of records) is under threshold
      #  mutate(coordinateUncertaintyInMeters = replace_na(coordinateUncertaintyInMeters, 0)) %>%
      #  filter(coordinateUncertaintyInMeters < 10000) %>%
      #  filter(!(species == "pensylvanicus" & (!(state.prov %in% c("Idaho", "Montana", "North Dakota"))))) 
      
     # temp <- rbind(temp, temp2)
      
      # make the df into a spatial file
      #temp$decimalLongitude <- na_if(temp$decimalLongitude, '')
      #temp$decimalLatitude <- na_if(temp$decimalLatitude, '')
      
      #temp <- temp %>% 
      #  filter(!is.na(decimalLongitude)) %>%
      #  filter(!is.na(decimalLatitude))
      
      #species_name <- species_vector[23]
      
     # # filter to records for species from decided time frame
      #filtered_2 <- temp %>%
       # filter(species == species_name,
       #        year > min_year_for_species_ranges) %>%
        #dplyr::select(decimalLatitude, decimalLongitude)
      
      # project the filtered data
     # filtered_prj_2 <- st_as_sf(filtered_2,
        #                        coords = c("decimalLongitude", "decimalLatitude"), 
      #                         crs = 4326) %>% 
      #st_transform(., crs = crs)
      
      
      
        
      # range map plot
      ggplot() +
        geom_sf(data = states_trans, fill = 'white', lwd = 0.05) +
        geom_sf(data = urban_grid, fill = "transparent", lwd = 0.3) +
        geom_sf(data = ch, fill = 'skyblue', alpha = 0.5) +
        geom_sf(data = filtered_prj, alpha = 0.5) +
        geom_sf(data = filtered_prj_2, shape = 4, size = 5, color = "red") +
        ggtitle(paste0("Inferred range for B.", species_name)) +
        labs(x = "Longitude") +
        labs(y = "Latitude") 
      # now see which sites (that are being included) overlap with the range
      
    }
    
  }
  
  ## --------------------------------------------------
  # Return stuff
  return(species_ranges)
  
}
