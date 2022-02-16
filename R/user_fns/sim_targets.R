
# function to simulate:
sim_targets = function(parms, targets, range_check) {

  # This will have to change for our model:
  targets_vector = rep(NA, length(targets$targets))
  names(targets_vector) = names(targets$targets)

  targets_outputs = tryCatch(
    expr = {
      model_results = model(70,parms = parms,targets = targets, range_check = range_check)

      # I think this part will only be executed if the model doesn't throw an error:
      targets_long = model_results %>%
        dplyr::mutate(i = row_number()) %>%
        pivot_longer(data = ., cols = S:R, names_to = "targets", values_to = "values") %>%
        mutate(target_name = paste0(targets,".t.", i))

      # check that the number of targets is correct
      stopifnot(nrow(targets_long) == length(targets$targets))

      targets_res_vector = targets_long$values
      names(targets_res_vector) = targets_long$target_name

      # Arranging the targets exactly like they were passed by IMABC:
      targets_res_vector = targets_res_vector[names(targets_vector)]

      # stop if there's a mismatch between the names of targets and the names of the vectors:
      stopifnot(all(names(targets_res_vector) == names(targets_vector)))

      return(targets_res_vector)

    },
    error = function(cond) {
      if(cond$message == "all(checks) is not TRUE"){
        # in this case, our range_checks got an unreasonable result, so we should return our targets:
        message("model did not pass range check")
        return(targets_vector)
      } else {
        message(cond$message)
        stop("model eval function returned an error")
      }
    })

  return(targets_outputs)
}
