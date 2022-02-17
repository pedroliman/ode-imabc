
# Use this file to set imabc parameters.
algo.params <- list(
    extras = list(priors.path = ""),
    imabc.args = list(
        target_fun = NULL,
        ${PREV_RESULTS_DIR},
        # N_start = 37000,
        N_start = 10, # 25000
        seed = 12345,
        latinHypercube = TRUE,
        N_centers = 10,
        Center_n = 100, # 1000
        N_post = 100, # 1000
        max_iter = 10, # 5
        N_cov_points = 250,
        sample_inflate = 2,
        verbose = TRUE,
        output_tag = "timestamp",
        improve_method = "percentile" # originally, it was gtbr. or sample_reduce
    )
)
