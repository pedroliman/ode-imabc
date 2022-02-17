# Code to run model from the terminal: Should accept the following arguments:
# "$WORKING_DIR" - working directory
# "$PARAMS" - named vector of parameters in json
# "$JSON_LB" - named lower bounds in json
# "$JSON_UB" - named upper bounds in json
# "$RESULT_FILE" - path where we should save the results file in json

# libraries
library(tidyr)
library(dplyr)
library(jsonlite)
library(deSolve)
print("run_model.R: which deSolve")
print(system.file(package = "deSolve"))
print(packageVersion("deSolve"))
library(imabc)
print("run_model.R: which imabc")
print(system.file(package = "imabc"))
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
params$seed = NULL
params = params %>% unlist() %>% as.numeric()
names(params) = read.csv(paste0(working_dir, "/priors.csv"), header = TRUE, stringsAsFactors = FALSE)[,1]

# create imabc target object, replace current bounds with information from imabc.
targets = read.csv(paste0(working_dir, "/targets.csv"), header = TRUE, stringsAsFactors = FALSE) %>%
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
# Scenarios numbers must be coded as integers.
scenarios_file = paste0(r_root, "/scenarios.R")
source(scenarios_file)
scenario_inputs = scenarios_list[[scenario]]

print(scenario_inputs)

# test to see how many runs are unnecessary with range checking
#if(!range_check(params, risk_change_ages = scenario_inputs$risk_change_ages)){
#  range_check_file = paste0(results_file, "_range_check_false")
#  file.create(range_check_file)
#}
# After running it, use this linux command to count how many files don't pass range_check:

# this assumes that the parameters vector can be a named list.
targets_results = sim_targets(parms = params, 
                              targets = targets, 
                              range_check = scenario_inputs$range_check)

# save the simulated targets as a json file:
jsonlite::write_json(x = targets_results, path = results_file)

# Here, return path to the output folder:
# normalizePath(paste0(getwd(),"/out"))