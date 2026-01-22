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
/*    qui get_full_mover_picture
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
    save ../temp/merged_data, replace*/

    foreach t in year_second  { 
        di "SAMP: `t'"
/*        cns_Output, samp(`t')
        qui make_movers, samp(`t')
        make_dest_origin, samp(`t')*/
        trends
    }
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
    use athr_id field msa_comb year inst_id inst msa_size impact_cite_affl_wt cite_affl_wt affl_wt impact_affl_wt avg_* sec* cns ppr_cnt unique_* if !mi(msa_comb) & !mi(inst_id) using ../external/samp/athr_panel_full_comb_`samp', clear 
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
    mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ r(N)
    foreach var in num_years avg_team_size x y life_time_prod num_moves {
        sum `var', d
        mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(mean) \ r(sd))
        if "`var'" == "y" {
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p75) \ r(sd))
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p90) \ r(sd))
        }
    }
    count if mover == 0 
    mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ r(N)
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if mover == 0 , d
        mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(mean) \ r(sd))
        if "`var'" == "y" {
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p75) \ r(sd))
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p90) \ r(sd))
        }
    } 
    count if mover == 1
    mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ r(N)
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if mover == 1 , d
        mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(mean) \ r(sd))
        if "`var'" == "y" {
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p75) \ r(sd))
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p90) \ r(sd))
        }
    }
    count if analysis_cond == 1 
    mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ r(N)
    foreach var in num_years avg_team_size x y life_time_prod {
        sum `var' if analysis_cond == 1  , d
        mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(mean) \ r(sd))
        if "`var'" == "y" {
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p75) \ r(sd))
            mat ind_stats_`samp' = nullmat(ind_stats_`samp') \ (r(p90) \ r(sd))
        }
    }
    restore

    preserve
    gen life_time_prod = y
    bys msa_comb inst_id: gen inst_cntr = _n == 1
    bys msa_comb: egen num_insts = total(inst_cntr)
    gcollapse (mean) x y num_insts (sum) life_time_prod, by(inst_id)
    count
    foreach var in num_insts y life_time_prod {
        qui sum `var' , d
        mat city_stats_`samp' = nullmat(city_stats_`samp') \ (r(mean) \  r(sd))
        if "`var'" == "y" {
            mat city_stats_`samp' = nullmat(city_stats_`samp') \ (r(p75) \ r(sd))
            mat city_stats_`samp' = nullmat(city_stats_`samp') \ (r(p90) \ r(sd))
        }
    }
    restore
    mat stat_`samp' = ind_stats_`samp' \ city_stats_`samp' 
end 

