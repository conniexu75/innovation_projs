set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global temp "/export/scratch/cxu_sci_geo/movers"
global y_name "Productivity"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Productivity"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year 
program main
    foreach t in year_firstlast {
        make_movers, samp(`t')
        qui mover_stats, samp(`t')
        output_tables, samp(`t')
        event_study, samp(`t') timeframe(20) ymax(1) ygap(0.1)
        event_study, samp(`t') timeframe(10) startyr(1945) endyr(1975) ymax(1) ygap(0.1)
        event_study, samp(`t') timeframe(10) startyr(1955) endyr(1985) ymax(1) ygap(0.1)
        event_study, samp(`t') timeframe(10) startyr(1965) endyr(1995) ymax(1) ygap(0.1)
        event_study, samp(`t') timeframe(10) startyr(1975) endyr(2005) ymax(1) ygap(0.1)
        event_study, samp(`t') timeframe(10) startyr(1985) endyr(2023) ymax(1) ygap(0.1)
    }
end

program make_movers
    syntax, samp(str)
    use if !mi(msa_comb) using ../external/samp/athr_panel_full_comb_`samp', clear 
    hashsort athr_id year
    gen place_count =  1 if msa_comb != msa_comb[_n-1]
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
    save ${temp}/mover_temp_`samp' , replace
end

program mover_stats
    syntax, samp(str)
    use ${temp}/mover_temp_`samp' , clear  
    gen patented = pat_wt > 0
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_patent = ln(pat_adj_wt)
    rename impact_affl_wt y
    rename msa_size x
    foreach var in ln_x ln_y {
        sum `var' if mover == 0
        mat nonmover = r(mean) \  r(sd) 
        sum `var' if mover == 1 
        mat mover = r(mean)\ r(sd)
        sum `var' if mover == 1 & origin == 1  
        mat mover_origin = r(mean)\ r(sd) 
        sum `var' if mover == 1 & dest == 1  
        mat mover_dest = r(mean)\ r(sd) 
        sum `var' if mover == 1  & num_moves == 1
        mat sing_mover = r(mean)\ r(sd)
        sum `var' if mover == 1  & num_moves == 1 & origin==1
        mat sing_mover_origin = r(mean)\ r(sd)
        sum `var' if mover == 1  & num_moves == 1 & dest==1
        mat sing_mover_dest = r(mean)\ r(sd)
        mat row = (nonmover, sing_mover, sing_mover_origin, sing_mover_dest)
        mat stat_`samp' = nullmat(stat_`samp') \ row 
    }
    qui gunique athr_id if mover == 0
    mat N = r(unique)
*    qui gunique athr_id if mover == 1
*    mat N = N, r(unique), r(unique), r(unique)
    qui gunique athr_id if mover == 1 & num_moves == 1
    mat N = N, r(unique), r(unique), r(unique)
    mat stat_`samp' = nullmat(stat_`samp') \ N
    gen ln_affl_wt = ln(affl_wt)
    gcollapse (mean) msa_y = y msa_x = x msa_ln_y = ln_y msa_ln_x = ln_x msa_ln_patent = ln_patent msa_patent = pat_adj_wt msa_patent_rate = patented msa_affl_wt = affl_wt msa_ln_affl_wt = ln_affl_wt (firstnm) msa, by(msa_comb ${time})
    save ${temp}/msa_`samp'_collapsed, replace

    use if mover == 1 & num_moves == 1 using ${temp}/mover_temp_`samp' , clear  
    gen ln_y = ln(impact_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_patent = ln(pat_adj_wt)
    gen ln_affl_wt = ln(affl_wt)
    gen patented = pat_wt > 0
    hashsort athr_id which_place year
    rename impact_affl_wt y
    rename msa_size x
    foreach var in y x  ln_y ln_x ln_patent ln_affl_wt patented {
        bys athr_id which_place: egen avg_`var' = mean(`var') 
    }
    hashsort athr_id which_place -year
    gduplicates drop athr_id which_place, force
    merge m:1 msa_comb year using ${temp}/msa_`samp'_collapsed, assert(2 3) keep(3) nogen
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
        by athr_id: gen `var'_diff = `var'[_n+1] - `var'
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
    graph export ../output/figures/place_productivity_patent_bs_`samp'.pdf , replace
    gcontract athr_id avg_ln_y_diff avg_ln_x_diff msa_ln_y_diff msa_ln_x_diff year
    drop _freq
    drop if mi(avg_ln_y_diff)
    rename year move_year
    save ../temp/dest_origin_changes, replace
end

program event_study 
    syntax, samp(str) timeframe(int) [startyr(int 1945) endyr(int 2023) ymax(real 1) ygap(real 0.2)] 
    cap mat drop _all  
    use if mover == 1 & num_moves == 1 & inrange(year, `startyr', `endyr')  using ${temp}/mover_temp_`samp' , clear  
    keep athr_id inst field year msa_comb impact_affl_wt msa_size which_place inst_id
    hashsort athr_id year
    by athr_id: gen move = which_place != which_place[_n+1] &  _n != _N
    gen move_year = year if move == 1
    hashsort athr_id move_year
    by athr_id: replace move_year = move_year[_n-1] if mi(move_year) & !mi(move_year[_n-1])
    gen rel = year - move_year
    gunique athr_id if rel == 0
    local num_movers = r(unique)
    merge m:1 athr_id move_year using ../temp/dest_origin_changes, keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_affl_wt)
    gen ln_x = ln(msa_size)
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
    reghdfe ln_y `lags' treat `leads' if inrange(rel,-`timeframe',`timeframe'), absorb(year field msa field#year field#msa athr_id) vce(cluster msa)
    local normalize = _b[lag1]
    foreach var in `lags' treat `leads' {
        mat row = _b[`var']-`normalize', _se[`var']
        if "`var'" == "lag1" {
            mat row = _b[`var']-`normalize',0
        }
        mat es = nullmat(es) \ row 
    }
    svmat es
    preserve
    keep es1 es2
    drop if mi(es1)
    rename (es1 es2) (b se)
    gen ub = b + 1.96*se
    gen lb  = b - 1.96*se
    gen rel = -`timeframe' if _n == 1
    replace rel = rel[_n-1]+ 1 if _n > 1
    drop if rel ==`timeframe' 
    sum b if inrange(rel, -`timeframe',-2)
    local pre_mean : di %3.2f r(mean)
    sum b if inrange(rel, 1,`timeframe')
    local post_mean : di %3.2f r(mean)
    local end = `timeframe' - 1
    tw rcap ub lb rel if rel != -1,  lcolor(gs10) || scatter b rel, mcolor(ebblue) xlab(-`timeframe'(1)`end', angle(45) labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
      yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(purple%50) lpattern(dash)) plotregion(margin(none)) ///
      legend(on order(- "N (Movers) = `num_movers'" ///
                                                        "Pre-period mean = `pre_mean'" ///
                                                        "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
    graph export ../output/figures/es`startyr'_`endyr'_`samp'.pdf, replace
    restore
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
