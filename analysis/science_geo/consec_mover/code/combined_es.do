set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global y_name "Output"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Output"
global excluded_tot_name "Log Output"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year

program combined
    estimates load ../output/field/es_1945_2023_year_second_negi.ster, clear


end
