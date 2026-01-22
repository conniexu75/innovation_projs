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

use ../external/prod/inst_in_msa_rank_year_second.dta, clear
compress
merge 1:1 inst using ../external/share/top_inst_output.dta, keep(1 3) nogen keepusing(perc)
hashsort msa_rank rank
drop neg_avg
li msa_comb inst impact_cite_affl_wt perc
rename perc inst_perc
merge m:1 msa_comb using ../external/share/top_msa_comb_output.dta, keep(1 3) nogen keepusing(perc)
hashsort msa_rank rank
li msa_comb inst impact_cite_affl_wt perc

