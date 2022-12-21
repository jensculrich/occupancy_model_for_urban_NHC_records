// multi-species occupancy model for GBIF occurrence data
// jcu, started nov 21, 2022.
// builds on model0 by introducing integrated model structure where
// citizen science data and gbif data may have their own observation processes
// and also allows for missing (NA) data

data {
  
  int<lower=1> n_species;  // observed species
  int<lower=1> species[n_species]; // vector of species
  
  int<lower=1> n_sites;  // sites within region
  int<lower=1> sites[n_sites];  // vector of sites
  
  int<lower=1> n_intervals;  // intervals during which sites are visited
  
  real intervals[n_intervals]; // vector of intervals (used as covariate data for 
                                // species specific effect of occupancy interval (time) on occupancy)
                                // needs to begin with intervals[1] = 0, i.e., 
                                // there is no temporal addition in the first interval
  
  int<lower=1> n_visits; // visits within intervals
  
  int<lower=0> V_citsci[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  int<lower=0> V_museum[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  
  int<lower=0> ranges[n_species, n_sites, n_intervals, n_visits];  // NA indicator where 1 == site is in range, 0 == not in range
  //int<lower=0> V_museum_NA[n_species, n_sites, n_intervals, n_visits];  // indicator where 1 == sampled, 0 == missing data
  
  int<lower=0> K[n_species, n_sites, n_intervals]; // Upper bound of population size
  
  vector[n_sites] site_areas; // spatial area extent of each site
  
} // end data

transformed data {
  int<lower=0> max_y[n_species, n_sites, n_intervals];
  int<lower=0> max_y_lower[n_species, n_sites, n_intervals];
  
  for (i in 1:n_species) {
    for(j in 1:n_sites){
      for(k in 1:n_intervals){
        
        // Set the floor of the latent state search to be at least as many as the most 
        // that we observed of a species at a site in a time interval (by cit sci records)
        max_y[i,j,k] = max(V_citsci[i,j,k]);
        
        // We only search abundance if it is it must be greater than 1, i.e.,
        // was detected by a museum but not by citizen science
        // or we search in a hypothetical situation where the site is suitable
        // we did not detect and records, but we consider the probabiility that 1:K
        // individuals exist and went undetected.
        // Therefore, replace any max_y == 0 with max_y == 1 
        // to be the floor of the latent state search.
        if(max_y[i,j,k] == 0){
            max_y[i,j,k] = 1;
          } else {
            max_y[i,j,k] = max_y[i,j,k];
          }
      
      } // end loop across intervals
    } // end loop across sites
  } // end loop across species
  
  for (i in 1:n_species) {
    for(j in 1:n_sites){
      for(k in 1:n_intervals){
        
        // Set the floor of the latent state search to be at least as many as the most 
        // that we observed of a species at a site in a time interval (by cit sci records)
        // Allow max_y_lower to stay at 0 if we didn't observe any records
        max_y_lower[i,j,k] = max(V_citsci[i,j,k]);
      
      } // end loop across intervals
    } // end loop across sites
  } // end loop across species
  
} // end transformed data

parameters {
  
  // ABUNDANCE
  
  real<lower=0,upper=1> omega;
  //real gamma_0; // occupancy intercept
  //real gamma_1; // relationship between abundance and occupancy 
  real<lower=0> phi; // abundance overdispersion parameter
  
  real mu_eta_0; // global intercept for occupancy
  
  real eta_site_area; // effect of site are on occupancy
  
  // DETECTION
  
  // citizen science observation process
  real mu_p_citsci_0; // global detection intercept for citizen science records
  
  // museum records observation process
  real mu_p_museum_0; // global detection intercept for citizen science records
  
} // end parameters


transformed parameters {
  
  real log_eta[n_species, n_sites, n_intervals]; // mean of abundance process
  real logit_p_citsci[n_species, n_sites, n_intervals]; // odds of detection by cit science
  real logit_p_museum[n_species, n_sites, n_intervals]; // odds of detection by museum
  
  //real omega[n_species, n_sites, n_intervals]; // availability
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          log_eta[i,j,k] = // 
            mu_eta_0 + // a baseline intercept
            //psi_species[species[i]] + // a species specific intercept
            //psi_site[sites[j]] + // a site specific intercept
            //psi_interval[species[i]]*intervals[k] + // a species specific temporal effect
            //psi_pop_density[species[i]]*pop_densities[j] + // an effect of pop density on occurrence
            eta_site_area*site_areas[j] // an effect of spatial area of the site on occurrence
            ; // end lambda[i,j,k]
          
          // Smith et al. 2012 Ecology trick for incorporating the abundance-occupancy 
          // relationship into a zero-inflated abundance model  
          // availability is predicted by abundance
          //omega[i,j,k] = gamma_0;
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
          logit_p_citsci[i,j,k] =  // logit scaled individual-level detection rate
            mu_p_citsci_0 //+ // a baseline intercept
            //p_citsci_species[species[i]] + // a species specific intercept
            //p_citsci_site[sites[j]] + // a spatially specific intercept
            //p_citsci_interval*intervals[k] + // an overall effect of time on detection
            //p_citsci_pop_density*pop_densities[j] // an overall effect of pop density on detection
           ; // end p_citsci[i,j,k]
           
          logit_p_museum[i,j,k] = // logit scaled species-level detection rate
            mu_p_museum_0 //+ // a baseline intercept
            //p_museum_species[species[i]] + // a species specific intercept
            //p_museum_site[sites[j]] + // a spatially specific intercept
            //p_museum_interval*intervals[k] + // an overall effect of time on detection
            //p_museum_pop_density*pop_densities[j] // an overall effect of pop density on detection
           ; // end p_museum[i,j,k]
           
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end transformed parameters


model {
  
  // PRIORS
  
  // Abundance (Ecological Process)
  
  //gamma_0 ~ normal(0, 1);
  //gamma_1 ~ normal(0, 1);
  
  phi ~ cauchy(0, 2.5); // abundance overdispersion scale parameter
  
  mu_eta_0 ~ cauchy(0, 2.5); // global intercept for abundance rate
  
  eta_site_area ~ cauchy(0, 2.5); // effect of site area on abundance rate
  
  // Detection (Observation Process)
  
  // citizen science records
  
  mu_p_citsci_0 ~ cauchy(0, 2.5); // global intercept for (citizen science) detection

  // museum records
  mu_p_museum_0 ~ cauchy(0, 2.5); // global intercept for (museum) detection
  
  // LIKELIHOOD
  
  // Stan can sample the mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
          
        // If the site is in the range of a species, then evaluate lp, otherwise do not (treat as NA).
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
        
        // If a species was detected at least once by either data set, Nijk > 0;
        // Evaluate sum probabilty of an abundance generating term (lambda_ijk),
        // an individual-level detection rate by citizen science data collections (p_citsci_ijk),
        // a species-level detection rate by museum data collections (p_museum_ijk),
        // and an occupancy-abundance relationship (omega_ijk)
        if(sum(V_citsci[i,j,k]) > 0 || sum(V_museum[i,j,k]) > 0) {
          
          vector[K[i,j,k] - max_y[i,j,k] + 1] lp; // lp vector of length of possible abundances 
            // (from max observed to K)
          
          // for each possible abundance:
          for(abundance in 1:(K[i,j,k] - max_y[i,j,k] + 1)){ 
          
            // lp of abundance given ecological model and observational model
            lp[abundance] = 
              // vectorized over n visits..
              neg_binomial_2_log_lpmf( // generation of abundance given count distribution
                max_y[i,j,k] + abundance - 1 | log_eta[i,j,k], phi) + 
              binomial_logit_lpmf( // individual-level detection, citizen science
                V_citsci[i,j,k] | max_y[i,j,k] + abundance - 1, logit_p_citsci[i,j,k]) +
              binomial_logit_lpmf( // binary, species-level detecion, museums
                sum(V_museum[i,j,k]) | n_visits, logit_p_museum[i,j,k]); 
          
          }
                
          target += log_sum_exp(lp +
              // plus outcome of site being available, given the 
              // abundance-dependent probability of suitability
              bernoulli_lpmf(1 | omega) 
              );
        
        } else { // else was never detected and the site may or may not be available
          
          real lp[2];
          
          // outcome of site being unavailable for occupancy, given the 
          // abundance-dependent probability of suitability
          lp[1] = bernoulli_lpmf(0 | omega); // site not available for species in interval
          // outcome of site being available for occupancy, given the 
          // abundance-dependent probability of suitability
          lp[2] = bernoulli_lpmf(1 | omega); // available but not observed
          
          // probability present at an available site with
          // some unknown latent abundance state; but never observed.
          // In this formulation the latent abundance could include 0,
          // potentially causing underestimates in species-level detection ability?
          for(abundance in 1:(K[i,j,k] - max_y_lower[i,j,k] + 1)){
            
            lp[2] = lp[2] +
             neg_binomial_2_log_lpmf( // generation of abundance given count distribution
                max_y_lower[i,j,k] + abundance - 1 | log_eta[i,j,k], phi) +
              binomial_logit_lpmf( // 0 individual-level detections, citizen science
                0 | max_y_lower[i,j,k] + abundance - 1, logit_p_citsci[i,j,k]) +
              binomial_logit_lpmf( // 0 species-level detecions, museums
                0 | n_visits, logit_p_museum[i,j,k]);
                
          }
          
          // sum lp of both possibilities of availability
          // and all possible abundance states that went unobserved if it's available
          target += log_sum_exp(lp);
        
        } // end else
            
        } // end if in range
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model