// multi-species occupancy model for GBIF occurrence data
// will include income as a predictor, but will also include a simplified random effects
// structure to see if this helps with non-convergence that occurred when using the original model
// jcu, started nov 21, 2022.

data {
  
  int<lower=1> n_species;  // observed species
  int<lower=1> species[n_species]; // vector of species identities
  
  int<lower=1> n_sites;  // (number of) sites within region (level-2 clusters)
  int<lower=1, upper=n_sites> sites[n_sites];  // vector of sites identities (level-2 clusters)
  int<lower=1> n_level_three;  // (number of) fine-scale (3) ecoregion areas (level-3 clusters)
  int<lower=1> n_level_four;  // (number of) broad-scale (1) ecoregion areas (level-4 clusters)
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
  vector[n_sites] avg_racial_minority; // (scaled) prop. of racial minority population of each site
  vector[n_sites] natural_habitat; // (scaled) undeveloped open surface cover of each site
  vector[n_sites] open_developed; // (scaled) open developed surface cover of each site
  
  vector[n_species] nativity; // nativity vector, 0 == non-native, 1 == native
  
} // end data


parameters {
  
  // OCCUPANCY
  
  real mu_psi_0; // global intercept for occupancy
  
  // species-specific intercepts allow some species to occur at higher rates than others, 
  // but with overall estimates for occupancy partially informed by the data pooled across all species.
  vector[n_species] psi_species_raw; // species specific intercept for occupancy
  real<lower=0> sigma_psi_species; // variance in species intercepts// Level-3 spatial random effect
  
  // spatially nested random effect on occupancy rates
  // Level-2 spatial random effect
  vector[n_sites] psi_site_raw; // site specific intercept for occupancy
  real<lower=0> sigma_psi_site; // variance in site intercepts
  // Level-3 spatial random effect
  vector[n_level_three] psi_level_three_raw; // level-three intercept for occupancy
  real<lower=0> sigma_psi_level_three; // variance in level-three intercepts
  // Level-4 spatial random effect
  vector[n_level_four] psi_level_four_raw; // level-four specific intercept for PL outcome
  real<lower=0> sigma_psi_level_four; // variance in level-four intercepts
  
  // random slope for species specific natural habitat effects on occupancy
  vector[n_species] psi_natural_habitat; // vector of species specific slope estimates
  real delta0; // baseline effect (mean)
  real delta1; // effect of being native on the expected value of the random effect
  real<lower=0> gamma0; // baseline effect (variance) (negative variance not possible)
  real gamma1; // effect of being native on the expected value of the random effect
  
  // fixed slope for open developed greenspace effects on occupancy
  real mu_psi_open_developed; // community mean of species specific slopes
  // fixed slope for household income effects on occupancy
  real mu_psi_income; // community mean of species specific slopes
  // fixed slope for racial diversity (prop. population minority) effects on occupancy
  real mu_psi_race; // community mean
  // fixed effect of site area on occupancy
  real psi_site_area;
  
  // DETECTION
  
  // community science observation process
  real mu_p_cs_0; // global detection intercept for community science records
  
  // random slope for site specific temporal effects on occupancy
  // level-2 spatial clusters
  vector[n_sites] p_cs_site_raw; // vector of spatially specific slope estimates
  real<lower=0> sigma_p_cs_site; // variance in site slopes
  // level-3 spatial clusters
  vector[n_level_three] p_cs_level_three_raw; // level-three specific intercept for cs detection
  real<lower=0> sigma_p_cs_level_three;  // variance in level-three slopes
  
  real p_cs_interval; // fixed temporal effect on cs detection probability
  real p_cs_pop_density; // fixed effect of population on cs detection probability
  real p_cs_income; // fixed effect of income on cs detection probability
  real p_cs_race; // fixed effect of race on cs detection probability

} // end parameters


