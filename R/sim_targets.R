# CRCSPIN Target Function
sim_targets <- function(parms_vec, targets, high_sens_weight = 1, risk_change_ages = c(20,50,60,70)) {
  
  # initialize the all targets vector to NAs, this allows an early break
  final_result <- rep(NA, length(targets$targets))
  names(final_result) <- names(targets$targets)
  
  # check ranges for basic calculations before simulating
  in_range <- range_check(parms_vec, risk_change_ages = risk_change_ages)
  if (!in_range) { return(final_result) }
  
  # set sensitivity of colonoscopy. Note that calibration could allow different sensitivities across targets.
  # To do that, create a new sensitivities data.frame and pass it to a sens_params object
  
  high_sensitivities = crcspin:::get_interpolation(
    x_knots = c(1,3,8,15,20,50),                 # sensitivity size *knots* 
    y_values = c(0.6,0.7,0.85,0.97,0.98,0.99),   # sensitivity values for each knot
    step = 0.5,                                  # compute sensitivity between every *step* value
    method = "stineman"                          # interpolation method
  )
  
  low_sensitivities =  crcspin:::get_interpolation(
    x_knots = c(1,5,10,20,50),                 # sensitivity size *knots* 
    y_values = c(0.1,0.2,0.6,0.9,0.99),   # sensitivity values for each knot
    step = 0.5,                                  # compute sensitivity between every *step* value
    method = "stineman"                          # interpolation method
  )
  
  baseline_sensitivities = data.frame(x = high_sensitivities$x,
                                      y = high_sens_weight * high_sensitivities$y + (1-high_sens_weight) * low_sensitivities$y)
  
  
  # Note that the function below will be used on this object
  sens_parms = list(
    cutpoints = baseline_sensitivities$x,     # this refers to size of adenomas in mm
    sensitivities = baseline_sensitivities$y, 
    coeff = c(0.575, 0.043, -0.0011125), # these are coefficients in a b_0 + b_1 x + b_2 x^2 miss rate function that operates for low values of size. This was CRCSPIN previous approach to calculate sensitivity for small adenomas. this should be irrelevant when the sensitivity is provided for the full range of adenoma sizes (1-50) mm.
    location.effect = 0,
    cancer.sens = 0.95
  )
  
  # To test that these parameters will result in the correct behavior, test this function:
  # test_function = crcscreen:::SensFnSetup(sens.parms = sens_parms, person.level = FALSE)
  # test_function(size = 5, cancer = F, location = 2, reach = 6)

  # the order of simulated targets is specified to allow evaluation of less expensive targets first, with early stopping 
  # Pickhardt	###########################################################################################################
  # adenoma size distribution
  pickhardt_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "Pickhardt",
    m_total = 50000,
    target_date = as.Date("2013-01-01", format = "%Y-%m-%d"),
    p_male = 0.59,
    mix_n = 1,
    mix_distn = 1,
    target_age_distn_name = "truncated normal",
    target_age_distn_parms_fem = c(57.42, 8.70, 40.00, 79.99),
    target_age_distn_parms_male = c(57.42, 8.70, 40.00, 79.99), 
    sens.parms=sens_parms,
    risk_change_ages = risk_change_ages
  )
  # check that the pickardt_targets are within current ranges - if not inrange then return results with NAs for
  #   remaining targets (do not simulate)
  if (
    any(is.na(pickhardt_targets)) || # Any target values are NA
    any(pickhardt_targets < targets$current_lower_bounds[names(pickhardt_targets)]) || # Any our below lower bounds
    any(pickhardt_targets > targets$current_upper_bounds[names(pickhardt_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(pickhardt_targets)] <- pickhardt_targets
  
  # Corley ##############################################################################################################
  # adenoma prevalence by age and sex
  corley_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "Corley",
    m_total = 200000,
    target_date = as.Date("2007-07-01", format = "%Y-%m-%d"),
    p_male = 0.5,
    mix_n = 2,
    mix_distn = c(0.66, 0.34),
    target_age_distn_name = c("uniform", "truncated normal"),
    target_age_distn_parms_fem = c(50.00, 69.99, 72.00, 6.50, 70.00, 89.99),
    target_age_distn_parms_male = c(50.00, 69.99, 72.00, 6.50, 70.00, 89.99), 
    sens.parms=sens_parms,
    risk_change_ages = risk_change_ages
  )
  # check that the corley_targets are within current ranges - if not inrange then return results with NAs for remaining 
  #   targets (do not simulate)
  if (
    any(is.na(corley_targets)) || # Any target values are NA
    any(corley_targets < targets$current_lower_bounds[names(corley_targets)]) || # Any our below lower bounds
    any(corley_targets > targets$current_upper_bounds[names(corley_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(corley_targets)] <- corley_targets
  
  # Church ##############################################################################################################
  # cancer prevalence by lesion size, lesion-level data based on a case-series with no information about age and sex
  church_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "Church",
    m_total = 300000,
    target_date = as.Date("2000-01-01", format = "%Y-%m-%d"),
    p_male = 0.56,  # based on Liang, Kalady, Appau, Church (2012) who studied a similar set of colonoscopies
    mix_n = 1,
    mix_distn = 1,
    target_age_distn_name = "truncated normal",
    target_age_distn_parms_fem = c(65, 5, 20, 90),
    target_age_distn_parms_male = c(65, 5, 20, 90), 
    sens.parms=sens_parms,
    risk_change_ages = risk_change_ages
  )
  # check that the church_targets are within current ranges - if not inrange then return results with NAs for remaining 
  #   targets (do not simulate)
  if (
    any(is.na(church_targets)) || # Any target values are NA
    any(church_targets < targets$current_lower_bounds[names(church_targets)]) || # Any our below lower bounds
    any(church_targets > targets$current_upper_bounds[names(church_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(church_targets)] <- church_targets
  
  # Lieberman ###########################################################################################################
  # cancer prevalence by largest lesion size, based on a VA study, with better information about age and sex
  lieberman_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "Lieberman",
    m_total = 500000,
    target_date = as.Date("2005-07-01", format = "%Y-%m-%d"),
    p_male = 0.529,
    mix_n = 2,
    mix_distn = c(0.83, 0.17),
    target_age_distn_name = c("truncated normal", "truncated normal"),
    target_age_distn_parms_fem = c(58.00, 7.00, 20.00, 69.99, 72.00, 6.50, 70.00, 99.99),
    target_age_distn_parms_male = c(58.00, 7.00, 20.00, 69.99, 72.00, 6.50, 70.00, 99.99), 
    sens.parms=sens_parms,
    risk_change_ages = risk_change_ages
  )
  # check that the lieberman_targets are within current ranges - if not inrange then return results with NAs for 
  #   remaining targets (do not simulate)
  if (
    any(is.na(lieberman_targets)) || # Any target values are NA
    any(lieberman_targets < targets$current_lower_bounds[names(lieberman_targets)]) || # Any our below lower bounds
    any(lieberman_targets > targets$current_upper_bounds[names(lieberman_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(lieberman_targets)] <- lieberman_targets
  
  # UKFSS ###############################################################################################################
  # screen detected CRC in the distal colon (based on flex sig) 
  ukfss_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "UKFSS",
    m_total = 200000,
    target_date = as.Date("1997-01-01", format = "%Y-%m-%d"),
    p_male = 0.49,
    mix_n = 1,
    mix_distn = 1,
    target_age_distn_name = "truncated normal",
    target_age_distn_parms_fem = c(59.50, 4.44, 55.00, 64.99),
    target_age_distn_parms_male = c(59.50, 4.44, 55.00, 64.99), 
    sens.parms=sens_parms,
    risk_change_ages = risk_change_ages
  )
  # check that the ukfss_targets are within current ranges - if not inrange then return results with NAs for remaining 
  #   targets (do not simulate)
  if (
    any(is.na(ukfss_targets)) || # Any target values are NA
    any(ukfss_targets < targets$current_lower_bounds[names(ukfss_targets)]) || # Any our below lower bounds
    any(ukfss_targets > targets$current_upper_bounds[names(ukfss_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(ukfss_targets)] <- ukfss_targets
  
  # SEER ################################################################################################################
  # clincically detected CRC by site (colon,rectal) 
  seer_targets <- call_CRCSPIN(
    parms = parms_vec,
    target_name = "SEER",
    m_total = 5000000,
    target_date = as.Date("1977-01-01", format = "%Y-%m-%d"),
    p_male = 0.5,
    mix_n = 3,
    mix_distn = c(0.47, 0.32, 0.21),
    target_age_distn_name = c("truncated normal", "truncated normal", "truncated normal"),
    target_age_distn_parms_fem = c(0.00, 35.00, 20.00, 39.99, 
                                    52.00, 18.00, 40.00, 59.99, 
                                    58.00, 16.00, 60.00, 99.99),
    target_age_distn_parms_male = c(0.00, 35.00, 20.00, 39.99, 
                                    52.00, 18.00, 40.00, 59.99, 
                                    58.00, 16.00, 60.00, 99.99),
    sens.parms=NULL,
    risk_change_ages = risk_change_ages
  )
  # check that the seer_targets are within current ranges - if not inrange then return results with NAs for remaining 
  #   targets (do not simulate)
  if (
    any(is.na(seer_targets)) || # Any target values are NA
    any(seer_targets < targets$current_lower_bounds[names(seer_targets)]) || # Any our below lower bounds
    any(seer_targets > targets$current_upper_bounds[names(seer_targets)]) # Any our above upper bounds
  ) { 
    return(final_result) 
  }
  final_result[names(seer_targets)] <- seer_targets
  
  #######################################################################################################################
  # Finished all target calculations
  return(final_result)
}
