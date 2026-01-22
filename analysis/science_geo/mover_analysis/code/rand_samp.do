set more off
clear all
capture log close                                                                                   
program drop _all                                                                                   
set scheme modern                                                                                   
graph set window fontface "Arial Narrow"                                                            
pause on                                                                                            
set seed 8975                                                                                       

use ../temp/mover_temp_year_second, clear 
keep if analysis_cond == 1
merge m:1 athr_id using ../temp/dest_origin_changes_year_second, assert(1 3) keep(3) nogen
merge m:1 athr_id year using ../output/stars_inst_id_year_second, assert(1 2 3) keep(3)  nogen
contract athr_id move_year origin_loc origin_inst dest_loc dest_inst 
gen rand = runiform()
hashsort rand
keep in 1/100
gisid athr_id 
drop rand _freq
merge 1:1 athr_id using ../external/openalex/athr_names, assert(2 3) keep(3) nogen
hashsort athr_id
gen actual_move_year = ""
gen phd_grad_year = ""
export excel using ../output/rand_samp_star_mvrs.xlsx, replace firstrow(variables) 




