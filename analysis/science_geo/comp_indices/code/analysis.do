set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global country_name "countries"
    global us_state_name "US states"
    global area_name "US cities"
    global city_full_name "world cities"
    global inst_name "institutions"
    foreach samp in cns_med scisub { 
        local samp_type = cond(strpos("`samp'", "cns")>0 | strpos("`samp'","med")>0, "main", "robust")
        foreach data in fund dis thera {
        di "SAMPLE IS : `samp' `data'"
            foreach var in affl_wt cite_affl_wt {
                athr_loc, data(`data') samp(`samp') wt_var(`var')
                qui trends, data(`data') samp(`samp') wt_var(`var')
            }
            qui output_tables, data(`data') samp(`samp') 
        }
        foreach var in affl_wt cite_affl_wt {
            qui comp_w_fund, samp(`samp')  wt_var(`var')
        }
    }
end

program athr_loc
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/cleaned_samps/cleaned_last5yrs_`data'_`samp', clear
    foreach loc in country  city_full inst {
        qui gunique pmid //which_athr //if !mi(affiliation)
        local articles = r(unique)
        qui sum `wt_var'
        local total = round(r(sum))
        assert `total' == `articles'
        qui sum `wt_var' if !mi(`loc') 
        local denom = r(sum) 
        preserve
        if inlist("`loc'", "us_state", "area") {
            qui keep if country == "United States"
        }
        gcollapse (sum) `wt_var', by(`loc')
        qui hashsort -`wt_var' 
        qui gen perc = `wt_var' / `total' * 100
        li if mi(`loc')
        qui drop if mi(`loc')
        qui gen cum_perc = sum(perc) 
        qui count
        local rank_end = min(r(N),20) 
        li `loc' perc in 1/`rank_end'
        di "Total articles: `total'"
        mkmat `wt_var' perc cum_perc in 1/`rank_end', mat(top_`loc'_`samp'`suf')
        mat top_`loc'_`data'_`samp' = nullmat(top_`loc'_`data'_`samp') , (top_`loc'_`samp'`suf')
        qui levelsof `loc' in 1/2
        global top2_`loc'_`data'_`samp' "`r(levels)'"
        if inlist("`loc'", "inst", "city_full") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc'_`data'_`samp' "`r(levels)'"
        }
        qui gen rank_grp = "first" if _n == 1
        qui levelsof `loc' if _n == 1
        global `loc'_first_`data'_`samp' "`r(levels)'"
        qui levelsof `loc' if _n == 2
        global `loc'_second_`data'_`samp' "`r(levels)'"
        qui replace rank_grp = "second" if _n == 2
        qui replace rank_grp = "rest of top 10" if inrange(_n,3,10)
        qui replace rank_grp = "remaining" if mi(rank_grp)
        keep `loc' rank_grp
        qui save ../temp/`loc'_rank_`data'_`samp'`suf', replace
        restore
    }
end

program trends
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/cleaned_samps/cleaned_all_`data'_`samp', clear
    qui bys pmid year: gen counter = _n == 1
    qui bys year: egen tot_in_yr = total(counter)
    foreach loc in country city_full inst {
        preserve
        qui merge m:1 `loc' using ../temp/`loc'_rank_`data'_`samp'`suf', assert(1 3) keep(1 3) nogen
        qui sum year
        local min_year = max(1988,r(min))
        qui egen year_bin  = cut(year),  at(1988 1991 1993 1995 1997 1999 2001 2003 2007 2009 2011 2013 2015 2017 2019 2021 2023)
        keep if which_athr == 1
        qui replace affl_wt = 1/num_affls
        local year_var year_bin
        qui bys pmid `year_var': replace counter = _n == 1
        qui bys `year_var': egen tot_in_`year_var' = total(counter)
        qui replace rank_grp = "remaining" if mi(rank_grp)
        bys pmid: replace cite_count = . if _n !=1 
        qui bys `year_var': egen tot_cites_in_`year_var' = total(cite_count)
        replace cite_wt = cite_count/ tot_cites_in_`year_var' * tot_in_`year_var'
        hashsort pmid cite_wt
        qui by pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        replace cite_affl_wt = affl_wt * cite_wt
        collapse (sum) `wt_var' (mean) tot_in_`year_var' (firstnm) `loc' , by(rank_grp `year_var')
        qui gen perc = `wt_var'/tot_in_`year_var' * 100
        qui bys `year_var': egen tot = sum(perc)
        qui replace tot = round(tot)
        assert tot==100
        qui drop tot
        label define rank_grp 1 ${`loc'_first_`data'_`samp'} 2 ${`loc'_second_`data'_`samp'} 3 "Rest of the top 10 ${`loc'_name}" 4 "Remaining places"
        label var rank_grp rank_grp
        qui gen group = 1 if rank_grp == "first"
        qui replace group = 2 if rank_grp == "second"
        qui replace group = 3 if rank_grp == "rest of top 10" 
        qui replace group = 4 if rank_grp == "remaining"
        qui hashsort `year_var' -group
        qui bys `year_var': gen stack_perc = sum(perc)
        keep rank_grp `year_var' `loc' perc group stack_perc
        local stacklines
        qui xtset group `year_var' 
        qui levelsof group, local(rank_grps)
        local items = `r(r)'
        foreach x of local rank_grps {
           colorpalette HTML purple, n(`items') nograph
           local stacklines `stacklines' area stack_perc `year_var' if group == `x', fcolor("`r(p`x')'") lcolor(black) lwidth(*0.2) || 
        }
        qui gen labely = . 
        qui gen rev_group = -group
        qui bys `year_var' (rev_group): replace labely = perc / 2 if group == 4
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] if group == 3
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 2
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] if group == 1
        qui gen labely_lab = "Everywhere else" if group == 4
        qui replace labely_lab = "Rest of the top 10 ${`loc'_name}" if group == 3
        qui replace labely_lab = ${`loc'_second_`data'_`samp'} if group == 2
        qui replace labely_lab = ${`loc'_first_`data'_`samp'} if group == 1
        qui replace labely_lab = subinstr(labely_lab, "United States", "US", .)
        qui replace labely_lab = subinstr(labely_lab, "United Kingdom", "UK", .)
        qui sum `year_var'
        replace `year_var' = 2022 if `year_var' == r(max)
        graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
          msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
          ytitle("Percent of Published Papers", size(small)) xtitle("Year", size(small)) xlabel(`min_year'(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
          graphregion(margin(r+25)) plotregion(margin(zero)) ///
          legend(off label(1 ${`loc'_first_`data'_`samp'}) label(2 ${`loc'_second_`data'_`samp'}) label(3 "Rest of the top 10 ${`loc'_name}") label(4 "Remaining places") ring(1) pos(6) rows(2))
        qui graph export ../output/figures/`loc'_stacked_`data'_`samp'`suf'.pdf, replace
        restore
    }
end 

program comp_w_fund
    syntax, samp(str) wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    foreach trans in dis thera {
         local fund_name "Fundamental"
         if "`trans'" == "dis"  local `trans'_name "Disease"
         if "`trans'" == "thera"  local `trans'_name "Therapeutics"
         foreach type in city_full inst {
            qui {
                global top_20 : list global(`type'_fund_`samp') | global(`type'_`trans'_`samp')
                use ../external/cleaned_samps/cleaned_last5yrs_fund_`samp', clear
                gen type = "fund"
                append using ../external/cleaned_samps/cleaned_last5yrs_`trans'_`samp'
                replace type = "trans" if mi(type)
                gen to_keep = 0
                foreach i of global top_20 {
                    replace to_keep = 1 if `type' == "`i'" 
                }
                gcollapse (sum) `wt_var' (mean) to_keep, by(`type' type)
                qui sum `wt_var' if type == "fund"
                gen share = `wt_var'/round(r(sum))*100 if type == "fund"
                qui sum `wt_var' if type == "trans"
                replace share = `wt_var'/round(r(sum))*100 if type == "trans"
                drop if mi(`type')
                hashsort type -`wt_var'
                by type: gen rank = _n 
                *keep if to_keep == 1
                qui sum rank
                local rank_lmt = r(max) 
                reshape wide `wt_var' rank share, i(`type') j(type) string
                gen onefund = _n
                gen onetrans = _n 
                gen zerofund = onefund-1
                gen zerotrans = onetrans-1
                // inst labels
                cap replace inst = "Caltech" if inst == "California Institute of Technology"
                cap replace inst = "CDC" if inst == "Centers for Disease Control and Prevention"
                cap replace inst = "Columbia" if inst == "Columbia University"
                cap replace inst = "Cornell" if inst == "Cornell University"
                cap replace inst = "Duke" if inst == "Duke University"
                cap replace inst = "Harvard" if inst == "Harvard University"
                cap replace inst = "JHU" if inst == "Johns Hopkins University"
                cap replace inst = "Rockefeller Univ." if inst == "The Rockefeller University"
                cap replace inst = "MIT" if inst == "Massachusetts Institute of Technology"
                cap replace inst = "Memorial Sloan" if inst == "Memorial Sloan-Kettering Cancer Center"
                cap replace inst = "NYU" if inst == "New York University"
                cap replace inst = "Stanford" if inst == "Stanford University"
                cap replace inst = "UCL" if inst == "University College London"
                cap replace inst = "UC Berkeley" if inst == "University of California, Berkeley"
                cap replace inst = "UCLA" if inst == "University of California, Los Angeles"
                cap replace inst = "UCSD" if inst == "University of California, San Diego"
                cap replace inst = "UCSF" if inst == "University of California, San Francisco"
                cap replace inst = "UChicago" if inst == "University of Chicago"
                cap replace inst = "UMich" if inst == "University of Michigan"
                cap replace inst = "UPenn" if inst == "University of Pennsylvania"
                cap replace inst = "Yale" if inst == "Yale University"
                cap replace inst = "Wash U" if inst == "Washington University in St. Louis"
                cap replace inst = "CAS" if inst == "Chinese Academy of Sciences"
                cap replace inst = "Oxford" if inst == "University of Oxford"
                cap replace inst = "Cambridge" if inst == "University of Cambridge"
                cap replace inst = "UT Dallas" if inst == "University of Texas, Dallas"
                cap replace inst = "UMich" if inst == "University of Michigan, Ann Arbor"
                cap replace inst = "Dana Farber" if inst == "Dana Farber Cancer Institute"

                // cities
                cap replace city_full = subinstr(city_full, "United States", "US",.)
                cap replace city_full = subinstr(city_full, "United Kingdom", "UK",.)
                local lmt = 20
                gen lab = `type' if rankfund <= `lmt' | ranktrans<= `lmt'
                gen lab_share = `type' 
                cap replace lab_share = "" if !(inlist(rankfund, 1, 2, 3,4, 5, 8) | inlist(ranktrans, 1, 2, 3,4, 5))
                cap replace lab_share = "" if inlist(`type', "Oxford, UK", "Baltimore, US", "Seattle, US", "Cambridge, UK", "University of Washington", "Universidade de Sao Paulo") & "`trans'" == "thera"
                cap replace lab_share = "" if inlist(`type', "Chinese Academy of Medical Sciences" ) & "`trans'" == "dis"
                egen clock = mlabvpos(rankfund ranktrans)
                cap replace clock = 3 if inlist(lab_share,"San Diego-La Jolla, US", "Stanford") & "`trans'" == "thera"
                cap replace clock = 2 if inlist(lab_share,"Beijing, China") & "`trans'" == "thera"
                cap replace clock = 12 if inlist(lab_share,"Pfizer" , "UC Berkeley") & "`cat'" == "thera"
                cap replace clock = 6 if inlist(lab_share,"London, UK", "Bay Area, US") & "`trans'" == "thera"
                cap replace clock = 9 if inlist(lab_share,"Rockefeller Univ.") & "`trans'" == "thera"
                cap replace clock = 6 if inlist(lab_share,"Max Planck", "University of Washington", "Brigham and Women's Hospital" ) & "`trans'" == "dis"
                cap replace clock = 3 if inlist(lab_share,"UCSF", "MIT", "Memorial Sloan", "Peking University" ) & "`trans'" == "dis"
                cap replace clock = 12 if inlist(lab_share,"UC Berkeley" ) & "`trans'" == "dis"
                local rank_lmt = 20
                tw scatter rankfund ranktrans if inrange(rankfund , 1,`rank_lmt') & inrange(ranktrans ,1,`rank_lmt'), ///
                  mlabel(lab) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line onefund onetrans if onefund <= `rank_lmt', lpattern(dash) lcolor(lavender)), ///
                  xtitle("``trans'_name' Research Output Rank", size(small)) ytitle("`fund_name' Science Research Output Rank", size(small)) ///
                  xlabel(1(1)`rank_lmt', labsize(vsmall)) ylabel(1(1)`rank_lmt', labsize(vsmall)) xsc(reverse) ysc(reverse) legend(off)
                *graph export ../output/figures/bt_`type'_`trans'_`samp'`suf'_scatter.pdf, replace
                local skip = 1 
                if "`type'" == "inst" local lim = 5
                if "`type'" == "inst" local skip = 1 
                qui sum sharefund
                local max = r(max)
                qui sum sharetrans
                local max = max(r(max), `max')
                local max = floor(`max') +1 
                qui corr sharefund sharetrans  if !mi(sharefund) & !mi(sharetrans)
                local corr : di %3.2f r(rho)
                local pos = 5
                if "`trans'" == "thera" local pos = 11
                tw scatter sharefund sharetrans if !mi(sharefund) & !mi(sharetrans), ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line zerofund zerotrans if zerofund <= `max', lpattern(dash) lcolor(lavender)), ///
                  xtitle("Share of Worldwide ``trans'_name' Research Output (%)", size(small)) ytitle("Share of Worldwide `fund_name' Science Research Output (%)", size(small)) ///
                  xlabel(0(`skip')`max', labsize(vsmall)) ylabel(0(`skip')`max', labsize(vsmall)) legend(on order(- "Correlation = `corr'") size(vsmall) pos(`pos') ring(0) region(lwidth(none)))
                graph export ../output/figures/bt_`type'_`trans'_`samp'`suf'_share_scatter.pdf, replace
            }
        }
    }
end
    
program output_tables
    syntax, data(str) samp(str)
    foreach file in {
        qui matrix_to_txt, saving("../output/tables/`file'_`data'_`samp'.txt") matrix(`file'_`data'_`samp') ///
           title(<tab:`file'_`data'>) format(%20.4f) replace
         }
 end
** 
main
