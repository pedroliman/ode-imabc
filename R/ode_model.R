
library(deSolve)
library(tictoc)
library(dplyr)

# SIR model is defined as a function:
SIR.model <- function(t, parms = c(bet = 1.5, gamm = 0.3), targets = NA, range_check = F){

  init <- c(S=1-1e-6,I=1e-6,R=0)
  time <- seq(0,t,by=t/(2*length(1:t)))

  eqn <- function(time,state,parms, targets, range_check){
    with(as.list(c(state,parms, list(targets = targets), range_check)),{

      # max time_step at which to do range_chekcing
      max_time_step = 0.1

      # Just do range checking when we're close enough to the integer - avoid integration problems.
      if(range_check & time > 1 & time %% 1 < max_time_step){
        #implement range checking here:
        i = findInterval(x = time, lb$time)

        # This may be generalized.
        # The 0.999 and the 1.001 add a little of wiggle room for a 0.1% error.
        S_pass = (S*1.01 >= get_target(targets, i, "S")["lb"] & S * 0.99 <= get_target(targets, i, "S")["ub"])
        I_pass = (I*1.01 >= get_target(targets, i, "I")["lb"] & I * 0.99 <= get_target(targets, i, "I")["ub"])
        R_pass = (R*1.01 >= get_target(targets, i, "R")["lb"] & R * 0.99 <= get_target(targets, i, "R")["ub"])

        checks = c(S_pass, I_pass, R_pass)
        stopifnot(all(checks))

        #if(!all(checks)){
        #  browser()
        # }
      }
      # Model code:
      dS <- -bet*S*I
      dI <- bet*S*I-gamm*I
      dR <- gamm*I
      derivatives = c(dS,dI,dR)
      return(list(derivatives))})}

  out<-ode(y=init,times=time,eqn,parms=parms, targets = targets, range_check = range_check)
  as.data.frame(out)

}

# Creating targets, lower bounds and upper bounds:
ground_truth = SIR.model(t = 70, parms = c(bet = 1.5, gamm=0.3))

binom_ci = function(p, alpha = 0.05, n, time) {
  z = (1-alpha/2)
  margin_of_error = qnorm(z) * sqrt((1/n)*p*(1-p))
  data.frame(lb = p - margin_of_error, targets = p, ub = p + margin_of_error) %>%
    dplyr::mutate(i = dplyr::row_number(),
                  time = time)
}

# Let's generate Conf intervals
targets = lapply(ground_truth[,2:4], binom_ci, n = 200, alpha = 0.1, time = ground_truth$time) %>%
  dplyr::bind_rows(., .id = "var")

get_target = function(targets, i, var){
  targets[targets$i == i & targets$var == var, c("lb", "ub")]
}

# test run:
tic()
SIR.model(70,parms = c(bet = 1.5, gamm = 0.3),targets = targets, range_check = T)
toc()

sim_targets = function(parms, targets, range_check) {

  # This will have to change for our model:
  targets_vector = rep(NA, nrow(targets))
  names(targets_vector) = paste0(targets$var, targets$i)

  targets_outputs = tryCatch(
    expr = {
      model_results = SIR.model(70,parms = parms,targets = targets, range_check = range_check)

      # I think this part will only be executed if the model doesn't throw an error:
      targets_long = model_results %>%
        dplyr::mutate(i = row_number()) %>%
        pivot_longer(data = ., cols = S:R, names_to = "targets", values_to = "values") %>%
        mutate(target_name = paste0(targets, i)) %>%
        arrange(target_name)

      targets_vector = targets_long$values
      names(targets_vector) = targets_long$target_name

      targets_vector

    },
    error = function(cond) {
      if(cond$message == "all(checks) is not TRUE"){
        # in this case, our range_checks got an unreasonable result, so we should return our targets:
        return(targets_vector)
      } else {
        message(cond$message)
        stop("model eval function returned an error")
      }
    })

  return(targets_outputs)
}


tic()
sim_targets(parms = c(bet = 1.5, gamm = 0.3), targets = targets, range_check = T)
toc()


tic()
sim_targets(parms = c(bet = 3, gamm = 0.3), targets = targets, range_check = T)
toc()


