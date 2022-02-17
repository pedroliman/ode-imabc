# load R
#module load r/4.0.3
# trying to export this path here as well.
# Testing access to personal library:

PERSONAL_R_LIBRARY=/home/prgs/pedro_lima_midasnetwork_us/R/x86_64-pc-linux-gnu-library/4.0

echo "scripts/midas_env.sh"

echo "PERSONAL_R_LIBRARY: $PERSONAL_R_LIBRARY"

if [ -w $PERSONAL_R_LIBRARY ] ; then echo 'Can Write library' ; fi
if [ -r $PERSONAL_R_LIBRARY ] ; then echo 'Can Read library' ; fi
if [ -x $PERSONAL_R_LIBRARY ] ; then echo 'Can Execute library' ; fi

ls -l /apps/install/r/4.0.3/gcc-9.1.0_openmpi-3.1.6/lib64/R/library/

ls -l /home/prgs/pedro_lima_midasnetwork_us/R/x86_64-pc-linux-gnu-library/4.0

export R_LIBS=/apps/install/r/4.0.3/gcc-9.1.0_openmpi-3.1.6/lib64/R/library/:/home/prgs/pedro_lima_midasnetwork_us/R/x86_64-pc-linux-gnu-library/4.0