transformed parameters {
  
  real logit_psi[n_species, n_sites, n_intervals];  // odds of occurrence
  real logit_p_cs[n_species, n_sites, n_intervals]; // odds of detection by community science

  // species intercepts
  vector[n_species] psi_species; // for occurrence
  psi_species = sigma_psi_species * psi_species_raw;
  
  vector[n_species] p_cs_species; // for detection
  p_cs_species = sigma_p_cs_species * p_cs_species_raw;
  
  // spatially nested intercepts
  vector[n_sites] psi_site;
  vector[n_level_three] psi_level_three;
  vector[n_level_four] psi_level_four;

  vector[n_sites] p_cs_site;
  vector[n_level_three] p_cs_level_three;
  
  vector[n_species] mu_psi_natural_habitat; // expected value for species specific slopes
  vector[n_species] sigma_psi_natural_habitat; // expected value for variance among species slopes

  //
  // compute the varying community science detection intercept at the ecoregion1 level
  // Level-4 (n_level_four level-4 random intercepts)
  psi_level_four = sigma_psi_level_four * psi_level_four_raw;
  // compute the varying community science detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    psi_level_three[i] = psi_level_four[level_four_lookup[i]] + 
      sigma_psi_level_three * psi_level_three_raw[i];
  }
  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    psi_site[i] = psi_level_three[level_three_lookup[i]] + 
      sigma_psi_site * psi_site_raw[i];
  }
  
  //
  // compute the varying community science detection intercept at the ecoregion3 level
  // Level-3 (n_level_three level-3 random intercepts)
  for(i in 1:n_level_three){
    p_cs_level_three[i] = sigma_p_cs_level_three * p_cs_level_three_raw[i];
  }
  // compute varying intercept at the site level
  // Level-2 (n_sites level-2 random intercepts, nested in ecoregion3)
  for(i in 1:n_sites){
    p_cs_site[i] = p_cs_level_three[level_three_lookup[i]] + 
      sigma_p_cs_site * p_cs_site_raw[i];
  }
  
  //
  // hard prior to disallow intercept plus nativity adjustment from being negative
  real<lower=0> gamma0_plus_gamma1;
  gamma0_plus_gamma1 = gamma0 + gamma1;
  
  // model the expected value for the random effect using a linear predictor that includes nativity
  for(i in 1:n_species){
    mu_psi_natural_habitat[i] = delta0 + delta1*nativity[i];
  }
  
  // model the group level variation (allow native and non-native groups to have different amounts of variation among species)
  for(i in 1:n_species){
    sigma_psi_natural_habitat[i] = gamma0 + gamma1*nativity[i];
  }
  
  //
  //
  
  // calculate logit scaled expected values for occurrence and detection
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals  
          
          logit_psi[i,j,k] = // the inverse of the log odds of occurrence is equal to..
            mu_psi_0 + // a global intercept
            psi_species[species[i]] + // a species-specific intercept
            psi_site[sites[j]] + // a spatially nested, site-specific intercept
            psi_natural_habitat[species[i]]*natural_habitat[j] + // a species-specific effect of natural habitat area
            mu_psi_income*avg_income[j] + // a species-specific effect of income
            mu_psi_race*avg_racial_minority[j] + // an effect of ethnic composition
            mu_psi_open_developed*open_developed[j] + // a species-specific effect of income
            psi_site_area*site_areas[j] // an effect of spatial area of the site on occurrence
            ; // end psi[i,j,k]
            
      } // end loop across all intervals
    } // end loop across all sites
  }  // end loop across all species
  
  for (i in 1:n_species){   // loop across all species
    for (j in 1:n_sites){    // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
          logit_p_cs[i,j,k] = // the inverse of the log odds of detection is equal to..
            mu_p_cs_0 + // a global intercept
            p_cs_species[species[i]] + // a species specific intercept // includes global intercept
            p_cs_site[sites[j]] + // a spatially specific intercept
            p_cs_interval*(intervals[k]^2) + // an overall effect of time on detection
            p_cs_pop_density*pop_densities[j] + // an overall effect of pop density on detection
            p_cs_income*avg_racial_minority[j] + // an overall effect of income on detection
            p_cs_race*avg_minority[j]
           ; // end p_cs[i,j,k]
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
             
  
} // end transformed parameters


model {
  
  // PRIORS
  
  // Occupancy (Ecological Process)
  mu_psi_0 ~ normal(0, 1); // global intercept for occupancy rate
  
    // species intercept effects
  psi_species_raw ~ std_normal();
  //psi_species ~ normal(0, sigma_psi_species); 
  sigma_psi_species ~ normal(0, 1); // weakly-informative prior
  
  // level-2 spatial grouping
  psi_site_raw ~ std_normal();
  sigma_psi_site ~ normal(0, 0.5); // weakly-informative prior
  // level-3 spatial grouping
  psi_level_three_raw ~ std_normal();
  sigma_psi_level_three ~ normal(0, 0.5); // weakly-informative prior
  // level-4 spatial grouping
  psi_level_four_raw ~ std_normal();
  sigma_psi_level_four ~ normal(0, 0.5); // weakly-informative prior

  psi_natural_habitat ~ normal(mu_psi_natural_habitat, sigma_psi_natural_habitat);
  // community effect (mu) and variation among species (sigma) is defined as a vector 
  // with intercept delta0 and an effect of nativity (delta1) on community mean
  // and intercept gamma0 and an effect of nativity (gamma1) on variation
  delta0 ~ normal(0, 2); // community mean
  delta1 ~ normal(0, 1); // effect of nativity
  gamma0 ~ normal(0, 1); // community mean variance
  gamma1 ~ normal(0, 0.25); // effect of nativity on variance
  
  mu_psi_open_developed ~ normal(0, 2); // community mean
  mu_psi_income ~ normal(0, 2); // community mean
  mu_psi_race ~ normal(0, 2); // community mean
  psi_site_area ~ normal(0, 2); // effect of site area on occupancy
  
  // community science records
  
  mu_p_cs_0 ~ normal(0, 2); // global intercept for detection
  p_cs_species_raw ~ std_normal();
  sigma_p_cs_species ~ normal(0, 2);
  
  // level-2 spatial grouping
  p_cs_site_raw ~ std_normal();
  sigma_p_cs_site ~ normal(0, 0.5); // weakly-informative prior
  // level-3 spatial grouping
  p_cs_level_three_raw ~ std_normal();
  sigma_p_cs_level_three ~ normal(0, 0.5); // weakly-informative prior
  
  // a temporal effect on detection probability
  p_cs_interval ~ normal(0, 2); 
  // a population effect on detection probability
  p_cs_pop_density ~ normal(0, 2);
  // an income effect on detection probability
  p_cs_income ~ normal(0, 2);
  // an income effect on detection probability
  p_cs_race ~ normal(0, 2);
  
  // LIKELIHOOD
  
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all intervals
        
        // If the site is in the range of a species, then evaluate lp, otherwise do not (treat as NA).
        if(sum(ranges[i,j,k]) > 0){ // The sum of the NA vector will be == 0 if site is not in range
        
          // if species is detected at the specific site*interval at least once
          // by community science efforts OR research collection records
          // then the species occurs there. lp_observed calculates
          // the probability density that species occurs given psi, plus the 
          // probability density that we did/did not observe it on each visit l in 1:nvisit.
          // Even though we don't estimate research collection parameters here (fully integrated model),
          // we still use rc detections to anchor and guide the likelihood function.
          // that is, if we see the species using the research collections but not the comm sci, 
          // we still know that the species is present but that our comm sci detection process is missing it.
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
              // Stan can sample the mean and sd of parameters by summing out the
              // parameter (marginalizing) across likelihood statements
            target += 
                    // present but never detected
                    log_sum_exp(log_inv_logit(logit_psi[i,j,k]) +
                    binomial_logit_lpmf(0 | n_visits, logit_p_cs[i,j,k]),
                    // not present
                    log1m_inv_logit(logit_psi[i,j,k])); 
            
          } // end if/else ever observed
        
        } // end if/ in range
          
      } // end loop across all intervals
    } // end loop across all sites
  } // end loop across all species
  
} // end model

