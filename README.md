
# CRCSPIN Calibration

Internal dependencies badges:
<!-- badges: start -->

* imabc [![imabc build](https://github.com/carolyner/imabc/workflows/R-CMD-check/badge.svg)](https://github.com/carolyner/imabc/actions)
* crcscreen [![crcscreen build](https://github.com/c-rutter/crcscreen/workflows/R-CMD-check/badge.svg)](https://github.com/c-rutter/crcscreen/actions)
* crcspin [![crcspin build](https://github.com/c-rutter/crcspin/workflows/R-CMD-check/badge.svg)](https://github.com/c-rutter/crcspin/actions)
* crcrdm [![crcrdm build](https://github.com/c-rutter/crcrdm/workflows/R-CMD-check/badge.svg)](https://github.com/c-rutter/crcrdm/actions)

<!-- badges: end -->

This repository contains code to calibrate the CRCSPIN model. This repository does not contain the crcspin model itself, which is stored within the CRCSPIN repository. This documentation file includes technical notes about the calibration process and the code to calibrate the model.

## Test Scripts

Use the file `R/calibrate_crcspin.R` to perform small-scale calibration and test runs. When performing those runs, edit the scripts within the `./R` folder using R studio. Place any data files within the `./data` folder and refrain from adding unnecessary dependencies to the project.

## Dependencies

Install `crcspin`, `crcscreen`, `crcrdm` and `imabc` from github. At the end of the project, use specific github versions to ensure reproducibility:

```r
# Set your own authentication token manually:
# my_auth_token = "ABC"
# https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token
remotes::install_github(repo = "c-rutter/crcrdm", auth_token = my_auth_token, lib = .libPaths()[2])
remotes::install_github(repo = "https://github.com/c-rutter/crcspin/tree/young_onset", auth_token = my_auth_token,  lib = .libPaths()[2])
remotes::install_github("https://github.com/carolyner/imabc/tree/interim_good_outputs", lib = .libPaths()[2])
remotes::install_github(repo = "c-rutter/crcscreen", auth_token = my_auth_token,  lib = .libPaths()[2])
 
```

# HPC Scripts

This repository uses EMEWS's EQ/R to perform calibration on Argonne's High-Performance Computing resources. The code in this repository was adapted from code supplied by Jonathan Ozik and Nick Collier. Before using this code, make sure to read and understand EMEWS's documentation. I've added notes to this read-me file to support our use of their code, but be aware that the following instructions assume familiarity with EMEWS.

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

`swift/imabc_workflow.swift` > `scripts/crcspin.sh` > `run_model.R` > `sim_targets.R` > `crcspin`.

Notes about some of these files:

The most important file the user should care about is the `run_model.R` file and how it passes parameters to the `sim_targets.R` function. Note that the run_model.R must save a standardized json file including the results for the targets in a specific location. These results are read by the `imabc_workflow.swift` 

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

The file `./data/algo_params` contains the run parameters for imabc. They need to be changed at every run.

The file `./data/cfgs/bebop.cfg` contains configurations for bebop. They contain paths to IMABC targets and priors as well as the number of nodes and processes to use.

## Running the Calibration at Argonne on the Bebop cluster

### Setting up the Environment

```bash
# ssh into bebop (the cluster where we run these experiments)
ssh bebop
# Navigate to the project folder:
cd /lcrc/project/EMEWS/plima/crcspin-imabc/
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

Memory available in each node must be >= memory used by each model run * PPN (processes per node). Set the PPN value in the `./data/cfgs/bebop.cfg` file accordingly before running. 

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

We did not try to run this calibration workflow outside Argonne for several reasons: i)  we don't have the computing power to do so outside Argonne, and ii) even if we did, one needs to install EMEWS and Swift/T, which has proven to be a time-consuming endeavor. Nonetheless, in principle, one should be able to do so on other computing systems.

# Calibration Experiments:

## v2.4_test

This calibration exercise consisted of testing the.
initial tests worked, but the continuation runs didn't work.

## v2.4_5.1 : Early Onset and Smooth Sensitivity Function

This calibration allows adenomas to start at age 10 and uses the new sensitivity function. The baseline calibration uses the high sensitivity scenario, but we may also calibrate the sensitivity.

Priors: crcspin_priors_neargood.csv: Adjusted mean of ar.20to49 and minimum to 0.75 of previous value:  
Near good:
mean: 0.044240959 * 0.75 = 0.03318072
min: 0.01 * 0.75 = 0.0075

Original - Interesting that the original is wider than the near good.
mean: 0.04 * 0.75 = 0.03
min: 0.02 * 0.75 = 0.015

I've made no changes to the target.
Targets: targets_renamed.csv

This version uses this version of crcspin:
```r
remotes::install_github("https://github.com/c-rutter/crcspin/tree/young_onset", auth_token = my_auth_token,  lib = .libPaths()[2])
```
running it:

```bash
source envs/bebop_env.sh
bash swift/bebop_run_imabc.sh v2.4_5.1_01 data/cfgs/bebop.cfg
```

### Attempt 1: 2021/12/16 21:33 run:**

N_start = 1000

```bash
[plima@beboplogin3 crcspin-imabc]$ bash swift/bebop_run_imabc.sh v2.4_5.1 data/cfgs/bebop.cfg
--------------------------
WALLTIME:              01:00:00
PROCS:                 280
PPN:                   35
PRIORS:                data/inputs/crcspin_priors_neargood.csv
TARGETS:               data/inputs/targets_renamed.csv
ALGO_PARAMS:           imabc_params.R
--------------------------
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable c might be read and not written, possibly leading to deadlock
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable c might be read and not written, possibly leading to deadlock
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable ME_rank is not used
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable v might be read and not written, possibly leading to deadlock
TURBINE-SLURM SCRIPT
NODES=8
PROCS=280
PPN=35
TURBINE_OUTPUT=/lcrc/project/EMEWS/plima/crcspin-imabc/experiments/v2.4_5.1
TURBINE_HOME=/lcrc/project/EMEWS/bebop/sfw/swift-t-7771807/turbine
wrote: /lcrc/project/EMEWS/plima/crcspin-imabc/experiments/v2.4_5.1/turbine-slurm.sh
JOB_ID=2304210

```
Job cancelled -> No valid parameters to work from.

```bash

[plima@beboplogin3 crcspin-imabc]$ seff 2304210
Job ID: 2304210
Cluster: bebop
User/Group: plima/cels
State: COMPLETED (exit code 0)
Nodes: 8
Cores per node: 36
CPU Utilized: 06:41:36
CPU Efficiency: 55.04% of 12:09:36 core-walltime
Job Wall-clock time: 00:02:32
Memory Utilized: 258.08 GB (estimated maximum)
Memory Efficiency: 17.47% of 1.44 TB (184.64 GB/node)

```

### Attempt 2: I realized I didn't change the begin_adenoma_risk_age to 10.

trying near_good again:

```bash
[plima@beboplogin3 crcspin-imabc]$ bash swift/bebop_run_imabc.sh v2.4_5.1 data/cfgs/bebop.cfg
Experiment directory exists. Continue? (Y/n) Y
--------------------------
WALLTIME:              01:00:00
PROCS:                 280
PPN:                   35
PRIORS:                data/inputs/crcspin_priors_neargood.csv
TARGETS:               data/inputs/targets_renamed.csv
ALGO_PARAMS:           imabc_params.R
--------------------------
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable c might be read and not written, possibly leading to deadlock
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable c might be read and not written, possibly leading to deadlock
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable ME_rank is not used
WARN  /lcrc/project/EMEWS/plima/crcspin-imabc/swift/imabc_workflow.swift:87:10: Variable usage warning. Variable v might be read and not written, possibly leading to deadlock
TURBINE-SLURM SCRIPT
NODES=8
PROCS=280
PPN=35
TURBINE_OUTPUT=/lcrc/project/EMEWS/plima/crcspin-imabc/experiments/v2.4_5.1
TURBINE_HOME=/lcrc/project/EMEWS/bebop/sfw/swift-t-7771807/turbine
wrote: /lcrc/project/EMEWS/plima/crcspin-imabc/experiments/v2.4_5.1/turbine-slurm.sh
JOB_ID=2304211
```

### Attempt 3: Starting from near good still didn't work, now trying from original posterior with larger N_start.

Now running this on bdwall, launching 10 nodes, 25 K runs.

JOB_ID=2304212

```bash
[plima@beboplogin4 crcspin-imabc]$ seff 2304212
Job ID: 2304212
Cluster: bebop
User/Group: plima/cels
State: COMPLETED (exit code 0)
Nodes: 10
Cores per node: 36
CPU Utilized: 1-12:11:52
CPU Efficiency: 18.60% of 8-02:36:00 core-walltime
Job Wall-clock time: 00:32:26
Memory Utilized: 987.80 GB (estimated maximum)
Memory Efficiency: 80.44% of 1.20 TB (122.80 GB/node)
[plima@beboplogin4 crcspin-imabc]$ 
```


### v2.4_5.1_F Continuation runs test:
- Try to make a continuation run work so I can show Jonathan and Nick any issues with continuation. We tried several runs, and the v

JOB_ID=2304661

```bash
[plima@beboplogin3 crcspin-imabc]$ seff 2304661
Job ID: 2304661
Cluster: bebop
User/Group: plima/cels
State: COMPLETED (exit code 0)
Nodes: 8
Cores per node: 36
CPU Utilized: 20-19:16:45
CPU Efficiency: 96.13% of 21-15:21:36 core-walltime
Job Wall-clock time: 01:48:12
Memory Utilized: 1.19 TB (estimated maximum)
Memory Efficiency: 82.30% of 1.44 TB (184.64 GB/node)
```


2305843
