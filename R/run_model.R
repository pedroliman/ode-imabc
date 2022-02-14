# Code to run model from bash: Should accept the following arguments:
# "$WORKING_DIR"
# "$PARAMS"
# "$JSON_LB"
# "$JSON_UB"
# "$RESULT_FILE"

# libraries
library(crcspin)
print("run_model.R: which crcspin")
print(system.file(package = "crcspin"))
#library(crcscreen)
library(tidyr)
#library(doParallel)
library(lubridate)
#library(pryr)
#library(MASS) # MASS needs to be loaded for dplyr or else select breaks - not true so far.
library(data.table)
library(jsonlite)
library(dplyr)
print("run_model.R: which R")
print(R.home())

print("run_model.R: session info")
sessionInfo()

# Taking job arguments -----------------------------------------------------
args = commandArgs(trailingOnly=TRUE)

# Load arguments from command line: 
scenario = args[1]
working_dir = args[2]
params = args[3] %>% fromJSON()
json_lb = args[4] %>% fromJSON()
json_ub = args[5] %>% fromJSON()
results_file = args[6]

# load in additional functions within the user_fns folder:
emews_root <- Sys.getenv("EMEWS_PROJECT_ROOT")
if (emews_root == "") {
  r_root <- getwd()
} else {
  r_root <- paste0(emews_root, "/R")
}

functions_path = paste0(r_root, "/user_fns/")
file.exists(functions_path)

# source necessary functions:
invisible(sapply(X = paste0(list.files(path =  functions_path, pattern = "*.R",full.names = T)),FUN = source, echo = F)) 

# Source file defining the scenarios:

# Setting the Model Seed ---------------------------------------------

# If desired, one can set the same seed for all runs:
# Set the seed here. note that this code is ran for each parameter set.
# set.seed(123456)

string_seed = params$seed

# convert seed from a string to a vector of integers:
integer_seed = string_seed %>%
    strsplit(., split = "_") %>%
    unlist(.) %>%
    as.integer(.)

# Setting the seed:
# The assignment below is suggested by Chris:
assign(".Random.seed", integer_seed, envir = .GlobalEnv, inherits = F)
# This also should work:
# .Random.seed <- integer_seed

# adjust parameter vector -> get rid of the seed and convert to numeric.
# We may want to use this seed later.
# Remove seed from the vector of parameters:
params$seed = NULL
params = params %>% unlist() %>% as.numeric()
names(params) = read.csv(paste0(working_dir, "/priors.csv"), header = TRUE, stringsAsFactors = FALSE)[,1]

# create imabc target object, replace current bounds with information from imabc.
# TODO: Check with carolyn and Jonathan that this is the intended use.
crcspin_targets = read.csv(paste0(working_dir, "/targets.csv"), header = TRUE, stringsAsFactors = FALSE) %>%
  # Incorporate the group target name in to the simple target name. This resolves issue with Church and Lieberman targets, 
  #   which otherwise have the same names
  mutate(current_lower_bounds = as.numeric(json_lb)) %>%
  mutate(current_upper_bounds = as.numeric(json_ub)) %>%
  imabc::as.targets(.data)

# simulate targets:
print("Simulating Targets")
print(Sys.time())
dput(params)

# Define Scenario inputs:
# Scenarios are meant to be a list of few hyper-parameters to the calibration exercise.
# We can "add" scenarios to the calibration exercise.
# Scenarios must be coded as integers.

scenarios_file = paste0(r_root, "/scenarios.R")
source(scenarios_file)
scenario_inputs = scenarios_list[[scenario]]

print(scenario_inputs)

# test to see how many runs are unnecessary:
#if(!range_check(params, risk_change_ages = scenario_inputs$risk_change_ages)){
#  range_check_file = paste0(results_file, "_range_check_false")
#  file.create(range_check_file)
#}
# After running it, use this linux command to count how many files don't pass range_check:

# this assumes that the parameters vector can be a named list.
targets_results = sim_targets(parms_vec = params, 
                              targets = crcspin_targets, 
                              high_sens_weight = scenario_inputs$sens, 
                              risk_change_ages = scenario_inputs$risk_change_ages)

# save target results to the results file:

# Let's assume params is a vector of numbers.

# save the simulated targets as a json file:
jsonlite::write_json(x = targets_results, path = results_file)

# Here, return path to the output folder:
# normalizePath(paste0(getwd(),"/out"))