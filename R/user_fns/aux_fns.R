
# Creates a binomial confidence interval
binom_ci = function(p, alpha = 0.05, n, time) {
  z = (1-alpha/2)
  margin_of_error = qnorm(z) * sqrt((1/n)*p*(1-p))
  data.frame(lb = p - margin_of_error, targets = p, ub = p + margin_of_error) %>%
    dplyr::mutate(i = dplyr::row_number(),
                  time = time)
}

# select targets.
get_target = function(targets, i, var){
  # this is the name convention we are following:
  t_name = paste0(var, ".t.",i)
  # return lower and upper bound for that particular target:
  c(lb = targets$current_lower_bounds[[t_name]],
    ub = targets$current_upper_bounds[[t_name]])
}
