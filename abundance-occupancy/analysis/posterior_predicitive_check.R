## --------------------------------------------------
### Posterior Predictive Check
# Chi-squared discrepancy 

# Read in a model file
stan_out_sim <- readRDS("./simulation/stan_out_sim_abundance.rds")

# as data frame
list_of_draws <- as.data.frame(stan_out_sim)

## --------------------------------------------------
# Abundance

# Evaluation of fit
plot(list_of_draws$fit, list_of_draws$fit_new, main = "", xlab =
       "Discrepancy actual data", ylab = "Discrepancy replicate data",
     frame.plot = FALSE,
     ylim = c(25000, 90000),
     xlim = c(25000, 90000))
abline(0, 1, lwd = 2, col = "black")

# Should be close to 1. 
# If the mean of actual data is greater (value > 1)
# then the model underpredicts the real variation in counts.
# If the mean of actual data is less (value < 1)
# then the model overpredicts the variation in counts.
mean(list_of_draws$fit) / mean(list_of_draws$fit_new)

# Should be close to 50% or 0.5
# similarly the actual data should be further away from  
# the expected value of the count about half of the time,
# (versus a count generated using the abundance rate and detection rate)
mean(list_of_draws$fit_new > list_of_draws$fit)

## --------------------------------------------------
# Occupancy

# Evaluation of fit
plot(list_of_draws$fit_occupancy, list_of_draws$fit_occupancy_new, main = "", xlab =
       "Discrepancy actual data", ylab = "Discrepancy replicate data",
     frame.plot = FALSE,
     ylim = c(0, 500),
     xlim = c(0, 500))
abline(0, 1, lwd = 2, col = "black")

# Should be close to 1. 
# If the mean of actual data is greater (value > 1)
# then the model underpredicts the real variation in counts.
# If the mean of actual data is less (value < 1)
# then the model overpredicts the variation in counts.
mean(list_of_draws$fit_occupancy) / mean(list_of_draws$fit_occupancy_new)

# Should be close to 50% or 0.5
# similarly the actual data should be further away from  
# the expected value of the count about half of the time,
# (versus a count generated using the abundance rate and detection rate)
mean(list_of_draws$fit_occupancy_new > list_of_draws$fit_occupancy)

## --------------------------------------------------
### Simple diagnostic plots

# traceplot
traceplot(stan_out_sim, pars = c(
  "mu_eta_0",
  "eta_site_area",
  "mu_p_citsci_0",
  "mu_p_museum_0",
  "phi",
  "gamma_0",
  "gamma_1"
))

# pairs plot
pairs(stan_out_sim, pars = c(
  "mu_eta_0",
  "eta_site_area",
  "mu_p_citsci_0",
  "mu_p_museum_0",
  "phi",
  "gamma_0",
  "gamma_1"
))

# Posterior predictive check
list_of_draws <- as.data.frame(stan_out_sim)