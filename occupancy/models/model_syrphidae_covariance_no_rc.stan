// multi-species occupancy model for GBIF occurrence data
// jcu, started nov 21, 2022.

data {
  
  int<lower=1> n_species;  // observed species
  int<lower=1> species[n_species]; // vector of species
  int<lower=1> n_genera;  // (number of) genera (level-3 clusters)
  int<lower=1> genus_lookup[n_species]; // level-3 cluster look up vector for level-2 cluster

  int<lower=1> n_sites;  // (number of) sites within region (level-2 clusters)
  int<lower=1, upper=n_sites> sites[n_sites];  // vector of sites
  int<lower=1> n_level_three;  // (number of) fine-scale (3) ecoregion areas (level-3 clusters)
  int<lower=1> n_ecoregion_one;  // (number of) broad-scale (1) ecoregion areas (level-4 clusters)
  int<lower=1> level_three_lookup[n_sites]; // level-3 cluster look up vector for level-2 cluster
  int<lower=1> ecoregion_one_lookup[n_level_three]; // level-4 cluster look up vector for level-3 cluster
  
  int<lower=1> n_intervals;  // intervals during which sites are visited
  
  int intervals[n_intervals]; // vector of intervals (used as covariate data for 
                                // species specific effect of occupancy interval (time) on occupancy)
                                // needs to begin with intervals[1] = 0, i.e., 
                                // there is no temporal addition in the first interval
  
  int<lower=1> n_visits; // visits within intervals
  
  int<lower=0> V_citsci[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  int<lower=0> V_museum[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  
  int<lower=0> ranges[n_species, n_sites, n_intervals, n_visits];  // NA indicator where 1 == site is in range, 0 == not in range
  //int<lower=0> V_museum_NA[n_species, n_sites, n_intervals, n_visits];  // indicator where 1 == sampled, 0 == missing data
  
  vector[n_sites] site_areas; // (scaled) spatial area extent of each site
  vector[n_sites] pop_densities; // (scaled) population density of each site
  vector[n_sites] avg_income; // (scaled) developed open surface cover of each site
  vector[n_sites] herb_shrub_forest; // (scaled) undeveloped open surface cover of each site
  vector[n_species] nativity;
  
} // end data


parameters {
  
  // OCCUPANCY
  real mu_psi_0; // global intercept for occupancy
  
  // species specific intercept allows some species to occur at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] psi_species; // species specific intercept for occupancy
  real<lower=0> sigma_psi_species; // variance in species intercepts// Level-3 spatial random effect
  // Level-3 phylogenetic random effect
  vector[n_genera] psi_genus; // site specific intercept for PL outcome
  real<lower=0> sigma_psi_genus; // variance in site intercepts
  
  // Spatially nested random effect on occupancy rates
  // Level-2 spatial random effect
  // site specific intercept allows some sites to be occupied at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all sites.
  vector[n_sites] psi_site; // site specific intercept for occupancy
  real<lower=0> sigma_psi_site; // variance in site intercepts
  // Level-3 spatial random effect
  // site specific intercept allows some sites to have lower success than others, 
  // but with overall estimates for success partially informed by the data pooled across all sites.
  vector[n_level_three] psi_level_three; // site specific intercept for PL outcome
  real<lower=0> sigma_psi_level_three; // variance in site intercepts
  // Level-4 spatial random effect
  // site specific intercept allows some sites to have lower success than others, 
  // but with overall estimates for success partially informed by the data pooled across all sites.
  vector[n_ecoregion_one] psi_ecoregion_one; // site specific intercept for PL outcome
  real<lower=0> sigma_psi_ecoregion_one; // variance in site intercepts
  
  // random slope for species specific natural habitat effects on occupancy
  vector[n_species] psi_herb_shrub_forest; // vector of species specific slope estimates
  //vector[n_species] mu_psi_herb_shrub_forest; // community mean of species specific slopes
  real delta0;
  real delta1;
  //real<lower=0> sigma_psi_herb_shrub_forest; // variance in species slopes
  real<lower=0> gamma0;
  real gamma1;
    
  // fixed effect of site area on occupancy
  real psi_site_area;
  
  // DETECTION
  
  // citizen science observation process
  real mu_p_citsci_0; // global detection intercept for citizen science records
  
  // species specific intercept allows some species to be detected at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] p_citsci_species; // species specific intercept for detection
  real<lower=0> sigma_p_citsci_species; // variance in species intercepts
  
  // random slope for site specific temporal effects on occupancy
  // level-2 spatial clusters
  vector[n_sites] p_citsci_site; // vector of spatially specific slope estimates
  real<lower=0> sigma_p_citsci_site; // variance in site slopes
  // level-3 spatial clusters
  vector[n_level_three] p_citsci_level_three; // site specific intercept for PL outcome
  real<lower=0> sigma_p_citsci_level_three;
  // level-4 spatial clusters
  vector[n_ecoregion_one] p_citsci_ecoregion_one; // site specific intercept for PL outcome
  real<lower=0> sigma_p_citsci_ecoregion_one; 
  
  real p_citsci_interval; // fixed temporal effect on detection probability
  real p_citsci_pop_density; // fixed effect of population on detection probability
  
} // end parameters


transformed parameters {
  
  real logit_psi[n_species, n_sites, n_intervals];  // odds of occurrence
  real logit_p_citsci[n_species, n_sites, n_intervals]; // odds of detection by cit science

  vector[n_species] mu_psi_herb_shrub_forest; // community mean of species specific slopes
  vector[n_species] sigma_psi_herb_shrub_forest; // community mean of species variation
  
  // spatially nested intercepts
  real psi0_site[n_sites];
  real psi0_level_three[n_level_three];

  real p0_citsci_site[n_sites];
  real p0_citsci_level_three[n_level_three];

  // phylogenetically nested intercepts
  real psi0_species[n_species];
  
  // intercept plus nativity adjustment can never be negative
  real<lower=0> gamma0_plus_gamma1;
  gamma0_plus_gamma1 = gamma0 + gamma1;
  
  //
  // compute the varying citsci detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    psi0_level_three[i] = psi_ecoregion_one[ecoregion_one_lookup[i]] + 
      psi_level_three[i];
  } 

  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    psi0_site[i] = psi0_level_three[level_three_lookup[i]] + 
      psi_site[i];
  }
  
  //
  // compute the varying citsci detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    p0_citsci_level_three[i] = p_citsci_ecoregion_one[ecoregion_one_lookup[i]] + 
      p_citsci_level_three[i];
  } 

  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    p0_citsci_site[i] = p0_citsci_level_three[level_three_lookup[i]] + 
      p_citsci_site[i];
  } 
  
  // Phylogenetic clustering for occurrence
  // compute the varying intercept at the level-2 species level
  // by clustering within Level-3 (n_genera level-3 random intercepts)
  for(i in 1:n_species){
    psi0_species[i] = psi_genus[genus_lookup[i]] + psi_species[i];
  }
  
  for(i in 1:n_species){
    mu_psi_herb_shrub_forest[i] = delta0 + delta1*nativity[i];
  }
  
  for(i in 1:n_species){
    sigma_psi_herb_shrub_forest[i] = gamma0 + gamma1*nativity[i];
  }
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          logit_psi[i,j,k] = // the inverse of the log odds of occurrence is equal to..
            psi0_species[species[i]] + // a phylogenetically nested, species-specific intercept
            psi0_site[sites[j]] + // a spatially nested, site-specific intercept
            psi_herb_shrub_forest[species[i]]*herb_shrub_forest[j] + // an effect 
            psi_site_area*site_areas[j] // an effect of spatial area of the site on occurrence
            ; // end psi[i,j,k]
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
          logit_p_citsci[i,j,k] = // the inverse of the log odds of detection is equal to..
            p_citsci_species[species[i]] +
            p0_citsci_site[sites[j]] + // a spatially specific intercept
            p_citsci_interval*(intervals[k]^2) + // an overall effect of time on detection
            p_citsci_pop_density*pop_densities[j] // an overall effect of pop density on detection
           ; // end p_citsci[i,j,k]

      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
             
  
} // end transformed parameters


