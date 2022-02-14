range_check <- function(parms, risk_change_ages) {
  
  # check whether ranges of some parameters are plausible this allows return without any simulation
  in_range <- TRUE
  
  # to avoid runs with an unrealistically large number of adenomas, which will take a long time to complete, check that
  #   the adenoma risk level is reasonable based on the maximum adenoma risk at ages 20, 50, 60, 70, and 80
  # CR: note that we will want something similar for SSLs
  # CR: note that variable names were misleading. previous check focused on parameter values, not prevalence,
  max_prev <- c(0.3, 0.5, 0.6, 0.7)

  # use n.adenoma at age ~ Pois(Lambda(age)) where Lambda(age) is the cumulative risk
  # expected prevalence is 1 - exp(-Lambda(age))
  # this uses the JASA formulation of the adenoma risk function, as does the crc-spin model,
  # which specifies a baseline log-risk at min_age equal to ar.mean min_age*ar.minto49

  #min_age=20
  risk_prevalences = risk_and_prevalence_nh_poisson(parms = parms, risk_ages = c(50, 60, 70, 80), risk_change_ages = risk_change_ages)
  
  in_range <- in_range & all(risk_prevalences$exp.prevs <= max_prev)

  # check that adenoma growth parameteters result in the probabilty that an adenoma reaches 10mm within 10 years that is
  #   between p_min and p_max
  p_min <- 0.0001	
  p_max <- 0.25
  
  # these calculations are based directly on the CDF of the time to reach 10mm
  p_10mm_in_10yrs_colon <- as.numeric(exp(-(10/parms["growth.colon.beta2"])^(-parms["growth.colon.beta1"])))
  in_range <- in_range & (p_10mm_in_10yrs_colon >= p_min) & (p_10mm_in_10yrs_colon <= p_max)
  
  p_10mm_in_10yrs_rectum <- as.numeric(exp(-(10/parms["growth.rectum.beta2"])^(-parms["growth.rectum.beta1"])))
  in_range <- in_range & (p_10mm_in_10yrs_rectum >= p_min) & (p_10mm_in_10yrs_rectum <= p_max)
  
  return(in_range) 
}

# This function is within the range_check script so every range_check dependency is listed here.
# Note that we intentionally do not load any libraries here and we use the internal functinos from crcspin, becasue we wannt this to be maximally fast.
# calculates cumulative risk and expected prevalenc for a Nonhomogenous Poisson process.
risk_and_prevalence_nh_poisson = function(parms, risk_ages = c(25,50,60,70), parms_risk_names = c("ar.20to49","ar.50to59","ar.60to69","ar.70plus"), risk_change_ages = c(20,50,60,70)) {
  
  cum_risk_parms <- crcspin:::get_cumulative_risk_parms(parms[parms_risk_names],risk_change_ages = risk_change_ages)
  y <- cum_risk_parms$y
  a <- cum_risk_parms$a
  b <- cum_risk_parms$b
  
  cumulative_age_risks <- crcspin:::crc_lambda((risk_ages - risk_change_ages[1]),risk_change_ages =  risk_change_ages, y, a, b)
  
  base_risk=exp(parms[["ar.mean"]] + 0.51 * parms[["ar.fem"]])
  
  cumulative_risks <- base_risk * cumulative_age_risks
  
  # return cumulative risk at each age and expected prevalence
  list(cum.risks = cumulative_risks, exp.prevs = 1 - exp(-cumulative_risks))
  
}