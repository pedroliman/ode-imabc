
# EMEWS/IMABC Workflow for deSolve models

This repository contains a calibration workflow for ODE models using IMABC and EMEWS. This is a testing ground and a starting point for other dynamic models that need to be calibrated with IMABC.

I use this repository as a starting point when I need to calibrate an ODE model with IMABC.

## Test Scripts

Use the file `R/ground_truth_tests.R` to perform small-scale calibration and test runs. When performing those runs, edit the scripts within the `./R` folder using R studio. Place any data files within the `./data` folder and refrain from adding unnecessary dependencies to the project.

## R Dependencies (required for small-scale tests)

Run the `R/install_dependencies.R` file. By doing so, you should be able to use the `ground_truth_test.R` test.

## System Dependencies (required for large-scale runs with EMEWS)

This project relies on `swift-t/1.5.0` (with python and R enabled), and the `EQR` swift-t extension. I do not avise you to try and install this on your machine - you should install those dependencies on your academic cluster or cloud. Installing those dependencies is a non-negligible endeavor, and you should contact your system administrator. 

# HPC Scripts

This repository uses EMEWS's EQ/R to perform calibration. The code in this repository was adapted from code generously supplied by Jonathan Ozik and Nick Collier. Before using this code, it is often helpful to read and understand EMEWS's documentation. I've added notes to this read-me file to support my use of their code, but be aware that the following instructions assume familiarity with EMEWS. 

### What is `bebop`?
`bebop` is the name of Argonne's cluster where I run most of those experiments. Before using this code, you should replace `bebop` with whatever 

## Calibration Scripts Overview

The calibration code relies on a set of bash, python, Swift/T and R scripts. The main code we use and change is within the R folder. The call stack among those scripts is described below.

**Model Exploration algorithm layer**

The model exploration layer is responsible for initiating the imabc algorithm and for passing parameters to the model evaluation layer.

At this layer, we initialize the model exploration script with the `bebop_run_imabc.sh` script. This script in turn invokes the `imabc_workflow.swift` script, which calls an `algo_file` file using the `EQR_init_script(ME, algo_file)` function. Note that the model exploration algorithm file is set at the `bebop_run_imabc.sh` file. Therefore the call stack is:

`swift/bebop_run_imabc.sh` > `swift/imabc_workflow.swift` (start function) > `imabc.R`

The backend function (the `b_fun` function) contains an `OUT_put()` and `IN_get()` calls that interact with the swift workflow script. note that the `payload_type` string used within the imabc_workflow script comes from the `imabc.R` script. Note that this backend function is passed to imabc, which is how the model exploration code (imabc) and the model evaluation code are integrated.

**Model Evaluation layer**

At the model evaluation layer, the `b_fun` in R pushes a string including the model parameters, json lower bounds and json upper bounds to the queue with `OUT_put(paste0(json_params, "|", json_lower_bounds, "|", json_upper_bounds))` and the workflow at that point parses those parameters, including the lower bounds and upper bounds and calls the `obj` swift function using those parameters within a for loop. After running the model over this set of parameters, the results are sent back to the algorithm with the `EQR_put` call, which continues the imabc algorithm.

Note that parameters are passed to the model evaluation function as strings (serialized in a JSON object) and the model evaluation function **saves** results within each result function also as a json object.

 The call stack is:

`swift/imabc_workflow.swift` > `scripts/model.sh` > `run_model.R` > `sim_targets.R` > `model function`.

Notes about some of these files:

The most important file the user should care about is the `run_model.R` file and how it passes parameters to the `sim_targets.R` function. Note that `run_model.R` must save a standardized json file including the results for the targets in a specific location. These results are read by the `imabc_workflow.swift` 

`swift/bebop_run_imabc.sh`:
Inputs:
- exp_id: the path in which to save the calibration run results;
- cfg_file: the configuration file to use.

`swift/imabc_workflow.swift` :
This file is responsible for running the imabc algorithm. This could be adapted to any other iterative algorithm where we want to perform a set of runs in parallel, gather results, then run another batch of runs in parallel. This file contains a set of functions and it ends with a main "program: that calls the start function'.
- run: runs the model script function bash script for a set of parameters, json upper and lower bounds. Note that all model inputs are transformed to strings and passed to the bash script as strings.
- rm: removes a file.
- obj: calls the run function to run the model. returns a string pointing to the model results.
- loop: gets the "payload", iterates over paramters calling the obj function.
- start: calls the loop function;
- rm_dir: removes a specific directory.
- main: calls the start function;

## Configuration files:

The file `./data/algo_params` contains the run parameters for imabc. They may need to be changed at every run.

The file `./data/cfgs/bebop.cfg` contains configurations for bebop. They contain paths to IMABC targets and priors as well as the number of nodes and processes to use.

## Running the Calibration workflow

### Setting up the Environment

```bash
# ssh into bebop (the cluster where we run these experiments)
ssh bebop
# Navigate to the project folder:
cd /my_project
# Set up the environment
# The bebop_env file might have to change depending on the environment.
source envs/bebop_env.sh
# After running it you may have to run R and install the R packages used by this project. This is a one-time step one needs to do before running any analysis.
# Also, make sure Rscript and R are recognized as commands:
which R
which Rscript
```

### Memory Considerations

Before running the calibration experiment, you should think about the maximum ammount of memory that each calibration run will use, otherwise R will run out of memory. 

Memory available in each node must be ~ >= memory used by each model run * PPN (processes per node). Set the PPN value in the `./data/cfgs/bebop.cfg` file accordingly before running. 

Often, it is reasonable to use a larger number of nodes in the initial run, then reduce this number of nodes in the follow-up runs; otherwise you will have many nodes staying idle towards the end of each iteration.

### Running the calibration experiment

Change the first parameter of this function every time you initiate a new run.

```bash
# From the project repository, run:
# exp_id: An folder name for your experiment. Ex: cal_2.2
# cfg_file: The path to the configuration file: 
swift/bebop_run_imabc.sh v2.4_5.1 data/cfgs/bebop.cfg
# Run this if you can't run the script without writing bash before its name:
# chmod u+x swift/bebop_run_imabc.sh
# it is always a good idea to check

```

After running this, Swift-T will submit your job, and you can `squeue -u my_username" to check your job. You should also see a new folder under the experiments folder with the same name as the first parameter of your function call.