model {
  
  // PRIORS
    
  // Occupancy (Ecological Process)
  mu_psi_0 ~ normal(0, 0.25); // global intercept for occupancy rate
  
  // level-2 spatial grouping
  psi_site  ~ normal(0, sigma_psi_site);
  sigma_psi_site ~ normal(0, 1); // weakly-informative prior
  // level-3 spatial grouping
  psi_level_three ~ normal(0, sigma_psi_level_three);
  sigma_psi_level_three ~ normal(0, 0.5); // weakly-informative prior
  // level-4 spatial grouping
  psi_ecoregion_one ~ normal(0, sigma_psi_ecoregion_one);
  sigma_psi_ecoregion_one ~ normal(0, 0.5); // weakly-informative prior
  
  // level-2 phylogenetic grouping
  psi_species ~ normal(0, sigma_psi_species); 
  sigma_psi_species ~ normal(0, 1); // weakly-informative prior
  // level-3 phylogenetic grouping
  psi_genus ~ normal(mu_psi_0, sigma_psi_genus); 
  sigma_psi_genus ~ normal(0, 0.25); // weakly-informative prior
  
  psi_herb_shrub_forest ~ normal(mu_psi_herb_shrub_forest, sigma_psi_herb_shrub_forest);
  //mu_psi_herb_shrub_forest ~ normal(0, 2); // community mean 
  //sigma_psi_herb_shrub_forest ~ normal(0.75, 0.1); // community variance
  // species-specific effect is now a vector with intercept delta0 and an effect of nativity (delta1)
  delta0 ~ normal(0, 1); // community mean
  delta1 ~ normal(0, 2); // effect of nativity
  gamma0 ~ normal(0, 0.5); // community mean
  gamma1 ~ normal(0, 0.25); // effect of nativity
  
  
  psi_site_area ~ normal(0, 2); // effect of site area on occupancy
  
  // Detection (Observation Process)
  
  // citizen science records
  mu_p_citsci_0 ~ normal(0, 0.25); // global intercept for detection
  
  p_citsci_species ~ normal(mu_p_citsci_0, sigma_p_citsci_species); 
  sigma_p_citsci_species ~ normal(0, 1); // weakly-informative prior
  
  // level-2 spatial grouping
  p_citsci_site  ~ normal(0, sigma_p_citsci_site);
  sigma_p_citsci_site ~ normal(0, 0.5); // weakly-informative prior
  // level-3 spatial grouping
  p_citsci_level_three ~ normal(0, sigma_p_citsci_level_three);
  sigma_p_citsci_level_three ~ normal(0, 0.25); // weakly-informative prior
  // level-4 spatial grouping
  p_citsci_ecoregion_one ~ normal(0, sigma_p_citsci_ecoregion_one);
  sigma_p_citsci_ecoregion_one ~ normal(0, 0.25); // weakly-informative prior
  
  // a temporal effect on detection probability
  p_citsci_interval ~ normal(0, 2); 
  
  // a population effect on detection probability
  p_citsci_pop_density ~ normal(0, 2);
  
  // LIKELIHOOD
  
  // Stan can sample the mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
        // If the site is in the range of a species, then evaluate lp, otherwise do not (treat as NA).
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
        
          // if species is detected at the specific site*interval at least once
          // by citizen science efforts OR museum records
          // then the species occurs there. lp_observed calculates
          // the probability density that species occurs given psi, plus the 
          // probability density that we did/did not observe it on each visit l in 1:nvisit
          if(sum(V_citsci[i, j, k, 1:n_visits]) > 0 || sum(V_museum[i, j, k, 1:n_visits]) > 0) {
            
             // lp_observed:
             target += log_inv_logit(logit_psi[i,j,k]) +
                      binomial_logit_lpmf(sum(V_citsci[i,j,k,1:n_visits]) | n_visits, logit_p_citsci[i,j,k]); 

          // else the species was never detected at the site*interval
          // lp_unobserved sums the probability density of:
          // 1) species occupies the site*interval but was not detected on each visit, and
          // 2) the species does not occupy the site*interval
          } else {
            
            // lp_unobserved
            target += log_sum_exp(log_inv_logit(logit_psi[i,j,k]) +
                    binomial_logit_lpmf(0 | 
                      n_visits, logit_p_citsci[i,j,k]),
                    
                    log1m_inv_logit(logit_psi[i,j,k])); 
            
          } // end if/else ever observed
        
        } // end if/ in range
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model

