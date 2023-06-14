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
    global msatitle_name "MSAs"
    foreach samp in cns {
        di "OUTPUT START"
        local samp_type = cond("`samp'" == "cns", "main", "robust")
        foreach data in newfund { 
            foreach var in cite_affl_wt {
                athr_loc, data(`data') samp(`samp') wt_var(`var')
                qui trends, data(`data') samp(`samp') wt_var(`var')
            }
            calc_broad_hhmi, data(`data') samp(`samp') 
            top_mesh_terms, data(`data') samp(`samp') samp_type(`samp_type')
            qui output_tables, data(`data') samp(`samp') 
        }
    } 
    top_mesh_terms, data(clin) samp(med) samp_type(clinical)
end

program athr_loc
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/cleaned_samps/cleaned_last5yrs_`data'_`samp', clear
    foreach loc in country city_full inst msatitle {
        qui gunique pmid 
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
        mkmat perc cum_perc in 1/`rank_end', mat(top_`loc'_`samp'`suf')
        mat top_`loc'_`data'_`samp' = nullmat(top_`loc'_`data'_`samp') , (top_`loc'_`samp'`suf')
        qui levelsof `loc' in 1/2
        global top2_`loc'_`data' "`r(levels)'"
        if inlist("`loc'", "inst", "city_full", "msatitle") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc'_`data' "`r(levels)'"
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
        qui replace rank_grp = "rest of top 10" if inrange(_n,3,10) & rank_grp!="china"
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
    cap drop counter

    qui bys pmid year: gen counter = _n == 1
    qui bys year: egen tot_in_yr = total(counter)
    foreach loc in country city_full inst msatitle {
        preserve
        replace `loc' = "harvard university" if `loc' == "university harvard"
        replace `loc' = "stanford university" if `loc' == "university stanford"
        qui merge m:1 `loc' using ../temp/`loc'_rank_`data'_`samp'`suf', assert(1 3) keep(1 3) nogen
        if "`loc'" == "inst" {
            replace `loc' = strproper(`loc')
        }
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
        if "`loc'" == "city_full" | "`loc'" == "msatitle" {
            label define rank_grp 1 ${`loc'_first} 2 ${`loc'_second} 3 "Rest of the top 10 ${`loc'_name}" 4 "Remaining places"
        }
        if "`loc'" == "inst" {
            local proper_1 = strproper(${`loc'_first})
            local proper_2 = strproper(${`loc'_second})
            label define rank_grp 1 "`proper_1'" 2 "`proper_2'" 3 "Rest of the top 10 ${`loc'_name}" 4 "Remaining places"
        }
        if "`loc'" == "country" {
            label define rank_grp 1 ${`loc'_first} 2 ${`loc'_second} 3 "China" 4 "Rest of the top 10 ${`loc'_name}" 5 "Remaining places"
        }
        label var rank_grp rank_grp
        qui gen group = 1 if rank_grp == "first"
        qui replace group = 2 if rank_grp == "second"
        qui replace group = 3 if rank_grp == "china" & "`loc'" == "country"
        local last = 2
        if "`loc'" == "country" local last = 3 
        qui replace group = `last'+1 if rank_grp == "rest of top 10" 
        qui replace group = `last'+2 if rank_grp == "remaining"
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
        qui gen labely_lab = "Everywhere else" if group == `last'+2
        qui replace labely_lab = "Rest of the top 10 ${`loc'_name}" if group == `last'+1
        qui replace labely_lab = "China" if group == 3 & "`loc'"=="country"
        qui replace labely_lab = ${`loc'_second} if group == 2
        qui replace labely_lab = ${`loc'_first} if group == 1
        qui replace labely_lab = strproper(${`loc'_second}) if group == 2 & "`loc'" == "inst"
        qui replace labely_lab = strproper(${`loc'_first}) if group == 1 & "`loc'" == "inst"
        qui replace labely_lab = subinstr(labely_lab, "United States", "US", .)
        qui replace labely_lab = subinstr(labely_lab, "United Kingdom", "UK", .)
        qui sum `year_var'
        replace `year_var' = 2022 if `year_var' == r(max)
        if "`loc'" == "country" {
            graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
              msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
              ytitle("Share of Worldwide Fundamental Science Research Output", size(vsmall)) xtitle("Year", size(vsmall)) xlabel(`min_year'(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
              graphregion(margin(r+25)) plotregion(margin(zero)) ///
              legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "China") label(4 "Rest of the top 10 ${`loc'_name}") label(5 "Remaining places") ring(1) pos(6) rows(2))
            qui graph export ../output/figures/`loc'_stacked_`data'_`samp'`suf'.pdf , replace 
        }
        local w = 25 
        if "`loc'" == "msatitle" local w = 32
        if "`loc'" != "country" {
            graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
              msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
              ytitle("Share of Worldwide Fundamental Science Research Output", size(vsmall)) xtitle("Year", size(vsmall)) xlabel(`min_year'(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
              graphregion(margin(r+`w')) plotregion(margin(zero)) ///
              legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "Rest of the top 10 ${`loc'_name}") label(4 "Remaining places") ring(1) pos(6) rows(2))
            qui graph export ../output/figures/`loc'_stacked_`data'_`samp'`suf'.pdf , replace 
        }
        restore
    }
end 
    
program top_mesh_terms
    syntax, data(str) samp(str) samp_type(str)
    use ../external/`samp_type'_split/mesh_`data'_`samp'.dta, clear 
    cap keep pmid mesh which_mesh cat journal_abbr
    qui merge m:1 pmid using ../external/cleaned_samps/list_of_pmids_`data'_`samp', assert(1 2 3) keep(3) nogen
    gunique pmid
    cap drop _merge
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
    qui contract pmid mesh, nomiss
    qui save ../temp/contracted_mesh_`data'_`samp', replace
    restore
    contract pmid gen_mesh, nomiss
    qui save ../temp/contracted_gen_mesh_`data'_`samp', replace

    foreach mesh in gen_mesh {
        use ../temp/contracted_`mesh'_`data'_`samp', clear
        qui bys pmid: gen wt = 1/_N
        qui bys pmid: gen num_`mesh' = _N
        sum num_`mesh'
        cap drop _freq
        collapse (sum) article_wt = wt , by(`mesh')
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
        collapse (sum) article_wt perc cum_perc, by(inst `mesh' rank)
        drop rank
        qui save ../temp/`mesh'_`data'_`samp', replace
    }
end

program output_tables
    syntax, data(str) samp(str)
    foreach file in top_country top_city_full top_inst top_gen_mesh top_msatitle {
        qui matrix_to_txt, saving("../output/tables/`file'_`data'_`samp'.txt") matrix(`file'_`data'_`samp') ///
           title(<tab:`file'_`data'_`samp'>) format(%20.4f) replace
         }
 end
** 
main
