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

use ../external/authors/main_es_coefs_1945_2023_year_firstlast_negi, clear
gen cat = "fl"
replace rel = rel - 0.09
append using ../external/authors/main_es_coefs_1945_2023_year_negi
replace cat = "all" if mi(cat)
replace rel = rel + 0.09 if cat == "all"
  tw rcap ub lb rel if rel != -1.09 & cat == "fl",  lcolor(lavender%70) msize(vsmall) || ///
     scatter b rel if cat == "fl", mcolor(lavender%70) msize(small) || ///
     rcap ub lb rel if rel != -0.91 & cat == "all",  lcolor(orange%70) msize(vsmall) || ///
     scatter b rel if cat == "all", mcolor(orange%70) msymbol(smdiamond) msize(small) ///
     xlab(-10(1)10, labsize(vsmall)) ylab(-1(.1)1, labsize(vsmall)) ///
     yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
       legend(on order(2 "Specification with First-Last Authors (N = 12273)" 4 "Specification with all Authors (N = 33057)")  pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Output", size(vsmall))
graph export ../output/figures/es_combined_authors.pdf, replace
