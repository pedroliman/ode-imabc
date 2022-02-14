
# This file defines the inputs included in the scenarios to be run:
# This list is defined here so it can be used outside of the run_model.R file.

# v2.6 calibration scenarios:
scenarios_list = list(
  "1" = list(sens = 1, risk_change_ages = c(20,50,60,70)),
  "2" = list(sens = 1, risk_change_ages = c(15,50,60,70)),
  "3" = list(sens = 1, risk_change_ages = c(10,50,60,70))
)