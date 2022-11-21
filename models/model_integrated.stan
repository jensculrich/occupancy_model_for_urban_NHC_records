// multi-species occupancy model for GBIF occurrence data
// jcu, started nov 21, 2022.
// builds on model0 by introducing integrated model structure where
// citizen science data and gbif data may have their own observation processes
// and also allows for missing (NA) data

data {
  
  int<lower=1> n_species;  // observed species
  int<lower=1> species[n_species];      // vector of species
  
  int<lower=1> n_sites;  // sites within region
  int<lower=1> sites[n_sites];      // vector of sites
  
  int<lower=1> n_intervals;  // intervals during which sites are visited
  
  real intervals[n_intervals]; // vector of intervals (used as covariate data for 
                                // species specific effect of occupancy interval (time) on occupancy)
                                // needs to begin with intervals[1] = 0, i.e., 
                                // there is no temporal addition in the first interval
  
  int<lower=1> n_visits; // visits within intervals
  
  // int<lower=0> V[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  int<lower=0> V_citsci[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  int<lower=0> V_museum[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  
  //vector[n_sites] pop_densities; // population density of each site
  //vector[n_sites] site_areas; // spatial area extent of each site
  
} // end data


parameters {
  
  // OCCUPANCY
  real mu_psi_0; // global intercept for occupancy
  
  // species specific intercept allows some species to occur at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  //vector[n_species] psi_species; // species specific intercept for occupancy
  //real<lower=0> sigma_psi_species; // variance in species intercepts
  
  // random slope for species specific temporal effects on occupancy
  //vector[n_species] psi_interval; // vector of species specific slope estimates
  //real mu_psi_interval; // community mean of species specific slopes
  //real<lower=0> sigma_psi_interval; // variance in species slopes
  
  // effect of population density on occupancy
  //real psi_pop_density;
  
  // effect of site are on occupancy
  //real psi_site_area;
  
  // DETECTION
  //real mu_p_0; // global intercept for detection
  real mu_p_citsci_0; // global detection intercept for citizen science records
  real mu_p_museum_0; // global detection intercept for museum records
  
  // species specific intercept allows some species to be detected at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  //vector[n_species] p_species; // species specific intercept for detection
  //real<lower=0> sigma_p_species; // variance in species intercepts
  
  // random slope for site specific temporal effects on occupancy
  //vector[n_sites] p_site; // vector of spatially specific slope estimates
  //real<lower=0> sigma_p_site; // variance in site slopes
  
  //real p_interval; // fixed temporal effect on detection probability
  
} // end parameters


transformed parameters {
  
  real psi[n_species, n_sites, n_intervals];  // odds of occurrence
  real p_citsci[n_species, n_sites, n_intervals, n_visits]; // odds of detection by cit science
  real p_museum[n_species, n_sites, n_intervals, n_visits]; // odds of detection by museum
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          psi[i,j,k] = inv_logit( // the inverse of the log odds of occurrence is equal to..
            mu_psi_0 //+ // a baseline intercept
            //psi_species[species[i]] + // a species specific intercept
            //psi_interval[species[i]]*intervals[k] + // a species specific temporal effect
            //psi_pop_density*pop_densities[j] + // an effect of pop density on occurrence
            //psi_site_area*site_areas[j] // an effect of spatial area of the site on occurrence
            ); // end psi[i,j,k]
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        for(l in 1:n_visits){ // loop across all visits
        
          p_citsci[i,j,k,l] = inv_logit( // the inverse of the log odds of detection is equal to..
            mu_p_citsci_0 //+ // a baseline intercept
            //p_species[species[i]] + // a species specific intercept
            //p_site[sites[j]] + // a spatially specific intercept
            //p_interval*intervals[k] // an overall effect of time on detection
           ); // end p[i,j,k,l]
           
          p_museum[i,j,k,l] = inv_logit( // the inverse of the log odds of detection is equal to..
            mu_p_museum_0 //+ // a baseline intercept
            //p_species[species[i]] + // a species specific intercept
            //p_site[sites[j]] + // a spatially specific intercept
            //p_interval*intervals[k] // an overall effect of time on detection
           ); // end p[i,j,k,l]
           
        } // end loop across all visits
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
             
  
} // end transformed parameters