program make_dest_origin
    syntax, samp(str)
    use ../temp/mover_temp_`samp' , clear  
    drop if year  == move_year & mover == 1
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_nocite = ln(impact_affl_wt)
    gen ln_none = ln(cite_affl_wt)
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
        gen `suf'_sum_ln_none= ln_none
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
        collapse (mean) ln_cns_y prob_cns avg_yr_ln_nocite = ln_nocite avg_yr_ln_none = ln_none avg_yr_ln_y  = ln_y avg_yr_stars = stars ln_x `suf'_athr_cnt `suf'_star_cnt cns_athr (sum)`suf'_sum_ln_nocite `suf'_sum_ln_none `suf'_sum_ln_y star_`suf'_sum_ln_y `suf'_athr_cnt_id star_`suf'_athr_cnt_id `suf'_y = y (firstnm) msa inst , by(`loc' ${time}) 
        save ../temp/`suf'_year_`samp'_collapsed, replace
        collapse (mean) `suf'_ln_cns_y = ln_cns_y `suf'_prob_cns = prob_cns `suf'_ln_nocite = avg_yr_ln_nocite `suf'_ln_none = avg_yr_ln_none `suf'_ln_y = avg_yr_ln_y star_`suf'_ln_y = avg_yr_stars `suf'_ln_x = ln_x `suf'_athr_cnt `suf'_star_cnt `suf'_cns_athr = cns_athr (sum) `suf'_sum_ln_y star_`suf'_sum_ln_y `suf'_sum_ln_nocite `suf'_sum_ln_none `suf'_y (firstnm) msa inst (min) min_year=year (max) max_year = year, by(`loc')
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
    gen ln_none = ln(cite_affl_wt)
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
    foreach var in ln_x ln_y ln_nocite {
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
    bys inst_id: egen old_num_none = total(avg_yr_ln_none * tag)
    bys inst_id: egen old_star_num = total(avg_yr_stars * tag)
    gen excluded_tot = inst_y - y
    gen excluded_mean = (inst_sum_ln_y - ln_y)/(inst_athr_cnt_id - 1)
    gen excluded_nocite_mean = (inst_sum_ln_nocite - ln_nocite)/(inst_athr_cnt_id - 1)
    gen excluded_none_mean = (inst_sum_ln_none - ln_none)/(inst_athr_cnt_id - 1)
    gen excluded_star_mean = (star_inst_sum_ln_y - ln_y)/(star_inst_athr_cnt_id - 1)
    gen new_num = old_num + (excluded_mean - avg_yr_ln_y)
    gen new_num_nocite = old_num_nocite + (excluded_nocite_mean - avg_yr_ln_nocite)
    gen new_num_none = old_num_none + (excluded_none_mean - avg_yr_ln_none)
    gen new_star_num = old_star_num + (excluded_star_mean - avg_yr_stars) if stars == 1
    replace new_star_num = old_star_num  if stars != 1
    gen excluded_inst_ln_y = new_num/denom
    gen excluded_inst_ln_nocite = new_num_nocite/denom
    gen excluded_inst_ln_none = new_num_none/denom
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
    foreach var in avg_ln_y avg_ln_nocite excluded_inst_ln_y excluded_star_inst_ln_y excluded_inst_ln_nocite excluded_inst_ln_none inst_ln_nocite inst_ln_none inst_ln_y x inst_ln_x msa_athr_cnt msa_ln_x star_inst_ln_y inst_prob_cns inst_ln_cns_y inst_cns_athr msa_noinst_athr excluded_tot tot_ls nonfed_ls_fund fed_ls_fund {
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
        if inlist("`var'" ,"inst_ln_y" , "star_inst_ln_y", "excluded_inst_ln_y" , "excluded_star_inst_ln_y", "inst_prob_cns", "inst_ln_cns_y", "inst_cns_athr", "excluded_inst_ln_nocite", "excluded_tot") | inlist("`var'", "fed_ls_fund", "tot_ls" , "nonfed_ls_fund","excluded_inst_ln_none") {
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
    binscatter2 avg_ln_nocite_diff inst_ln_nocite_diff,  mcolor(gs5) lcolor(ebblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) xtitle("Destination-Origin Difference in Log Output", size(vsmall)) ytitle("Change in Log Output after Move", size(vsmall)) legend(on order(- "N (Movers) = `N'" ///
                                                            "Slope = `coef'") pos(5) ring(0) size(vsmall) region(fcolor(none)))
    graph export ../output/figures/place_effect_nocite_desc_`samp'.pdf , replace
    
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

program trends 
    use ../temp/mover_temp_year_second, clear
    contract athr_id  move_year
    drop _freq
    merge 1:1 athr_id using ../temp/dest_origin_changes_year_second, assert(1 3) keep(3) nogen 
    gen l2h_move = excluded_inst_ln_y_diff > 0        
    gen h2l_move = excluded_inst_ln_y_diff < 0     
    merge 1:m  athr_id using ../external/athrs/second/cleaned_all_15jrnls, keep(3) nogen
    gen non_top = inlist(jrnl , "PLoS ONE", "The FASEB Journal", "Journal of Biological Chemistry")
    gen num_pubs = 1
    bys athr_id: egen tot_pubs = total(num_pubs)
    gcollapse (sum) num_pubs non_top (mean) move_year tot_pubs h2l, by(athr_id year)
    gen rate = non_top/num_pubs*100
    gen top_rate = 100-rate
    gen rel = year - move_year
    keep if inrange(rel, -10, 10)
    gen sd_rate = rate
    gen sd_top_rate = top_rate 
    preserve
    gcollapse (mean) rate top_rate (sum) num_pubs (sd) sd_rate sd_top_rate [aw = tot_pubs], by(rel h2l_move)
    gen lb = top_rate - 1.96*sd_top_rate/sqrt(num_pubs)
    gen ub = top_rate + 1.96*sd_top_rate/sqrt(num_pubs)
    replace rel = rel +0.1 if h2l_move == 1
    tw rcap ub lb rel if h2l_move == 1, lcolor(lavender) || ///
        line top_rate rel if h2l_move == 1, lcolor(lavender) || ///
        scatter top_rate rel if h2l_move ==1, mcolor(lavender) ||  ///
        rcap ub lb rel if h2l_move == 0, lcolor(dkorange) || ///
        line top_rate rel if h2l_move == 0  , lcolor(dkorange) || ///
        scatter top_rate rel if h2l_move == 0, mcolor(dkorange) xtitle("Year Relative to Move") ytitle("Rate published in top journals") ylab(0(5)50) ///
        xlab(-10(1)10) legend(on order(2 "High to Low Move" 5 "Low to High Move")  pos(7) ring(0))
    graph export ../output/figures/top_pub_rate_wt.pdf, replace
    restore
    preserve
    gcollapse (sum) num_pubs (mean) rate top_rate (sd) sd_rate sd_top_rate , by(rel h2l_move)
    gen lb = top_rate - 1.96*sd_top_rate/sqrt(num_pubs)
    gen ub = top_rate + 1.96*sd_top_rate/sqrt(num_pubs)
    replace rel = rel +0.1 if h2l_move == 1
    tw rcap ub lb rel if h2l_move == 1, lcolor(lavender) || ///
        line top_rate rel if h2l_move == 1, lcolor(lavender) || ///
        scatter top_rate rel if h2l_move ==1, mcolor(lavender) ||  ///
        rcap ub lb rel if h2l_move == 0, lcolor(dkorange) || ///
        line top_rate rel if h2l_move == 0  , lcolor(dkorange) || ///
        scatter top_rate rel if h2l_move == 0, mcolor(dkorange) xtitle("Year Relative to Move") ytitle("Rate published in top journals") ylab(0(5)50) ///
        xlab(-10(1)10) legend(on order(2 "High to Low Move" 5 "Low to High Move")  pos(7) ring(0))
    graph export ../output/figures/top_pub_rate.pdf, replace
    restore

end
** 
main