generated quantities{
  
  // Effect of nat habitat area for all, native and non-native species is a derived parameter
  // we estimate the expected value for all species, native, or non-native species using our linear predictor.
  // By doing this in each step of the MCMC we can get a distribution of outcomes 
  // (propagating our uncertainty in delta0 and delta1 to an uncertainty in the group level effects)
  
  real mu_psi_natural_habitat_native;
  mu_psi_natural_habitat_native = delta0 + delta1*1;
  
  real mu_psi_natural_habitat_nonnative;
  mu_psi_natural_habitat_nonnative = delta0 + delta1*0;
  
  real mu_psi_natural_habitat_all_species;
  mu_psi_natural_habitat_all_species = mean(mu_psi_natural_habitat);

  // occurrence of species at each site in each year
  int z_simmed[n_species, n_sites, n_intervals]; // simulate occurrence

  for(i in 1:n_species){
   for(j in 1:n_sites){
     for(k in 1:n_intervals){
          z_simmed[i,j,k] = bernoulli_logit_rng(logit_psi[i,j,k]); 
      }    
    }
  }
  
  //
  // posterior predictive check (number of detections, binned by species)
  //
  int<lower=0> W_species_rep_cs[n_species]; // sum of simulated detections

  // initialize at 0
  for(i in 1:n_species){
    W_species_rep_cs[i] = 0;
  }
      
  // generating posterior predictive distribution
  // Predict Z at sites
  for(i in 1:n_species) { // loop across all species
    for(j in 1:n_sites) { // loop across all sites
      for(k in 1:n_intervals){ // loop across all years

          if(sum(ranges[i,j,k]) > 0){
            
            // detections in replicated data (us z_simmed from above)
            W_species_rep_cs[i] = W_species_rep_cs[i] + 
              (z_simmed[i,j,k] * binomial_rng(n_visits, inv_logit(logit_p_cs[i,j,k])));
            
          } // end if{}
           
      } // end loop across years
    } // end loop across sites
  } // end loop across species
  
} // end generated quantities
