### Gather and prep spatial data for pollinator occurrence
# jcu; started oct 27, 2022

# Collect spatial data to describe where the observations occur i.e.
# We will construct a grid of cells across the spatial extent (California)
# Each cell will be a site, where observations of any species can
# be said to have occurred in any of the years of our timeline.
# Choosing the spatial size of the grid cells will be important,
# and also importantly we will plan to limit the grid cells to those 
# that contain 'urban areas'.

# THEN intersect the filtered pollinator occurrence data against the urban grid
# to retain only occurrence data from our sites. This is the data that we will 
# format and then feed to the model (data_urban_occurrences.csv)

# This file 'get_spatial_data.R' contains a function 'get_spatial_data' which
# can be called from a 'run_model_X_.R' file with specific data collection
# choices of grid size and minimum pop in the cell to be chosen or varied

# This file walks through this process, with plots to visualize
# how the spatial data is gathered and how data 'collection' choices 
# like grid size and minimum urbanization intensity to include a site
# shape the data that we will analyze with our model

library(tidyverse)
library(tigris) # get state shapefile
library(sf) # spatial data processing
library(raster) # process pop dens raster

## --------------------------------------------------
## Operation Functions
## predictor center scaling function
center_scale <- function(x) {
  (x - mean(x)) / sd(x)
}

## --------------------------------------------------
# occurrence data
df <- read.csv("./data/data_unfiltered.csv")

## --------------------------------------------------
# Study design

## global options
# grid size
grid_size <- 30000 # e.g., 25000 = 25km x 25 km sites
# CRS for NAD83 / UTM Zone 10N
crs <- "+proj=utm +zone=10 +ellps=GRS80 +datum=NAD83"
# minimum population size
# a grid cell must intersect a city with min_population_size or more
# people living there. This filters out grid cell sites that do not
# have a an urban center above some minimum threshold

# min_population_size of 38 (/km^2) is ~ 100/mile^2 which is a typical threshold for 
# considering an area to be 'urban'
# let's up the minimum a bit and go with 100 per sq km, which is about 260/sq mile
min_population_size <- 250 

## --------------------------------------------------
# Spatial extent and urban areas

# spatial data - California state shapefile
CA <- tigris::states() %>%
  filter(NAME == "California")
str(CA)
st_crs(CA)
crs(CA)

# spatial data - 'urban areas' - with population size in 2015
# downloaded manually to the directory from:
# https://maps.princeton.edu/catalog/stanford-zd071bk4213
urban_areas <- st_read('./data/california_urban_areas/zd071bk4213.shp') %>%
  st_transform(crs)

## --------------------------------------------------
# ecological rasters

# human pop density raster
# https://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-density-rev11/data-download
# 2015 pop density at 1km resolution
pop_raster=raster("./data/pden2010_block/pden2010_block/gpw_v4_population_density_rev11_2015_30_sec.tif")
crs(pop_raster)

# TIN raster
tin=raster::raster("./data/pheno_veg_rasters/tin_2014w/tin_2014w_ProjectRaster1.tif")
raster::crs(tin)

# impervious surface raster
# 2016 urban imp surface cover https://www.mrlc.gov/data/nlcd-2016-percent-developed-imperviousness-conus
imp=raster::raster("D:/urban_spatial_data/nlcd_2016_impervious_l48_20210604/nlcd_2016_impervious_l48_20210604.img")
raster::crs(imp)

## --------------------------------------------------
# Prep the data

## transform
# transform state shapefile to crs
CA_trans <- st_transform(CA, 26910) # NAD83 / UTM Zone 10N

# make the df into a spatial file
(df_sf <- st_as_sf(df,
                   coords = c("decimalLongitude", "decimalLatitude"), 
                   crs = 4326))

# and then transform it to the crs
df_trans <- st_transform(df_sf, crs = crs)

ggplot() +
  geom_sf(data=CA)

# and let's just plot 100 points to get a picture of the data and shapefile
df_trans_100 <- df_trans %>%
  sample_n(100)

