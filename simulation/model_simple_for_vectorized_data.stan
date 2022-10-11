// multi-species occupancy model for GBIF occurrence data

functions{
  
  // if the species is detected at the site*interval at least once..
  real lp_observed(int V, real logit_psi, real logit_p){ 
    
    return log_inv_logit(logit_psi) + 
            // probability density of getting an occurrence 
            // of a species at a site*interval plus..
            binomial_logit_lpmf(V | 1, logit_p); 
            // probability density of then observing or not observing  
            // that specific species at the site*interval per single visit l
            
  } // end lp_observed
  
  // if the species is never detected at the site*interval..
  real lp_unobserved(real logit_psi, real logit_p){ 

    return log_sum_exp(log_inv_logit(logit_psi) +
           // probability density of the species occupying the site*interval
           // but not being detected at the visit l plus..
           log1m_inv_logit(logit_p),
           // probability density of not detecting it on the visit l
           
           // summed with..
           log1m_inv_logit(logit_psi));
           // probability density of the species NOT occupying the site*interval
           // and therefore detection is not possible
           
  } // end lp_unobserved
  
} // end functions

data {
  
  int<lower=1> R; // number of interval*site*species*visit combinations
  
  int<lower=1> n_species;  // observed species
  int<lower=1> species[R];      // vector of species
  
  int<lower=1> n_sites;  // sites within region
  int<lower=1> site[R];      // vector of sites
  
  int<lower=1> n_intervals;  // intervals during which sites are visited
  int<lower=1> interval[R]; // vector of intervals (used as covariate data for 
                                // fixed effect of occupancy interval (time) on occupancy)
  
  int<lower=1> n_visits; // visits within intervals
  
  int<lower=0> V[R, n_visits];  // visits when species i was detected at site j on interval k
  
} // end data


parameters {
  
  // OCCUPANCY
  real mu_psi_0; // global interecept for occupancy
  
  // species specific intercept allows some species to occur at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] psi_species; // species specific intercept for occupancy
  real<lower=0> sigma_psi_species; // variance in species intercepts
  
  // random slope for species specific temporal effects on occupancy
  vector[n_species] psi_interval; // vector of species specific slope estimates
  real mu_psi_interval; // community mean of species specific slopes
  real<lower=0> sigma_psi_interval; // variance in species slopes
  
  // DETECTION
  real mu_p_0;
  
  // species specific intercept allows some species to be detected at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] p_species; // species specific intercept for detection
  real<lower=0> sigma_p_species; // variance in species intercepts
  
  // random slope for site specific temporal effects on occupancy
  vector[n_sites] p_site; // vector of spatially specific slope estimates
  real<lower=0> sigma_p_site; // variance in site slopes
  
  real p_interval; // fixed temporal effect on detection probability
  
} // end parameters


transformed parameters {
  
  real logit_psi[n_species*n_sites*n_intervals];  // log odds  of occurrence
  real logit_p[R, n_visits];  // log odds of detection
  
  for (i in 1:R){   // loop across all species*site*intervals
          
          logit_psi[i] = // log odds  of occurrence is equal to
            mu_psi_0 + // a baseline intercept
            psi_species[species[i]] + // a species specific intercept
            psi_interval[species[i]]*interval[i]; // a species specific temporal effect
            
  }
  
  for (i in 1:R){   // loop across all species*site*intervals
    for (j in 1:n_visits){
          
          logit_p[i, j] = // log odds  of detection is equal to
            mu_p_0 + // a baseline intercept
            p_species[species[i]] + // a species specific intercept
            p_site[site[i]] + // a spatially specific intercept
            p_interval*interval[i]; // an overall effect of time on detection
            
    }       
  }
  
} // end transformed parameters


model {
  // PRIORS
  
  // Occupancy (Ecological Process)
  mu_psi_0 ~ cauchy(0, 2.5); // global intercept for occupancy rate
  
  psi_species ~ normal(0, sigma_psi_species); 
  // occupancy intercept for each species drawn from the community
  // distribution (variance defined by sigma), centered at 0. 
  sigma_psi_species ~ cauchy(0, 2.5);
  
  psi_interval ~ normal(0, sigma_psi_interval);
  // occupancy slope (temporal effect on occupancy) for each species drawn from the 
  // community distribution (variance defined by sigma), centered at mu_psi_interval. 
  // centering on mu (rather than 0) allows us to estimate the average effect of
  // the management on abundance across all species.
  sigma_psi_interval ~ cauchy(0, 2.5); // community variance
  
  // Detection (Observation Process)
  mu_p_0 ~ cauchy(0, 2.5); // global intercept for detection
  
  p_species ~ normal(0, sigma_p_species); 
  // detection intercept for each species drawn from the community
  // distribution (variance defined by sigma), centered at 0. 
  sigma_p_species ~ cauchy(0, 2.5);
  
  // multivariate hierarchical prior
  p_site ~ normal(0, sigma_p_site);
  // detection intercept for each site*interval drawn from the spatiotemporal
  // distribution (variance defined by sigma), centered at 0. 
  sigma_p_site ~ cauchy(0, 2.5); // spatiotemporal variance
  
  p_interval ~ cauchy(0, 2.5);
  
  // LIKELIHOOD
  // Stan can sample mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:R) { // loop across all interval*site*species combinations
    for(j in 1:n_visits) { // loop across all visits
          
          // if species is detected at the specific site*interval at least once
          // lp_observed calculates the probability density that occurs given logit_psi plus
          // the probability density that we did/did not observe it on each visit l in 1:nvisit
          if(sum(V[i,1:n_visits]) > 0){ 
            target += lp_observed(V[i, j], 
              logit_psi[i], logit_p[i, j]);
          
          // else the species was never detected at the site*interval
          // lp_unobserved sums the probability density of:
          // 1) species occupies the site*interval but was not detected on each visit, and
          // 2) the species does not occupy the site*interval
          } else {
            target += lp_unobserved(logit_psi[i], logit_p[i, j]);
            
          } // end if/else
          
    }
  }
} // end model
