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
    global msatitle_name "MSAs"
    global inst_name "institutions"
    foreach samp in cns scisub demsci { 
        local samp_type = cond(strpos("`samp'", "cns")>0 | strpos("`samp'","med")>0, "main", "robust")
        foreach data in newfund {
        di "SAMPLE IS : `samp' `data'"
            foreach var in affl_wt cite_affl_wt {
                athr_loc, data(`data') samp(`samp') wt_var(`var')
            }
            qui output_tables, data(`data') samp(`samp') 
        }
    }
    foreach var in cite_affl_wt {
         comp_samps, samp1(cns) samp2(scisub) wt_var(`var')
         comp_samps, samp1(cns) samp2(demsci) wt_var(`var')
    }
    mat corr_across_samp = corr_scisub_wt \ corr_demsci_wt
    matrix_to_txt, saving("../output/tables/corr_across_samp.txt") matrix(corr_across_samp) ///
       title(<tab:corr_across_samp>) format(%20.4f) replace
end


program athr_loc
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/openalex/cleaned_last5yrs_`data'_`samp', clear
    drop if journal_abbr == "PLoS One"
    foreach loc in country msa_c_world inst { 
        qui gunique pmid //which_athr //if !mi(affiliation)
        local articles = r(unique)
        qui sum `wt_var'
        local total = round(r(sum))
        assert `total' == `articles'
        qui sum `wt_var' if !mi(`loc') 
        local denom = r(sum) 
        preserve
        if inlist("`loc'", "us_state", "area", "msatitle") {
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
        if inlist("`loc'", "country", "inst", "city_full", "msatitle", "msa_world", "msa_c_world") {
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
     if "`samp1'" == "cns"  local `samp1'_name "CNS"
     if "`samp2'" == "cns"  local `samp2'_name "CNS"
     if "`samp1'" == "scisub"  local `samp1'_name "Scientific Sub Journals"
     if "`samp2'" == "scisub"  local `samp2'_name "Scientific Sub Journals"
     if "`samp1'" == "demsci"  local `samp1'_name "Democratic Science Journals"
     if "`samp2'" == "demsci"  local `samp2'_name "Democratic Science Journals"
    foreach cat in newfund {
         if "`cat'" == "fund"  local `cat'_name "Fundamental"
         if "`cat'" == "newfund"  local `cat'_name "Fundamental"
         if "`cat'" == "dis"  local `cat'_name "Disease"
         if "`cat'" == "thera"  local `cat'_name "Therapeutics"
         if "`cat'" == "nofund"  local `cat'_name "Disease + Therapeutics"
         foreach loc in country msa_c_world inst {
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
                cap replace inst = "Caltech" if inst == "california institute technology"
                cap replace inst = "CDC" if inst == "centers disease control and prevention"
                cap replace inst = "Columbia" if inst == "columbia University"
                cap replace inst = "Cornell" if inst == "cornell University"
                cap replace inst = "Duke" if inst == "duke university"
                cap replace inst = "Harvard" if inst == "university harvard"
                cap replace inst = "JHU" if inst == "johns hopkins university"
                cap replace inst = "Rockefeller Univ." if inst == "the rockefeller university"
                cap replace inst = "MIT" if inst == "massachusetts institutetechnology"
                cap replace inst = "Memorial Sloan" if inst == "memorial sloan-kettering cancer center"
                cap replace inst = "MGH" if inst == "massachusetts general hospital"
                cap replace inst = "NYU" if inst == "new york university"
                cap replace inst = "NIH" if inst == "nih"
                cap replace inst = "Stanford" if inst == "university stanford"
                cap replace inst = "UCL" if inst == "university college london"
                cap replace inst = "UC Berkeley" if inst == "university california berkeley"
                cap replace inst = "UCLA" if inst == "university california los angeles"
                cap replace inst = "UCSD" if inst == "university california san diego"
                cap replace inst = "UCSF" if inst == "ucsf"
                cap replace inst = "UChicago" if inst == "university chicago"
                cap replace inst = "UMich" if inst == "university michigan"
                cap replace inst = "UPenn" if inst == "university pennsylvania"
                cap replace inst = "Yale" if inst == "yale university"
                cap replace inst = "Wash U" if inst == "washington university st louis"
                cap replace inst = "CAS" if inst == "chinese academysciences"
                cap replace inst = "Oxford" if inst == "university oxford"
                cap replace inst = "Cambridge" if inst == "university cambridge"
                cap replace inst = "UT Dallas" if inst == "university texas dallas"
                cap replace inst = "UMich" if inst == "university michigan ann arbor"
                cap replace inst = "Dana Farber" if inst == "dana farber cancer institute"

                // cities
                foreach i in  msa_c_world {
                    cap replace `i' = subinstr(`i', "United States", "US",.)
                    cap replace `i' = subinstr(`i', "United Kingdom", "UK",.)
                }
                local lmt = 20
                gen lab_share = `loc'
                replace lab_share = strproper(lab_share) if "`loc'" != "msatitle"
                cap replace lab_share = subinstr(lab_share, "United States", "US",.)
                cap replace lab_share = subinstr(lab_share, "United Kingdom", "UK",.)
                cap replace lab_share = "" if !(inlist(rank`samp1', 1, 2, 3, 5, 8) | inlist(rank`samp2', 1, 2, 3))
                cap replace lab_share = `loc' if inlist(`loc', "Memorial Sloan", "MIT", "Stanford", "Berlin, Germany", "Daejeon, South Korea", "Baltimore, US", "New York, US") & "`cat'" == "thera"
                cap replace lab_share = "" if inlist(`loc', "Netherlands", "Switzerland") & "`cat'" == "thera"
               
                cap replace lab_share = `loc' if inlist(`loc', "UCSF", "JHU", "UCSD", "MIT", "China","London, UK", "Houston, US", "Japan") & "`cat'" == "newfund" & "`samp2'" == "scisub"
                cap replace lab_share = "" if inlist(`loc', "Switzerland", "Canada", "Germany", "Beijing, China", "France") & "`cat'" == "newfund" & "`samp2'" == "scisub"
                
                cap replace lab_share = `loc' if inlist(`loc', "Germany", "London, UK", "Houston, US", "Tokyo, Japan", "UCLA") & "`cat'" == "dis"
                cap replace lab_share = "" if inlist(`loc', "Sweden", "Canada", "Cambridge, UK") & "`cat'" == "dis"

                cap replace lab_share = "" if inlist(`loc',"Wash U", "UCSD", "Germany", "Japan", "Canada", "Cambridge, UK") & "`cat'" == "nofund" & "`samp2'" == "scisub"
                cap replace lab_share = `loc' if inlist(`loc', "Columbia") & "`cat'" == "nofund" & "`suf'" == "" & "`samp2'" == "scisub"
                cap replace lab_share = `loc' if inlist(`loc', "Columbia") & "`cat'" == "nofund" & "`suf'" == "" & "`samp2'" == "scisub"
                cap replace lab_share = `loc' if inlist(`loc', "MGH", "Chongqing, China") & "`cat'" == "nofund" & "`suf'" == "_wt" & "`samp2'" == "scisub"

                cap replace lab_share = "" if inlist(`loc', "Memorial Sloan", "Seoul National University", "Canada", "Japan", "Shanghai, China", "Bethesda-DC, US" , "Wash U" , "UCSD", "Cambridge, UK") & "`cat'" == "nofund" &  "`samp2'" == "demsci" 
                cap replace lab_share = "" if inlist(`loc', "France", "Fudan University"") & "`cat'" == "nofund" &  "`samp2'" == "demsci" 
                cap replace lab_share = "" if inlist(`loc', "Rockefeller Univ.", "United Kingdom", "Canada" , "Switzerland", "Seattle, US", "Cambridge, UK", "Japan", "Univeresity of Washington") & "`cat'" == "newfund" & "`samp2'" == "demsci"
                *cap replace lab_share = "" if inlist(`loc', "Research Triangle, US", "Israel")
                egen clock = mlabvpos(rank`samp1' rank`samp2')
                replace clock = 3 if inlist(lab_share, "Spain", "China", "San Diego-La Jolla, US", "Baltimore, US", "Berlin, Germany", "New York, US") & "`cat'"== "thera"
                replace clock = 12 if inlist(lab_share, "Switzerland") & "`cat'"== "thera"
                replace clock = 6 if inlist(lab_share, "Bay Area, US", "Stanford") & "`cat'"== "thera"
               
                replace clock = 12 if inlist(lab_share, "United Kingdom") & "`cat'"== "newfund" & "`samp2'" == "scisub"
                replace clock = 3 if inlist(lab_share, "Germany", "Houston, US", "New York, US", "London, UK" , "UCSF", "UCSD", "San Diego-La Jolla, US") & "`cat'"== "newfund" & "`samp2'" == "scisub"
                replace clock = 3 if inlist(lab_share, "MIT", "JHU", "Japan", "China", "Stanford") & "`cat'" == "newfund" & "`samp2'" == "scisub"
                replace clock = 6 if inlist(lab_share, "Boston-Cambridge, US") & "`cat'" == "newfund" & "`samp2'" == "scisub" & "`suf'" == ""
                replace clock = 11 if inlist(lab_share, "Bay Area, US") & "`cat'" == "newfund"  & "`suf'" == ""
                replace clock = 6 if inlist(lab_share, "University of Washington") & "`cat'" == "newfund" & "`samp2'" == "scisub"
               
               replace clock = 3 if inlist(lab_share, "China", "United Kingdom", "Boston-Cambridge, US", "New York, US" , "Bay Area, US", "London, UK", "Seoul, South Korea", "Beijing, China") & "`samp2'" == "demsci" & "`cat'" == "nofund"
               replace clock = 3  if inlist(lab_share, "Boston-Cambridge, US", "New York, US", "San Diego-La Jolla, US", "Tokyo, Japan", "UC Berkeley", "Stanford", "Max Planck") & "`samp2'" == "demsci" & "`cat'" == "newfund"
               replace clock = 3 if inlist(lab_share, "Harvard", "CAS", "CNRS") & "`samp2'" == "demsci" & "`cat'" == "newfund"
                replace clock = 3 if inlist(lab_share, "Tokyo, Japan","Houston, US", "China", "UCLA") & "`cat'"== "dis"
                replace clock = 6 if inlist(lab_share, "Germany") & "`cat'"== "dis"
                
                replace clock = 3 if inlist(lab_share, "Harvard", "Memorial Sloan", "Columbia", "MGH", "China", "Bethesda-DC, US", "Bay Area, US") & "`cat'" == "nofund" & "`samp2'" == "scisub"
                replace clock = 9 if inlist(lab_share, "United Kingdom", "London, UK") & "`cat'" == "nofund" & "`samp2'" == "scisub"
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
                  xtitle("``cat'_name' Research Rank - ``samp2'_name'", size(small)) ytitle("`cat_name' Research Rank - ``samp1'_name' ", size(small)) ///
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
                if "`cat'" == "newfund" {
                    mat corr_`samp2'`suf' = nullmat(corr_`samp2'`suf') , r(rho)
                }
                tw scatter share`samp1' share`samp2' if (share`samp1'<=`max') & (share`samp2'<=`max'), ///  //if  (inrange(rank`samp1' , 1,`rank_lmt') |  inrange(rank`samp2' , 1,`rank_lmt')) & (share`samp1'<=`max') & (share`samp2'<=`max'), ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (function y=x ,range(0 `max') lpattern(dash) lcolor(lavender)), ///
                  xtitle("``cat'_name' Research Share (%) - ``samp2'_name'", size(small)) ytitle("``cat'_name' Research Share (%) - ``samp1'_name'", size(small)) ///
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
