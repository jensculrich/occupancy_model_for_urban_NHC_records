title: "README"

# Data and code for the manuscript "Urban landscapes with more natural greenspace support higher pollinator diversity"

Last updated September 4, 2023, by Jens Ulrich.

To run an analysis, open ./occupancy/analysis/run_model.R.
you will be prompted to enter details that will specify the model run, including:
taxonomic group, spatial grain and temporal divisions of occupancy intervals.

This repository holds three public subdirectories: ./occupancy/, ./data/ and ./figures. 


## Analyses (./occupancy/)

Contains simulation files (./simulation/), data prep(./data_prep/), models (./models/), model implementation (./analysis/) and model outputs (./model_outputs/).

The models used for the main analyses (held in the models subdirectory) are labelled "model_syrphidae.stan" and "model_bombus.stan".  

#### How to run a model:

Run a model (./analysis/run_model.R) by specifying the data level constraints (taxonomic group, spatial grain and temporal divisions of occupancy intervals) and by tweaking the HMC settings if desired.

After specifiying the data level constraints at the top of the file, you will be offered to prepare data for an analysis (prep_data() function). This preparation takes while (~10 minutes) to run, so if it's already been done and the prepared data has been previously saved, you can go ahead and skip down to load the previously saved data and then enter the HMC setting before running the model. Prepared data .rds files are held in the ./analysis/prepped_data/ folder

There are a few quick model diagnostic check functions listed after the model run call so that you can conveniently check the model run properties in this same file.  

#### Data prep (./data_prep/)
The function prep_data() (called by run_model.R) is held in prep_data.R. After being called, this function will then communicate with get_spatial_data.R to define sites and gather covariate data before attributing detections to sites and inferring a sampling process. The function will also communicate with get_species_ranges.R to determine which sites are in range and which are out of range (should be treated as NA's) based on each species's distribution.

#### Model outputs (./model_outputs/)
These are the saved HMC runs.

The model outputs used for the main results in manuscript are in the subfolder ./large_files/. These 4,000 iteration runs are too large to upload without purchasing credits.

#### Simulation (./simulation/)

Simulate a community of pollinators inferring the same ecological process and observation process. Also provides options to "break" some of the assumptions of our model and observe the consequences on the parameters. For example, our model ignores the possibility of research collections community surveys recovering zero species. We can see how consequential this is for the results by simulating some "hidden" community surveys that are overlooked. 



## Data (./data/)

Includes both spatial data and occurrence records data. Due to file sizes the data are not shared publicly in this repository, but one can follow any of the source links provided below to access the publicly available data.

### Supplemental Data for Publication (./supplemental_data)
"site_data.xlsx" contains a list of sites and their covariate values. The metadata for this is included on the second page of the sheet.

### Site-level Environmental/Spatial Data (./spatial_data/): 
Site-level environmental data are publicly available. These data files are too large to store on a github repository and must be downloaded directly from source. The linked sources may provide data from different years/resolutions or other formats. Please follow the query information for each data element to ensure that the correct data is downloaded. To reprocess the data and refit the models the data will need to be placed in the paths listed in the ./occupancy/data_prep/ files.

#### Land cover (./land_cover/) 
Contains a raster with land cover data (NLCD data) at 30 m resolution from 2016. 
[source](https://www.mrlc.gov/data/nlcd-2016-land-cover-conus).
See land cover classification descriptions [here](https://www.mrlc.gov/data/legends/national-land-cover-database-class-legend-and-description)

#### Household_income (./socioeconomic_data/)
Contains a shapefile and table data for:
2020 income data, B19013 == Median Household Income in the Past 12 Months (in 2020 Inflation-Adjusted Dollars)
[source](https://data2.nhgis.org/main)

#### Racial composition (./DECENNIALDP2020.DP1_2024-06-19&183658/)
Contains a shapefile and table data for:
2020 race and other factors, DP1_0078P == Percentage of people identifying as "white, no other race"
[source](https://data.census.gov/table/DECENNIALDP2020.DP1)

#### Population Density (./population_density/)
Contains a raster with population density at 1 km resolution from the year 2015.
[source](https://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-density-rev11/data-download)

#### Ecoregion 1 (./na_cec_eco_l1/)
Contains shapefile for ecoregion 1 in the north america (broadest spatial clustering unit for analysis).
[source](https://www.epa.gov/eco-research/ecoregions)

#### Ecoregion 3 (./NA_CEC_Eco_Level3/)
Contains shapefile for ecoregion 3 in the north america (intermediate spatial clustering unit for analysis).
[source](https://www.epa.gov/eco-research/ecoregions)

#### Metropolitan areas (./tl_2019_us_cbsa/)
Contains shapefile for metropolitan areas in the United States, defined in 2018 using 2010 census data.
[source](https://catalog.data.gov/dataset/tiger-line-shapefile-2019-nation-u-s-current-metropolitan-statistical-area-micropolitan-statist)



### Occurrence Data (./occurrence_data/): 

Contains occurrence data for bumble bees (BBNA (private folder due to data rights and size)) and for hoverflies (from GBIF (private folder due to size))

Compressed occurrence data available here:
https://github.com/jensculrich/occupancy_model_for_urban_NHC_records/tree/master/data/compressed_data/zip_folders

bumble bee data: bbna_trimmed.csv. see bbna_metadata_README.txt
hoverfly data: syrphidae_data_all.csv; syrphidae nativity. see syrphidae_data_metadata_README.txt

These data sets are also publicly available:
Go [here](https://www.leifrichardson.org/bbna.html) for bumble bee data, and [here part 1](https://doi.org/10.15468/dl.nga26z) and [here part 2](https://doi.org/10.15468/dl.n5cmwv) for hoverfly data. Go [here](https://github.com/jensculrich/occupancy_model_for_urban_NHC_records/tree/master/data/compressed_data/zip_folders) for the compressed occurrence data. Note I will remove this link once the data are uploaded to Dryad. 


see

IMPORTANT: 

see ./data/get_occurence_data.R for further processing to the above data
We further processed the data provided by BBNA and by GBIF by:

(1) combining Bombus bifarius and Bombus vancouverensis into a single species concept cluster (Bombus bifarius). 

(2) Making the following taxonomic clusterings for hoverflies:

```{r}
  # replace all Eumerus with Eumerus sp.
  mutate(species = ifelse(genus == "Eumerus", "Eumerus sp.", species)) %>%
  # replace all Chrysogaster with Chrysogaster sp.
  mutate(species = ifelse(genus == "Chrysogaster", "Chrysogaster sp.", species)) %>%
  # replace Eoseristalis (genus name) with Eristalis (genus name)
  mutate(species = gsub("Eoseristalis", "Eristalis", species))
```

and (3) appending a column of "basisOfRecord" where we identified detections as originating from "community science" or "research collections" observation processes



## ./figures/

make figures for the manuscript and/or for presentations
