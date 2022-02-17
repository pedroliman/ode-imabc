#! /usr/bin/env bash

set -eu

if [ "$#" -ne 2 ]; then
  script_name=$(basename $0)
  echo "Usage: ${script_name} exp_id cfg_file"
  exit 1
fi

export TURBINE_LOG=0 TURBINE_DEBUG=0 ADLB_DEBUG=0
# export TURBINE_STDOUT=out-%%r.txt
export TURBINE_STDOUT=
export ADLB_TRACE=0
export EMEWS_PROJECT_ROOT=$( cd $( dirname $0 )/.. ; /bin/pwd )
# source some utility functions used by EMEWS in this script                                                                                 
source "${EMEWS_PROJECT_ROOT}/etc/emews_utils.sh"

export EXPID=$1
export TURBINE_OUTPUT=$EMEWS_PROJECT_ROOT/experiments/$EXPID
check_directory_exists

CFG_FILE=$2
source $CFG_FILE

echo "--------------------------"
echo "WALLTIME:              $CFG_WALLTIME"
echo "PROCS:                 $CFG_PROCS"
echo "PPN:                   $CFG_PPN"
echo "PRIORS:                $CFG_PRIORS"
echo "TARGETS:               $CFG_TARGETS"
echo "ALGO_PARAMS:           $CFG_ALGO_PARAMS_FILE"
echo "SCENARIO:              $CFG_SCENARIO"
echo "--------------------------"

export PROCS=$CFG_PROCS
export QUEUE=$CFG_QUEUE
export WALLTIME=$CFG_WALLTIME
export PPN=$CFG_PPN
export TURBINE_JOBNAME="${EXPID}_job"
export PROJECT=$CFG_PROJECT

# if R cannot be found, then these will need to be
# uncommented and set correctly.
# export R_HOME=/path/to/R
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$R_HOME/lib
# if python packages can't be found, then uncommited and set this
# PYTHONPATH="/lcrc/project/EMEWS/bebop/repos/probabilistic-sensitivity-analysis:"
# PYTHONPATH+="/lcrc/project/EMEWS/bebop/repos/panmodel-0.20.0:"
# PYTHONPATH+="$EMEWS_PROJECT_ROOT/python"
# export PYTHONPATH
# echo "PYTHONPATH: $PYTHONPATH"

export SITE=theta

# Resident task workers and ranks
export TURBINE_RESIDENT_WORK_WORKERS=1
export RESIDENT_WORK_RANKS=$(( PROCS - 2 ))

# EQ/R location
# EQR=/lcrc/project/EMEWS/bebop/repos/spack/opt/spack/linux-centos7-broadwell/gcc-7.1.0/eqr-1.0-5hb4aszbbtezlifks6fz4g24zldnkdbx
EQR=/projects/Swift-T/public/sfw/theta/aprun/EQ-R

#R=/projects/Swift-T/public/sfw/theta/aprun/R-3.6.0/lib64/R                                                                  
R=/projects/Swift-T/public/sfw/theta/compute/gcc-7.3.0/R-3.6.0_2020-07-23/lib64/R
# Maybe add this too for GPareto - /theta-archive/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64        
LLP=$R/lib:/opt/gcc/8.3.0/snos/lib64:/opt/cray/pe/atp/2.1.3/libApp


# set machine to your schedule type (e.g. pbs, slurm, cobalt etc.),
# or empty for an immediate non-queued unscheduled run
MACHINE="theta"

if [ -n "$MACHINE" ]; then
  MACHINE="-m $MACHINE"
fi


mkdir -p $TURBINE_OUTPUT/tmp
mkdir -p $TURBINE_OUTPUT/results

cp $CFG_FILE $TURBINE_OUTPUT/cfg.cfg

SRC_TARGETS_FILE=$EMEWS_PROJECT_ROOT/$CFG_TARGETS
DST_TARGETS_FILE=$TURBINE_OUTPUT/targets.csv
cp $SRC_TARGETS_FILE $DST_TARGETS_FILE

PRIORS_FILE_SOURCE=$EMEWS_PROJECT_ROOT/$CFG_PRIORS
PRIORS_FILE=$TURBINE_OUTPUT/priors.csv
cp $PRIORS_FILE_SOURCE $PRIORS_FILE

ALGO_R_FILE=$EMEWS_PROJECT_ROOT/R/imabc.R
AR_FILE=$TURBINE_OUTPUT/algo.R
cp $ALGO_R_FILE $AR_FILE

ALGO_PARAMS_FILE=$EMEWS_PROJECT_ROOT/data/algo_params/$CFG_ALGO_PARAMS_FILE
AP_FILE=$TURBINE_OUTPUT/algo.params.R
# cp $ALGO_PARAMS_FILE $AP_FILE
source "${EMEWS_PROJECT_ROOT}/etc/algo_params_utils.sh"
resolve_algo_params $ALGO_PARAMS_FILE $AP_FILE

CFG_EXTRA_FILES_TO_INCLUDE=${CFG_EXTRA_FILES_TO_INCLUDE:-}
for f in ${CFG_EXTRA_FILES_TO_INCLUDE[@]}; do
  tf="$(basename -- $f)"
  cp $EMEWS_PROJECT_ROOT/$f $TURBINE_OUTPUT/$tf
done

CMD_LINE_ARGS="$* -algo_file=$AR_FILE -algo_params_file=$AP_FILE -scenario=$CFG_SCENARIO"


# Add any script variables that you want to log as
# part of the experiment meta data to the USER_VARS array,
# for example, USER_VARS=("VAR_1" "VAR_2")
USER_VARS=("MODEL_DIR" "STOP_AT" "MODEL_PROPS" \
 "STOP_AT")
# log variables and script to to TURBINE_OUTPUT directory

# export TURBINE_LAUNCH_OPTIONS="-d 8 -j 1 -cc depth"


log_script

# echo's anything following this standard out
# set -x

swift-t -n $PROCS $MACHINE -p \
    -r $EQR -I $EQR \
    -e EMEWS_PROJECT_ROOT \
    -e SITE \
    -e TURBINE_OUTPUT \
    -e TURBINE_LOG \
    -e TURBINE_DEBUG \
    -e ADLB_DEBUG \
    -e TURBINE_RESIDENT_WORK_WORKERS \
    -e RESIDENT_WORK_RANKS \
    -e LD_LIBRARY_PATH=$LLP:$LD_LIBRARY_PATH \
    $EMEWS_PROJECT_ROOT/swift/imabc_workflow.swift $CMD_LINE_ARGS

chmod g+rw $TURBINE_OUTPUT/*.tic
