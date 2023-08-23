// multi-species occupancy model for BBNA occurrence data
// jcu, started nov 21, 2022.

data {
  
  int<lower=1> n_species; // number of observed species
  int<lower=1> species[n_species]; // vector of species identities
  
  int<lower=1> n_sites;  // number of sites (level-2 clusters)
  int<lower=1, upper=n_sites> sites[n_sites]; // vector of site identities
  int<lower=1> n_level_three;  // (number of) fine-scale ecoregion areas (level-3 clusters)
  int<lower=1> n_level_four;  // (number of) broad-scale ecoregion areas (level-4 clusters)

  int<lower=1> level_three_lookup[n_sites]; // level-3 cluster look up vector for level-3 cluster
  int<lower=1> level_four_lookup[n_level_three]; // level-4 cluster look up vector for level-4 cluster

  int<lower=1> n_intervals;  // intervals during which sites are visited
  
  int intervals[n_intervals]; // vector of intervals (used as covariate data for 
                                // species specific effect of occupancy interval (time) on detection)
  int<lower=1> n_visits; // visits within intervals
  
  int<lower=0> V_cs[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  int<lower=0> V_rc[n_species, n_sites, n_intervals, n_visits];  // visits l when species i was detected at site j on interval k
  
  int<lower=0> ranges[n_species, n_sites, n_intervals, n_visits];  // NA indicator where 1 == site is in range, 0 == not in range
  int<lower=0> V_rc_NA[n_species, n_sites, n_intervals, n_visits];  // indicator where 1 == sampled, 0 == missing data
  
  vector[n_sites] site_areas; // (scaled) spatial area extent of each site
  vector[n_sites] pop_densities; // (scaled) population density of each site
  vector[n_sites] avg_income; // (scaled) household income of each site
  vector[n_sites] natural_habitat; // (scaled) undeveloped open surface cover of each site

} // end data


parameters {

  // OCCUPANCY
  real mu_psi_0; // global intercept for occupancy
  
  // species specific intercept allows some species to occur at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] psi_species; // species specific intercept for occupancy
  real<lower=0> sigma_psi_species; // variance in species intercepts
  
  // Spatially nested random effect on occupancy rates
  // Level-2 spatial random effect
  vector[n_sites] psi_site; // site specific intercept for occupancy
  real<lower=0> sigma_psi_site; // variance in site intercepts
  // Level-3 spatial random effect
  vector[n_level_three] psi_level_three; // level-three specific intercept for PL outcome
  real<lower=0> sigma_psi_level_three; // variance in level-three intercepts
  // Level-4 spatial random effect
  vector[n_level_four] psi_level_four; // level-four specific intercept for PL outcome
  real<lower=0> sigma_psi_level_four; // variance in level-four intercepts
  
  // random slope for species specific natural habitat effects on occupancy
  vector[n_species] psi_natural_habitat; // vector of species specific slope estimates
  real mu_psi_natural_habitat; // community mean of species specific slopes
  real<lower=0> sigma_psi_natural_habitat; // variance in species slopes
  
  // random slope for species specific household income effects on occupancy
  vector[n_species] psi_income; // vector of species specific slope estimates
  real mu_psi_income; // community mean of species specific slopes
  real<lower=0> sigma_psi_income; // variance in species slopes
  
  // fixed effect of site area on occupancy
  real psi_site_area;
  
  // DETECTION
  
  // citizen science observation process
  real mu_p_cs_0; // global detection intercept for citizen science records
  
  // species specific intercept allows some species to be detected at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] p_cs_species; // species specific intercept for detection
  real<lower=0> sigma_p_cs_species; // variance in species intercepts
  
  // random slope for site specific temporal effects on occupancy
  // level-2 spatial clusters
  vector[n_sites] p_cs_site; // vector of spatially specific slope estimates
  real<lower=0> sigma_p_cs_site; // variance in site slopes
  // level-3 spatial clusters
  vector[n_level_three] p_cs_level_three; // level-three specific intercept for cs detection
  real<lower=0> sigma_p_cs_level_three;  // variance in level-three slopes
  // level-4 spatial clusters
  vector[n_level_four] p_cs_level_four; // level-four specific intercept for cs detection
  real<lower=0> sigma_p_cs_level_four;  // variance in level-four slopes
  
  real p_cs_interval; // fixed temporal effect on cs detection probability
  real p_cs_pop_density; // fixed effect of population on cs detection probability
  
} // end parameters


transformed parameters {
  
  real logit_psi[n_species, n_sites, n_intervals];  // odds of occurrence
  real logit_p_cs[n_species, n_sites, n_intervals]; // odds of detection by community science

  // spatially nested intercepts
  real psi0_site[n_sites];
  real psi0_level_three[n_level_three];

  real p0_cs_site[n_sites];
  real p0_cs_level_three[n_level_three];

  //
  // compute the varying community science detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    psi0_level_three[i] = psi_level_four[level_four_lookup[i]] + 
      psi_level_three[i];
  } 

  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    psi0_site[i] = psi0_level_three[level_three_lookup[i]] + 
      psi_site[i];
  }
  
  //
  // compute the varying community science detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    p0_cs_level_three[i] = p_cs_level_four[level_four_lookup[i]] + 
      p_cs_level_three[i];
  } 

  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    p0_cs_site[i] = p0_cs_level_three[level_three_lookup[i]] + 
      p_cs_site[i];
  }
  
  //
  //
  
  // calculate logit scaled expected values for occurrence and detection
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          logit_psi[i,j,k] = // the inverse of the log odds of occurrence is equal to..
            psi_species[species[i]] + // a species specific intercept
            psi0_site[sites[j]] + // a spatially nested, site-specific intercept
            psi_natural_habitat[species[i]]*natural_habitat[j] + // a species-specific effect of natural habitat area
            psi_income[species[i]]*avg_income[j] + // a species-specific effect of household income
            psi_site_area*site_areas[j] // an effect of spatial area of the site 
            ; // end psi[i,j,k]
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
          logit_p_cs[i,j,k] = // the inverse of the log odds of detection is equal to..
            p_cs_species[species[i]] + // a species-specific intercept
            p0_cs_site[sites[j]] + // a spatially specific intercept 
            p_cs_interval*(intervals[k]^2) + // an overall effect of time on detection
            p_cs_pop_density*pop_densities[j] // an overall effect of pop density on detection
           ; // end p_cs[i,j,k]
           
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
             
  
} // end transformed parameters


