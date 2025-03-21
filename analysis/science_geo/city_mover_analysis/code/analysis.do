set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
global y_name "Productivity"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Productivity"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year 

program main
    use ../external/year_insts/filled_in_panel_${time}, clear
    keep if country_code == "US"
    hashsort athr_id year
    gen place_count =  1 if msa_comb != msa_comb[_n-1]
    bys athr_id: egen num_moves = total(place_count)
    bys athr_id (year): gen which_place = sum(place_count)
    bys athr_id: gen athr_counter =  _n == 1
    replace num_moves = num_moves-1
    bys athr_id (year) : gen move_year = year if place_count == 1  & _n != 1
    replace move_year = move_year - 3
    bys athr_id : egen first_pub_yr  = min(year)
    gcontract athr_id  move_year  num_moves first_pub_yr
    drop _freq
    drop if mi(move_year)
    drop if num_moves <= 0
    save ../temp/movers, replace

    foreach t in year_firstlast {
        qui make_movers, samp(`t')
        make_dest_origin, samp(`t')
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(msa_ln_y_diff)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(msa_wo_inst_diff)
    }
end

program make_movers
    syntax, samp(str)
    use athr_id field msa_comb year inst_id msa_size impact_cite_affl_wt avg_team_size if !mi(msa_comb) & !mi(inst_id) using ../external/samp/athr_panel_full_comb_`samp', clear 
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
    gcontract athr_id move_year first_pub_yr
    drop _freq
    bys athr_id: gen N = _n 
    keep if N == 1
    save ../temp/mover_xw_`samp', replace
    restore

    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(1 3) 
    bys inst_id year: egen has_mover = max(mover == 1)
    drop if has_mover == 0
    gen analysis_cond = mover == 1 & num_moves == 1 & ((mover == 0 & _merge == 1) | (mover == 1 & _merge == 3))
    drop _merge
    drop has_mover place_count athr_counter athr_year_counter N
    save ../temp/mover_temp_`samp' , replace
end

program make_dest_origin
    syntax, samp(str)
    use ../temp/mover_temp_`samp' , clear  
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    rename impact_cite_affl_wt y
    rename msa_size x
    foreach loc in inst_id msa_comb {
        preserve
        if "`loc'" == "inst_id" {
            local suf inst 
        }
        if "`loc'" == "msa_comb" {
            local suf msa 
        }
        gcollapse (mean) `suf'_ln_y = ln_y `suf'_ln_x = ln_x  (firstnm) msa , by(`loc' ${time}) 
        foreach v in `suf'_ln_y `suf'_ln_x {
            bys `loc' (year): gen pre_`v' = (`v'+`v'[_n-1])/2
            bys `loc' (year): gen post_`v' = (`v'+`v'[_n+1])/2
        }
        save ../temp/`suf'_`samp'_collapsed, replace
        restore
    }

    preserve
    bys inst_id year: egen tot_inst_prod = total(ln_y)
    bys msa_comb year: egen tot_msa_prod = total(ln_y)
    bys msa_comb year: egen num_insts = count(inst_id)
    gen msa_wo_inst = (tot_msa_prod - tot_inst_prod)/(num_insts - 1)
    keep athr_id year msa_wo_inst
    save ../temp/msa_wo_inst_`samp', replace
    restore
        
    use if analysis_cond == 1  using ../temp/mover_temp_`samp' , clear  
    merge 1:1 athr_id year using ../temp/msa_wo_inst_`samp', assert(2 3) keep(3) nogen
    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    hashsort athr_id which_place year
    rename impact_cite_affl_wt y
    rename msa_size x
    gen rel = year - move_year
    foreach var in ln_x ln_y {
        bys athr_id which_place: egen avg_`var' = mean(`var') 
    }
    hashsort athr_id which_place -year
    gduplicates drop athr_id which_place, force
    rename year current_year
    gen year = current_year if which_place == 1
    replace year = move_year if which_place == 2
    merge m:1 inst_id year using ../temp/inst_`samp'_collapsed, assert(1 2 3) keep(3) nogen
    merge m:1 msa_comb year using ../temp/msa_`samp'_collapsed, assert(1 2 3) keep(3) nogen keepusing(msa_ln_x pre_msa_ln_x post_msa_ln_x msa_ln_y)
    save ../output/delta_dist_msa, replace
    hashsort athr_id which_place year
    foreach var in avg_ln_x avg_ln_y inst_ln_y inst_ln_x msa_ln_x msa_ln_y msa_wo_inst {
        if strpos("`var'", "avg_") == 0 {
            local type "Destination-Origin Difference in"
            local stem = subinstr(subinstr("`var'", "msa_","",.), "inst_", "",.)
            by athr_id (which_place year): gen `var'_diff = `var'[_n+1] - `var'
            *by athr_id (which_place year): gen `var'_diff = post_`var'[_n+1] - pre_`var'
        }
        if strpos("`var'", "avg_") > 0 {
            local type "Change in"
            local stem = subinstr("`var'", "avg_","",.)
            by athr_id (which_place year): gen `var'_diff = `var'[_n+1] - `var'
        }
        qui sum `var'_diff
        local N = r(N)
        local mean : dis %3.2f r(mean)
        local sd : dis %3.2f r(sd)
        tw hist `var'_diff, frac ytitle("Share of Movers", size(vsmall)) xtitle("`type' ${`stem'_name}", size(vsmall)) color(edkblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                        "Mean = `mean'" ///
                                                        "            (`sd')") pos(1) ring(0) size(vsmall) region(fcolo(none)))
        graph export ../output/figures/`var'_diff_`samp'.pdf, replace
    }
    gen origin_loc = msa_comb if which_place  == 1
    gen dest_loc = msa_comb if which_place  == 2
    hashsort athr_id which_place year
    by athr_id : replace dest_loc = dest_loc[_n+1] if mi(dest_loc)
    by athr_id : replace origin_loc = origin_loc[_n-1] if mi(origin_loc)
    gcontract athr_id avg_ln_y_diff avg_ln_x_diff inst_ln_y_diff inst_ln_x_diff move_year origin_loc dest_loc msa_ln_x_diff msa_ln_y_diff msa_wo_inst_diff
    drop _freq
    drop if mi(avg_ln_y_diff)
    save ../temp/dest_origin_changes, replace
