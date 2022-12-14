### Prepeare data to feed to model_integrated.stan
# jcu; started oct 27, 2022

# will need to assign occupancy intervals and visit numbers
# for occupancy (as opposed to abundance), will need to 
# filter down to one unique occurrence per species*site*interval*year

## The data we will need to prepare to feed to the model:
# V_citsci # an array of presence/absence citizen science detection data
# V_citsci_NA # indicator of whether site is in species range 
# V_museum # an array of presence/absence museum records detection data
# V_museum_NA # indicator of whether a) site is in species range and b) ..
# if a museum community sampling event occurred at the site in the visit time
# n_species # number of species
# n_sites # number of sites
# n_intervals # number of occupancy intervals 
# n_visits # number of visits in each interval

library(tidyverse)

prep_data <- function(era_start, era_end, n_intervals, n_visits, 
                      min_records_per_species,
                      grid_size, min_population_size, 
                      min_records_for_community_sampling_event,
                      min_year_for_species_ranges) {
  
  source("./data/get_spatial_data.R")
  
  # retrieve the spatial occurrence record data
  my_spatial_data <- get_spatial_data(
    grid_size, min_population_size)
  
  # save the data in case you want to make tweaks to the model run
  # without redoing the data prep
  # saveRDS(my_spatial_data, "./analysis/spatial_data_list.rds")
  # my_spatial_data <- readRDS("./analysis/spatial_data_list.rds")
  gc()
  
  df_id_urban_filtered <- as.data.frame(my_spatial_data$df_id_urban_filtered)
  
  # spatial covariate data to pass to run model
  pop_density_vector <- my_spatial_data$scaled_pop_density
  impervious_cover_vector <- my_spatial_data$scaled_impervious_cover
  site_area_vector <- my_spatial_data$scaled_grid_area
  site_name_vector <- my_spatial_data$site_name_vector
  urban_grid <- my_spatial_data$urban_grid
  
  # other info to pass to output that we may want to keep track of
  # correlation between variables
  correlation_matrix <- my_spatial_data$correlation_matrix
  # total records from time period
  total_records <- nrow(df_id_urban_filtered)
  # citsci and museum records from time period
  citsci_records <- df_id_urban_filtered %>%
    filter(basisOfRecord == "HUMAN_OBSERVATION") %>%
    nrow()
  museum_records <- df_id_urban_filtered %>%
    filter(basisOfRecord == "PRESERVED_SPECIMEN") %>%
    nrow()
  # species counts
  species_counts <- df_id_urban_filtered %>%
    group_by(species) %>%
    count()
  
  ## --------------------------------------------------
  # assign study dimensions
  
  total_years <- era_end - era_start + 1
  remainder <- total_years %% n_intervals
  n_visits <- n_visits
  min_records_per_species <- min_records_per_species
  
  ## --------------------------------------------------
  # assign occupancy visits and intervals and reduce to one
  # sample per species per site per visit
  
  df_filtered <- df_id_urban_filtered %>%
    
    # remove records (if any) missing species level identification
    filter(species != "") %>%
    
    # assign year as - year after era_start
    mutate(occ_year = (year - era_start)) %>% 
    
    # remove data from years that are in the remainder
    # occupancy intervals have to be equal in length for the model to process
    # e.g. we can't have intervals of 3 years and then one interval with only 1 year
    # filter(occ_year %in% (remainder:1)) %>%
    
    # remove years before the start date
    filter(occ_year >= 0) %>%
    # remove years after end date
    filter(occ_year < total_years) %>%
    
    # now assign the years into 1:n_intervals
    mutate(occ_interval = occ_year %/% n_visits) %>%
    
    # add a sampling round (1:n)
    mutate(visit = (occ_year %% n_visits)) %>%
    
    # remove species with total observations (n) < min_records_per_species 
    group_by(species) %>%
    add_tally() %>%
    filter(n >= min_records_per_species) %>%
    ungroup() %>%
    
    # one unique row per site*species*occ_interval*visit combination
    group_by(grid_id, species, occ_interval, visit) %>% 
    slice(1) %>%
    ungroup() %>%
    
    # for now, reducing down to mandatory data columns
    dplyr::select(species, grid_id, occ_interval, occ_year, visit) %>%
    arrange((occ_year))
  # end pipe
  
  ## --------------------------------------------------
  # filter to citizen science records
  # assign occupancy visits and intervals and reduce to one
  # sample per species per site per visit
  
  df_citsci <- df_id_urban_filtered %>%
    
    # remove records (if any) missing species level identification
    filter(species != "") %>%
    
    # assign year as - year after era_start
    mutate(occ_year = (year - era_start)) %>%
    
    # remove years before the start date
    filter(occ_year >= 0) %>%
    # remove years after end date
    filter(occ_year < total_years) %>%
    
    # now assign the years into 1:n_intervals
    mutate(occ_interval = occ_year %/% n_visits) %>%
    
    # add a sampling round (1:n)
    mutate(visit = (occ_year %% n_visits)) %>%
    
    # remove species with total observations (n) < min_records_per_species
    # these are records across all citizen science AND preserved specimen records
    group_by(species) %>%
    add_tally() %>%
    filter(n >= min_records_per_species) %>%
    ungroup() %>%
    
    # filter to citizen science data only
    filter(basisOfRecord == "HUMAN_OBSERVATION") %>% 
    
    # one unique row per site*species*occ_interval*visit combination
    group_by(grid_id, species, occ_interval, visit) %>% 
    slice(1) %>%
    ungroup() %>%
    
    # for now, reducing down to mandatory data columns
    dplyr::select(species, grid_id, occ_interval, occ_year, visit) %>%
    arrange((occ_year))
  # end pipe
  
  ## --------------------------------------------------
  # filter to museum records
  # assign occupancy visits and intervals and reduce to one
  # sample per species per site per visit
  
  df_museum <- df_id_urban_filtered %>%
    
    # remove records (if any) missing species level identification
    filter(species != "") %>%
    
    # assign year as - year after era_start
    mutate(occ_year = (year - era_start)) %>%
    
    # remove years before the start date
    filter(occ_year >= 0) %>%
    # remove years after end date
    filter(occ_year < total_years) %>%
    
    # now assign the years into 1:n_intervals
    mutate(occ_interval = occ_year %/% n_visits) %>%
    
    # add a sampling round (1:n)
    mutate(visit = (occ_year %% n_visits)) %>%
    
    # remove species with total observations (n) < min_records_per_species
    # these are records across all citizen science AND preserved specimen records
    group_by(species) %>%
    add_tally() %>%
    filter(n >= min_records_per_species) %>%
    ungroup() %>%
    
    # filter to citizen science data only
    filter(basisOfRecord == "PRESERVED_SPECIMEN") %>% 
    
    # determine whether a community sampling event occurred
    # using collector name might be overly conservative because for example
    # the data includes recordedBy == J. Fulmer *and* recordedBy J. W. Fulmer
    # instead grouping by collections housed in the same institution from the same year
    # within a site
    group_by(institutionCode, year, grid_id) %>%
    mutate(n_species_sampled = n_distinct(species)) %>%
    filter(n_species_sampled >= min_species_for_community_sampling_event) %>%
    
    # one unique row per site*species*occ_interval*visit combination
    group_by(grid_id, species, occ_interval, visit) %>% 
    slice(1) %>%
    ungroup() %>%
    
    # for now, reducing down to mandatory data columns
    dplyr::select(species, grid_id, occ_interval, occ_year, visit) %>%
    arrange((occ_year))
  # end pipe
  
  ## --------------------------------------------------
  # Extract stan data from df
  # I use the list of all species and all sites 
  # rather than species and sites sampled potentially by only citizen science or by only museums
  # to generate these master lists of all possible sites and species
  
  ## Get unique species 
  # create an alphabetized list of all species encountered across all sites*intervals*visits
  species_list <- df_filtered %>%
    group_by(species) %>%
    slice(1) %>% # take one row per species (the name of each species)
    ungroup() %>%
    dplyr::select(species) # extract species names column as vector
  
  # get vectors of species, sites, intervals, and visits 
  # these are all species that were observed at least min_records_per_species
  species_vector <- species_list %>%
    pull(species)
  
  ## Get unique sites 
  # create an alphabetized list of all sites
  site_vector <- site_name_vector
  
  site_list <- as.data.frame(site_vector) %>%
    rename("grid_id" = "site_vector")
  
  interval_vector <- as.vector(levels(as.factor(df_filtered$occ_interval)))
  
  visit_vector <- as.vector(levels(as.factor(df_filtered$visit)))
  
  # find study dimensions from the pooled data
  n_species <- length(species_vector)
  
  n_sites <- length(site_vector)
  
  n_intervals <- length(interval_vector)
  
  n_visits <- length(visit_vector)
  
  ## --------------------------------------------------
  ## Now we are ready to create the detection matrices, V_citsci and V_museum
  
  ## --------------------------------------------------
  ## V_citsci 
  V_citsci <- array(data = NA, dim = c(n_species, n_sites, n_intervals, n_visits))
  
  for(i in 1:n_intervals){
    for(j in 1:n_visits){
      
      # iterate this across visits within intervals
      temp <- df_citsci %>%
        # filter to indices for interval and visit
        filter(occ_interval == (i - 1), # intervals start at 0 so need to subtract 1 from i
               visit == (j - 1)) %>%  # visits start at 0 so need to subtract 1 from j
        # now join with all species (so that we include species not captured during 
        # this interval*visit but which might actually be at some sites undetected)
        full_join(species_list, by="species") %>%
        # now join with all sites columns (so that we include sites where no species captured during 
        # this interval*visit but which might actually have some species that went undetected)
        mutate(grid_id = as.character(grid_id)) %>%
        full_join(site_list, by="grid_id") %>%
        # have to convert back to integer to get correct ordering from low to high
        # MUST MATCH SITE NAMES VECTOR
        mutate(grid_id = as.integer(grid_id)) %>%
        # group by SPECIES
        group_by(species) %>%
        mutate(row = row_number()) %>%
        # spread sites by species, and fill with 0 if species never captured this interval*visit
        spread(grid_id, row, fill = 0) %>%
        # replace number of unique site captures of the species (if > 1) with 1.
        mutate_at(5:(ncol(.)), ~replace(., . > 1, 1)) %>%
        # if more columns are added these indices above^ might need to change
        # 5:(n_species+5) represent the columns of each site in the matrix
        # just need the matrix of 0's and 1's
        dplyr::select(5:(ncol(.))) %>%
        # if some sites had no species, this workflow will construct a row for species = NA
        # we want to filter out this row ONLY if this happens and so need to filter out rows
        # for SPECIES not in SPECIES list
        filter(species  %in% levels(as.factor(species_list$species)))
      
      # convert from dataframe to matrix
      temp_matrix <- as.matrix(temp)
      # remove species names
      temp_matrix <- temp_matrix[,-1]
      
      # replace NAs for the interval i and visit j with the matrix
      V_citsci[1:n_species, 1:n_sites,i,j] <- temp_matrix[1:n_species, 1:n_sites]
      
    }
  }
  
  class(V_citsci) <- "numeric"
  
  ## --------------------------------------------------
  ## V_museum 
  V_museum <- array(data = NA, dim = c(n_species, n_sites, n_intervals, n_visits))
  
  for(i in 1:n_intervals){
    for(j in 1:n_visits){
      
      # iterate this across visits within intervals
      temp <- df_museum %>%
        # filter to indices for interval and visit
        filter(occ_interval == (i - 1), # intervals start at 0 so need to subtract 1 from i
               visit == (j - 1)) %>%  # visits start at 0 so need to subtract 1 from j
        # now join with all species (so that we include species not captured during 
        # this interval*visit but which might actually be at some sites undetected)
        full_join(species_list, by="species") %>%
        # now join with all sites columns (so that we include sites where no species captured during 
        # this interval*visit but which might actually have some species that went undetected)
        mutate(grid_id = as.character(grid_id)) %>%
        full_join(site_list, by="grid_id") %>%
        # have to convert back to integer to get correct ordering from low to high
        # MUST MATCH SITE NAMES VECTOR
        mutate(grid_id = as.integer(grid_id)) %>%
        # group by SPECIES
        group_by(species) %>%
        mutate(row = row_number()) %>%
        # spread sites by species, and fill with 0 if species never captured this interval*visit
        spread(grid_id, row, fill = 0) %>%
        # replace number of unique site captures of the species (if > 1) with 1.
        mutate_at(5:(ncol(.)), ~replace(., . > 1, 1)) %>%
        # if more columns are added these indices above^ might need to change
        # 5:(n_species+5) represent the columns of each site in the matrix
        # just need the matrix of 0's and 1's
        dplyr::select(5:(ncol(.))) %>%
        # if some sites had no species, this workflow will construct a row for species = NA
        # we want to filter out this row ONLY if this happens and so need to filter out rows
        # for SPECIES not in SPECIES list
        filter(species  %in% levels(as.factor(species_list$species)))
      
      
      # convert from dataframe to matrix
      temp_matrix <- as.matrix(temp)
      # remove species names
      temp_matrix <- temp_matrix[,-1]
      
      # replace NAs for the interval i and visit j with the matrix
      V_museum[1:n_species, 1:n_sites,i,j] <- temp_matrix[1:n_species, 1:n_sites]
      
    }
  }
  
  class(V_museum) <- "numeric"
  
  ## --------------------------------------------------
  # Generate an indicator array for whether or not a community-wide museum 
  # sampling event occurred at the site in a year
  
  # first make a df of all possible site visits * species visits
  all_species_site_visits <- as.data.frame(cbind(
    rep(species_vector, times=(n_sites*n_intervals*n_visits)),
    as.integer(rep(site_vector, each=n_species, times=n_intervals*n_visits)),
    rep(interval_vector, each=n_species*n_sites, times=(n_visits)),
    rep(visit_vector, each=n_species*n_sites*n_intervals)
    #rep(0:(total_years-1),)
  )) %>%
    rename("species" = "V1",
           "grid_id" = "V2",
           "occ_interval" = "V3",
           "visit" = "V4") %>%
    #"occ_year" = "V5") %>%
    mutate(grid_id = as.integer(grid_id))
  
  ## --------------------------------------------------
  # Get species ranges
  source("./data/get_species_ranges.R")
  species_ranges <- get_species_ranges(urban_grid,
                                       site_name_vector,
                                       n_sites,
                                       species_vector,
                                       n_species,
                                       min_year_for_species_ranges)
  
  gc()
  
  ## --------------------------------------------------
  # Now infer an NA structure for sites outside of range or 
  # sites* visits (museums only) where no community sampling event occurred
  
  ## --------------------------------------------------
  # Infer citizen science missing data
  # Particularly, whether the species can be sampled or not at a site given its range
  # this is the only condition considered to effect whether a species could potentially
  # be detected by a citizen science survey effort (compare with museum records)
  
   df_citsci_visits <- as.data.frame(cbind(rep(species_vector, each=n_sites),
                rep(site_vector, times = n_species),
                rep(1, times = n_species*n_sites),
    unlist(species_ranges))) %>%
    rename("species" = "V1",
           "grid_id" = "V2",
           "community_sample" = "V3",
           "in_range" = "V4") %>%
    mutate(sampled = as.numeric(community_sample)*
             as.numeric(in_range),
           grid_id = as.integer(grid_id)) %>%
    left_join(all_species_site_visits, .) 
  
  V_citsci_NA <- array(data = df_citsci_visits$sampled, dim = c(n_species, n_sites, n_intervals, n_visits))
  # check <- which(V_citsci>V_citsci_NA) # should NEVER have occurrences where the species can't be sampled,
  # thus check should be empty
  
  ## --------------------------------------------------
  # Infer museum record missing data
  # Particularly, whether the species can be sampled or not at a site given its range
  # AND 
  # whether or not a community sampling event has occurred
  # be detected by a citizen science survey effort (compare with museum records)
  
  # remove extra species rows, just one for each species per site per unique visit
  # keep in mind that we've already removed visits that did not pass our
  # minimum threshold for a community sample
  # so all site visits here have min_species_for_community_sampling_event or more species in the visit
  df_museum_visits <- df_museum %>%
    group_by(grid_id, occ_year, visit) %>%
    slice(1) %>% # take one row per species (the name of each species)
    ungroup() %>%
    dplyr::select(-species) %>%
    mutate(community_sample = 1) %>%
    mutate(occ_interval = as.character(occ_interval),
           occ_year = as.character(occ_year),
           visit = as.character(visit))
  
  all_visits_museum_visits_joined <- left_join(all_species_site_visits, df_museum_visits, 
                    by=c("grid_id", "occ_interval", "visit")) %>%
    # create an indicator if the site visit was a sample or not
    mutate(community_sample = replace_na(community_sample, 0),
           occ_interval = as.integer(occ_interval),
           visit = as.integer(visit)) %>%
    dplyr::select(-occ_year)
  
  ranges <- as.data.frame(cbind(rep(species_vector, each=n_sites),
                      rep(site_vector, times = n_species),
                      unlist(species_ranges))) %>%
    rename("species" = "V1",
           "grid_id" = "V2",
           "in_range" = "V3") %>%
    mutate(grid_id = as.integer(grid_id))
  
  all_visits_museum_visits_joined <- left_join(all_visits_museum_visits_joined, ranges) %>%
    mutate(sampled = as.numeric(community_sample)*
             as.numeric(in_range))
  
  # now would be appropriate to replace those records for the species collected at the museums 
  # for < min_species_for_community_sampling_event with a sampled indicator
  # i.e., keep the data for the singletons and doubletons, while not inferring abscense for the rest of the community
  
  # now spread into 4 dimensions
  V_museum_NA <- array(data = all_visits_museum_visits_joined$sampled, dim = c(n_species, n_sites, n_intervals, n_visits))
  # check <- which(V_museum>V_museum_NA) # this will give you numerical value
  # thus check should be empty
  
  ## --------------------------------------------------
  # Return stuff
  return(list(
    
    V_citsci = V_citsci, # citizen science detection data
    V_museum = V_museum, # museum detection data
    V_citsci_NA = V_citsci_NA, # array indicating whether sampling occurred in a site*interval*visit
    V_museum_NA = V_museum_NA, # array indicating whether sampling occurred in a site*interval*visit
    n_species = n_species, # number of species
    n_sites = n_sites, # number of sites
    n_intervals = n_intervals, # number of surveys 
    n_visits = n_visits,
    
    intervals = interval_vector,
    sites = site_vector,
    species = species_vector,
    
    pop_densities = pop_density_vector,
    impervious_cover = impervious_cover_vector,
    site_areas = site_area_vector,
    
    correlation_matrix = correlation_matrix,
    total_records = total_records,
    citsci_records = citsci_records,
    museum_records = museum_records,
    species_counts = species_counts
    
  ))
  
}
