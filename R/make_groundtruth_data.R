
library(deSolve)
library(dplyr)
library(tidyr)
library(imabc)

# source user functions:
invisible(sapply(X = paste0(list.files(path =  "./R/user_fns", pattern = "*.R",full.names = T)),FUN = source, echo = F))

# Create ground_truth_data ------------------------------------------------
ground_truth = model(t = 70, parms = c(bet = 1.5, gamm=0.3))

# Creating targets --------------------------------------------------------
targets_df = lapply(ground_truth[,2:4], binom_ci, n = 200, alpha = 0.01, time = ground_truth$time) %>%
  dplyr::bind_rows(., .id = "var") %>%
  rename(stopping_lower_bounds = lb, stopping_upper_bounds = ub) %>%
  # Restrictive initial bounds - useful for testing:
  mutate(current_lower_bounds = stopping_lower_bounds-0.001, current_upper_bounds = stopping_upper_bounds+0.001) %>%
  # Permissible initial bounds - useful for the real runs:
  #mutate(current_lower_bounds = -0.1, current_upper_bounds = 1.1) %>%
  mutate(target_group = as.character(paste0("t.",i))) %>%
  mutate(target_names = paste0(var,".",target_group)) %>%
  mutate(across(.cols = where(is.numeric), .fns = ~ signif(x = .x, digits = 3))) %>%
  select(all_of(c("target_names","target_group","targets","current_lower_bounds","current_upper_bounds","stopping_lower_bounds","stopping_upper_bounds")))

targets_imabc = imabc::as.targets(targets_df)

# Write csv data for imabc:
write.csv(x = as.data.frame(targets_imabc),file = "./data/inputs/targets.csv", row.names = F)

# Create priors -----------------------------------------------------------
priors = define_priors(
  bet = add_prior(
    #parameter_name = "bet",
    dist_base_name = "unif",
    min = 1,
    max = 2
  ),
  # x1: Uniform Prior (from base R)
  gamm = add_prior(
    #parameter_name = "gamm",
    dist_base_name = "unif",
    min = 0.1,
    max = 0.6
  )
)
# Write csv data for imabc:
write.csv(x = as.data.frame(priors),file = "./data/inputs/priors.csv", row.names = F)

# test run - given the current targets, all runs will be completed, because initial bounds are permissive.
model(70,parms = c(bet = 1.5, gamm = 0.3),targets = targets_imabc, range_check = T)

# functino to simulate targets:
sim_targets(parms = c(bet = 1.5, gamm = 0.3), targets = targets_imabc, range_check = T)

# there's nothing that will throw an error if range bounds are too permissible.
sim_targets(parms = c(bet = 1.51, gamm = 0.3), targets = targets_imabc, range_check = T)

# This seems to work!
sim_targets(parms = c(bet = 1.7, gamm = 0.3), targets = targets_imabc, range_check = F)
