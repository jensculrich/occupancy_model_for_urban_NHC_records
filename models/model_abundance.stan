// multi-species occupancy model for GBIF occurrence data
// jcu, started nov 21, 2022.
// builds on model0 by introducing integrated model structure where
// citizen science data and gbif data may have their own observation processes
// and also allows for missing (NA) data

functions {
  
  // covariance matrix
  matrix cov_matrix_2d(vector sigma, real rho) {
    matrix[2,2] Sigma;
    Sigma[1,1] = square(sigma[1]);
    Sigma[2,2] = square(sigma[2]);
    Sigma[1,2] = sigma[1] * sigma[2] * rho;
    Sigma[2,1] = Sigma[1,2];
    return Sigma;
  }

} // end functions

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
  
  int<lower=0> V_citsci_NA[n_species, n_sites, n_intervals, n_visits];  // indicator where 1 == sampled, 0 == missing data
  //int<lower=0> V_museum_NA[n_species, n_sites, n_intervals, n_visits];  // indicator where 1 == sampled, 0 == missing data
  
  int<lower=0> K[n_species, n_sites, n_intervals]; // Upper bound of population size
  
} // end data

transformed data {
  int<lower=0> max_y[n_species, n_sites, n_intervals];
  
  for (i in 1:n_species) {
    for(j in 1:n_sites){
      for(k in 1:n_intervals){
        max_y[i,j,k] = max(V_citsci[i,j,k]);
      }
    }
  }
  
} // end transformed data

parameters {
  
  // ABUNDANCE
  
  real<lower=0> phi; // abundance overdispersion parameter
  
  real mu_lambda_0; // global intercept for occupancy
  
  // DETECTION
  
  // citizen science observation process
  real mu_p_citsci_0; // global detection intercept for citizen science records
  
  // museum records observation process
  real mu_p_museum_0; // global detection intercept for citizen science records
  
  // Covarying parameters
  real<lower=-1,upper=1> rho_uv; // correlation of (abundance, detection)
  vector<lower=0>[2] sigma_uv; // sd of (abundance, detection)
  vector[2] uv[n_species]; // covarying species-specific abundance and museum detection rate intercepts
  
} // end parameters


transformed parameters {
  
  real lambda[n_species, n_sites, n_intervals];  // odds of occurrence
  real p_citsci[n_species, n_sites, n_intervals]; // odds of detection by cit science
  real p_museum[n_species, n_sites, n_intervals]; // odds of detection by museum
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          lambda[i,j,k] = // 
            mu_lambda_0 + // a baseline intercept
            uv[i,1]
            //psi_species[species[i]] + // a species specific intercept
            //psi_site[sites[j]] + // a site specific intercept
            //psi_interval[species[i]]*intervals[k] + // a species specific temporal effect
            //psi_pop_density[species[i]]*pop_densities[j] + // an effect of pop density on occurrence
            //psi_site_area*site_areas[j] // an effect of spatial area of the site on occurrence
            ; // end lambda[i,j,k]
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
          p_citsci[i,j,k] =  // removed inv_logit transormation..
            mu_p_citsci_0 //+ // a baseline intercept
            //p_citsci_species[species[i]] + // a species specific intercept
            //p_citsci_site[sites[j]] + // a spatially specific intercept
            //p_citsci_interval*intervals[k] + // an overall effect of time on detection
            //p_citsci_pop_density*pop_densities[j] // an overall effect of pop density on detection
           ; // end p_citsci[i,j,k]
           
          p_museum[i,j,k] = // the inverse of the log odds of detection is equal to..
            mu_p_museum_0 + // a baseline intercept
            uv[i,2]
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
  
  phi ~ cauchy(0, 2.5); // abundance overdispersion scale parameter
  
  mu_lambda_0 ~ cauchy(0, 2.5); // global intercept for occupancy rate
  
  // Detection (Observation Process)
  
  // citizen science records
  
  mu_p_citsci_0 ~ cauchy(0, 2.5); // global intercept for detection

  // museum records
  mu_p_museum_0 ~ cauchy(0, 2.5); // global intercept for detection
  
  // Covarying parameters
  sigma_uv ~ cauchy(0, 2.5);
  (rho_uv + 1) / 2 ~ beta(2, 2);
  uv ~ multi_normal(rep_vector(0, 2), cov_matrix_2d(sigma_uv, rho_uv));
  
  // LIKELIHOOD
  
  // Stan can sample the mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
          
        // If the site is in the range
        if(sum(V_citsci_NA[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if not in range
        
        vector[K[i,j,k] - max_y[i,j,k] + 1] lp; // lp vector of length of possible abundances 
            // (from max observed to K) 
          
        for(abundance in 1:(K[i,j,k] - max_y[i,j,k] + 1)){ // for each possible abundance:
        
          // lp of abundance given ecological model and observational model
          
          lp[abundance] = 
            neg_binomial_2_log_lpmf(
              max_y[i,j,k] + abundance - 1 | lambda[i,j,k], phi) +
            binomial_logit_lpmf(
              V_citsci[i,j,k] | max_y[i,j,k] + abundance - 1, p_citsci[i,j,k]); 
                // vectorized over n visits..
                
          // If the species was ever detected at the site during the interval then occupancy = 1  
          if((sum(V_citsci_NA[i,j,k]) > 0) || (sum(V_citsci[i,j,k]) > 0)){
                
              lp[abundance] = lp[abundance] + 
                
                1 - exp(-inv_logit(p_museum[i,j,k]) * exp(lambda[i,j,k]));
                    
          } else {
          // else 
            
            lp[abundance] = lp[abundance] + 
                
                exp(inv_logit(p_museum[i,j,k]) * exp(lambda[i,j,k]));
            
          }
            
            
        }
        
        target += log_sum_exp(lp);
            
        } // end loop across if in range
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model