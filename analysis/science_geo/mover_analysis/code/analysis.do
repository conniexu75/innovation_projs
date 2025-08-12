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

program main
    qui get_full_mover_picture
    local main_fes "year athr_fes = athr_id"
    local field "field year athr_fes = athr_id"
    import delimited using ../external/rd/herd_2010_2022, clear
    merge 1:1 inst_id using ../external/xw/inst_names, assert(2 3) keep(3) nogen
    drop _freq
    merge 1:1 inst_id using ../external/xw/herd_oa_xw, assert(1 2 3) keep(3) nogen
    rename inst_id herd_id
    rename matched_oa_inst_id inst_id
    replace fed_ls_fund = 0 if mi(fed_ls_fund)
    replace nonfed_ls_fund = 0 if mi(nonfed_ls_fund)
    gen tot_ls = fed_ls_fund + nonfed_ls_fund
    gcollapse (mean) tot_ls fed_ls_fund nonfed_ls_fund, by(inst_id)
    save ../temp/merged_data, replace
    foreach t in year_second year_second_cns year year_firstlast year_first { 
        di "SAMP: `t'"
        cns_Output, samp(`t')
        qui make_movers, samp(`t')
        sum_stats, samp(`t')
        make_dest_origin, samp(`t')
        qui output_tables, samp(`t')
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_inst_ln_y_diff) fes(`main_fes') fol(main) het_analysis(1)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_inst_ln_y_diff) fes(`field') fol(field)  het_analysis(1)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(star_inst_ln_y_diff) fes(`main_fes') fol(main)
        event_study, samp(`t') timeframe(10) startyr(1995) endyr(2023) delta(excluded_inst_ln_y_diff) ymax(1) ygap(0.1) fes(`main_fes') fol(main)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(inst_ln_x_diff) fes(`main_fes') fol(size)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(inst_cns_athr_diff) fes(`main_fes') fol(main)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_tot_diff) fes(`main_fes') fol(main) het_analysis(1)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(nonfed_ls_fund_diff) fes(`main_fes') fol(main) het_analysis(0) 
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(fed_ls_fund_diff) fes(`main_fes') fol(main) het_analysis(0) 
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(tot_ls_diff) fes(`main_fes') fol(main) het_analysis(0) 
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_inst_ln_nocite_diff) yvar(ln_nocite) fes(`main_fes') fol(main) het_analysis(0)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_tot_diff) yvar(avg_tot_athrs) fes(`main_fes') fol(main) het_analysis(0)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_tot_diff) yvar(unique_coathrs) fes(`main_fes') fol(main) het_analysis(0)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_tot_diff) yvar(avg_us_athrs) fes(`main_fes') fol(main) het_analysis(0)
        event_study, samp(`t') timeframe(10) ymax(1) ygap(0.1) delta(excluded_tot_diff) yvar(unique_us_coathrs) fes(`main_fes') fol(main) het_analysis(0)
    }
    qui coathr_locs, samp(year_second)
    qui coathr_prod, samp(year_second)
end

program get_full_mover_picture
    use if country_code == "US" using ../external/year_insts/filled_in_panel_${time}, clear
    hashsort athr_id year
    gen place_count =  1 if inst_id != inst_id[_n-1] & athr_id == athr_id[_n-1] 
    bys athr_id: egen num_moves = total(place_count)
    bys athr_id (year): gen which_place = sum(place_count)
    by athr_id: gen athr_counter =  _n == 1
    bys athr_id (year) : gen move_year = year if place_count == 1  & _n != 1 & year[_n-1] == year-1
    replace move_year = move_year - 3
    bys athr_id : egen first_pub_yr  = min(year)
    bys athr_id : egen last_pub_yr  = max(year)
    gcontract athr_id  move_year  num_moves first_pub_yr last_pub_yr
    drop _freq
    drop if mi(move_year)
    hashsort athr_id move_year
    by athr_id: gen which_move = _n
    drop if num_moves <= 0
    drop if num_moves >6
    rename num_moves tot_moves
    save ../temp/movers, replace
    preserve
    gcontract athr_id move_year first_pub_yr last_pub_yr
    bys athr_id (move_year) : gen i = _n 
    drop _freq
    reshape wide move_year,  i(athr_id first_pub_yr last_pub_yr) j(i)
    save ../temp/move_years, replace
    restore
    gcontract athr_id tot_moves first_pub_yr last_pub_yr
    drop _freq
    save ../temp/mover_chars, replace
end

program cns_Output
    syntax, samp(str)
    if strpos("`samp'", "cns") == 0 {
        use athr_id impact_cite_affl_wt year using ../external/samp/athr_panel_full_comb_`samp'_cns, clear 
        rename impact_cite_affl_wt  cns_impact_cite_affl_wt
        save ../temp/`samp'_cns_prod, replace
    }
end

program make_movers
    syntax, samp(str)
    use athr_id field msa_comb year inst_id inst msa_size impact_cite_affl_wt impact_affl_wt avg_* sec* cns ppr_cnt unique_* if !mi(msa_comb) & !mi(inst_id) using ../external/samp/athr_panel_full_comb_`samp', clear 
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
    }
    replace msa_comb = "Bay Area, CA" if inst_id == "I180670191"
    merge m:1 athr_id using ../temp/mover_chars, assert(1 2 3) keep(1 3)
    gen ever_mover = _merge == 3
    drop _merge
    if strpos("`samp'", "cns") == 0 {
        merge 1:1 athr_id year using ../temp/`samp'_cns_prod, assert(1 3) keep(1 3) nogen
    }
    hashsort athr_id year

    gen place_count =  1 if inst_id != inst_id[_n-1] & athr_id == athr_id[_n-1] 
    gen city_count =  1 if msa_comb != msa_comb[_n-1] & athr_id == athr_id[_n-1] 
    bys athr_id: egen num_moves = total(place_count)
    bys athr_id: egen num_cities = total(city_count)
    bys athr_id (year): gen which_place = sum(place_count)
    bys athr_id: gen athr_counter =  _n == 1
    gen mover = num_moves > 0 
    gen city_mover = num_cities > 0
    tab num_moves if athr_counter == 1 & mover == 1
    tab mover if athr_counter == 1
    bys athr_id year: gen athr_year_counter =  _n == 1
    tab mover if athr_year_counter == 1
    replace which_place = which_place + 1
    replace which_place = 0 if mover == 0
    hashsort athr_id year 
    bys athr_id (year): gen origin = 1 if which_place == 1
    gen dest = place_count == 1 & origin != 1 & mover == 1
    bys athr_id (year): replace origin = 1 if mover == 1 & place_count[_n+1] == 1 & mi(origin) 
    hashsort athr_id which_place origin
    bys athr_id which_place:  replace origin = origin[_n-1] if mi(origin) & !mi(origin[_n-1])
    drop if num_moves >=5
    
    preserve
    keep if mover == 1  & num_moves == 1
    gcontract athr_id year
    bys athr_id: egen min_year = min(year)
    bys athr_id: egen max_year = max(year)
    drop _freq
    gcontract athr_id min_year max_year
    drop if _freq == 1
    drop _freq
    save ../temp/single_movers_`samp', replace

    merge 1:m athr_id using ../temp/movers, assert(1 2 3) keep(3) nogen
    keep if move_year >= min_year & move_year <= max_year
    gcontract athr_id move_year first_pub_yr which_move
    drop _freq
    bys athr_id: gen N = _n 
    keep if N == 1
    save ../temp/mover_xw_`samp', replace
    restore

    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(1 3) 
    drop if mover == 1 &  num_moves > 1 
    bys inst_id year: egen has_mover = max(mover == 1)
    gen analysis_cond = mover == 1 & ( num_moves == 1) & ((mover == 0 & _merge == 1) | (mover == 1 & _merge == 3))
    drop _merge
    save ../temp/mover_temp_`samp' , replace
end

program sum_stats
    syntax, samp(str)
    use ../temp/mover_temp_`samp' , clear  
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    if strpos("`samp'" , "cns") == 0 {
        gen ln_cns_y = ln(cns_impact_cite_affl_wt)
    }
    cap gen ln_cns_y = ln_y
    gen ln_x = ln(msa_size)
    rename impact_cite_affl_wt y
    rename msa_size x

    // individual level stats
    preserve
    bys athr_id: gen num_years = _N
    bys athr_id inst_id : gen inst_cntr = _n == 1
    bys athr_id : egen num_insts = total(inst_cntr)
    gen life_time_prod = y
    gcollapse (mean) num_years num_moves avg_team_size x y num_insts mover (min) analysis_cond (sum) life_time_prod, by(athr_id)
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
end 

program make_dest_origin
    syntax, samp(str)
    use ../temp/mover_temp_`samp' , clear  
    drop if year  == move_year & mover == 1
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_nocite = ln(impact_affl_wt)
    if strpos("`samp'" , "cns") == 0 {
        gen ln_cns_y = ln(cns_impact_cite_affl_wt)
    }
    cap gen ln_cns_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen prob_cns = cns/ppr_cnt
    bys athr_id: egen is_cns_athr = max(cns)
    replace is_cns_athr = is_cns_athr > 0 
    gen cns_athr = ln_y if is_cns_athr > 0
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
        egen p95_value = pctile(ln_y), p(95) by(`loc' year)
        gen stars = ln_y if ln_y >= p95_value
        bys `loc' athr_id : gen `suf'_athr_cnt_id = _n == 1
        bys `loc' : egen `suf'_tot_movers = total(`suf'_athr_cnt_id & mover == 1) 
        bys `loc'  : egen `suf'_athr_cnt = total(`suf'_athr_cnt_id)
        drop `suf'_athr_cnt_id
        bys `loc' athr_id year : gen `suf'_athr_cnt_id = _n == 1
        bys `loc' year : egen athr_yrs = total(`suf'_athr_cnt_id) 
        bys `loc' year : gen athr_yr_id = _n ==1
        replace athr_yrs = . if athr_yr_id != 1
        bys `loc': egen avg_athr_yrs = mean(athr_yrs)
        bys `loc' athr_id year : gen star_`suf'_athr_cnt_id = _n == 1 &  ln_y >= p95_value
        bys `loc' athr_id : gen `suf'_star_cnt_id = _n == 1 &  ln_y >= p95_value
        bys `loc' : egen `suf'_star_cnt= total(`suf'_star_cnt_id)
        bys `loc' year: gen yr_cnt = _n == 1
        bys `loc': egen tot_yrs = total(yr_cnt)
        bys `loc' inst_id : gen inst_cnt = _n == 1
        bys `loc' : egen tot_insts = total(inst_cnt) 
        gen `suf'_sum_ln_y = ln_y
        gen `suf'_sum_ln_nocite = ln_nocite
        gen star_`suf'_sum_ln_y = stars 
        drop if tot_yrs <= 5 
        if "`loc'" == "inst_id" {
            *drop if avg_athr_yrs < 100 
            drop if `suf'_athr_cnt < 100 
            drop if `suf'_tot_movers < 10
            /*drop if tot_insts <= 5
            drop if `sfu'_athr_cnt <=25 */
        }
        if "`loc'" == "msa_comb" {
            *drop if avg_athr_yrs < 100 
            drop if `suf'_athr_cnt < 100 
            drop if `suf'_tot_movers < 10
            /*drop if tot_insts <= 5
            drop if avg_athr_yrs <=20 
            drop if `suf'_athr_cnt <=100 */
        }
        collapse (mean) ln_cns_y prob_cns avg_yr_ln_nocite = ln_nocite avg_yr_ln_y  = ln_y avg_yr_stars = stars ln_x `suf'_athr_cnt `suf'_star_cnt cns_athr (sum)`suf'_sum_ln_nocite `suf'_sum_ln_y star_`suf'_sum_ln_y `suf'_athr_cnt_id star_`suf'_athr_cnt_id `suf'_y = y (firstnm) msa inst , by(`loc' ${time}) 
        save ../temp/`suf'_year_`samp'_collapsed, replace
        collapse (mean) `suf'_ln_cns_y = ln_cns_y `suf'_prob_cns = prob_cns `suf'_ln_nocite = avg_yr_ln_nocite `suf'_ln_y = avg_yr_ln_y star_`suf'_ln_y = avg_yr_stars `suf'_ln_x = ln_x `suf'_athr_cnt `suf'_star_cnt `suf'_cns_athr = cns_athr (sum) `suf'_sum_ln_y star_`suf'_sum_ln_y `suf'_sum_ln_nocite `suf'_y (firstnm) msa inst (min) min_year=year (max) max_year = year, by(`loc')
        replace `suf'_prob_cns = . if `suf'_prob_cns == 0
        hashsort -`suf'_y
        gen `suf'_rank = 1 if _n <= 5
        replace `suf'_rank = 2 if inrange(_n,6,10)
        replace `suf'_rank = 3 if inrange(_n,11,20)
        save ../temp/`suf'_`samp'_collapsed, replace
        restore
    }
        
    use if analysis_cond == 1  using ../temp/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_nocite = ln(impact_affl_wt)
    gen ln_x = ln(msa_size)
    gen prob_cns = cns/ppr_cnt
    egen p95_value = pctile(ln_y), p(95) by(inst_id year)
    gen stars = ln_y >= p95_value
    preserve
    gcontract athr_id year if stars == 1
    drop _freq
    save ../output/stars_inst_id_`samp' , replace
    restore
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
    bys inst_id year: gen tag = _n == 1 
    bys inst_id : egen denom = total(tag) 
    merge m:1 inst_id  year using ../temp/inst_year_`samp'_collapsed, assert(1 2 3) keep(3) nogen 
    bys inst_id: egen old_num = total(avg_yr_ln_y * tag)
    bys inst_id: egen old_num_nocite = total(avg_yr_ln_nocite * tag)
    bys inst_id: egen old_star_num = total(avg_yr_stars * tag)
    gen excluded_tot = inst_y - y
    gen excluded_mean = (inst_sum_ln_y - ln_y)/(inst_athr_cnt_id - 1)
    gen excluded_nocite_mean = (inst_sum_ln_nocite - ln_nocite)/(inst_athr_cnt_id - 1)
    gen excluded_star_mean = (star_inst_sum_ln_y - ln_y)/(star_inst_athr_cnt_id - 1)
    gen new_num = old_num + (excluded_mean - avg_yr_ln_y)
    gen new_num_nocite = old_num_nocite + (excluded_nocite_mean - avg_yr_ln_nocite)
    gen new_star_num = old_star_num + (excluded_star_mean - avg_yr_stars) if stars == 1
    replace new_star_num = old_star_num  if stars != 1
    gen excluded_inst_ln_y = new_num/denom
    gen excluded_inst_ln_nocite = new_num_nocite/denom
    gen excluded_star_inst_ln_y = new_star_num/denom if stars == 1 
    replace excluded_star_inst_ln_y = old_star_num/denom if stars != 1 
    merge m:1 inst_id  using ../temp/inst_`samp'_collapsed, assert(1 2 3) keep(3) nogen
    merge m:1 inst_id  using ../temp/merged_data, assert(1 2 3) keep(1 3) nogen
    merge m:1 msa_comb using ../temp/msa_`samp'_collapsed, assert(1 2 3) keep(3) nogen keepusing(msa_ln_x msa_athr_cnt msa_rank) 
    gen msa_noinst_athr = msa_athr_cnt-inst_athr_cnt
    replace excluded_tot = ln(excluded_tot)
    replace tot_ls = ln(tot_ls)
    replace fed_ls_fund = ln(fed_ls_fund)
    replace nonfed_ls_fund = ln(nonfed_ls_fund)
    save ../output/make_delta_figs_inst_`samp', replace
    hashsort athr_id which_place year
    foreach var in avg_ln_y excluded_inst_ln_y excluded_star_inst_ln_y excluded_inst_ln_nocite inst_ln_nocite inst_ln_y x inst_ln_x msa_athr_cnt msa_ln_x star_inst_ln_y inst_prob_cns inst_ln_cns_y inst_cns_athr msa_noinst_athr excluded_tot tot_ls nonfed_ls_fund fed_ls_fund {
        if strpos("`var'", "avg_") == 0 {
            local type "Destination-Origin Difference in"
            local stem = subinstr(subinstr("`var'", "msa_","",.), "inst_", "",.)
            by athr_id (which_place year): gen `var'_diff = `var'[_n+1] - `var'
            by athr_id (which_place year): gen dest_`var' = `var'[_n+1] 
            by athr_id (which_place year): gen origin_`var' = `var'
        }
        if strpos("`var'", "avg_") > 0 {
            local type "Change in"
            local stem = subinstr("`var'", "avg_","",.)
            by athr_id (which_place year): gen `var'_diff = `var'[_n+1] - `var'
        }
        if inlist("`var'" ,"inst_ln_y" , "star_inst_ln_y", "excluded_inst_ln_y" , "excluded_star_inst_ln_y", "inst_prob_cns", "inst_ln_cns_y", "inst_cns_athr", "excluded_inst_ln_nocite", "excluded_tot") | inlist("`var'", "fed_ls_fund", "tot_ls" , "nonfed_ls_fund") {
            qui sum `var'_diff
            local N = r(N)
            local mean : dis %3.2f r(mean)
            local sd : dis %3.2f r(sd)
            tw hist `var'_diff, frac ytitle("Share of Movers", size(vsmall)) xtitle("`type' ${`stem'_name}", size(vsmall)) color(edkblue) xlab(-4(1)4, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                            "Mean = `mean'" ///
                                                            "            (`sd')") pos(1) ring(0) size(vsmall) region(fcolo(none)))
            graph export ../output/figures/`var'_diff_`samp'.pdf, replace
        }
    }

    reg avg_ln_y_diff inst_ln_y_diff  
    local N = e(N)
    local coef : dis %3.2f _b[inst_ln_y_diff]
    binscatter2 avg_ln_y_diff inst_ln_y_diff,  mcolor(gs5) lcolor(ebblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) xtitle("Destination-Origin Difference in Log Output", size(vsmall)) ytitle("Change in Log Output after Move", size(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                            "Slope = `coef'") pos(5) ring(0) size(vsmall) region(fcolor(none)))
    graph export ../output/figures/place_effect_desc_`samp'.pdf , replace
    
    gen origin_loc = msa_comb if which_place  == 1
    gen dest_loc = msa_comb if which_place  == 2
    gen dest_rank = msa_rank if which_place == 2
    hashsort athr_id which_place year
    by athr_id : replace dest_loc = dest_loc[_n+1] if mi(dest_loc)
    by athr_id : replace dest_rank = dest_rank[_n+1] if mi(dest_rank)
    by athr_id : replace origin_loc = origin_loc[_n-1] if mi(origin_loc)
    gcontract athr_id move_year origin_* dest_* *_diff  
    drop _freq
    drop if mi(avg_ln_y_diff)
    save ../temp/dest_origin_changes_`samp', replace

    use ../temp/mover_temp_`samp' , clear  
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    rename impact_cite_affl_wt y
    rename msa_size x

    // individual level stats
    preserve
    bys athr_id: gen num_years = _N
    bys athr_id inst_id : gen inst_cntr = _n == 1
    bys athr_id : egen num_insts = total(inst_cntr)
    gen life_time_prod = y
    gcollapse (mean) num_years num_moves avg_team_size x y num_insts mover (min) analysis_cond (sum) life_time_prod, by(athr_id)
    count if mover == 1
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if mover == 0 
        mat mvr_stats_`samp' = nullmat(mvr_stats_`samp') \ (r(mean) , r(sd))
    }
    merge 1:1 athr_id using ../temp/dest_origin_changes_`samp', assert(1 3) keep(1 3) nogen 
    count if analysis_cond == 1 & inst_ln_y_diff >= 0
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if analysis_cond == 1  & inst_ln_y_diff >=0
        mat mvr_stats_`samp' = nullmat(mvr_stats_`samp') \ (r(mean) , r(sd))
    }
    count if analysis_cond == 1 & inst_ln_y_diff < 0
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if analysis_cond == 1  & inst_ln_y_diff < 0
        mat mvr_stats_`samp' = nullmat(mvr_stats_`samp') \ (r(mean) , r(sd))
    }
    restore
