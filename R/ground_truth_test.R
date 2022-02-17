
library(deSolve)
library(dplyr)
library(tidyr)
library(imabc)
library(tictoc)
library(parallel)
library(doParallel)

# registerDoParallel if needed:
# registerDoParallel(cores = detectCores()-1)

# source user functions:
invisible(sapply(X = paste0(list.files(path =  "./R/user_fns", pattern = "*.R",full.names = T)),FUN = source, echo = F))

# Create ground_truth_data ------------------------------------------------
ground_truth = model(t = 70, parms = c(bet = 1.5, gamm=0.3))

# Creating targets --------------------------------------------------------
targets_df = lapply(ground_truth[,2:4], binom_ci, n = 200, alpha = 0.05, time = ground_truth$time) %>%
  dplyr::bind_rows(., .id = "var") %>%
  #rename(stopping_lower_bounds = lb, stopping_upper_bounds = ub) %>%
  # adding some wiggle room to the stopping bounds because they tend to 0 or 1 at the end:
  mutate(stopping_lower_bounds = lb-0.006, stopping_upper_bounds = ub+0.006) %>%
  # Restrictive initial bounds - useful for testing:
  #mutate(current_lower_bounds = stopping_lower_bounds-0.001, current_upper_bounds = stopping_upper_bounds+0.001) %>%
  # Permissible initial bounds - useful for the real runs:
  mutate(current_lower_bounds = -0.1, current_upper_bounds = 1.1) %>%
  mutate(target_groups = as.character(paste0("t.",i))) %>%
  mutate(target_names = paste0(var,".",target_groups)) %>%
  mutate(across(.cols = where(is.numeric), .fns = ~ signif(x = .x, digits = 3))) %>%
  select(all_of(c("target_names","target_groups","targets","current_lower_bounds","current_upper_bounds","stopping_lower_bounds","stopping_upper_bounds")))

targets_imabc = imabc::as.targets(targets_df)

# Write csv data for imabc:
write.csv(x = as.data.frame(targets_imabc),file = "./data/inputs/targets.csv", row.names = F)

# Create priors -----------------------------------------------------------
priors = define_priors(
  bet = add_prior(
    parameter_name = "bet",
    dist_base_name = "unif",
    min = 1,
    max = 6
  ),
  # x1: Uniform Prior (from base R)
  gamm = add_prior(
    parameter_name = "gamm",
    dist_base_name = "unif",
    min = 0.1,
    max = 1
  )
)
# Write csv data for imabc:
write.csv(x = as.data.frame(priors),file = "./data/inputs/priors.csv", row.names = F)

# test run - given the current targets, all runs will be completed, because initial bounds are permissive.
model(70,parms = c(bet = 1.5, gamm = 0.3),targets = targets_imabc, range_check = T)

# functino to simulate targets:
test_sim_targets = sim_targets(parms = c(bet = 1.51, gamm = 0.29), targets = targets_imabc, range_check = T)

all(test_sim_targets > targets_imabc$current_lower_bounds)
all(test_sim_targets < targets_imabc$current_upper_bounds)
all(test_sim_targets >= targets_imabc$stopping_lower_bounds)
all(test_sim_targets <= targets_imabc$stopping_upper_bounds)

# there's nothing that will throw an error if range bounds are too permissible.
sim_targets(parms = c(bet = 1.51, gamm = 0.3), targets = targets_imabc, range_check = T)

# This seems to work!
sim_targets(parms = c(bet = 1.7, gamm = 0.3), targets = targets_imabc, range_check = F)



# Test imabc --------------------------------------------------------------

# looks like the local test only allows this type of function (or else I need to create a backend function)
fn = function(bet, gamm){
  sim_targets(parms = c(bet = bet, gamm = gamm), targets = targets_imabc, range_check = F)
  }

target_fun <- define_target_function(targets = targets_imabc,priors = priors, FUN = fn, use_seed = FALSE)

tic()
imabc_results_direct = imabc_results <- imabc(
  improve_method = "direct",
  priors = priors,
  targets = targets_imabc,
  target_fun = target_fun,
  seed = 54321,
  N_start = 1000,
  max_iter = 50,
  max_fail_iter = 5,
  N_centers = 3,
  Center_n = 100,
  N_cov_points = 50,
  N_post = 10#,
  #output_directory = "./imabc-results"
)
toc()


tic()
imabc_results_percentile = imabc_results <- imabc(
  improve_method = "percentile",
  priors = priors,
  targets = targets_imabc,
  target_fun = target_fun,
  seed = 54321,
  N_start = 1000,
  max_iter = 50,
  max_fail_iter = 5,
  N_centers = 3,
  Center_n = 100,
  N_cov_points = 50,
  N_post = 10#,
  #output_directory = "./imabc-results"
)
toc()


imabc_results_direct$good_parm_draws$method = "direct"
imabc_results_percentile$good_parm_draws$method = "percentile"

library(ggplot2)

rbind(imabc_results_direct$good_parm_draws, imabc_results_percentile$good_parm_draws) %>%
  ggplot(data = ., mapping = aes(x = bet, y = gamm, color = method)) +
  geom_density2d() +
  geom_vline(xintercept = 1.5) +
  geom_hline(yintercept = 0.3)