generated quantities{
  
  // Track mean occupancy effect of nat habitat area for native versus non-native species
  real mu_psi_nat_habitat_native;
  mu_psi_nat_habitat_native = delta0 + delta1*1;
  
  real mu_psi_nat_habitat_nonnative;
  mu_psi_nat_habitat_nonnative = delta0 + delta1*0;
  
  // Post pred check
  int Z[n_species, n_sites, n_intervals];
  
  int z_rep[n_species, n_sites, n_intervals];
  int y_rep_citsci[n_species, n_sites, n_intervals, n_visits]; // repd detections

  real eval_citsci[n_species,n_sites,n_intervals,n_visits]; // expected values

  real T_rep_citsci[n_species]; // Freeman-Tukey distance from eval (species bin)
  real T_obs_citsci[n_species]; // Freeman-Tukey distance from eval (species bin)

  real P_species_citsci[n_species]; // P-value by species

  // Initialize T_rep and T_obs and P-values
  for(i in 1:n_species){
    
    T_rep_citsci[i] = 0;
    T_obs_citsci[i] = 0;
    
    P_species_citsci[i] = 0;

  }
      
  // Predict Z at sites
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
      
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
          
          // if occupancy state is certain then the expected occupancy is 1
          if(sum(V_citsci[i, j, k, 1:n_visits]) > 0 || sum(V_museum[i, j, k, 1:n_visits]) > 0) {
          
            Z[i,j,k] = 1;
          
          // else the site could be occupied or not
          } else {
            
            // occupancy but never observed by either dataset
            real ulo = inv_logit(logit_psi[i,j,k]) * 
              ((1 - inv_logit(logit_p_citsci[i,j,k]))^n_visits);
            // non-occupancy
            real uln = (1 - inv_logit(logit_psi[i,j,k]));
            
            // outcome of occupancy given the likelihood associated with both possibilities
            Z[i,j,k] = bernoulli_rng(ulo / (ulo + uln));
            
          } // end else uncertain occupancy state
        
        // else the site is not in range for the species
        } else {
          
          // and by definition the site is unoccupied
          Z[i,j,k] = 0;
          
        } // end else the site is not in the species range
        
      } // end loop across intervals
    } // end loop across sites
  } // end loop across species
      
  // generating posterior predictive distribution
  // Predict Z at sites
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        for(l in 1:n_visits){
          
          // expected detections
          eval_citsci[i,j,k,l] = Z[i,j,k] * 
            bernoulli_logit_rng(logit_p_citsci[i,j,k]);
          
          // occupancy in replicated data
          // should evaluate to zero if the site is not in range
          z_rep[i,j,k] = bernoulli_logit_rng(logit_psi[i,j,k]); 
          if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
            z_rep[i,j,k] = z_rep[i,j,k];
          } else {
            z_rep[i,j,k] = 0;
          }
          
          // detections in replicated data
          y_rep_citsci[i,j,k,l] = z_rep[i,j,k] * bernoulli_logit_rng(logit_p_citsci[i,j,k]);

          // Compute fit statistic (Tukey-Freeman) for replicate data
          // Citizen science records
          // Binned by species
          T_rep_citsci[i] = T_rep_citsci[i] + (sqrt(y_rep_citsci[i,j,k,l]) - 
            sqrt(eval_citsci[i,j,k,l]))^2;
          // Compute fit statistic (Tukey-Freeman) for real data
          // Binned by species
          T_obs_citsci[i] = T_obs_citsci[i] + (sqrt(V_citsci[i,j,k,l]) - 
            sqrt(eval_citsci[i,j,k,l]))^2;
          
        } // end loop across visits
      } // end loop across intervals
    } // end loop across sites
  } // end loop across species
  
  // bin by species
  for(i in 1:n_species) { // loop across all species
    
    // if the discrepancy is lower for the real data for the species
    // versus the replicated data
    if(T_obs_citsci[i] < T_rep_citsci[i]){
      
      // then increase species P by 1      
      P_species_citsci[i] = P_species_citsci[i] + 1;
      // the ppc will involve averaging P across the number of post-burnin iterations
            
    }
    
  }

}