model {
  
  // PRIORS

  // Occupancy (Ecological Process)
  mu_psi_0 ~ normal(0, 1); // global intercept for occupancy rate
  
  // level-2 spatial grouping
  psi_site  ~ normal(0, sigma_psi_site);
  sigma_psi_site ~ normal(0, 0.5); // weakly-informative prior
  // level-3 spatial grouping
  psi_level_three ~ normal(0, sigma_psi_level_three);
  sigma_psi_level_three ~ normal(0, 0.5); // weakly-informative prior
  // level-5 spatial grouping
  psi_level_four ~ normal(0, sigma_psi_level_four);
  sigma_psi_level_four ~ normal(0, 0.5); // weakly-informative prior
  
  psi_species ~ normal(mu_psi_0, sigma_psi_species); 
  sigma_psi_species ~ normal(0, 1); // weakly-informative prior
  
  psi_natural_habitat ~ normal(mu_psi_natural_habitat, sigma_psi_natural_habitat);
  mu_psi_natural_habitat ~ normal(0, 2); // community mean
  sigma_psi_natural_habitat ~ normal(0, 1); // community variance
  
  psi_income ~ normal(mu_psi_income, sigma_psi_income);
  mu_psi_income ~ normal(0, 2); // community mean
  sigma_psi_income ~ normal(0, 1); // community variance
  
  psi_site_area ~ normal(0, 2); // effect of site area on occupancy
  
  // Detection (Observation Process)
  
  // community science records
  
  mu_p_cs_0 ~ normal(0, 2); // global intercept for detection
  
  p_cs_species ~ normal(mu_p_cs_0, sigma_p_cs_species); 
  sigma_p_cs_species ~ normal(0, 1); // weakly-informative prior
  
  // level-2 spatial grouping
  p_cs_site  ~ normal(0, sigma_p_cs_site);
  sigma_p_cs_site ~ normal(0, 0.25); // weakly-informative prior
  // level-3 spatial grouping
  p_cs_level_three ~ normal(0, sigma_p_cs_level_three);
  sigma_p_cs_level_three ~ normal(0, 0.25); // weakly-informative prior
  // level-5 spatial grouping
  p_cs_level_four ~ normal(0, sigma_p_cs_level_four);
  sigma_p_cs_level_four ~ normal(0, 0.25); // weakly-informative prior

  // a temporal effect on detection probability
  p_cs_interval ~ normal(0, 2); 
  
  // a population effect on detection probability
  p_cs_pop_density ~ normal(0, 2);
  
  // LIKELIHOOD
  
  // Stan can sample the mean and sd of parameters by summing out the
  // parameter (marginalizing) across likelihood statements
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
        // If the site is in the range of a species, then evaluate lp, otherwise do not (treat as NA).
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
        
          // if species is detected at the specific site*interval at least once
          // by community science efforts OR research collection records
          // then the species occurs there. lp_observed calculates
          // the probability density that species occurs given psi, plus the 
          // probability density that we did/did not observe it on each visit l in 1:nvisit
          if(sum(V_cs[i, j, k, 1:n_visits]) > 0 || sum(V_rc[i, j, k, 1:n_visits]) > 0) {
            
             // lp_observed:
             target += log_inv_logit(logit_psi[i,j,k]) +
                      binomial_logit_lpmf(sum(V_cs[i,j,k,1:n_visits]) | n_visits, logit_p_cs[i,j,k]);
                          
          // else the species was never detected at the site*interval
          // lp_unobserved sums the probability density of:
          // 1) species occupies the site*interval but was not detected on each visit, and
          // 2) the species does not occupy the site*interval
          } else {
            
            // lp_unobserved
            target += log_sum_exp(log_inv_logit(logit_psi[i,j,k]) +
                    binomial_logit_lpmf(0 | 
                      n_visits, logit_p_cs[i,j,k]),
                    
                    log1m_inv_logit(logit_psi[i,j,k])); 
            
          } // end if/else ever observed
        
        } // end if/ in range
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model