end

program event_study 
    syntax, samp(str) timeframe(int) delta(str) [startyr(int 1945) endyr(int 2023) ymax(real 1) ygap(real 0.2) ] 
    cap mat drop _all  
    use if analysis_cond == 1 & inrange(year, `startyr', `endyr')  using ../temp/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year first_pub_yr
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ../temp/dest_origin_changes, keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/`timeframe' {
        gen lag`i' = 1 if rel == -`i'
        gen lead`i' = 1 if rel == `i'
        gen int_lag`i' = 1 if rel == -`i'
        gen int_lead`i' = 1 if rel == `i'
    }
    ds int_lead* int_lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
        replace `var' = `var'*`delta'
    }
    ds lead* lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
    }
    gen int_treat = `delta' if rel == 0  
    gen treat = 1 if rel == 0  
    replace int_treat = 0 if mi(int_treat)
    replace treat = 0 if mi(treat)
    local leads
    local int_leads
    local lags
    local int_lags
    forval i = 1/`timeframe' {
        local leads `leads' lead`i'
        local int_leads `int_leads' int_lead`i'
    }
    forval i = 2/`timeframe' {
        local lags lag`i' `lags'
        local int_lags int_lag`i' `int_lags'
    }
    gunique athr_id 
    local num_movers = r(unique)
	gen move_age_pub = move_year - first_pub_yr  + 1 + 25
    gen l2h_move = `delta'  > 0
    gen h2l_move = `delta' < 0
    gen s2b_move = msa_ln_x_diff > 0
    gen b2s_move = msa_ln_x_diff < 0
	by athr_id: gen counter = _n == 1
	sum move_age_pub if counter == 1, d
	gen old = move_age_pub >= r(p50)
    gen young = move_age_pub < r(p50)
    foreach cond in "" "& l2h_move== 1" "& h2l_move == 1" "& b2s_move == 1" "& s2b_move == 1"  "& old == 1" "& young == 1" {
        local c "inrange(rel,-`timeframe',`timeframe') `cond'"
        local suf = ""
        if "`cond'" == "& l2h_move== 1" {
            local suf = "_l2h"
        }
        else if "`cond'" == "& h2l_move == 1" {
            local suf = "_h2l"
        }
        else if "`cond'" == "& b2s_move == 1" {
            local suf = "_b2s"
        }
        else if "`cond'" == "& s2b_move == 1" {
            local suf = "_s2b"
        }
        else if "`cond'" == "& pos_move_size == 1" {
            local suf = "_ll2hh"
        }
        else if "`cond'" == "& neg_move_size == 0" {
            local suf = "_hh2ll"
        }
		else if "`cond'" == "& old == 1" {
            local suf = "_old"
        }
		else if "`cond'" == "& young == 1" {
            local suf = "_young"
        }
        preserve
        mat drop _all
        reghdfe ln_y `lags' `leads' lag1 treat `int_lags' int_treat `int_leads' int_lag1  if `c' , absorb(year field field#year athr_fes = athr_id) vce(cluster msa)
        estimates save ../output/es_`startyr'_`endyr'_`samp'`suf'_`delta', replace
        gunique athr_id if `c'
        local num_movers = r(unique)
        foreach var in `int_lags' int_treat `int_leads' int_lag1 {
            mat row = _b[`var'], _se[`var']
            if "`var'" == "int_lag1" {
                mat row = 0,0
            }
            mat es = nullmat(es) \ row 
        }
        svmat es
        keep es1 es2
        drop if mi(es1)
        rename (es1 es2) (b se)
        gen ub = b + 1.96*se
        gen lb  = b - 1.96*se
        gen rel = -`timeframe' if _n == 1
        replace rel = rel[_n-1]+ 1 if _n > 1
        replace rel = rel+ 1 if rel >= -1
        replace rel = -1 if rel == `timeframe'+1
        sum b if inrange(rel, -`timeframe',-2)
        local pre_mean : di %3.2f r(mean)
        sum b if inrange(rel, 1,`timeframe')
        local post_mean : di %3.2f r(mean)
        replace lb = -1 if lb < -1
        replace ub = 1 if ub > 1
		save ../temp/es_coefs_`startyr'_`endyr'_`samp'`suf'_`delta', replace
        tw rcap ub lb rel if rel != -1,  lcolor(ebblue%50) msize(vsmall) || scatter b rel if se !=0 | rel == -1, mcolor(ebblue%50) msize(small) xlab(-`timeframe'(1)`timeframe', angle(45) labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
          legend(on order(- "N (Movers) = `num_movers'" ///
                                                            "Pre-period mean = `pre_mean'" ///
                                                            "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
        graph export ../output/figures/es`startyr'_`endyr'_`samp'`suf'_`delta'.pdf, replace
        restore
    }
	gunique athr_id if l2h_move== 1
    local l2h_num_movers = r(unique)
	gunique athr_id if h2l_move== 1
    local h2l_num_movers = r(unique)
	
	gunique athr_id if s2b_move== 1
    local s2b_num_movers = r(unique)
	gunique athr_id if b2s_move== 1
    local b2s_num_movers = r(unique)
	gunique athr_id if young== 1
    local young_num_movers = r(unique)
	gunique athr_id if old== 1
    local old_num_movers = r(unique)

	// merge l2h h2
	use ../temp/es_coefs_`startyr'_`endyr'_`samp'_l2h_`delta', clear
	gen cat = "l2h"
	replace rel = rel - 0.09
	append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_h2l_`delta'
	replace cat = "h2l" if mi(cat)
	replace rel = rel + 0.09 if cat == "h2l"
	tw rcap ub lb rel if rel != -1.09 & cat == "l2h",  lcolor(lavender%70) msize(vsmall) || ///
	   scatter b rel if cat == "l2h", mcolor(lavender%70) msize(small) || ///
	   rcap ub lb rel if rel != -0.91 & cat == "h2l",  lcolor(orange%70) msize(vsmall) || ///
	   scatter b rel if cat == "h2l", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
	   xlab(-`timeframe'(1)`timeframe', angle(45) labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
          legend(on order(2 "Low to High Productivity Place Movers (N = `l2h_num_movers')" 4 "High to Low Productivity Place Movers (N = `h2l_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
    graph export ../output/figures/es`startyr'_`endyr'_`samp'_`delta'_prodchg.pdf, replace
	
	// merge s2b b2s
	use ../temp/es_coefs_`startyr'_`endyr'_`samp'_s2b_`delta', clear
	gen cat = "s2b"
	replace rel = rel - 0.09
	append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_b2s_`delta'
	replace cat = "b2s" if mi(cat)
	replace rel = rel + 0.09 if cat == "b2s"
	tw rcap ub lb rel if rel != -1.09 & cat == "s2b",  lcolor(lavender%70) msize(vsmall) || ///
	   scatter b rel if cat == "s2b", mcolor(lavender%70) msize(small) || ///
	   rcap ub lb rel if rel != -0.91 & cat == "b2s",  lcolor(orange%70) msize(vsmall) || ///
	   scatter b rel if cat == "b2s", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
	   xlab(-`timeframe'(1)`timeframe', angle(45) labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
          legend(on order(2 "Small to Big Place Movers (N = `s2b_num_movers')" 4 "Big to Small Place Movers (N = `b2s_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
    graph export ../output/figures/es`startyr'_`endyr'_`samp'_`delta'_sizechg.pdf, replace
	
	// merge young old
	use ../temp/es_coefs_`startyr'_`endyr'_`samp'_young_`delta', clear
	gen cat = "young"
	replace rel = rel - 0.09
	append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_old_`delta'
	replace cat = "old" if mi(cat)
	replace rel = rel + 0.09 if cat == "old"
	tw rcap ub lb rel if rel != -1.09 & cat == "young",  lcolor(lavender%70) msize(vsmall) || ///
	   scatter b rel if cat == "young" & rel > -8, mcolor(lavender%70) msize(small) || ///
	   rcap ub lb rel if rel != -0.91 & cat == "old",  lcolor(orange%70) msize(vsmall) || ///
	   scatter b rel if cat == "old", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
	   xlab(-`timeframe'(1)`timeframe', angle(45) labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
          legend(on order(2 "Movers Aged < 40 (N = `young_num_movers')" 4 "Movers Aged >= 40 (N = `old_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
    graph export ../output/figures/es`startyr'_`endyr'_`samp'_`delta'_age.pdf, replace
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