end

program event_study 
    syntax, samp(str) timeframe(int) fes(str) fol(str) [yvar(name) delta(name) startyr(int 1945) endyr(int 2023) ymax(real 1) ygap(real 0.2) addcond(str) het_analysis(real 0)] 
    cap mkdir "../output/`fol'"
    cap mkdir "../output/figures/`fol'"
    cap mkdir "../output/tables/`fol'"
    cap mat drop _all  
     if "`delta'" == "" {
         local delta excluded_inst_ln_y_diff
     }
     if "`yvar'" == "" {
         local yvar ln_y 
         local yvar_name "Log Output"
     }
     if "`yvar'" == "prob_cns" {
        local yvar_name "Probability of Publishing in CNS"
     }
     if "`yvar'" == "ln_nocite" {
        local yvar_name "Log Paper Count"
     }
     if "`yvar'" == "avg_tot_athrs" {
        local yvar_name "Average Team Size"
     }
     if "`yvar'" == "unique_coathrs" {
        local yvar_name "# of Unique Coauthors"
     }
     if "`yvar'" == "unique_us_coathrs" {
        local yvar_name "# of Unique Coauthors"
     }
     if "`yvar'" == "avg_us_athrs" {
        local yvar_name "Average Team Size"
     }
     if "`addcond'" == "" {
         local addcond "" 
     }
    use if analysis_cond == 1 & inrange(year, `startyr', `endyr')  using ../temp/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw_`samp', assert(1 2 3) keep(3) nogen
    if strpos("`samp'" , "cns") == 0 {
        keep athr_id field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year first_pub_yr ppr_cnt cns cns_impact_cite_affl_wt which_move city_mover impact_affl_wt avg* unique_*
    }
    if strpos("`samp'" , "cns") > 0 {
        keep athr_id field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year first_pub_yr ppr_cnt cns which_move city_mover impact_affl_wt  avg* unique_*
    }
    bys athr_id : egen has_cns = max(cns)
    gen ever_cns = has_cns > 0
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ../temp/dest_origin_changes_`samp', keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_nocite = ln(impact_affl_wt)
    if strpos("`samp'" , "cns") == 0 {
        gen ln_cns_y = ln(cns_impact_cite_affl_wt)
    }
    cap gen ln_cns_y = ln(impact_cite_affl_wt)
    gen prob_cns = cns/ppr_cnt  
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
    egen pos_move_size = cut(excluded_inst_ln_y_diff) if excluded_inst_ln_y_diff > 0, group(2)
    egen neg_move_size = cut(excluded_inst_ln_y_diff) if excluded_inst_ln_y_diff < 0, group(2)
    gen l2h_move = excluded_inst_ln_y_diff > 0
    gen h2l_move = excluded_inst_ln_y_diff < 0
    gen s2b_move = msa_athr_cnt_diff > 0 & city_mover == 1
    gen b2s_move = msa_athr_cnt_diff < 0 & city_mover == 1 
    gen s2b2_move = msa_noinst_athr_diff > 0 & city_mover == 1
    gen b2s2_move = msa_noinst_athr_diff < 0 & city_mover == 1
    gen top_city = dest_rank == 1 
    gen mid_city = dest_rank == 2 
    gen low_city = dest_rank == 3
    gen first_move = which_move == 1
    gen later_move = which_move > 1
	by athr_id: gen counter = _n == 1
	sum move_age_pub if counter == 1, d
	gen old = move_age_pub >= 40 
    gen young = move_age_pub < 40 
    gen dest_boston =  dest_loc == "Boston-Cambridge-Newton, MA-NH"
    gen dest_sf =  dest_loc == "Bay Area, CA"
    gen not_boston_sf = dest_loc != "Boston-Cambridge-Newton, MA-NH" & dest_loc != "Bay Area, CA"
    // baseline Event Study
    local cond ""
    local c "inrange(rel,-`timeframe',`timeframe') `cond'`addcond'"
    local suf = ""
    if strpos("`delta'", "star") == 0 local delta_suf = "" 
    if "`delta'" == "tot_ls_diff" local delta_suf = "_tot_ls"
    if "`delta'" == "fed_ls_fund_diff" local delta_suf = "_fed_ls"
    if "`delta'" == "nonfed_ls_fund_diff" local delta_suf = "_nonfed_ls"
    if "`delta'" == "excluded_tot_diff" local delta_suf = "_tot_otpt"
    if "`delta'" == "excluded_inst_ln_y_diff" local delta_suf = "_negi" 
    if "`delta'" == "excluded_inst_ln_nocite_diff" local delta_suf = "_nocite" 
    if "`delta'" == "ln_x_diff" local delta_suf = "_size" 
    if "`delta'" == "excluded_star_inst_ln_y_diff" local delta_suf = "_star_negi" 
    if "`delta'" == "star_inst_ln_y_diff" local delta_suf = "_star" 
    if "`yvar'" == "ln_cns_y" local delta_suf = "_cns_prod" 
    if "`yvar'" == "avg_tot_athrs" local delta_suf = "_athrs" 
    if "`yvar'" == "unique_coathrs" local delta_suf = "_unique" 
    if "`yvar'" == "unique_us_coathrs" local delta_suf = "_unique_us" 
    if "`yvar'" == "avg_us_athrs" local delta_suf = "_us_athrs" 
    if "`delta'" == "inst_cns_athr_diff" local delta_suf = "_cns_delta" 
    local suf = "`suf'`delta_suf'" 
    preserve
    mat drop _all
    reghdfe `yvar' `lags' `leads' lag1 treat `int_lags' int_treat `int_leads' int_lag1  if `c' , absorb(`fes') vce(cluster inst)
    estimates save ../output/`fol'/es_`startyr'_`endyr'_`samp'`suf', replace
    gunique athr_id if `c' 
    local num_movers = r(unique) 
    if inlist("`delta'" , "nonfed_ls_fund_diff", "fed_ls_fund_diff", "tot_ls_diff") {
        gunique athr_id if `c' & !mi(`delta')
        local num_movers = r(unique)
    }
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
*        replace lb = -1 if lb < -1
*        replace ub = 1 if ub > 1
    save ../temp/es_coefs_`startyr'_`endyr'_`samp'`suf', replace
    if "`cond'" == "" {
        tw rcap ub lb rel if rel != -1,  lcolor(ebblue%50) msize(vsmall) || scatter b rel if se !=0 | rel == -1, msize(small) mcolor(ebblue%50) xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(-0.5, lcolor(gs12) lpattern(dash))  ///
          legend(on order(- "N (Movers) = `num_movers'" ///
                                                            "Pre-period mean = `pre_mean'" ///
                                                            "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'`suf'.pdf, replace

    }
    restore
    // only run if you want het analysis 
    if `het_analysis' == 1 {
        foreach cond in "& l2h_move== 1" "& h2l_move == 1" "& b2s_move == 1" "& s2b_move == 1"  "& old == 1" "& young == 1" "& first_move == 1" "& later_move == 1" "& dest_boston == 1" "& dest_boston == 0" "& b2s2_move == 1" "& s2b2_move == 1"  "& top_city == 1" "& mid_city == 1" "& low_city == 1" { 
            local c "inrange(rel,-`timeframe',`timeframe') `cond'`addcond'"
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
            else if "`cond'" == "& b2s2_move == 1" {
                local suf = "_b2s2"
            }
            else if "`cond'" == "& s2b2_move == 1" {
                local suf = "_s2b2"
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
            else if "`cond'" == "& first_move == 1" {
                local suf = "_mv1"
            } 
            else if "`cond'" == "& later_move == 1" {
                local suf = "_mvafter1"
            } 
            else if "`cond'" == "& dest_boston == 1" {
                local suf = "_boston"
            } 
            else if "`cond'" == "& dest_boston == 0" {
                local suf = "_notboston"
            } 
            else if "`cond'" == "& dest_sf == 1" {
                local suf = "_sf"
            } 
            else if "`cond'" == "& not_boston_sf == 1" {
                local suf = "_not_boston_sf"
            } 
            else if "`cond'" == "& top_city == 1" {
                local suf = "_top_city"
            } 
            else if "`cond'" == "& mid_city == 1" {
                local suf = "_mid_city"
            } 
            else if "`cond'" == "& low_city == 1" {
                local suf = "_low_city"
            } 
            local suf = "`suf'`delta_suf'" 
            preserve
            mat drop _all
            reghdfe `yvar' `lags' `leads' lag1 treat `int_lags' int_treat `int_leads' int_lag1  if `c' , absorb(`fes') vce(cluster inst)
            estimates save ../output/`fol'/es_`startyr'_`endyr'_`samp'`suf', replace
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
    *        replace lb = -1 if lb < -1
    *        replace ub = 1 if ub > 1
            save ../temp/es_coefs_`startyr'_`endyr'_`samp'`suf', replace
            if "`cond'" == "" {
                tw rcap ub lb rel if rel != -1,  lcolor(ebblue%50) msize(vsmall) || scatter b rel if se !=0 | rel == -1, msize(small) mcolor(ebblue%50) xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
                  yline(0, lcolor(black) lpattern(solid)) xline(-0.5, lcolor(gs12) lpattern(dash))  ///
                  legend(on order(- "N (Movers) = `num_movers'" ///
                                                                    "Pre-period mean = `pre_mean'" ///
                                                                    "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
                graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'`suf'.pdf, replace

            }
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
        gunique athr_id if s2b2_move== 1
        local s2b2_num_movers = r(unique)
        gunique athr_id if b2s2_move== 1
        local b2s2_num_movers = r(unique)
        gunique athr_id if young== 1
        local young_num_movers = r(unique)
        gunique athr_id if old== 1
        local old_num_movers = r(unique)
        gunique athr_id if first_move== 1
        local first_move_num_movers = r(unique)
        gunique athr_id if later_move== 1
        local later_move_num_movers = r(unique)
        gunique athr_id if dest_boston== 1
        local dest_boston_num_movers = r(unique)
        gunique athr_id if dest_boston== 0
        local not_dest_boston_num_movers = r(unique)
        gunique athr_id if dest_sf== 1
        local dest_sf_num_movers = r(unique)
        gunique athr_id if not_boston_sf== 1
        local not_boston_sf_num_movers = r(unique)
        gunique athr_id if top_city== 1
        local top_city_movers= r(unique)
        gunique athr_id if mid_city== 1
        local mid_city_movers= r(unique)
        gunique athr_id if low_city== 1
        local low_city_movers= r(unique)

        // boston sf vs not those
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_boston`delta_suf', clear
        gen cat = "boston"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_notboston`delta_suf'
        replace cat = "not_boston" if mi(cat)
        replace rel = rel + 0.09 if cat == "not_boston"
        tw rcap ub lb rel if rel != -1.09 & cat == "boston",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "boston", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -0.91 & cat == "not_boston",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "not_boston", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Movers to Boston (N = `dest_boston_num_movers')" 4 "Movers Not to Boston  (N = `not_dest_boston_num_movers')")  pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_citydiff`delta_suf'.pdf, replace
        
        // top vs mid vs low cities
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_top_city`delta_suf', clear
        gen cat = "top_city"
        replace rel = rel - 0.27
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_mid_city`delta_suf'
        replace cat = "mid_city" if mi(cat)
        replace rel = rel - 0.09 if cat == "mid_city"
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_low_city`delta_suf'
        replace cat = "low_city" if mi(cat)
        replace rel = rel + 0.09 if cat == "low_city"
        tw rcap ub lb rel if rel != -1.27 & cat == "top_city",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "top_city", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -1.09 & cat == "mid_city",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "mid_city", mcolor(orange%70) msymbol(smdiamond) msize(small) || /// 
           rcap ub lb rel if rel != -0.91 & cat == "low_city",  lcolor(ebblue%70) msize(vsmall) || ///
           scatter b rel if cat == "low_city", mcolor(ebblue%70) msymbol(smsquare) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Movers to Top 5 City (N = `top_city_movers')" 4 "Movers to Top 6-10 City (N = `mid_city_movers')" 6 "Movers to Top 11-20 City (N = `low_city_movers')")  pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_cityrank`delta_suf'.pdf, replace
        
        // merge l2h h2
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_l2h`delta_suf', clear
        gen cat = "l2h"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_h2l`delta_suf'
        replace cat = "h2l" if mi(cat)
        replace rel = rel + 0.09 if cat == "h2l"
        tw rcap ub lb rel if rel != -1.09 & cat == "l2h",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "l2h", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -0.91 & cat == "h2l",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "h2l", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Low to High Output Place Movers (N = `l2h_num_movers')" 4 "High to Low Output Place Movers (N = `h2l_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_prodchg`delta_suf'.pdf, replace
        
        // merge s2b b2s
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_s2b`delta_suf', clear
        gen cat = "s2b"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_b2s`delta_suf'
        replace cat = "b2s" if mi(cat)
        replace rel = rel + 0.09 if cat == "b2s"
        tw rcap ub lb rel if rel != -1.09 & cat == "s2b",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "s2b", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -0.91 & cat == "b2s",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "b2s", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Small to Big Place Movers (N = `s2b_num_movers')" 4 "Big to Small Place Movers (N = `b2s_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_sizechg`delta_suf'.pdf, replace
        
        // merge s2b2 b2s2
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_s2b2`delta_suf', clear
        gen cat = "s2b2"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_b2s2`delta_suf'
        replace cat = "b2s2" if mi(cat)
        replace rel = rel + 0.09 if cat == "b2s2"
        tw rcap ub lb rel if rel != -1.09 & cat == "s2b2",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "s2b2", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -0.91 & cat == "b2s2",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "b2s2", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Small to Big Place Movers (N = `s2b2_num_movers')" 4 "Big to Small Place Movers (N = `b2s2_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_sizechg22`delta_suf'.pdf, replace

        // merge young old
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_young`delta_suf', clear
        gen cat = "young"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_old`delta_suf'
        replace cat = "old" if mi(cat)
        replace rel = rel + 0.09 if cat == "old"
        tw rcap ub lb rel if rel != -1.09 & cat == "young" & ub != lb,  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "young", mcolor(lavender%70) msize(small)|| ///
           rcap ub lb rel if rel != -0.91 & cat == "old" & ub!= lb,  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "old", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "Movers Aged < 40 (N = `young_num_movers')" 4 "Movers Aged >= 40 (N = `old_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_age`delta_suf'.pdf, replace
        
        // merge first and later 
        use ../temp/es_coefs_`startyr'_`endyr'_`samp'_mv1`delta_suf', clear
        gen cat = "first"
        replace rel = rel - 0.09
        append using ../temp/es_coefs_`startyr'_`endyr'_`samp'_mvafter1`delta_suf'
        replace cat = "later" if mi(cat)
        replace rel = rel + 0.09 if cat == "later"
        tw rcap ub lb rel if rel != -1.09 & cat == "first",  lcolor(lavender%70) msize(vsmall) || ///
           scatter b rel if cat == "first", mcolor(lavender%70) msize(small) || ///
           rcap ub lb rel if rel != -0.91 & cat == "later",  lcolor(orange%70) msize(vsmall) || ///
           scatter b rel if cat == "later", mcolor(orange%70) msymbol(smdiamond) msize(small) /// 
           xlab(-`timeframe'(1)`timeframe', labsize(vsmall)) ylab(-`ymax'(`ygap')`ymax', labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(gs12) lpattern(dash))  ///
              legend(on order(2 "First-Time Movers (N = `first_move_num_movers')" 4 "Repeat Movers (N = `later_move_num_movers')") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("`yvar_name'", size(vsmall))
        graph export ../output/figures/`fol'/es`startyr'_`endyr'_`samp'_which_move`delta_suf'.pdf, replace
    }
end

program output_tables
    syntax, samp(str)
    foreach file in stat mvr_stats { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }
end

program coathr_locs
    syntax, samp(str)
    use ../temp/mover_temp_`samp', clear
    keep if analysis_cond == 1
    gcontract athr_id year move_year
    drop _freq
    save ../temp/samp_restrict_`samp', replace 

    use if analysis_cond == 1 & origin == 1 using ../temp/mover_temp_`samp' , clear  
    replace move_year = move_year + 3
    gcontract athr_id inst_id msa_comb 
    gisid athr_id
    rename athr_id focal_id
    rename msa_comb origin_msa
    rename inst_id origin_inst
    drop _freq
    save ../temp/mover_origin_`samp', replace

    use if analysis_cond == 1 & dest == 1 using ../temp/mover_temp_`samp' , clear  
    replace move_year = move_year + 3
    gcontract athr_id inst_id msa_comb
    gisid athr_id
    rename athr_id focal_id
    rename msa_comb dest_msa
    rename inst_id dest_inst
    drop _freq
    save ../temp/mover_dest_`samp', replace

    use ../external/openalex/cleaned_all_15jrnls.dta, clear
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    keep if country_code == "US"
    gcontract pmid year athr_id inst_id msa_comb
    merge m:1 athr_id year using ../temp/samp_restrict_`samp', keep(3) nogen
    drop _freq
    rename athr_id focal_id
    save ../temp/focal_list_`samp', replace
    use ../external/openalex/cleaned_all_15jrnls.dta, clear
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    keep if country_code == "US"
    gcontract pmid year athr_id inst_id msa_comb
    drop _freq
    rename inst_id coathr_inst
    rename msa_comb coathr_msa
    save ../temp/coauthors_`samp', replace

    use ../temp/focal_list_`samp', clear
    joinby pmid using ../temp/coauthors_`samp'
    drop if focal_id == athr_id
    gcontract focal_id year athr_id inst_id msa_comb coathr* move_year
    drop _freq
    merge m:1 focal_id using ../temp/mover_origin_`samp', assert(1 2 3) keep(3) nogen
    merge m:1 focal_id using ../temp/mover_dest_`samp', assert(1 2 3) keep(3) nogen
    bys focal_id year: gen num_coathrs = _N 
    gen same_inst = inst_id == coathr_inst
    gen same_msa = msa_comb ==  coathr_msa
    gen same_origin_inst = origin_inst == coathr_inst
    gen same_dest_inst = coathr_inst == dest_inst 
    gen same_origin_msa = origin_msa == coathr_msa
    gen same_dest_msa = coathr_msa == dest_msa 
    gen rel = year - move_year 
    gcollapse (sum) same* (mean) num_coathrs (mean) move_year, by(focal_id rel)
    foreach v in inst msa origin_inst dest_inst origin_msa dest_msa {
        gen share_`v' = same_`v'/num_coathrs
    }
    gcollapse (mean) share*, by(rel)
    tw (line share_origin_inst rel if inrange(rel,-10,10), lcolor(lavender%70))  ///
        (line share_dest_inst rel if inrange(rel,-10,10), lcolor(orange%70))   ///
        (scatteri 1 3 0 3, recast(line) lwidth(vthin) lpattern(dash) lcolor(ebblue))  ///
        (scatteri 1 0 0 0, recast(line) lwidth(vthin) lpattern(dash) lcolor(gs12)),  ///
        xlabel(-10(1)10, labsize(vsmall)) ylabel(0(0.1)1, labsize(vsmall)) ///
        xtitle("Relative Year to Move", size(vsmall)) ytitle("Share of co-authors", size(vsmall)) ///
        legend(on order(1 "Co-authors from Origin Institution" 2 "Co-authors from Destination Institution" 3 "First Publication Affiliated with Destination" 4 "Move") pos(11) ring(0) size(vsmall) region(fcolor(none))) 
    graph export ../output/figures/coauthor_same_inst_`samp'.pdf, replace
    tw (line share_origin_msa rel if inrange(rel,-10,10), lcolor(lavender%70))  ///
        (line share_dest_msa rel if inrange(rel,-10,10), lcolor(orange%70))  ///
        (scatteri 1 3 0 3, recast(line) lwidth(vthin) lpattern(dash) lcolor(ebblue))  ///
        (scatteri 1 0 0 0, recast(line) lwidth(vthin) lpattern(dash) lcolor(gs12)),  ///
        xlabel(-10(1)10, labsize(vsmall)) ylabel(0(0.1)1, labsize(vsmall)) ///
        xtitle("Relative Year to Move", size(vsmall)) ytitle("Share of co-authors", size(vsmall)) ///
        legend(on order(1 "Co-authors from Origin City" 2 "Co-authors from Destination City" 3 "First Publication Affiliated with Destination" 4 "Move") pos(11) ring(0) size(vsmall) region(fcolor(none))) 
    graph export ../output/figures/coauthor_same_msa_`samp'.pdf, replace
    tw (line share_inst rel if inrange(rel,-10,10), lcolor(lavender%70)) ||  ///
        (line share_msa rel if inrange(rel,-10,10), lcolor(orange%70)) ///
        (scatteri 1 3 0 3, recast(line) lwidth(vthin) lpattern(dash) lcolor(ebblue))  ///
        (scatteri 1 0 0 0, recast(line) lwidth(vthin) lpattern(dash) lcolor(gs12)),  ///
        xlabel(-10(1)10, labsize(vsmall)) ylabel(0(0.1)1, labsize(vsmall)) ///
        xtitle("Relative Year to Move", size(vsmall)) ytitle("Share of co-authors", size(vsmall)) ///
        legend(on order(1 "Co-authors from Same Institution" 2 "Co-authors from Same City" 3 "First Publication Affiliated with Destination" 4 "Move") pos(11) ring(0) size(vsmall) region(fcolor(none))) 
    graph export ../output/figures/coauthor_same_geo_`samp'.pdf, replace
end
program coathr_prod
    syntax, samp(str)
    use ../temp/mover_temp_`samp', clear
    local fes "year athr_fes = athr_id"
    keep if analysis_cond == 1
    gcontract athr_id year move_year
    drop _freq
    save ../temp/samp_restrict_movers, replace 

    use ../external/openalex/cleaned_all_15jrnls.dta, clear
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    keep if country_code == "US"
    gcontract pmid year athr_id inst_id msa_comb 
    merge m:1 athr_id year using ../temp/samp_restrict_movers, keep(3) nogen
    drop _freq
    rename athr_id focal_id
    save ../temp/focal_list_movers, replace
    use ../external/openalex/cleaned_all_15jrnls.dta, clear
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    keep if country_code == "US"
    gcontract pmid year athr_id inst_id msa_comb
    drop _freq
    rename inst_id coathr_inst
    rename msa_comb coathr_msa
    rename athr_id coathr_id
    save ../temp/coauthors_movers, replace

    use ../temp/focal_list_movers, clear
    merge m:1 focal_id using ../temp/mover_origin_`samp', assert(1 2 3) keep(3) nogen
    joinby pmid using ../temp/coauthors_movers
    drop if focal_id == coathr_id
    gcontract focal_id year coathr_id move_year  origin_inst inst_id
    drop _freq
    gen same_origin = origin_inst == inst_id 
    bys coathr_id:  egen comes_from_same = max(same_origin)
    keep if comes_from_same == 1
    rename focal_id athr_id
    merge m:1 athr_id  year using ../output/stars_inst_id_`samp', assert(1 2 3) keep(1 3) 
    gen star = _merge ==3
    drop _merge
    rename athr_id mover_id
    rename coathr_id athr_id
    gcontract athr_id mover_id move_year star
    drop _freq
    bys athr_id : gen num_mover_coathrs = _N
    bys athr_id : egen num_star_coathrs = total(star)
    keep if num_mover_coathrs == 1
    save ../temp/coathr_mover_list, replace
    keep if num_star_coathrs == 1
    save ../temp/coathr_star_list, replace

    local yvar ln_y 
    local yvar_name "Log Output"
    use if analysis_cond == 0 & inrange(year, 1945, 2023)  using ../temp/mover_temp_`samp' , clear  
    drop move_year
    merge m:1 athr_id using ../temp/coathr_mover_list, assert(1 2 3) keep(3) nogen
    hashsort athr_id year
    gen rel = year - move_year
    replace rel = -10 if rel <=-10 
    replace rel = 10 if rel >= 10
    hashsort athr_id year
    gegen msa = group(msa_comb)
    cap drop inst
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/10 {
        gen lag`i' = 1 if rel == `i'
        gen lead`i' = 1 if rel == -`i'
    }
    gen lag0 = 1 if rel == 0
    ds lead* lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
    }
    local leads
    local lags
    forval i = 2/10 {
        local leads lead`i' `leads' 
    }
    forval i = 0/10 {
        local lags  `lags' lag`i'
    }
    gunique athr_id 
    local num_movers = r(unique)
	by athr_id: gen counter = _n == 1
    // baseline Event Study
    local suf = ""
    preserve
    mat drop _all
    reghdfe `yvar' `leads' `lags' lead1 , absorb(`fes') vce(cluster inst)
    gunique athr_id  if !mi(`delta')

    local num_movers =r(unique) 
    foreach var in `leads' `lags' lead1 {
        mat row = _b[`var'], _se[`var']
        if "`var'" == "lead1" {
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
    gen rel = -10 if _n == 1
    replace rel = rel[_n-1]+ 1 if _n > 1
    replace rel = rel+ 1 if rel >= -1
    replace rel = -1 if rel == 10+1
    sum b if inrange(rel, -10,-2)
    local pre_mean : di %3.2f r(mean)
    sum b if inrange(rel, 1,10)
    local post_mean : di %3.2f r(mean)
        tw rcap ub lb rel if rel != -1,  lcolor(ebblue%50) msize(vsmall) || scatter b rel if se !=0 | rel == -1, msize(small) mcolor(ebblue%50) xlab(-10(1)10, labsize(vsmall)) ylab(-1(0.1)1, labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(-0.5, lcolor(gs12) lpattern(dash))  ///
          legend(on order(- "N (Movers) = `num_movers'" ///
                                                            "Pre-period mean = `pre_mean'" ///
                                                            "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Output", size(vsmall))
        graph export ../output/figures/main/es1945_2023_`samp'`suf'_coauthor.pdf, replace
    restore
    use if analysis_cond == 0 & inrange(year, 1945, 2023)  using ../temp/mover_temp_`samp' , clear  
    drop move_year
    merge m:1 athr_id using ../temp/coathr_star_list, assert(1 2 3) keep(3) nogen
    hashsort athr_id year
    gen rel = year - move_year
    replace rel = -10 if rel <=-10 
    replace rel = 10 if rel >= 10
    hashsort athr_id year
    cap drop inst
    gegen msa = group(msa_comb)
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/10 {
        gen lag`i' = 1 if rel == `i'
        gen lead`i' = 1 if rel == -`i'
    }
    gen lag0 = 1 if rel == 0
    ds lead* lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
    }
    local leads
    local lags
    forval i = 2/10 {
        local leads lead`i' `leads' 
    }
    forval i = 0/10 {
        local lags  `lags' lag`i'
    }
    gunique athr_id 
    local num_movers = r(unique)
	by athr_id: gen counter = _n == 1
    // baseline Event Study
    local suf = ""
    preserve
    mat drop _all
    reghdfe `yvar' `leads' `lags' lead1 , absorb(`fes') vce(cluster inst)
    gunique athr_id 
    local num_movers = r(unique)
    foreach var in `leads' `lags' lead1 {
        mat row = _b[`var'], _se[`var']
        if "`var'" == "lead1" {
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
    gen rel = -10 if _n == 1
    replace rel = rel[_n-1]+ 1 if _n > 1
    replace rel = rel+ 1 if rel >= -1
    replace rel = -1 if rel == 10+1
    sum b if inrange(rel, -10,-2)
    local pre_mean : di %3.2f r(mean)
    sum b if inrange(rel, 1,10)
    local post_mean : di %3.2f r(mean)
        tw rcap ub lb rel if rel != -1,  lcolor(ebblue%50) msize(vsmall) || scatter b rel if se !=0 | rel == -1, msize(small) mcolor(ebblue%50) xlab(-10(1)10, labsize(vsmall)) ylab(-2(0.2)1, labsize(vsmall)) ///
          yline(0, lcolor(black) lpattern(solid)) xline(-0.5, lcolor(gs12) lpattern(dash))  ///
          legend(on order(- "N (Movers) = `num_movers'" ///
                                                            "Pre-period mean = `pre_mean'" ///
                                                            "Post-period mean = `post_mean'") pos(1) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Output", size(vsmall))
        graph export ../output/figures/main/es1945_2023_`samp'`suf'_coauthor_star.pdf, replace
    restore
end
** 
main