ggplot() +
  geom_sf(data=CA) + 
  # geom_sf(data=urban_areas) +
  geom_sf(data = df_trans_100, 
          aes(fill = species), 
          size = 4, alpha = 0.5, shape = 23) +
  theme(legend.position="none")

## --------------------------------------------------
# Overlay spatial polygon with grid 

# create _km grid - here you can substitute by specifying grid_size above
grid <- st_make_grid(CA_trans, cellsize = c(grid_size, grid_size)) %>% 
  st_sf(grid_id = 1:length(.))

# create labels for each grid_id
grid_lab <- st_centroid(grid) %>% cbind(st_coordinates(.))

# view sampled points transposed to the grid on the polygon
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  #geom_sf(data = sample_n(df_trans, 500), 
  #         aes(fill = species), 
  #        size = 4, alpha = 0.5, shape = 23) +
  geom_sf(data = grid, fill = 'transparent', lwd = 0.3) +
  #geom_text(data = grid_lab, aes(x = X, y = Y, label = grid_id), size = 2) +
  coord_sf(datum = NA)  +
  labs(x = "") +
  labs(y = "") +
  theme(legend.position="none")

## --------------------------------------------------
# Tag records with site ID's based on spatial intersection

# which grid square is each point in?
df_id <- df_trans %>% st_join(grid, join = st_intersects) %>% as.data.frame

## --------------------------------------------------
# Extract pop density from each grid cell

r2 <- crop(pop_raster, CA)
r3 <- mask(r2, CA)
maxValue(r3)
r3

plot(log(r3+1),
     col=rev(terrain.colors(10)),
     alpha=1,
     legend=T,
     main="Log((Population Density/km^2) + 1)")

my_window <- extent(-125, -112, 32, 42)
plot(my_window, col=NA, xlab="longitude", ylab = "latitude")
plot(log(r3+1), add=T)

# project the grid to the raster
crs_raster <- sf::st_crs(raster::crs(r3))
prj1 <- st_transform(grid, crs_raster)

# Extract raster values to list object
# this takes a while since there are many raster cells with their own values
# in each grid cell.
r.vals <- raster::extract(r3, prj1)

# Use list apply to calculate mean raster value for each grid cell
r.mean <- lapply(r.vals, FUN=mean, na.rm=TRUE)

# this takes a long long time to plot
r3_df <- as.data.frame(r3, xy = TRUE) %>%
  rename("pop_dens" = "gpw_v4_population_density_rev11_2015_30_sec") %>%
  mutate(logp1_pop_dens = log(pop_dens + 1))
ggplot(r3_df) +
  geom_tile(aes(x=x, y=y, fill=gpw_v4_population_density_rev11_2015_30_sec))
plot(pop_raster)

# Join mean values to polygon data
grid_pop_dens <- cbind(grid, unlist(r.mean)) %>% 
  rename("pop_density_per_km2" = "unlist.r.mean.")

## Now let's join the pop dens back with the df
df_id_dens <- left_join(df_id, grid_pop_dens) %>%
  left_join(., dplyr::select(df, gbifID, decimalLatitude, decimalLongitude), by="gbifID") %>%
  filter(pop_density_per_km2 > min_population_size) %>%
  mutate(scaled_pop_den_km2 = center_scale(pop_density_per_km2))

# and then project it again
df_w_dens_sf <- st_as_sf(df_id_dens,
                   coords = c("decimalLongitude", "decimalLatitude"), 
                   crs = 4326)

# and then transform it to the crs again
df_w_dens_trans <- st_transform(df_w_dens_sf, crs = crs)

## Let's try again with only the grid cells that overlap with urban areas
urban_grid <- st_join(grid, df_w_dens_trans, join = st_intersects)

urban_grid <- st_join(urban_grid, urban_areas, join = st_intersects)

