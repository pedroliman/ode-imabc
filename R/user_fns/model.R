

model <- function(t, parms = c(bet = 1.5, gamm = 0.3), targets = NULL, range_check = F){

  init <- c(S=1-1e-6,I=1e-6,R=0)
  time <- seq(0,t,by=t/(2*length(1:t)))

  # create a data.frame with target names for reference:
  # here we assume that there's a target for every time-step defined in time.
  if(!is.null(targets)) {
    target_names_df = do.call(rbind, strsplit(x = names(targets$targets), split = ".t.")) %>% as.data.frame(.)
    colnames(target_names_df) = c("var", "i")
    target_names_df$target_name = names(targets$targets)
    target_names_df$time = rep(x = time, times = length(unique(target_names_df$var)))
  } else {
    target_names_df = NULL
  }


  eqn <- function(time,state,parms, targets, target_names_df, range_check){
    with(as.list(c(state,parms, list(targets = targets, target_names_df = target_names_df), range_check)),{

      # max time_step at which to do range_chekcing
      max_time_step = 0.05

      # range checking:
      # Just do range checking when we're close enough to the integer - avoid integration problems.
      if(range_check & time > 1 & time %% 1 <= max_time_step){

        #implement range checking here:
        i = findInterval(x = time, unique(target_names_df$time))

        # This may be generalized.
        # Here is w
        # The 0.999 and the 1.001 add a little of wiggle room for a 0.1% error.
        S_pass = (S*1.01 >= get_target(targets, i, "S")["lb"] & S * 0.99 <= get_target(targets, i, "S")["ub"])
        I_pass = (I*1.01 >= get_target(targets, i, "I")["lb"] & I * 0.99 <= get_target(targets, i, "I")["ub"])
        R_pass = (R*1.01 >= get_target(targets, i, "R")["lb"] & R * 0.99 <= get_target(targets, i, "R")["ub"])

        # vector of all checks:
        checks = c(S_pass, I_pass, R_pass)

        # if targets are not within bounds, stop simulation because this run is useless beyond this point.
        stopifnot(all(checks))

        # use for debugging:
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

  out<-ode(y=init,times=time,eqn,parms=parms, targets = targets, target_names_df = target_names_df, range_check = range_check)
  as.data.frame(out)

}
