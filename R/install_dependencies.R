
# install imabc from github: develop branch.
# if this script doesn't install all the required dependencies, please add them here.
install.packages("remotes")

# install imabc:
remotes::install_github("https://github.com/carolyner/imabc/tree/develop")

# other dependencies
r_dependencies = c("deSolve", "jsonlite", "dplyr", "tidyr", "readr", "doParallel")

install.packages(r_dependencies)
