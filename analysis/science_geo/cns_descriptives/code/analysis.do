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
    foreach samp in cns {
        di "OUTPUT START"
        local samp_type = cond("`samp'" == "cns", "main", "robust")
        *get_total_articles, samp(`samp') samp_type(`samp_type')
        foreach data in fund { //dis thera {
            foreach var in cite_affl_wt {
                athr_loc, data(`data') samp(`samp') wt_var(`var')
                qui trends, data(`data') samp(`samp') wt_var(`var')
            }
            calc_broad_hhmi, data(`data') samp(`samp') 
            top_mesh_terms, data(`data') samp(`samp') samp_type(`samp_type')
            top_mesh_terms, data(trans) samp(`samp') samp_type(`samp_type')
            qui output_tables, data(`data') samp(`samp') 
        }
        foreach var in affl_wt cite_affl_wt {
            *qui comp_w_fund, samp(`samp')  wt_var(`var')
        }
    } // test if github work
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
        mkmat perc cum_perc in 1/`rank_end', mat(top_`loc'_`samp'`suf')
        mat top_`loc'_`data'_`samp' = nullmat(top_`loc'_`data'_`samp') , (top_`loc'_`samp'`suf')
        qui levelsof `loc' in 1/2
        global top2_`loc'_`data' "`r(levels)'"
        if inlist("`loc'", "inst", "city_full") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc'_`data' "`r(levels)'"
        }
        qui gen rank_grp = "first" if _n == 1
        qui levelsof `loc' if _n == 1
        global `loc'_first "`r(levels)'"
        qui levelsof `loc' if _n == 2
        global `loc'_second "`r(levels)'"
        qui replace rank_grp = "second" if _n == 2
        qui replace rank_grp = "rest of top 10" if inrange(_n,3,10)
        qui replace rank_grp = "remaining" if mi(rank_grp)
        keep `loc' rank_grp
        qui save ../temp/`loc'_rank_`data'_`samp'`suf', replace
        restore
    }
end

program calc_broad_hhmi
   syntax, data(str) samp(str) 
   use ../external/cleaned_samps/cleaned_last5yrs_`data'_`samp', clear
   qui gunique pmid which_athr
   local num_athrs = r(unique)
   qui gunique pmid which_athr if country == "United States"
   local num_athrs_US = r(unique)
   foreach i in broad hhmi {
       qui gunique pmid which_athr if has_`i'_affl == 1
       local num_`i' = r(unique)
       di `num_`i'' " authors of " `num_athrs' " are " "`i' affiliated or " `num_`i''/`num_athrs'*100 " percent"
       qui gunique pmid which_athr if has_`i'_affl == 1 & country == "United States"
       local num_`i'_US = r(unique)
       di `num_`i'_US' " US authors of " `num_athrs_US' " are " "`i' affiliated or " `num_`i'_US'/`num_athrs_US'*100 " percent"
       // hhmi has to be us
       preserve
       keep if country == "United States"
       qui gunique pmid which_athr if has_`i'_affl == 1 & inst == "Stanford University" 
       local num_`i'_stanford = r(unique)
       di `num_`i'_stanford' " stanford authors of " `num_`i'_US' " are " "`i' affiliated or " `num_`i'_stanford'/`num_`i'_US'*100 " percent"
       qui gunique pmid which_athr if has_`i'_affl == 1 & inst == "Harvard University" 
       local num_`i'_harvard = r(unique)
       di `num_`i'_harvard' " harvard authors of " `num_`i'_US' " are " "`i' affiliated or " `num_`i'_harvard'/`num_`i'_US'*100 " percent"
       restore
       if "`i'" == "broad" {
           qui count if  inlist(inst, "Harvard University", "Massachusetts Institute of Technology", "Boston Children's Hospital", "Dana Farber Cancer Institute", "Massachusetts General Hospital", "Brigham and Women's Hospital", "Beth Israel Deaconess Medical Center")
           if r(N) > 0 {
               preserve
               keep if inlist(inst, "Harvard University", "Massachusetts Institute of Technology", "Boston Children's Hospital", "Dana Farber Cancer Institute", "Massachusetts General Hospital", "Brigham and Women's Hospital", "Beth Israel Deaconess Medical Center")
               qui gunique pmid which_athr if has_`i'_affl == 1 
               local num_athrs_broad = r(unique)
               qui gunique pmid which_athr if has_`i'_affl == 1 & inst == "Harvard University" 
               local num_`i'_harvard = r(unique)
               di `num_`i'_harvard' " harvard authors of " `num_athrs_broad' " are " "`i' affiliated or " `num_`i'_harvard'/`num_athrs_broad'*100 " percent"
               qui gunique pmid which_athr if has_`i'_affl == 1 & inst == "Massachusetts Institute of Technology" 
               local num_`i'_mit= r(unique)
               di `num_`i'_mit' " mit authors of " `num_athrs_broad' " are " "`i' affiliated or " `num_`i'_mit'/`num_athrs_broad'*100 " percent"
               restore 
           }
        }
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
        label define rank_grp 1 ${`loc'_first} 2 ${`loc'_second} 3 "Rest of the top 10 ${`loc'_name}" 4 "Remaining places"
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
        qui replace labely_lab = ${`loc'_second} if group == 2
        qui replace labely_lab = ${`loc'_first} if group == 1
        qui replace labely_lab = subinstr(labely_lab, "United States", "US", .)
        qui replace labely_lab = subinstr(labely_lab, "United Kingdom", "UK", .)
        qui sum `year_var'
        replace `year_var' = 2022 if `year_var' == r(max)
        graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
          msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
          ytitle("Share of Worldwide Fundamental Science Research Output", size(small)) xtitle("Year", size(small)) xlabel(`min_year'(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
          graphregion(margin(r+25)) plotregion(margin(zero)) ///
          legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "Rest of the top 10 ${`loc'_name}") label(4 "Remaining places") ring(1) pos(6) rows(2))
        qui graph export ../output/figures/`loc'_stacked_`data'_`samp'`suf'.pdf , replace 
        restore
    }
end 

program comp_w_fund
    syntax, samp(str) wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    foreach trans in nofund {
         local fund_name "Fundamental Science"
         if "`trans'" == "dis"  local `trans'_name "Disease"
         if "`trans'" == "thera"  local `trans'_name "Therapeutics"
         if "`trans'" == "nofund"  local `trans'_name "Disease + Therapeutics"
         foreach type in city_full inst {
            qui {
                global top_20 : list global(`type'_fund) | global(`type'_`trans')
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
                keep if to_keep == 1
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
                cap replace city_full = subinstr(city_full, "United States", "US", .)
                cap replace city_full = subinstr(city_full, "United Kingdom", "UK", .)

                // cities
                cap replace city_full = subinstr(city_country, "United States", "US",.)
                cap replace city_full = subinstr(city_country, "United Kingdom", "UK",.)
                local lmt = 20
                gen lab = `type' if rankfund <= `lmt' | ranktrans<= `lmt'
                gen lab_share = `type' 
                cap replace lab_share = "" if inlist(inst, "UT Dallas", "University of Washington", "Peking University", "Memorial Sloan", "UPenn", "UCL", "Medical Research Council")
                cap replace lab_share = "" if inlist(inst,  "UCLA", "UChicago", "Oxford", "UMich", "Columbia", "Rockefeller Univ.")
                cap replace lab_share = "" if inlist(city_full, "Princeton, US", "Shanghai, China", "Saint Louis, US", "Research Triangle, US" , "Dallas, US")
                cap replace lab_share = "" if inlist(city_full, "Seattle, US", "Los Angeles, US",  "Houston, US", "Heidelberg, Germany", "Toronto, Canada", "Chicago, US")
                cap replace lab_share = "" if inlist(city_full, "Baltimore, US", "Oxford, UK", "Paris, France", "Pasadena, US", "Philadelphia, US")
                cap replace lab_share = "" if !(inlist(rankfund, 1, 2, 3, 5, 10, 12) | inlist(ranktrans, 1, 2, 3, 5, 10, 15))
                egen clock = mlabvpos(rankfund ranktrans)
/*                cap replace clock = 4 if city_full == "Los Angeles, US"
                cap replace clock = 6 if city_full == "New York, US"
                cap replace clock = 3 if city_full == "Atlanta, US"
                cap replace clock = 3 if city_full == "Bethesda-DC, US"
                cap replace clock = 6 if city_full == "Boston-Cambridge, US"
                cap replace clock = 7 if city_full == "Cambridge, UK"
                cap replace clock = 9 if city_full == "Bay Area, US"
                cap replace clock = 3 if city_full == "New York, US"
                cap replace clock = 3 if city_full == "London, UL"
                cap replace clock = 3 if city_full == "New Haven, US"
                cap replace clock = 6 if city_full == "Ann Arbor, US"
                cap replace clock = 3 if city_full == "Beijing, China"
                cap replace clock = 3 if city_full == "San Diego-La Jolla, US"
                cap replace clock = 9 if city_full == "Cambridge, UK"
                cap replace clock = 11 if inst == "University of Cambridge"
                cap replace clock = 3 if inst == "Brigham and Women's Hospital"
                cap replace clock = 12 if inst == "UC Berkeley"
                cap replace clock = 5 if inst == "Wash U"
                cap replace clock = 3 if inst == "MIT"
                cap replace clock = 12 if inst == "Caltech"
                cap replace clock = 9 if inst == "Stanford"
                cap replace clock = 9 if inst == "UCSD"
                cap replace clock = 9 if inst == "UCSF"
                cap replace clock = 9 if inst == "Yale"
                cap replace clock = 9 if inst == "NIH"
                cap replace clock = 4 if inst == "Cambridge"
                cap replace clock = 3 if inst == "CNRS"
                cap replace clock = 12 if inst == "Harvard"
                cap replace inst = "CAS" if inst == "Chinese Academy of Sciences"
                cap replace clock = 9 if inst == "CAS"
                cap replace clock = 3 if inst == "CDC"
                cap replace clock = 3 if inst == "JHU"
                cap replace clock = 6 if inst == "Wash U"*/
                local rank_lmt = 20
                tw scatter rankfund ranktrans if inrange(rankfund , 1,`rank_lmt') & inrange(ranktrans ,1,`rank_lmt'), ///
                  mlabel(lab) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line onefund onetrans if onefund <= `rank_lmt', lpattern(dash) lcolor(lavender)), ///
                  xtitle("``trans'_name' Research Output Rank", size(small)) ytitle("`fund_name' Science Research Output Rank", size(small)) ///
                  xlabel(1(1)`rank_lmt', labsize(vsmall)) ylabel(1(1)`rank_lmt', labsize(vsmall)) xsc(reverse) ysc(reverse) legend(off)
                *graph export ../output/figures/bt_`type'_`trans'_`samp'`suf'_scatter.pdf, replace
                local skip = 0.5 
                if "`type'" == "inst" local lim = 5
                if "`type'" == "inst" local skip = 0.5 
                qui sum sharefund
                local max = r(max)
                qui sum sharetrans
                local max = max(r(max), `max')
                local max = floor(`max') +1 
                tw scatter sharefund sharetrans, ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line zerofund zerotrans if zerofund <= `max', lpattern(dash) lcolor(lavender)), ///
                  xtitle("Share of Worldwide ``trans'_name' Research Output (%)", size(small)) ytitle("Share of Worldwide `fund_name' Science Research Output (%)", size(small)) ///
                  xlabel(0(`skip')`max', labsize(vsmall)) ylabel(0(`skip')`max', labsize(vsmall)) legend(off)
                graph export ../output/figures/bt_`type'_`trans'_`samp'`suf'_share_scatter.pdf, replace
            }
            corr sharefund sharetrans
        }
    }
end
    
program top_mesh_terms
    syntax, data(str) samp(str) samp_type(str)
    use ../external/`samp_type'_split/mesh_`data'_`samp'.dta, clear
    qui merge m:1  pmid using ../external/`samp_type'_filtered/all_jrnl_articles_`samp', assert(1 2 3) keep(3) nogen
    qui merge m:1 pmid using ../external/wos/`samp'_appended, assert(1 2 3)  // restrict to those that were found in wos 
    qui drop if _merge == 2
    tab _merge
    qui keep if strpos(doc_type, "Article")>0
    qui drop if strpos(doc_type, "Retracted")>0
    qui keep if _merge == 3 
    drop _merge
*    qui merge m:1 pmid using ../external/cleaned_samps/list_of_pmids_last5yrs_`data'_`samp', keep(3) nogen
    qui gunique pmid
    local total_articles = r(unique)
    qui replace mesh = subinstr(mesh, "=Y>","",.)
    qui replace mesh = subinstr(mesh, "=N>","",.)
    qui gen gen_mesh = mesh if strpos(mesh, ",") == 0 & strpos(mesh, ";") == 0
    qui replace gen_mesh = mesh if strpos(mesh, "Models") > 0
    qui replace gen_mesh = subinstr(gen_mesh, "&; ", "&",.)
    qui gen rev_mesh = reverse(mesh)
    qui replace rev_mesh = substr(rev_mesh, strpos(rev_mesh, ",")+1, strlen(rev_mesh)-strpos(rev_mesh, ","))
    qui replace rev_mesh = reverse(rev_mesh)
    qui replace gen_mesh = rev_mesh if mi(gen_mesh) 
    qui drop rev_mesh
    preserve
    qui gcontract pmid mesh, nomiss
    qui save ../temp/contracted_mesh_`data'_`samp', replace
    restore
    gcontract pmid gen_mesh, nomiss
    qui save ../temp/contracted_gen_mesh_`data'_`samp', replace

    foreach mesh in mesh gen_mesh {
        use ../temp/contracted_`mesh'_`data'_`samp', clear
        qui bys pmid: gen wt = 1/_N
        qui bys pmid: gen num_`mesh' = _N
        sum num_`mesh'
        cap drop _freq
        gcollapse (sum) article_wt = wt , by(`mesh')
        qui hashsort -article_wt
        qui gen perc = article_wt/`total_articles'*100
        qui gen cum_perc = sum(perc) 
        qui sum article_wt
        local total = round(r(sum))
        qui count
        local rank_end = min(20,r(N))
        li in 1/`rank_end'
        mkmat article_wt perc cum_perc in 1/`rank_end', mat(top_`mesh'_`samp')
        mat top_`mesh'_`data'_`samp' = top_`mesh'_`samp' \ (.,`total', .)
        qui levelsof `mesh' in 1/3, local(`mesh'_terms_`data')
        qui gen rank = _n
        qui replace rank = 4 if rank > 3
        qui replace `mesh' = "other" if rank == 4
        qui gen inst = "total"
        gcollapse (sum) article_wt perc cum_perc, by(inst `mesh' rank)
        drop rank
        qui save ../temp/`mesh'_`data'_`samp', replace
       /* 
        use ../temp/cleaned_last5yrs_`data'_`samp', clear
        gcollapse (sum) affl_wt , by(pmid inst)
        qui joinby pmid using ../temp/contracted_`mesh'_`data'_`samp'
        qui bys pmid inst : gen num_`mesh' = _N
        qui gen article_wt = affl_wt * 1/num_`mesh'
        qui keep if inlist(inst, "Harvard University", "Stanford University", "University of California, San Francisco", "NIH")
        gen keep_`mesh' = 0
        foreach m in ``mesh'_terms_`data'' {
            qui replace keep_`mesh' = 1 if `mesh' == "`m'"
        }
        qui replace `mesh' = "other" if keep_`mesh' == 0
        gcollapse (sum) article_wt , by(inst `mesh')
        qui bys inst : egen tot = total(article_wt)
        qui hashsort inst -article_wt
        gen perc = article_wt/tot
        gen cum_perc = sum(perc)
        drop tot
        append using ../temp/`mesh'_`data'_`samp'
        qui save ../temp/`mesh'_`data'_`samp', replace*/
    }
end

program output_tables
    syntax, data(str) samp(str)
    foreach file in top_country top_city_full top_inst top_mesh top_gen_mesh {
        qui matrix_to_txt, saving("../output/tables/`file'_`data'_`samp'.txt") matrix(`file'_`data'_`samp') ///
           title(<tab:`file'_`data'_`samp'>) format(%20.4f) replace
         }
 end
** 
main
