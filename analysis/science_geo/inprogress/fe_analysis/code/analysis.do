set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global temp "/export/scratch/cxu_sci_geo/movers"
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
        qui make_movers, samp(`t')
        sum_stats, samp(`t')
        get_inst_fes, samp(`t') timeframe(18) ymax(1) ygap(0.1) 
    }
end

program make_movers
    syntax, samp(str)
    use ${${time}_insts}/filled_in_panel_${time}, clear
    keep if country_code == "US"
    hashsort athr_id year
    gen place_count =  1 if inst_id != inst_id[_n-1] & msa_comb != msa_comb[_n-1]
    bys athr_id: egen num_moves = total(place_count)
    bys athr_id (year): gen which_place = sum(place_count)
    bys athr_id: gen athr_counter =  _n == 1
    replace num_moves = num_moves-1
    bys athr_id (year) : gen move_year = year if place_count == 1  & _n != 1
    gcontract athr_id  move_year  num_moves
    drop _freq
    drop if mi(move_year)
    drop if num_moves <= 0
    save ../temp/movers, replace
    
    use if !mi(msa_comb) & !mi(inst_id) using ../external/samp/athr_panel_full_comb_`samp', clear 
    hashsort athr_id year
    gen place_count =  1 if inst_id != inst_id[_n-1] & msa_comb != msa_comb[_n-1]
    bys athr_id: egen num_moves = total(place_count)
    bys athr_id (year): gen which_place = sum(place_count)
    bys athr_id: gen athr_counter =  _n == 1
    replace num_moves = num_moves-1
    gen mover = num_moves > 0 
    tab num_moves if athr_counter == 1 & mover == 1
    tab mover if athr_counter == 1
    bys athr_id year: gen athr_year_counter =  _n == 1
    tab mover if athr_year_counter == 1
    replace which_place = 0 if mover == 0
    replace which_place = 1 if which_place == 0 & mover == 1
    bys athr_id: egen min_which_place =min(which_place)
    replace which_place = which_place + 1 if mover == 1 & min_which_place == 0
    drop min_which_place
    hashsort athr_id year 
    bys athr_id (year): gen origin = 1 if which_place == 1
    gen dest = place_count == 1 & origin != 1 & mover == 1
    bys athr_id (year): replace origin = 1 if mover == 1 & place_count[_n+1] == 1 & mi(origin) 
    hashsort athr_id which_place origin
    bys athr_id which_place:  replace origin = origin[_n-1] if mi(origin) & !mi(origin[_n-1])
    preserve
    keep if mover == 1 & num_moves == 1 
    gcontract athr_id year
    drop _freq
    bys athr_id: egen min_year = min(year)
    bys athr_id: egen max_year = max(year)
    gcontract athr_id min_year max_year
    drop _freq
    save ../temp/single_movers_`samp', replace
    merge 1:m athr_id using ../temp/movers, assert(1 2 3) keep(3) nogen
    keep if move_year >= min_year & move_year <= max_year
    gcontract athr_id move_year
    drop _freq
    bys athr_id: gen N = _n 
    keep if N == 1
    save ../temp/mover_xw, replace
    restore
    merge m:1 athr_id using ../temp/mover_xw, assert(1 2 3) keep(1 3) 
    *keep if (mover == 0 & _merge == 1) | (mover == 1 & _merge == 3)
    bys inst_id year: egen has_mover = max(mover == 1)
*    bys msa_comb year: egen has_mover = max(mover == 1)
    drop if has_mover == 0
    gen analysis_cond = mover == 1 & num_moves == 1 & ((mover == 0 & _merge == 1) | (mover == 1 & _merge == 3))
    save ${temp}/mover_temp_`samp' , replace
end

program sum_stats
    syntax, samp(str)
    use ${temp}/mover_temp_`samp' , clear  
    gen patented = pat_wt > 0
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_patent = ln(pat_adj_wt)
    rename impact_cite_affl_wt y
    rename msa_size x

    // individual level stats
    preserve
    bys athr_id: gen num_years = _N
    bys athr_id inst_id : gen inst_cntr = _n == 1
    bys athr_id : egen num_insts = total(inst_cntr)
    gen life_time_prod = y
    gcollapse (mean) num_years num_moves avg_team_size x y pat_adj_wt num_insts mover (min) analysis_cond (sum) life_time_prod, by(athr_id)
    count
    foreach var in num_years avg_team_size x y life_time_prod num_moves {
        sum `var'
        mat ind_stats = nullmat(ind_stats) \ (r(mean) , r(sd))
    }
    count if mover == 0 
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if mover == 0 
        mat ind_stats = nullmat(ind_stats) \ (r(mean) , r(sd))
    } 
    count if mover == 1
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if mover == 1 
        mat ind_stats = nullmat(ind_stats) \ (r(mean) , r(sd))
    }
    count if analysis_cond == 1 
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if analysis_cond == 1  
        mat ind_stats = nullmat(ind_stats) \ (r(mean) , r(sd))
    }
    restore
    preserve
    gen life_time_prod = y
    bys msa_comb inst_id: gen inst_cntr = _n == 1
    bys msa_comb: egen num_insts = total(inst_cntr)
    gcollapse (mean) x y num_insts (sum) life_time_prod, by(inst_id)
    count
    foreach var in num_insts x y life_time_prod {
        qui sum `var' 
        mat city_stats = nullmat(city_stats) \ (r(mean), r(sd))
    }
    restore
    mat stat_`samp' = ind_stats \ city_stats 
    gen ln_affl_wt = ln(affl_wt)
    gcollapse (mean) msa_y = y msa_x = x msa_ln_y = ln_y msa_ln_x = ln_x msa_ln_patent = ln_patent msa_patent = pat_adj_wt msa_patent_rate = patented msa_affl_wt = affl_wt msa_ln_affl_wt = ln_affl_wt (firstnm) msa , by(inst_id ${time}) 
    save ${temp}/msa_`samp'_collapsed, replace

    use if analysis_cond == 1  using ${temp}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw, assert(1 2 3) keep(3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_patent = ln(pat_adj_wt)
    gen ln_affl_wt = ln(affl_wt)
    gen patented = pat_wt > 0
    hashsort athr_id which_place year
    rename impact_cite_affl_wt y
    rename msa_size x
    gen rel = year - move_year
    foreach var in y x  ln_x ln_y ln_patent ln_affl_wt patented {
        bys athr_id which_place: egen avg_`var' = mean(`var') 
    }
    hashsort athr_id which_place -year
    gduplicates drop athr_id which_place, force
    rename year current_year
    gen year = current_year if which_place == 1
    replace year = move_year if which_place == 2
    merge m:1 inst_id year using ${temp}/msa_`samp'_collapsed, assert(1 2 3) keep(3) nogen
    hashsort athr_id which_place year
    foreach var in msa_ln_y msa_ln_x msa_ln_patent avg_ln_y avg_ln_x avg_ln_patent {
        if strpos("`var'", "msa_") > 0 {
            local type "Destination-Origin Difference in"
            local stem = subinstr("`var'", "msa_","",.)
        }

        if strpos("`var'", "avg_") > 0 {
            local type "Change in"
            local stem = subinstr("`var'", "avg_","",.)
        }
        by athr_id (which_place year): gen `var'_diff = `var'[_n+1] - `var'
        qui sum `var'_diff
        local N = r(N)
        local mean : dis %3.2f r(mean)
        local sd : dis %3.2f r(sd)
        tw hist `var'_diff, frac ytitle("Share of Movers", size(vsmall)) xtitle("`type' ${`stem'_name}", size(vsmall)) color(edkblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                        "Mean = `mean'" ///
                                                        "            (`sd')") pos(1) ring(0) size(vsmall) region(fcolo(none)))
        graph export ../output/figures/`var'_diff_`samp'.pdf, replace
    }

    reg avg_ln_y_diff msa_ln_y_diff  
    local N = e(N)
    local coef : dis %3.2f _b[msa_ln_y_diff]
    binscatter2 avg_ln_y_diff msa_ln_y_diff,  mcolor(gs5) lcolor(ebblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) xtitle("Destination-Origin Difference in Log Productivity", size(vsmall)) ytitle("Change in Log Productivity after Move", size(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                            "Slope = `coef'") pos(5) ring(0) size(vsmall) region(fcolor(none)))
    graph export ../output/figures/place_effect_desc_`samp'.pdf , replace
    
    reg avg_ln_patent_diff msa_ln_y_diff 
    local N = e(N)
    local coef : dis %3.2f _b[msa_ln_y_diff]
    binscatter2 avg_ln_patent_diff msa_ln_y_diff,  mcolor(gs5) lcolor(ebblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) ytitle("Change in Log Paper-to-Patent Citations after Move", size(vsmall)) xtitle("Destination-Origin Difference in Log Productivity", size(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                                             "Slope = `coef'") pos(5) ring(0) size(vsmall) region(fcolor(none)))
    *graph export ../output/figures/place_productivity_patent_bs_`samp'.pdf , replace
    gcontract athr_id avg_ln_y_diff avg_ln_x_diff msa_ln_y_diff msa_ln_x_diff move_year
    drop _freq
    drop if mi(avg_ln_y_diff)
    save ../temp/dest_origin_changes, replace
end

program get_inst_fes
    syntax, samp(str) timeframe(int) [startyr(int 1945) endyr(int 2023) ymax(real 1) ygap(real 0.2)] 
    cap mat drop _all  
    use if analysis_cond == 1 & inrange(year, `startyr', `endyr')  using ${temp}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw, assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ../temp/dest_origin_changes, keep(3) nogen
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
    mat drop _all
    reghdfe ln_y `lags' treat `leads' i.inst if inrange(rel, -`timeframe',`timeframe') , absorb(year field msa field#year field#msa athr_id) vce(cluster inst)
    estimates save ../temp/main_es_fes, replace
    glevelsof inst, local(institutes)
    foreach i in `institutes' {
        cap di _b[`i'.inst]
        local estimate_er = _rc
        cap di _se[`i'.inst]
        local se_er = _rc
        if `estimate_er' == 0 & `se_er' == 0 {
            mat inst_fes = nullmat(inst_fes) \ (`i', _b[`i'.inst] , _se[`i'.inst])
        }
    }
    contract inst*
    drop _freq
    save ../temp/inst_xw, replace
    clear
    svmat inst_fes
    rename (inst_fes1 inst_fes2 inst_fes3) (inst b se)
    //    normalize
    sum b
    gen z = (b - r(mean))/r(sd)
    gen lb = z - 1.96 * se 
    gen ub = z + 1.96 * se 
    merge 1:1 inst using ../temp/inst_xw, assert(2 3) keep(3) nogen
    hashsort z
    gen rank = _n 
    gen inrange = inrange(rank, 420, 620)
    replace lb = -1 if lb < -1 & inrange == 1 
    replace ub = 1 if ub > 1 & inrange == 1 
    graph tw rcap lb ub rank if inrange == 1 , msize(vtiny) lcolor(gs12%20) || scatter z rank if inrange == 1 , msize(vsmall) mcolor(edkblue) legend(off)  ylab(-1(.1)1) yline(0)
    graph export ../output/figures/test.pdf, replace
    save ../output/normalized_inst_fes, replace
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