model {
  
  // PRIORS
  
  // Occupancy (Ecological Process)
  mu_psi_0 ~ cauchy(0, 2.5); // global intercept for occupancy rate
  
  //psi_species ~ normal(0, sigma_psi_species); 
  // occupancy intercept for each species drawn from the community
  // distribution (variance defined by sigma), centered at 0. 
  //sigma_psi_species ~ cauchy(0, 2.5);
  
  //psi_interval ~ normal(mu_psi_interval, sigma_psi_interval);
  // occupancy slope (temporal effect on occupancy) for each species drawn from the 
  // community distribution (variance defined by sigma), centered at mu_psi_interval. 
  // centering on mu (rather than 0) allows us to estimate the average effect of
  // the management on abundance across all species.
  //mu_psi_interval ~ cauchy(0, 2.5); // community mean
  //sigma_psi_interval ~ cauchy(0, 2.5); // community variance
  
  //psi_pop_density ~ cauchy(0, 2.5); // effect of population density on occupancy
  //psi_site_area ~ cauchy(0, 2.5); // effect of site area on occupancy
  
  // Detection (Observation Process)
  mu_p_citsci_0 ~ cauchy(0, 2.5); // global intercept for detection
  mu_p_museum_0 ~ cauchy(0, 2.5); // global intercept for detection

  //p_species ~ normal(0, sigma_p_species); 
  // detection intercept for each species drawn from the community
  // distribution (variance defined by sigma), centered at 0. 
  //sigma_p_species ~ cauchy(0, 2.5);
  
  // should redefine p_site so that it is spatially AND temporally heterogenous 
  //p_site ~ normal(0, sigma_p_site);
  // detection intercept for each site drawn from the spatially heterogenous
  // distribution (variance defined by sigma), centered at 0. 
  //sigma_p_site ~ cauchy(0, 2.5); // spatial variance
  
  //p_interval ~ cauchy(0, 2.5); // temporal effect on detection probability
  
  // LIKELIHOOD
  
  // Stan can sample the mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        // for(l in 1:n_visits){ // loop across all visits
          
          // if species is detected at the specific site*interval at least once
          // by citizen science efforts OR museum records
          // then the species occurs there. lp_observed calculates
          // the probability density that species occurs given psi, plus the 
          // probability density that we did/did not observe it on each visit l in 1:nvisit
          if(sum(V_citsci[i, j, k, 1:n_visits]) > 0 || sum(V_museum[i, j, k, 1:n_visits]) > 0) {
            
             // lp_observed:
             target += log(psi[i,j,k]);
             target += bernoulli_lpmf(V_citsci[i,j,k] | p_citsci[i,j,k]); // vectorized over repeat sampling visits l
             target += bernoulli_lpmf(V_museum[i,j,k] | p_museum[i,j,k]); // vectorized over repeat sampling visits l

          // else the species was never detected at the site*interval
          // lp_unobserved sums the probability density of:
          // 1) species occupies the site*interval but was not detected on each visit, and
          // 2) the species does not occupy the site*interval
          } else {
            
            // lp_unobserved
            // currently written as log1m(p) for each visit in 1:n_visits (manually defined below as 1, 2, 3...)
            // should be proper to wrap this up in a single statement that increments the log probability
            // for each p in 1:n_visit, but simply putting log1m(p[i,j,k,l]) doesn't seem to work 
            // for reasons that I don't understand. This way below works, it's just a bit too brute force
            // and needs to be rewritten to accomodate the specific number of max visits
            target += log_sum_exp(log(psi[i,j,k]) + 
                                 log1m(p_citsci[i,j,k,1]) + log1m(p_citsci[i,j,k,2]) + log1m(p_citsci[i,j,k,3]) +
                                 log1m(p_museum[i,j,k,1]) + log1m(p_museum[i,j,k,2]) + log1m(p_museum[i,j,k,3]),
                          log1m(psi[i,j,k]));
            
          } // end if/else
          
          
        // } // end loop across all visits
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model