generated quantities{
  
  // posterior predictive check (Freeman-Tukey posterior pred check, binned by species)
  
  // estimate expected values (occurrence is a partially latent variable so when we don't observe the species, we don't actually know the expected values)
  // create replicated data using the paramter estimates and stochastic process defined by the model
  // gather real detecions
  
  // test the rate at which the number of detections in the real data versus the repped data 
  // are closer to the expected values. The FTP is the rate at which the real data are closer.
  
  int Z[n_species, n_sites, n_intervals];
  
  int z_rep[n_species, n_sites, n_intervals]; // repped occurrence
  int y_rep_cs[n_species, n_sites, n_intervals, n_visits]; // repped detections

  real eval_cs[n_species,n_sites,n_intervals,n_visits]; // expected values

  real T_rep_cs[n_species]; // Freeman-Tukey distance from eval (species bin)
  real T_obs_cs[n_species]; // Freeman-Tukey distance from eval (species bin)
  
  real P_species_cs[n_species]; // P-value by species

  // Initialize T_rep and T_obs and P-values
  for(i in 1:n_species){
    
    T_rep_cs[i] = 0;
    T_obs_cs[i] = 0;
    
    P_species_cs[i] = 0;
    
  }
      
  // Predict Z at sites
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
      
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
          
          // if occupancy state is certain then the expected occupancy is 1
          if(sum(V_cs[i, j, k, 1:n_visits]) > 0 || sum(V_rc[i, j, k, 1:n_visits]) > 0) {
          
            Z[i,j,k] = 1;
          
          // else the site could be occupied or not
          } else {
            
            // occupancy but never observed by either dataset
            real ulo = inv_logit(logit_psi[i,j,k]) * 
              ((1 - inv_logit(logit_p_cs[i,j,k]))^n_visits);
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
          eval_cs[i,j,k,l] = Z[i,j,k] * 
            bernoulli_logit_rng(logit_p_cs[i,j,k]);
          
          // occupancy in replicated data
          // should evaluate to zero if the site is not in range
          z_rep[i,j,k] = bernoulli_logit_rng(logit_psi[i,j,k]); 
          if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
            z_rep[i,j,k] = z_rep[i,j,k];
          } else {
            z_rep[i,j,k] = 0;
          }
          
          // detections in replicated data
          y_rep_cs[i,j,k,l] = z_rep[i,j,k] * bernoulli_logit_rng(logit_p_cs[i,j,k]);

          // Compute fit statistic (Tukey-Freeman) for replicate data
          // community science records
          // Binned by species
          T_rep_cs[i] = T_rep_cs[i] + (sqrt(y_rep_cs[i,j,k,l]) - 
            sqrt(eval_cs[i,j,k,l]))^2;
          // Compute fit statistic (Tukey-Freeman) for real data
          // Binned by species
          T_obs_cs[i] = T_obs_cs[i] + (sqrt(V_cs[i,j,k,l]) - 
            sqrt(eval_cs[i,j,k,l]))^2;
          
        } // end loop across visits
      } // end loop across intervals
    } // end loop across sites
  } // end loop across species
  
  // bin by species
  for(i in 1:n_species) { // loop across all species
    
    // if the discrepancy is lower for the real data for the species
    // versus the replicated data
    if(T_obs_cs[i] < T_rep_cs[i]){
      
      // then increase species P by 1      
      P_species_cs[i] = P_species_cs[i] + 1;
      // the ppc will involve averaging P across the number of post-burnin iterations
            
    }
    
  }

}