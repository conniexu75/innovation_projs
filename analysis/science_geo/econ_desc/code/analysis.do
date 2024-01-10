set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
here, set

program main
    global country_name "countries"
    global us_state_name "US states"
    global area_name "US cities"
    global city_full_name "cities"
    global inst_name "institutions"
    global msatitle_name "MSAs"
    global msa_comb_name "MSAs"
    global msa_world_name "cities"
    global msa_c_world_name "cities"
    di "OUTPUT START"
    foreach athr_type in all {
    if "`athr_type'" == "first_last" local fol "fl"
    if "`athr_type'" == "all" local fol "all"
        foreach var in impact_cite_affl_wt {
            di "ALL: `var'"
            athr_loc, samp(econs) wt_var(`var') fol(`fol')
            qui trends,  samp(econs) wt_var(`var') fol(`fol')

        }
        qui output_tables, samp(econs) fol(`fol')
    }
end

program athr_loc
    syntax,  samp(str)  wt_var(str) fol(str)
    local athr = cond("`fol'" == "fl", "", "_all")
    local suf = ""
    if "`wt_var'" == "cite_affl_wt" local suf "_wt"
    if "`wt_var'" == "impact_affl_wt" local suf "_if"
    if "`wt_var'" == "impact_cite_affl_wt" local suf "_if_wt"
    if "`wt_var'" == "pat_adj_wt" local suf "_pat"
    if "`wt_var'" == "frnt_adj_wt" local suf "_frnt"
    if "`wt_var'" == "body_adj_wt" local suf "_body"
    use ../external/`fol'/cleaned_last5yrs_`samp', clear 
    replace inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    local end 20
    foreach loc in country msa_c_world inst {
        if "`loc'" == "inst" & ("`wt_var'" != "pat_adj_wt" & "`wt_var'" != "body_adj_wt") {
            local end 50
        }
        qui gunique id 
        local articles = r(unique)
        qui sum `wt_var'
        local total = round(r(sum))
        assert `total' == `articles'
        qui sum `wt_var' if !mi(`loc') 
        local denom = r(sum) 
        preserve
        if inlist("`loc'", "us_state", "area", "msatitle", "msa_comb") {
            qui keep if country == "United States"
        }
        collapse (sum) `wt_var', by(`loc')
        qui hashsort -`wt_var' 
        qui gen perc = `wt_var' / `total' * 100
        li if mi(`loc')
        qui drop if mi(`loc')
        qui gen cum_perc = sum(perc) 
        gen rank = _n 
        save ../temp/rankings_`loc'`suf'`athr', replace
        drop rank
        qui count
        local rank_end = min(r(N),`end') 
        li `loc' perc in 1/`rank_end'
        di "Total articles: `total'"
        mkmat perc cum_perc in 1/`rank_end', mat(top_`loc'_`samp'`suf'`athr')
*        mat top_`loc'_`data'_`samp' = nullmat(top_`loc'_`data'_`samp') , (top_`loc'_`samp'`suf')
        qui levelsof `loc' in 1/2
        global top2_`loc' "`r(levels)'"
        if inlist("`loc'", "inst", "city_full", "msatitle","msa_comb", "msaworld", "msa_c_world") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc' "`r(levels)'"
        }
        qui gen rank_grp = "first" if _n == 1
        replace `loc' = "harvard university" if `loc' == "university harvard"
        replace `loc' = "stanford university" if `loc' == "university stanford"
        qui levelsof `loc' if _n == 1 
        global `loc'_first "`r(levels)'"
        qui levelsof `loc' if _n == 2

        global `loc'_second "`r(levels)'"
        qui replace rank_grp = "second" if _n == 2
        qui replace rank_grp = "china" if `loc' == "China"
        qui replace rank_grp = "uk" if `loc' == "United Kingdom"
        qui replace rank_grp = "rest of top 10" if inrange(_n,3,10) & !inlist(rank_grp,"china", "uk")
        qui replace rank_grp = "remaining" if mi(rank_grp)
        keep `loc' rank_grp
        qui save ../temp/`loc'_rank_`samp'`suf'`athr', replace
        restore
    }
end

program trends
    syntax, samp(str)  wt_var(str) fol(str)
    local athr = cond("`fol'" == "fl", "", "_all")
    local suf = ""
    if "`wt_var'" == "cite_affl_wt" local suf "_wt"
    if "`wt_var'" == "impact_affl_wt" local suf "_if"
    if "`wt_var'" == "impact_cite_affl_wt" local suf "_if_wt"
    if "`wt_var'" == "pat_adj_wt" local suf "_pat"
    if "`wt_var'" == "frnt_adj_wt" local suf "_frnt"
    if "`wt_var'" == "body_adj_wt" local suf "_body"
    use if inrange(year, 1945, 2022)  using ../external/`fol'/cleaned_all_`samp', clear
    replace inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    cap drop counter
    cap drop tot_in_yr
    gen msa_world = msatitle
    replace msa_world = city if country != "United States"
    qui bys id year: gen counter = _n == 1
    qui bys year: egen tot_in_yr = total(counter)
    foreach loc in country  msa_c_world inst {
        preserve
        if inlist("`loc'", "us_state", "area", "msatitle", "msa_comb") {
            qui keep if country == "United States"
        }
        replace `loc' = "harvard university" if `loc' == "university harvard"
        replace `loc' = "stanford university" if `loc' == "university stanford"
        qui merge m:1 `loc' using ../temp/`loc'_rank_`samp'`suf'`athr', assert(1 3) keep(1 3) nogen
        if "`loc'" == "inst" {
            replace `loc' = strproper(`loc')
        }
        qui sum year
        local min_year = max(1945,r(min))
        qui egen year_bin  = cut(year), at(1945(3)2023) 
        keep if !mi(`loc')
        local year_var year_bin

        collapse (sum) `wt_var'  (firstnm) `loc'  , by(rank_grp `year_var')
        bys `year_var': egen tot_in_`year_var' = total(`wt_var')
        qui gen perc = `wt_var'/tot_in_`year_var' * 100
        qui bys `year_var': egen tot = sum(perc)
        save ../temp/trends_`loc'`suf'`athr', replace
        qui replace tot = round(tot)
        assert tot==100
        qui drop tot
        if "`loc'" == "city_full" | "`loc'" == "msatitle" | "`loc'" == "msa_world" |  "`loc'" == "msa_c_world" | "`loc'" == "msa_comb" {
            label define rank_grp 1 ${`loc'_first} 2 ${`loc'_second} 3 "Remaining top 10" 4 "Remaining places" 
        }
        if "`loc'" == "inst" {
            local proper_1 = strproper(${`loc'_first})
            local proper_2 = strproper(${`loc'_second})
            label define rank_grp 1 "`proper_1'" 2 "`proper_2'" 3 "Remaining top 10" 4 "Remaining places" 
        }
        if "`loc'" == "country" {
            label define rank_grp 1 ${`loc'_first} 2 "United Kingdom" 3 "China" 4 "Remaining top 10" 5 "Remaining places" 
        }
        label var rank_grp rank_grp
        qui gen group = 1 if rank_grp == "first"
        qui replace group = 2 if rank_grp == "second"  & "`loc'"!= "country"
        qui replace group = 2 if rank_grp == "uk" & "`loc'" == "country"
        qui replace group = 3 if rank_grp == "china" & "`loc'" == "country"
        local last = 2
        if "`loc'" == "country" local last = 3 
        qui replace group = `last'+1 if rank_grp == "rest of top 10" 
        qui replace group = `last'+2 if rank_grp == "remaining"
        *qui replace group = `last'+3 if rank_grp == "missing"
        qui hashsort `year_var' -group
        qui bys `year_var': gen stack_perc = sum(perc)
        keep rank_grp `year_var' `loc' perc group stack_perc
        local stacklines
        qui xtset group `year_var' 
        qui sum group 
        local max_grp = r(max)
        qui levelsof group, local(rank_grps)
        local items = `r(r)'
        foreach x of local rank_grps {
           colorpalette carto Teal, intensify(0.85)  n(`items') nograph
           local stacklines `stacklines' area stack_perc `year_var' if group == `x', fcolor("`r(p`x')'") lcolor(white) lwidth(*0.3) || 
/*           if `x' == `max_grp' {
               local stacklines `stacklines' area stack_perc `year_var' if group == `x', fcolor("dimgray") lcolor(black) lwidth(*0.2) || 
           }*/
        }
        qui gen labely = . 
        qui gen rev_group = -group
        if "`loc'"=="country" {
            qui bys `year_var' (rev_group): replace labely = perc/2 if group == 5
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] if group == 4
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 3
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] if group == 2
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] + perc[_n-4] if group == 1
        }
        if "`loc'"!="country" {
            qui bys `year_var' (rev_group): replace labely = perc/2 if group == 4
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] if group == 3
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 2
            qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] if group == 1
        }
*        qui gen labely_lab = "Missing Info" if group == `last'+3
        qui gen labely_lab = "Everywhere else" if group == `last'+2
        qui replace labely_lab = "Remaining top 10" if group == `last'+1
        qui replace labely_lab = "China" if group == 3 & "`loc'"=="country"
        qui replace labely_lab = ${`loc'_second} if group == 2
        qui replace labely_lab = ${`loc'_second} if group == 2
        qui replace labely_lab = ${`loc'_first} if group == 1
        qui replace labely_lab = "United Kingdom" if group == 2 & "`loc'"=="country"
        qui replace labely_lab = strproper(${`loc'_second}) if group == 2 & "`loc'" == "inst"
        qui replace labely_lab = strproper(${`loc'_first}) if group == 1 & "`loc'" == "inst"
        qui replace labely_lab = subinstr(labely_lab, "United States", "US", .)
        qui replace labely_lab = subinstr(labely_lab, "MA-NH", "US", .) if strpos("`loc'" , "world")>0
        qui replace labely_lab = subinstr(labely_lab, "NY-NJ-PA", "US", .) if strpos("`loc'" , "world")>0
        qui replace labely_lab = subinstr(labely_lab, "CA", "US", .) if strpos("`loc'" , "world")>0
        qui replace labely_lab = subinstr(labely_lab, "United Kingdom", "UK", .)
        qui sum `year_var'
        replace `year_var' = 2023 if `year_var' == r(max)
        if "`loc'" == "country" {
            graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2023, ms(smcircle) ///
              msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
              ytitle("Share of Worldwide Fundamental Science Research Output", size(vsmall)) xtitle("Year", size(vsmall)) xlabel(`min_year'(3)2023, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
              graphregion(margin(r+27)) plotregion(margin(zero)) ///
              legend(off label(1 ${`loc'_first}) label(2 "United Kingdom") label(3 "China") label(4 "Remaining top 10") label(5 "Remaining places")  ring(1) pos(6) rows(2))
            qui graph export ../output/figures/`loc'_stacked_`samp'`suf'`athr'.pdf , replace 
        }
        local w = 27 
        if ("`loc'" == "msatitle" | "`loc'" == "msa_world" | "`loc'" == "msa_c_world" | "`loc'" == "msa_comb") local w = 27 
        if "`loc'" != "country" {
            graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2023, ms(smcircle) ///
              msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
              ytitle("Share of Worldwide Fundamental Science Research Output", size(vsmall)) xtitle("Year", size(vsmall)) xlabel(`min_year'(3)2023, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
              graphregion(margin(r+`w')) plotregion(margin(zero)) ///
              legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "Remaining top 10") label(4 "Remaining places")  ring(1) pos(6) rows(2))
            qui graph export ../output/figures/`loc'_stacked_`samp'`suf'`athr'.pdf , replace 
        }
        restore
    }
end 
    
program output_tables
    syntax, samp(str) fol(str)
    local athr = cond("`fol'" == "fl", "", "_all")
    cap mat if_comb`athr' = top_country_jrnls_if_wt`athr' \ top_msa_c_world_jrnls_if_wt`athr'
    cap matrix_to_txt, saving("../output/tables/if_comb`athr'.txt") matrix(if_comb`athr') title(<tab:if_comb`athr'>) format(%20.4f) replace
    foreach file in top_inst {
        cap qui matrix_to_txt, saving("../output/tables/`file'_`samp'_wt`athr'.txt") matrix(`file'_`samp'_wt`athr') ///
           title(<tab:`file'_`samp'_wt`athr'>) format(%20.4f) replace
        cap qui matrix_to_txt, saving("../output/tables/`file'_`samp'_if_wt`athr'.txt") matrix(`file'_`samp'_if_wt`athr') ///
           title(<tab:`file'_`samp'_if_wt`athr'>) format(%20.4f) replace
         }
 end
** 
main