urban_grid_prepped <- urban_grid %>% 
  filter(!is.na(grid_id.y)) %>% # remove grid cells that don't overlap with urban areas
  # we will select one row per grid cell (one city admin area)
  # keeping the city with the largest population size for now
  group_by(grid_id.y) %>% 
  slice(which.max(pop2010)) %>%
  ungroup() %>%
  dplyr::select(grid_id.y, pop_density_per_km2, scaled_pop_den_km2, name, pop2010, ..x) %>%
  rename("grid_id" = "grid_id.y",
         "city" = "name",
         "total_pop_of_largest_intersecting_city" = "pop2010",
         "geometry" = "..x") 

scaled_pop_density <- urban_grid_prepped %>%
  pull(scaled_pop_den_km2)

city_name <- urban_grid_prepped %>%
  pull(city)

grid_id_names <- as.character(urban_grid_prepped %>%
  pull(grid_id))

## --------------------------------------------------
# plot the spatial data
# create labels for each grid_id
urban_grid_lab <- st_centroid(urban_grid_prepped) %>% cbind(st_coordinates(.))

# view sampled points transposed to the grid on the polygon
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  geom_sf(data = urban_grid_prepped, lwd = 0.3) +
  #scale_fill_gradient2() +
  geom_sf(data = sample_n(df_w_dens_trans, 500), 
          aes(fill = species), 
          size = 4, alpha = 0.5, shape = 23) +
  geom_text(data = urban_grid_lab, aes(x = X, y = Y, label = grid_id), size = 2) +
  labs(x = "Longitude") +
  labs(y = "Latitude") +
  ggtitle("Random sample of 500 NHC records from urban areas", 
          subtitle = "(coloured by species)") +
  theme(legend.position = "none")

# view sites only
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  geom_sf(data = urban_grid_prepped, aes(fill = pop_density_per_km2), lwd = 0.3) +
  scale_fill_gradient2(name = "Population density (pop/km^2)") +
  #geom_text(data = urban_grid_lab, 
  #          aes(x = X, y = Y, label = grid_id), size = 2) +
  ggtitle("Population density (pop / km^2) in urbanized areas") +
  labs(x = "Longitude") +
  labs(y = "Latitude") 
  # coord_sf(datum = NA)

# view sites only with scaled data
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  geom_sf(data = urban_grid_prepped, aes(fill = scaled_pop_den_km2), lwd = 0.3) +
  scale_fill_gradient2(name = "Scaled population density") +
  #geom_text(data = urban_grid_lab, 
  #          aes(x = X, y = Y, label = grid_id), size = 2) +
  ggtitle("Population density (pop / km^2) in urbanized areas") +
  labs(x = "Longitude") +
  labs(y = "Latitude") 
# coord_sf(datum = NA)

## --------------------------------------------------
# Calculate land area of grid cells 
# some cells might partially be outside of the area where we are getting records from
# e.g. a cell half in California and half in Mexico or a cell that is along the
# coastline and only overlaps slightly with land
# we would expect fewer species to occur in these smaller areas and therefore should
# account for site area (extent of grid cell intersection w/ shapefile) in our analysis

# THE VECTOR 'scaled_grid_area' is the output that lists scaled site area 
# in order from lowest site number to highest.

# intersect - note that sf is intelligent with attribute data!
grid_intersect <- st_intersection(CA_trans, urban_grid_prepped)
plot(CA_trans$geometry, axes = TRUE)
plot(urban_grid_prepped$geometry, add = TRUE)
plot(grid_intersect$geometry, add = TRUE, col = 'red')
title("Site x Land Area Intersection")

# add in areas in m2
attArea <- grid_intersect %>% 
  mutate(area = st_area(.) %>% as.numeric())

# for each field, get area overlapping with admin area
scaled_grid_area <- attArea %>% 
  as_tibble() %>% 
  group_by(grid_id) %>% 
  summarize(area = sum(area)) %>%
  mutate(scaled_site_area = center_scale(area)) %>%
  pull(scaled_site_area)

