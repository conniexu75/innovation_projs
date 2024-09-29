set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global temp "/export/scratch/cxu_sci_geo/age_cohort"
global all_fund "/export/scratch/cxu_sci_geo/scrape_full_pmids"
global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
global years "/export/scratch/cxu_sci_geo/append_all_pprs/output"
global y_name "Productivity"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Productivity"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year 

program main
*    get_athr_prod
    foreach t in year year_firstlast {
        *find_age, samp(`t')
        *make_movers, samp(`t')
        *sum_stats, samp(`t')
        *qui output_tables, samp(`t')
        *event_studies, samp(`t')
    }
    plot_prod_profile
end

program get_athr_prod
    use ../external/samp/cleaned_all_all_jrnls.dta, clear
    gcollapse (count) num_pprs = pmid (sum) cite_affl_wt body_adj_wt impact_affl_wt affl_wt impact_cite_affl_wt, by(athr_id year)
    compress, nocoalesce
    save ${temp}/athr_prod_year, replace
    use ../external/first_last/cleaned_all_all_jrnls.dta, clear
    gcollapse (count) num_pprs = pmid (sum) cite_affl_wt body_adj_wt impact_affl_wt affl_wt impact_cite_affl_wt, by(athr_id year)
    compress, nocoalesce
    save ${temp}/athr_prod_year_firstlast, replace

    use ${all_fund}/output/openalex_all_jrnls_merged, clear 
    gen date = date(pub_date, "YMD")
    gen year = yofd(date)
    gcontract athr_id year
    drop _freq
    bys athr_id: egen first_fund_ppr = min(year)
    gcontract athr_id first_fund_ppr
    drop _freq
    save ${temp}/fund_athr_yr, replace
end

program find_age
    syntax, samp(str)
    // find your publishing birth year first
    use ${${time}s}/appended_athr_yrs, clear
    bys athr_id (year): gen year_rank = _n
    by athr_id: gegen first_pub_yr = min(year)
    by athr_id: gegen last_pub_yr = max(year)
    keep if year_rank == 1 
    gisid athr_id 
    gcontract athr_id first_pub_yr last_pub_yr
    drop _freq
    save ${temp}/athr_first_last_pub, replace

    merge 1:m athr_id using ../temp/athr_prod_`samp', assert(1 2 3) keep(3) nogen 
    bys athr_id : egen first_yr_in_top15 = min(year)
    gcontract athr_id first_pub_yr last_pub_yr first_yr_in_top15
    drop _freq
    merge 1:1 athr_id using ../external/dissertation/appended_pprs, assert(1 2 3) keep(1 3) nogen
    gunique athr_id 
    local N_athrs = r(unique)
    gunique athr_id if !mi(phd_year)
    di "% of US authors with disseration year: " r(unique)/`N_athrs'*100
    gunique athr_id if dissertation_tag == 1  
    di "% of US authors with disseration tag: " r(unique)/`N_athrs'*100
    gunique athr_id if dissertation_tag == 0 & strpos(lwr_title, "dissertation")>0 | strpos(lwr_title, "thesis")>0  
    di "% of US authors with disseration title " r(unique)/`N_athrs'*100
    gen year_since_first_pub = 2024-first_pub_yr + 1 
    gen publishing_lifespan= last_pub_yr-first_pub_yr + 1 
    gen post_phd = phd_year - first_pub_yr + 1
    gen post_phd_lifespan = last_pub_yr - phd_year + 1  
    gen top15_post_phd = phd_year - first_yr_in_top15+1 
    gen top15_pub_diff = first_yr_in_top15 - first_pub_yr + 1 
    gegen publishing_lifespan99 = pctile(publishing_lifespan), p(99)
    gegen post_phd_lifespan99 = pctile(post_phd_lifespan), p(99)
    gen windsorize = publishing_lifespan >= publishing_lifespan99 | (post_phd_lifespan >= post_phd_lifespan99 & !mi(phd_year))
    foreach var in first_pub_yr last_pub_yr phd_year year_since_first_pub publishing_lifespan post_phd post_phd_lifespan first_yr_in_top15 top15_post_phd top15_pub_diff {
        replace `var' = . if windsorize == 1  
    }
    gen cohort_bin = floor(phd_year/10)*10
    replace cohort_bin = cohort_bin + 5 if phd_year >= cohort_bin+5
    gisid athr_id
    preserve
    merge 1:m athr_id using ../temp/athr_prod_`samp', assert(1 2 3) keep(3) nogen 
    gen pub_age = year - first_pub_yr + 25  
    drop if mi(pub_age)
    replace pub_age = 25 if pub_age < 25 
    bys pub_age athr_id: gen athr_cnt = _n == 1
    gcollapse (sum) athr_cnt (mean) num_pprs cite_affl_wt body_adj_wt impact_affl_wt affl_wt impact_cite_affl_wt, by(pub_age)
    save ../temp/age_prod_`samp', replace
    restore
    preserve
    merge 1:m athr_id using ../temp/athr_prod_`samp', assert(1 2 3) keep(3) nogen 
    keep if !mi(phd_year)
    gen phd_age = year - phd_year + 30 if !mi(phd_year)
    bys phd_age athr_id: gen athr_cnt = _n == 1
    gcollapse (sum) athr_cnt (mean) num_pprs cite_affl_wt body_adj_wt impact_affl_wt affl_wt impact_cite_affl_wt, by(phd_age)
    save ../temp/phd_age_prod_`samp', replace
    restore
    preserve
    merge 1:m athr_id using ../temp/athr_prod_`samp', assert(1 2 3) keep(3) nogen 
    keep if mi(phd_year)
    gen phd_age = year - first_pub_yr + 25 
    replace phd_age = 25 if phd_age < 25 
    bys phd_age athr_id: gen athr_cnt = _n == 1
    gcollapse (sum) athr_cnt (mean)  cite_affl_wt body_adj_wt impact_affl_wt affl_wt impact_cite_affl_wt num_pprs, by(phd_age)
    drop if mi(phd_age)
    save ../temp/no_phd_age_prod_`samp', replace
    restore
    compress, nocoalesce
    save ../temp/age_`samp', replace
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
    gcontract athr_id move_year num_moves 
    drop _freq
    drop if mi(move_year)
    drop if num_moves <= 0
    save ../temp/movers, replace
    
    use if !mi(msa_comb) & !mi(inst_id) using ../external/panel/athr_panel_full_comb_`samp', clear 
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
    bys inst_id year: egen has_mover = max(mover == 1)
    drop if has_mover == 0
    gen analysis_cond = mover == 1 & num_moves == 1 & ((mover == 0 & _merge == 1) | (mover == 1 & _merge == 3))
    drop _merge
    save ${temp}/mover_temp_`samp' , replace
end

program sum_stats
    syntax, samp(str)
    use ${temp}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/age_`samp', assert(1 2 3) keep(3) nogen
    // plot stats at the author level
    preserve
    gcontract athr_id analysis_cond year_since_first_pub publishing_lifespan post_phd top15_post_phd phd_year first_pub_yr first_yr_in_top15 last_pub_yr top15_pub_diff post_phd_lifespan
    drop _freq
    gisid athr_id
    corr first_pub_yr phd_year
    local n = r(N)
    local corr: di %3.2f r(rho) 
    binscatter2 first_pub_yr phd_year, xtitle("PhD Graduation Year", size(small)) ytitle("Publishing Birth Year", size(small)) legend(on  order(- "N = `n'" "corr. = `corr'") pos(11) ring(0) region(fcolor(none)) size(small)) xlab(1945(5)2022, labsize(small)) ylab(1945(5)2022, labsize(small))
    graph export ../output/figures/bs_phd_pub_yr.pdf, replace 
    gisid athr_id 
    local gap 5
    local pos 10
    foreach var in phd_year first_pub_yr year_since_first_pub post_phd top15_post_phd first_yr_in_top15 top15_pub_diff {
        sum `var', d
        local min_year = r(min)
        local max_year = r(max)
        qui sum `var' if analysis_cond == 1 , d
        local mover_mean: di %3.2f r(mean)
        local mover_med: di %3.2f r(p50)
        local mover_N = r(N)
        qui sum `var' if analysis_cond == 0 , d
        local nonmover_mean: di %3.2f r(mean)
        local nonmover_med: di %3.2f r(p50)
        local nonmover_N = r(N)
        if "`var'" == "phd_year" local xtit = "PhD Graduation Year"
        if "`var'" == "first_pub_yr" {
            local xtit = "Publishing Birth Year"
            local gap = 10
        }
        if "`var'" == "first_yr_in_top15" {
            local xtit = "Top 15 First/Last Author Publishing Birth Year"
            local gap = 4 
            local pos = 11
        }
        if "`var'" == "year_since_first_pub" {
            local xtit = "Publishing Age (2023-Publishing Birth Year)"
            local gap = 10
            local pos = 1
        }
        if "`var'" == "post_phd" {
            local xtit = "PhD Graduation Year - Publishing Birth Year"
            local gap = 10
        }
        if "`var'" == "top15_post_phd" {
            local xtit = "PhD Graduation Year - Top 15 First/Last Author Publishing Birth Year"
            local gap = 10
        }
        if "`var'" == "top15_pub_diff" {
            local xtit = "Years it Takes to Publish in the Top 15"
            local gap = 10
            local pos = 1
        }
        tw hist `var' if analysis_cond == 1 , frac color(eltgreen%60) xline(`mover_mean', lcolor(eltgreen) lpattern(dash)) || ///
           hist `var' if analysis_cond == 0, frac color(dkorange%60)  xline(`nonmover_mean', lcolor(dkorange) lpattern(dash)) ///
           ytitle("Share of authors", size(vsmall)) xtitle("`xtit'", size(vsmall)) xlab(`min_year'(`gap')`max_year', labsize(vsmall) angle(45)) ylab(, labsize(vsmall)) ///
           legend(on label(1 "Movers: " "N = `mover_N'" "mean = `mover_mean'" "median = `mover_med'") label(2 "Nonmovers: " "N = `nonmover_N'" "mean = `nonmover_mean'" "median = `nonmover_med'") pos(`pos') ring(0) size(vsmall) region(fcolor(none)))
        graph export ../output/figures/`var'_dist_`samp'.pdf, replace
    }
    restore

    // create tables of phd_year ?
    preserve
    gcontract athr_id cohort_bin
    drop _freq
    drop if mi(cohort_bin)
    gcontract cohort_bin, freq(num_athrs)
    sum num_athrs
    gen perc = num_athrs/r(sum)*100
    mkmat cohort_bin num_athrs perc, mat(cohort_dist_`samp')
    restore

    preserve
    gcontract athr_id year_since_first_pub 
    drop _freq
    gcontract year_since_first_pub, freq(num_athrs)
    sum num_athrs
    gen perc = num_athrs/r(sum)*100
    mkmat year_since_first_pub num_athrs perc, mat(pub_age_dist_`samp')
    restore
    
    gen patented = pat_wt > 0
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_patent = ln(pat_adj_wt)
    rename impact_cite_affl_wt y
    rename msa_size x

    // individual level stats
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
    }
    gcontract athr_id avg_ln_y_diff avg_ln_x_diff msa_ln_y_diff msa_ln_x_diff move_year
    drop _freq
    drop if mi(avg_ln_y_diff)
    save ../temp/dest_origin_changes, replace
end

program event_studies 
    syntax, samp(str) 
    cap mat drop _all  
    use if analysis_cond == 1 using ${temp}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../temp/mover_xw, assert(1 2 3) keep(3) nogen
    merge m:1 athr_id using ../temp/age_`samp', assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year year_since_first_pub publishing_lifespan post_phd top15_post_phd phd_year first_pub_yr first_yr_in_top15 last_pub_yr top15_pub_diff post_phd_lifespan cohort_bin
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ../temp/dest_origin_changes, keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/10 {
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
    forval i = 1/10 {
        local leads `leads' lead`i'
        local lags lag`i' `lags'
    }
    gunique athr_id 
    local num_movers = r(unique)
    // assume you're 25 when you first publish 
    // assume you're 28 when you graduate your phd
    gen move_age_pub = move_year - first_pub_yr  + 1 + 25
    gen move_age_phd = move_year - phd_year + 1 + 28 
*    replace move_age_phd = . if move_age_phd <=0 
    bys athr_id: gen counter = _n == 1
    corr move_age_pub move_age_phd if counter == 1  
    local n = r(N)
    local corr: di %3.2f r(rho) 
    binscatter2 move_age_pub move_age_phd if counter == 1 , xtitle("Move Age (based on PhD)", size(small)) ytitle("Move Age (based on Publishing Birth Year)", size(small)) legend(on  order(- "N = `n'" "corr. = `corr'") pos(11) ring(0) region(fcolor(none)) size(small)) xlab(, labsize(small)) ylab(, labsize(small))
    graph export ../output/figures/bs_phd_pub_move_yr.pdf, replace 
    foreach var in move_age_pub move_age_phd {
        sum `var' if counter == 1 , d
        local N = r(N)
        local median : dis %3.2f r(p50) 
        local mean : dis %3.2f r(mean)
        tw hist `var' if counter == 1 & `var' > 0, frac ytitle("Share of movers", size(vsmall)) xtitle("Move Age", size(vsmall)) color(edkblue) legend(on order(- "N = `N'" ///
                        "Mean = `mean'" ///
                        "Median = `median'") pos(1) ring(0) size(vsmall) region(fcolor(none))) xlab(, labsize(vsmall)) ylab(, labsize(vsmall))
        graph export ../output/figures/`var'.pdf, replace
    }
    qui sum move_age_pub if counter == 1, d
    gen old = move_age_pub >= r(p50) 
    gen young = move_age_pub < r(p50) 
    qui sum move_age_phd if counter == 1 & !mi(move_age_phd), d
    gen old_phd = move_age_phd >= r(p50) if !mi(move_age_phd)
    gen young_phd = move_age_phd < r(p50) if !mi(move_age_phd)
    foreach stem in "" "_phd"  {
        sum msa_ln_y_diff if old`stem' == 1 & counter == 1
        local N_old = r(N)
        local mean_old :di %3.2f r(mean)
        sum msa_ln_y_diff if young`stem' == 1& counter == 1
        local N_young = r(N)
        local mean_young : di %3.2f r(mean)
        graph tw hist msa_ln_y_diff if old`stem' == 1& counter == 1 , frac color(edkblue) xline(`mean_old', lpattern(dash)) || ///
           hist msa_ln_y_diff if young`stem' == 1 & counter == 1 , frac color(lavender%50) xline(`mean_young', lpattern(dash)) ytitle("Share of movers", size(vsmall)) xtitle("Destination-Origin Diff in Log Productivity", size(vsmall))  legend(on order(- "N Old = `N_old'" ///
                        "Mean Old = `mean_old'" ///
                        "N Young = `N_young'" ///
                        "Mean Young = `mean_young'") pos(1) ring(0) size(vsmall) region(fcolor(none))) xlab(, labsize(vsmall)) ylab(, labsize(vsmall))

        graph export ../output/figures/move_size`stem'.pdf, replace
        foreach c in "inrange(rel, -10,10) & old`stem' ==1" "inrange(rel, -10,10) & young`stem' == 1" { 
            cap mat drop _all 
            local timeframe 10
            preserve
            if "`c'" == "inrange(rel, -10,10) & old`stem' ==1" local suf = "old" 
            if "`c'" == "inrange(rel, -10,10) & young`stem' == 1" local suf = "young" 
            reghdfe ln_y `lags' treat `leads' if `c' , absorb(field#year athr_id) vce(cluster inst)
            gunique athr_id if `c'
            local num_movers = r(unique)
            local normalize = _b[lag1]
            foreach var in `lags' treat `leads' {
                mat row = _b[`var']-`normalize', _se[`var']
                if "`var'" == "lag1" {
                    mat row = _b[`var']-`normalize',0
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
            drop if rel ==`timeframe' 
            sum b if inrange(rel, -`timeframe',-2)
            local pre_mean : di %3.2f r(mean)
            sum b if inrange(rel, 1,`timeframe')
            local post_mean : di %3.2f r(mean)
            local end = `timeframe' - 1
            replace lb = -1 if lb < -1
            replace ub = 1 if ub > 1
            tw rcap ub lb rel if rel != -1 & se!= 0,  lcolor(gs12) msize(vsmall) || scatter b rel if (se !=0 | rel == -1) , mcolor(ebblue) xlab(-10(1)`end', angle(45) labsize(vsmall)) ylab(-1(0.2)1, labsize(vsmall)) ///
              yline(0, lcolor(black) lpattern(solid)) xline(0, lcolor(purple%50) lpattern(dash)) plotregion(margin(none)) ///
              legend(on order(- "N (Movers) = `num_movers'" ///
                                                                "Pre-period mean = `pre_mean'" ///
                                                                "Post-period mean = `post_mean'") pos(5) ring(0) size(vsmall) region(fcolor(none))) xtitle("Relative Year to Move", size(vsmall)) ytitle("Log Productivity", size(vsmall))
            graph export ../output/figures/es_`samp'_`suf'`stem'.pdf, replace
            restore
        }
    }
end

program plot_prod_profile
    use ../temp/age_prod_year, clear
    gen grp = "year"
    append using ../temp/age_prod_year_firstlast
    replace grp = "year_firstlast" if mi(grp)
    gen cohort_bin = floor(pub_age/10)*10
    replace cohort_bin = cohort_bin + 5 if pub_age >= cohort_bin+5
    foreach var in impact_cite_affl_wt body_adj_wt num_pprs {
        local ylab "0(0.1)1.4"
        if "`var'" == "impact_cite_affl_wt"  local ytit "Average Life Sciences Productivity (Top 15)"
        if "`var'" == "body_adj_wt" local ytit "Paper to Patent Productivity (Top 15)"
        if "`var'" == "num_pprs" {
            local ytit "Total Publications in (Top 15)" 
            local ylab "1(0.05)1.5"
        }
        heatplot athr_cnt `var' pub_age if grp == "year", discrete scatter colors(blues, ipolate(20)) p(mlc(black)) legend(off) ytitle(`ytit', size(vsmall)) xtitle("Age", size(vsmall)) xlab(25(5)150, labsize(vsmall)) ylab(`ylab', labsize(vsmall)) 
        graph export ../output/figures/pub_age_`var'_profile_year.pdf, replace
        heatplot athr_cnt `var' pub_age if grp == "year_firstlast", discrete scatter colors(blues, ipolate(20)) p(mlc(black)) legend(off) ytitle(`ytit', size(vsmall)) xtitle("Age", size(vsmall)) xlab(25(5)150, labsize(vsmall)) ylab(`ylab', labsize(vsmall)) 
        graph export ../output/figures/pub_age_`var'_profile_year_firstlast.pdf, replace
        preserve
        if "`var'" != "num_pprs" local ylab "0(0.1)1.4"
        gen num = `var' * athr_cnt
        bys cohort_bin grp : egen tot_athrs = total(athr_cnt)
        bys cohort_bin grp : egen tot_num = total(num)
        gen mean_prod = tot_num/tot_athrs
        gcollapse (mean) mean_prod (sum) athr_cnt, by(cohort_bin grp)
        tw scatter mean_prod cohort_bin if grp == "year", mcolor(edkblue) || scatter mean_prod cohort_bin if grp == "year_firstlast", mcolor(dkorange) ytitle(`ytit', size(vsmall)) xtitle("Age", size(vsmall)) xlab(0(5)150, labsize(vsmall)) ylab(`ylab', labsize(vsmall)) legend(on label(1 "All Authors") label(2 "First & Last Authors") size(tiny) pos(11) ring(0) lwidth(none)region(fcolor(none)))
        graph export ../output/figures/cohort_`var'_profile.pdf, replace
        restore
    }
/*    use ../temp/phd_age_prod_year, clear
    replace phd_age = phd_age 
    gen grp = "phd"
    gen cohort_bin = floor(phd_age/10)*10
    replace cohort_bin = cohort_bin + 5 if phd_age >= cohort_bin+5
    foreach var in impact_cite_affl_wt body_adj_wt num_pprs {
        local ylab "0(0.05)0.6"
        if "`var'" == "impact_cite_affl_wt"  local ytit "Average Life Sciences Productivity (Top 15)"
        if "`var'" == "body_adj_wt" local ytit "Paper to Patent Productivity (Top 15)"
        if "`var'" == "num_pprs" {
            local ytit "Total Publications in (Top 15)" 
            local ylab "1(0.05)1.5"
        }
        heatplot athr_cnt `var' phd_age if grp == "phd" & phd_age >= 15, discrete scatter colors(blues, ipolate(20)) p(mlc(black)) legend(off) ytitle(`ytit', size(vsmall)) xtitle("Age", size(vsmall)) xlab(15(10)100, labsize(vsmall)) ylab(`ylab', labsize(vsmall)) 
        graph export ../output/figures/phd_age_`var'_profile_year.pdf, replace
    }*/
end

program output_tables
    syntax, samp(str)
    foreach file in cohort_dist pub_age_dist { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }

end
** 
main
