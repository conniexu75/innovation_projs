set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global movers "/export/scratch/cxu_sci_geo/movers"
global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
global y_name "Productivity"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Productivity"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year 
program main
    foreach t in year year_firstlast {
        qui event_study, samp(`t') timeframe(18) ymax(1) ygap(0.1) 
    }
end

program pre_move_changes
    use if analysis_cond == 1 & inrange(year, `startyr', `endyr')  using ${movers}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ${movers}/mover_xw, assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ${movers}/dest_origin_changes, keep(3) nogen
    preserve
    gcontract athr_id msa_ln_y_diff
    drop _freq
    save ../temp/athr_move_size, replace
    restore
    keep if rel == -1 | rel == -3
    gen ln_y = ln(impact_cite_affl_wt)
    bys athr_id (rel): gen pre_mv_diff = ln_y - ln_y[_n+1]
    contract athr_id pre_mv_diff, nomiss
    drop _freq
    merge 1:1 athr_id using ../temp/athr_move_size, assert(2 3) keep(3) nogen
    binscatter pre_mv_diff msa_ln_y_diff


end 
program event_study 
    syntax, samp(str) timeframe(int) [startyr(int 1945) endyr(int 2023) ymax(real 1) ygap(real 0.2)] 
    cap mat drop _all  
    use if analysis_cond == 1 & inrange(year, `startyr', `endyr')  using ${movers}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ${movers}/mover_xw, assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ${movers}/dest_origin_changes, keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/`timeframe' {
        gen lag`i' = 1 if rel == -`i'
        gen lead`i' = 1 if rel == `i'
    }
    ds lead* lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
        replace `var' = `var'*msa_ln_y_diff
    }
    gen treat = msa_ln_y_diff if rel == 0  
    replace treat = 0 if mi(treat)
    local leads
    local lags
    forval i = 1/`timeframe' {
        local leads `leads' lead`i'
        local lags lag`i' `lags'
    }
    gunique athr_id 
    local num_movers = r(unique)
    egen pos_move_size = cut(msa_ln_y_diff) if msa_ln_y_diff > 0, group(2)
    egen neg_move_size = cut(msa_ln_y_diff) if msa_ln_y_diff < 0, group(2)
    bys athr_id: egen l2h_move = max(msa_ln_y_diff > 0)
    bys athr_id: egen h2l_move = max(msa_ln_y_diff < 0)
    local c "inrange(rel,-`timeframe',`timeframe') `cond'"
    local suf = ""
    if "`cond'" == "& l2h_move== 1" {
        local suf = "_l2h"
    }
    else if "`cond'" == "& h2l_move == 1" {
        local suf = "_h2l"
    }
    else if "`cond'" == "& pos_move_size == 0" {
        local suf = "_l2m"
    }
    else if "`cond'" == "& pos_move_size == 1" {
        local suf = "_ll2hh"
    }
    else if "`cond'" == "& neg_move_size == 0" {
        local suf = "_hh2ll"
    }
    else if "`cond'" == "& neg_move_size == 1" {
        local suf = "_h2m"
    }
    mat drop _all
    reghdfe ln_y `lags' treat `leads' if `c' , absorb(year field msa field#year field#msa inst_fes = inst athr_fes = athr_id) vce(cluster inst) residuals
    predict y_hat , xb
    gcollapse (mean) y_hat inst_fes athr_fes, by(inst_id year)
    gcollapse (mean) y_hat inst_fes athr_fes, by(inst_id)
    foreach var in y_hat inst_fes athr_fes {
        qui sum `var', d 
        local `var'_var= r(Var)
    }
    di "Share of cross inst variance reduced by equaliazing resachers = " 1 - `inst_fes_var'/`y_hat_var'
    di "Share of cross inst variance reduced by equaliazing place = " 1 - `athr_fes_var'/`y_hat_var'
end

program output_tables
    syntax, samp(str)
    foreach file in stat { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }

end
** 
main