# view sites only with scaled data
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  geom_sf(data = urban_grid_prepped, aes(fill = scaled_pop_den_km2), lwd = 0.3) +
  scale_fill_gradient2(name = "Scaled population density") +
  #geom_text(data = urban_grid_lab, 
  #          aes(x = X, y = Y, label = grid_id), size = 2) +
  ggtitle("Population density (pop / km^2) in urbanized areas") +
  labs(x = "Longitude") +
  labs(y = "Latitude") 
# coord_sf(datum = NA)

# could save data frame of urban occurrences as a .csv
# don't need to keep this file if the prep_data function calls the get_spatial_data function
# write.csv(df_w_dens_trans, "./data/data_urban_occurrences.csv")


## --------------------------------------------------
# Calculate land TIN value of each grid cell
crs(tin)
plot(tin,
     #col=rev(terrain.colors(10)),
     legend=T,
     main="TIN")


# project the grid to the raster
crs_tin <- sf::st_crs(raster::crs(tin))
prj1 <- st_transform(grid, crs_tin)

tin2 <- crop(tin, CA)
tin3 <- mask(tin2, CA)
maxValue(tin3)

plot(tin3,
     col=rev(terrain.colors(10)),
     alpha=1,
     legend=T,
     main="NDVI")

my_window <- extent(-125, -112, 32, 42)
plot(my_window, col=NA, xlab="longitude", ylab = "latitude")
plot(tin3, add=T)


# this takes a long long time to plot
tin_df <- as.data.frame(tin3, xy = TRUE) # %>%
#mutate(logp1_pop_dens = log(pop_dens + 1))
plot <- ggplot(tin_df) +
  geom_sf(data=CA) 

plot <- plot + geom_tile(aes(x=x, y=y, fill=tin_2014w_ProjectRaster1)) 


## --------------------------------------------------
# Calculate land impervious surface cover value of each grid cell

# project the grid to the raster
crs_imp <- sf::st_crs(raster::crs(imp))
prj2 <- st_transform(urban_grid_prepped, crs_imp)

imp2 <- crop(imp, prj2)

#aggregate (to a coarser scale to speed the processing)
# 1/30meters = x/500 meters -> 16.7 
imp_agg <- aggregate(imp2, 10, fun=mean)

writeRaster(imp_agg, "D:/urban_spatial_data/nlcd_2016_impervious_l48_20210604/nlcd_2016_impervious_l48_20210604.tif")

imp_agg <- mask(imp_agg, prj2)

# Extract raster values to list object
# this takes a while since there are many raster cells with their own values
# in each grid cell.
# Use list apply to calculate mean raster value for each grid cell

r.vals_imp <- raster::extract(imp_agg, prj2)

for(i in 1:length(r.vals_imp)){
  r.vals_imp[[i]][r.vals_imp[[i]]==127] <- NA
}

r.mean_imp <- lapply(r.vals_imp, FUN=mean, na.rm=TRUE)

urban_grid_prepped <- cbind(urban_grid_prepped, unlist(r.mean_imp)) %>%
  rename("impervious_cover" = "unlist.r.mean_imp.") %>%
  mutate(scaled_impervious_cover = center_scale(impervious_cover))

# view sites only with scaled data
ggplot() +
  geom_sf(data = CA_trans, fill = 'white', lwd = 0.05) +
  geom_sf(data = urban_grid_prepped, aes(fill = scaled_impervious_cover), lwd = 0.3) +
  scale_fill_gradient2(name = "Scaled impervious surface cover") +
  #geom_text(data = urban_grid_lab, 
  #          aes(x = X, y = Y, label = grid_id), size = 2) +
  ggtitle("Impervious surface of urbanized areas") +
  labs(x = "Longitude") +
  labs(y = "Latitude") 

# pretty high correlation here..
cor(urban_grid_prepped$scaled_impervious_cover, urban_grid_prepped$scaled_pop_den_km2)

## --------------------------------------------------
# spatial data - more states state shapefile
states <- tigris::states() %>%
  filter(NAME %in% c("California", "Oregon", "Washington", "Arizona", "Nevada", "Idaho"))
str(states)
st_crs(states)
crs(states)

ggplot() +
  geom_sf(data=states)
