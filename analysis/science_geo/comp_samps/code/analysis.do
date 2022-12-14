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
            }
            qui output_tables, data(`data') samp(`samp') 
        }
    }
    foreach var in affl_wt { //cite_affl_wt {
         comp_samps, samp1(cns_med) samp2(scisub) wt_var(`var')
    }
end


program athr_loc
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/cleaned_samps/cleaned_last5yrs_`data'_`samp', clear
    foreach loc in country city_full inst {
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
        if inlist("`loc'", "country", "inst", "city_full") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc'_`data'_`samp' "`r(levels)'"
        }
        qui gen rank_grp = "first" if _n == 1
        qui levelsof `loc' if _n == 1
        global `loc'_first "`r(levels)'"
        qui levelsof `loc' if _n == 2
        global `loc'_second "`r(levels)'"
        gen rank = _n 
        keep `loc'  rank perc
        rename perc share
        qui save ../temp/`loc'_rank_`data'_`samp'`suf', replace
        restore
    }
end

program comp_samps
    syntax, samp1(str) samp2(str) wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
     if "`samp1'" == "cns_med"  local `samp1'_name "CNS + Med"
     if "`samp2'" == "cns_med"  local `samp2'_name "CNS + Med"
     if "`samp1'" == "scisub"  local `samp1'_name "Scientific Sub Journals"
     if "`samp2'" == "scisub"  local `samp2'_name "Scientific Sub Journals"
    foreach cat in fund dis thera {
         if "`cat'" == "fund"  local `cat'_name "Fundamental"
         if "`cat'" == "dis"  local `cat'_name "Disease"
         if "`cat'" == "thera"  local `cat'_name "Therapeutics"
         foreach loc in country city_full inst {
             use ../temp/`loc'_rank_`cat'_`samp1'`suf', clear
             gen samp = "`samp1'"
             append using ../temp/`loc'_rank_`cat'_`samp2'`suf'
             replace samp = "`samp2'" if mi(samp)
             greshape wide rank share, i(`loc') j(samp)
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
                gen lab_share = `loc' 
                cap replace lab_share = "" if !(inlist(rank`samp1', 1, 2, 3, 5, 8) | inlist(rank`samp2', 1, 2, 3))
                cap replace lab_share = `loc' if inlist(`loc', "Memorial Sloan", "MIT", "Stanford", "Berlin, Germany", "Daejeon, South Korea", "Baltimore, US", "New York, US") & "`cat'" == "thera"
                cap replace lab_share = `loc' if inlist(`loc', "UCSF", "JHU", "UCSD", "MIT", "China","London, UK", "Houston, US") & "`cat'" == "fund"
                cap replace lab_share = `loc' if inlist(`loc', "Germany", "London, UK", "Houston, US", "Tokyo, Japan", "UCLA") & "`cat'" == "dis"
                cap replace lab_share = "" if inlist(`loc', "Netherlands", "Switzerland") & "`cat'" == "thera"
                cap replace lab_share = "" if inlist(`loc', "Switzerland", "Canada", "Germany") & "`cat'" == "fund"
                cap replace lab_share = "" if inlist(`loc', "Sweden", "Canada", "Cambridge, UK") & "`cat'" == "dis"
                *cap replace lab_share = "" if inlist(`loc', "Research Triangle, US", "Israel")
                egen clock = mlabvpos(rank`samp1' rank`samp2')
                replace clock = 3 if inlist(lab_share, "Spain", "China", "San Diego-La Jolla, US", "Baltimore, US", "Berlin, Germany", "New York, US") & "`cat'"== "thera"
                replace clock = 12 if inlist(lab_share, "Switzerland") & "`cat'"== "thera"
                replace clock = 6 if inlist(lab_share, "Bay Area, US", "Stanford") & "`cat'"== "thera"
                replace clock = 12 if inlist(lab_share, "United Kingdom") & "`cat'"== "fund"
                replace clock = 3 if inlist(lab_share, "Germany", "Houston, US", "New York, US", "London, UK" , "UCSF", "UCSD") & "`cat'"== "fund"
                replace clock = 3 if inlist(lab_share, "Tokyo, Japan","Houston, US", "China", "UCLA") & "`cat'"== "dis"
                replace clock = 6 if inlist(lab_share, "Germany") & "`cat'"== "dis"

                local rank_lmt = 20
                qui sum rank`samp2' if inrange(rank`samp1' , 1,`rank_lmt')
                local max = r(max) 
                qui sum rank`samp1' if inrange(rank`samp2' , 1,`rank_lmt')
                local max= max(`max', r(max))
                corr rank`samp1' rank`samp2' if inrange(rank`samp1' , 1,`rank_lmt') & inrange(rank`samp2' ,1,`rank_lmt')
                local corr :  di %3.2f r(rho)
                tw scatter rank`samp1' rank`samp2' if inrange(rank`samp1' , 1,`rank_lmt') & inrange(rank`samp2' ,1,`rank_lmt') , ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (function y=x ,range(0 `max') lpattern(dash) lcolor(lavender)), ///
                  xtitle("``cat'_name' Research Rank - ``samp2'_name'", size(small)) ytitle("`cat_name' Science Research Rank - ``samp1'_name' ", size(small)) ///
                  xlabel(1(1)`rank_lmt', labsize(vsmall)) ylabel(1(1)`rank_lmt', labsize(vsmall)) xsc(reverse) ysc(reverse) legend(on order(- "Correlation = `corr'") size(vsmall) pos(5) ring(0) region(lwidth(none)))
                *graph export ../output/figures/`samp1'_`samp2'_`cat'_`loc'_rank`suf'.pdf, replace
                local skip = 5 
                *if "`type'" == "inst" local lim = 5
                if "`loc'" == "inst" local skip = 0.5 
                if "`loc'" == "city_full" local skip = 1 
                qui sum share`samp1' if  !mi(share`samp1') & !mi(share`samp2') //(inrange(rank`samp1' , 1,`rank_lmt') |  inrange(rank`samp2' , 1,`rank_lmt')) & !mi(share`samp1') & !mi(share`samp2')
                local max = r(max)
                qui sum share`samp2' if  !mi(share`samp1') & !mi(share`samp2') //inrange(rank`samp1' , 1,`rank_lmt') |  inrange(rank`samp2' , 1,`rank_lmt') & !mi(share`samp1') & !mi(share`samp2')
                local max = max(r(max), `max')
                local max = floor(`max') +1 
                di `max'
                corr share`samp1' share`samp2'  if  (share`samp1'<=`max') & (share`samp2'<=`max')
                local corr :  di %3.2f r(rho)
                tw scatter share`samp1' share`samp2' if (share`samp1'<=`max') & (share`samp2'<=`max'), ///  //if  (inrange(rank`samp1' , 1,`rank_lmt') |  inrange(rank`samp2' , 1,`rank_lmt')) & (share`samp1'<=`max') & (share`samp2'<=`max'), ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (function y=x ,range(0 `max') lpattern(dash) lcolor(lavender)), ///
                  xtitle("``cat'_name' Research Share (%) - ``samp2'_name'", size(small)) ytitle("``cat'_name' Science Research Share (%) - ``samp1'_name'", size(small)) ///
                  xlabel(0(`skip')`max', labsize(vsmall)) ylabel(0(`skip')`max', labsize(vsmall)) legend(on order(- "Correlation = `corr'") size(vsmall) pos(5) ring(0) region(lwidth(none))) 
                graph export ../output/figures/`samp1'_`samp2'_`cat'_`loc'_share`suf'.pdf, replace
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
