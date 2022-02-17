# Environment for swift-t 

module load swift-t

# R_LIBS is set to some wonky path under spack's r-inside and rcpp for some reason. This should reset it.
export R_LIBS=/apps/install/r/4.0.3/gcc-9.1.0_openmpi-3.1.6/lib64/R/library/:/home/prgs/pedro_lima_midasnetwork_us/R/x86_64-pc-linux-gnu-library/4.0
# In case I need my path, here it is: /home/prgs/pedro_lima_midasnetwork_us/R/x86_64-pc-linux-gnu-library/4.0/

#export PATH=/lcrc/project/EMEWS/bebop/sfw/swift-t-7771807/stc/bin:$PATH