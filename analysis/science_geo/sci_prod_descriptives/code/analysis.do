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
    foreach samp in select_jrnl natsub scijrnls demsci {
        local samp_type = cond("`samp'" == "select_jrnl", "main", "robust")
        qui get_total_articles, samp(`samp') samp_type(`samp_type')
        foreach data in fund dis thera {
            avg_affiliations, data(`data') samp(`samp') samp_type(`samp_type')
            top_jrnls, data(`data') samp(`samp') 
            athr_loc, data(`data') samp(`samp') 
            calc_broad_hhmi, data(`data') samp(`samp') 
            qui trends, data(`data') samp(`samp') 
            qui top_mesh_terms, data(`data') samp(`samp') samp_type(`samp_type')
            qui output_tables, data(`data') samp(`samp') 
        }
        qui comp_w_fund, samp(`samp') 
    }
end

program get_total_articles 
    syntax, samp(str) samp_type(str)
    use ../external/`samp_type'_total/`samp'_all_pmids, clear
    drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
    drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279)
    gcontract year journal_abbr, freq(num_articles)
    save ../temp/`samp'_counts, replace
    *use ../external/filtered/all_jrnl_articles_select_jrnl, clear
    *save ../temp/all_jrnl_articles_select_jrnl, replace
*    use ../external/total/select_jrnls_pmids, clear
*    merge m:1 pmid using ../temp/all_jrnl_articles_select_jrnl, assert(1 3) keep(3) nogen
*    save ../temp/select_jrnls_pmids, replace
end

program avg_affiliations
    syntax, data(str) samp(str) samp_type(str)
    use ../external/`samp_type'_split/cleaned_`data'_all_`samp', clear
    qui {
        merge m:1  pmid using ../external/`samp_type'_filtered/all_jrnl_articles_`samp', assert(1 2 3) keep(3) nogen
        merge m:1 pmid using ../external/`samp_type'_total/`samp'_all_pmids, assert(2 3) keep(3) nogen
        *gen year = year(date)
        cap drop affil
        replace affiliation = strtrim(affiliation)
        replace affiliation = "" if affiliation == "The authors' affiliations are listed in the Appendix."
        replace affiliation = "" if affiliation == "."
        replace affiliation = "" if strpos(affiliation, "@")>0 & mi(institution)
        gen mi_affl = mi(affiliation)
        bys pmid which_athr: gen which_mi_affl = sum(mi_affl)
        drop if which_mi_affl > 1
        drop which_mi_affl mi_affl
        // we don't want to count broad and HHMI if they are affiliated with other institutions. 
        bys pmid which_athr: gen athr_id = _n == 1
        bys pmid (which_athr): gen which_athr2 = sum(athr_id)
        drop which_athr athr_id
        rename which_athr2 which_athr
        bys pmid which_athr: gen num_affls = _N
        bys pmid which_athr: gen author_counter = _n == 1
        replace num_affls = . if num_affls == 1 & mi(affiliation)
        replace institution = "Broad" if strpos(affiliation, "Broad Institute of MIT and Harvard") > 0 | strpos(affiliation, "Broad Institute") > 0
        gen only_broad = num_affls == 1 & broad_affl == 1
        bys pmid which_athr: egen has_broad_affl = max(broad_affl)
        replace has_broad_affl = 0 if only_broad == 1
        drop if institution == "Broad" & only_broad == 0
        bys pmid which_athr: replace num_affls = _N
        cap rename hmmi_affl hhmi_affl
        replace hhmi_affl = 1 if strpos(affiliation, "Howard Hughes") > 0 | strpos(affiliation, "HHMI") > 0 

        // the below can be moved to server
        replace institution = "HHMI-Janelia" if hhmi_affl == 1 & strpos(affiliation, "Janelia") > 0 
        replace hhmi_affl = 0 if institution == "HHMI-Janelia"
        replace institution = "HHMI" if hhmi_affl == 1 & mi(institution) & num_affls == 1 & city == "Cambridge"
        drop if num_affls > 1 & hhmi_affl == 1 & mi(institution) 
        bys pmid which_athr: egen has_hhmi_affl = max(hhmi_affl)
        qui hashsort pmid which_athr which_affiliation
        bys pmid which_athr: gen athr_id = _n == 1
        bys pmid (which_athr): gen which_athr2 = sum(athr_id)
        drop which_athr athr_id
        rename which_athr2 which_athr
        bys pmid which_athr: replace which_affiliation = _n
        bys pmid which_athr: replace num_affls = _N
        bys pmid which_athr institution: gen inst_counter = _n == 1 if !mi(institution)
        bys pmid which_athr: egen num_insts = total(inst_counter)
        gen mi_inst = mi(institution)
        bys pmid which_athr: egen has_mi_inst = max(mi_inst)
        drop if inst_counter != 1 & num_affls > 1 & num_insts == 1 & has_mi_inst == 0
        bys pmid which_athr: replace which_affiliation = _n
        bys pmid which_athr: replace num_affls = _N
        bys pmid: egen num_athrs = max(which_athr)
        gen affl_wt = 1/num_athrs * 1/num_affls
        replace journal_abbr = "Science" if journal == "Science"
        replace journal_abbr = "BMJ" if journal == "British medical journal (Clinical research ed.)"
        replace journal_abbr = "annals" if journal_abbr == "Ann Intern Med"
        replace journal_abbr = "nejm" if journal_abbr == "N Engl J Med"
        replace journal_abbr = "nat_biotech" if journal_abbr == "Nat Biotechnol"
        replace journal_abbr = "nat_cell_bio" if journal_abbr == "Nat Cell Bio"
        replace journal_abbr = "nat_chem_bio" if journal_abbr == "Nat Chem Bio"
        replace journal_abbr = "nat_genet" if journal_abbr == "Nat Genet"
        replace journal_abbr = "nat_med" if journal_abbr == "Nat Med"
        replace journal_abbr = "faseb" if journal_abbr == "FASEB J"
        replace journal_abbr = "jbc" if journal_abbr == "J Biol Chem"
        replace journal_abbr = "onco" if journal_abbr == "Oncogene"
        replace journal_abbr = "plos" if journal_abbr == "PLoS One"
        replace journal_abbr = "cell_stem_cell" if journal_abbr == "Cell Stem Cell"
        replace journal_abbr = "nat_neuro" if journal_abbr == "Nat Neurosci"
        replace journal_abbr = "neuron" if journal_abbr == "Neuron"
        replace journal_abbr = lower(journal_abbr)
        cap drop _merge
    }
    qui gen mi_affl = mi(affiliation)
    qui bys pmid: egen all_mi_affl = min(mi_affl)
    gunique pmid
    gunique pmid if all_mi_affl == 1
    qui drop if all_mi_affl == 1
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
    qui {
        gen us_city = city if country == "United States"  & !inlist(city, "Center")
        gen area = us_city
        replace area = "Boston-Cambridge" if inlist(us_city, "Boston", "Cambridge")
        replace area = "Bay Area"  if (inlist(us_city, "Stanford", "San Francisco", "Berkeley", "Palo Alto") | inlist(us_city, "Mountain View", "San Jose", "Oakland", "Sunnyvale", "Cupertino", "Menlo Park") | inlist(us_city, "South San Francisco" , "Foster City")) & us_state == "CA" 
        replace area = "San Diego-La Jolla" if inlist(us_city, "La Jolla", "San Diego")
        replace area = "Bethesda-DC" if inlist(us_city, "Bethesda", "Washington")
        replace area = "Research Triangle" if inlist(us_city, "Durham", "Chapel Hill", "Raleigh", "Research Triangle Park", "Cary" , "RTP")
        gen city_country = area + ", " + country if !mi(area) & !mi(country)
        replace city_country = city + ", " + country if !mi(city) & mi(city_country) & !mi(country)
        replace city_country = "Uncoded cities in " + country if mi(city_country) & !mi(country)
        rename city_country city_full
    }
    bys pmid: gen pmid_counter = _n == 1
    rename institution inst
    cap drop _merge
    qui save ../temp/cleaned_all_`data'_`samp', replace
    preserve
    gcollapse (mean) num_athrs num_affls, by(year)
    tw line num_affls year, xlabel(1988(2)2022, angle(45) labsize(vsmall)) ytitle("Average Number of Affiliations per Author", size(small)) xtitle(Year, size(small)) ylabel(1(0.2)5, labsize(vsmall))
    qui graph export ../output/figures/avg_affls_overtime_`data'_`samp'.pdf, replace
    *qui graph export ../output/figures/avg_affls_overtime_`data'_`samp'.png, replace
    tw line num_athrs year, xlabel(1988(2)2022, angle(45) labsize(vsmall)) ytitle("Average Number of Authors per Article", size(small)) xtitle(Year, size(small)) ylabel(0(5)80, labsize(vsmall))
    qui graph export ../output/figures/avg_athrs_overtime_`data'_`samp'.pdf, replace
    *qui graph export ../output/figures/avg_athrs_overtime_`data'_`samp'.png, replace
    restore
    qui keep if inrange(date, td(01jan2015), td(31mar2022))
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
    qui save ../temp/cleaned_last5yrs_`data'_`samp', replace
    preserve
    qui gcontract pmid year
    drop _freq
    qui save ../temp/list_of_pmids_last5yrs_`data'_`samp', replace
    restore
end

program top_jrnls
    syntax, data(str) samp(str) 
    use ../temp/cleaned_all_`data'_`samp', clear
    preserve
    gcollapse (sum) pmid_counter, by(journal_abbr year)
    qui merge 1:1 journal_abbr year using ../temp/`samp'_counts, assert(1 2 3) keep(3) nogen
    gen percent_of_tot = pmid_counter/num_articles
    gcollapse (mean) avg_articles = pmid_counter avg_perc = percent_of_tot, by(journal_abbr)
    qui hashsort -avg_articles
    qui replace avg_perc = avg_perc * 100
    li 
    mkmat avg_articles avg_perc, mat(top_jrnls_`data'_`samp')
    restore
end 

program athr_loc
    syntax, data(str) samp(str) 
    use ../temp/cleaned_last5yrs_`data'_`samp', clear
    foreach loc in country us_state area city_full inst {
        qui gunique pmid //which_athr //if !mi(affiliation)
        qui sum affl_wt
        local total = round(r(sum))
        *local total = r(unique)
        qui sum affl_wt if !mi(`loc') 
        local denom = r(sum) 
        preserve
        if inlist("`loc'", "us_state", "area") {
            qui keep if country == "United States"
        }
        gcollapse (sum) affl_wt, by(`loc')
        qui hashsort -affl_wt 
        qui gen perc = affl_wt / `total' * 100
        li if mi(`loc')
        qui drop if mi(`loc')
        qui gen cum_perc = sum(perc) 
        li `loc' perc in 1/20
        mkmat affl_wt perc cum_perc in 1/20, mat(top_`loc'_`samp')
        mat top_`loc'_`data'_`samp' = top_`loc'_`samp' \ (.,`total', .)
        qui levelsof `loc' in 1/2
        global top2_`loc'_`data' "`r(levels)'"
        if inlist("`loc'", "inst", "city_full") {
            qui levelsof `loc' in 1/20
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
        qui save ../temp/`loc'_rank_`data'_`samp', replace
        restore
    }
end

program calc_broad_hhmi
   syntax, data(str) samp(str) 
   use ../temp/cleaned_last5yrs_`data'_`samp', clear
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
end

program trends
    syntax, data(str) samp(str) 
    use ../temp/cleaned_all_`data'_`samp', clear
    qui bys pmid year: gen counter = _n == 1
    qui bys year: egen tot_in_yr = total(counter)
    foreach loc in country us_state area city_full inst {
        preserve
        qui merge m:1 `loc' using ../temp/`loc'_rank_`data'_`samp', assert(1 3) keep(1 3) nogen
        qui egen year_bin  = cut(year),  at(1988 1990 1992 1994 1996 1998 2000 2002 2004 2006 2008 2010 2012 2014 2016 2018 2020 2022 2024)
        *qui egen year_bin = cut(year),  at(1988 1992 1996 2000 2004 2008 2012 2016 2020 2024) 
        keep if which_athr == 1
        qui replace affl_wt = 1/num_affls
        local year_var year_bin
        qui bys pmid `year_var': replace counter = _n == 1
        qui bys `year_var': egen tot_in_`year_var' = total(counter)
        qui replace rank_grp = "remaining" if mi(rank_grp)
        collapse (sum) affl_wt (mean) tot_in_`year_var' (firstnm) `loc' , by(rank_grp `year_var')
        qui gen perc = affl_wt/tot_in_`year_var' * 100
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
        graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
          msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
          ytitle("Percent of Published Papers", size(small)) xtitle("Year", size(small)) xlabel(1988(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
          graphregion(margin(r+25)) plotregion(margin(zero)) ///
          legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "Rest of the top 10 ${`loc'_name}") label(4 "Remaining places") ring(1) pos(6) rows(2))
        qui graph export ../output/figures/`loc'_stacked_`data'_`samp'.pdf, replace
        restore
    }
end 

program comp_w_fund
    syntax, samp(str) 
    foreach trans in dis thera {
         local fund_name "Fundamental"
         if "`trans'" == "dis"  local `trans'_name "Disease"
         if "`trans'" == "thera"  local `trans'_name "Therapeutics"
         foreach type in city_full inst {
            qui {
                global top_20 : list global(`type'_fund) | global(`type'_`trans')
                use ../temp/cleaned_last5yrs_fund_`samp', clear
                gen type = "fund"
                append using ../temp/cleaned_last5yrs_`trans'_`samp'
                replace type = "trans" if mi(type)
                gen to_keep = 0
                foreach i of global top_20 {
                    replace to_keep = 1 if `type' == "`i'" 
                }
                gcollapse (sum) affl_wt (mean) to_keep, by(`type' type)
                qui sum affl_wt if type == "fund"
                gen share = affl_wt/round(r(sum))*100 if type == "fund"
                qui sum affl_wt if type == "trans"
                replace share = affl_wt/round(r(sum))*100 if type == "trans"
                drop if mi(`type')
                hashsort type -affl_wt
                by type: gen rank = _n 
                keep if to_keep == 1
                qui sum rank
                local rank_lmt = r(max) 
                reshape wide affl_wt rank share, i(`type') j(type) string
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

                egen clock = mlabvpos(rankfund ranktrans)
                cap replace clock = 4 if city_full == "Los Angeles, US"
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
                cap replace clock = 6 if inst == "Wash U"
                local rank_lmt = 20
                tw scatter rankfund ranktrans if inrange(rankfund , 1,`rank_lmt') & inrange(ranktrans ,1,`rank_lmt'), ///
                  mlabel(lab) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line onefund onetrans if onefund <= `rank_lmt', lpattern(dash) lcolor(lavender)), ///
                  xtitle("``trans'_name' Research Output Rank", size(small)) ytitle("`fund_name' Science Research Output Rank", size(small)) ///
                  xlabel(1(1)`rank_lmt', labsize(vsmall)) ylabel(1(1)`rank_lmt', labsize(vsmall)) xsc(reverse) ysc(reverse) legend(off)
                graph export ../output/figures/bt_`type'_`trans'_`samp'_scatter.pdf, replace
                local lim = 15
                local skip = 1
                if "`type'" == "inst" local lim = 5
                if "`type'" == "inst" local skip = 0.5 
                tw scatter sharefund sharetrans, ///
                  mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
                  (line zerofund zerotrans if zerofund <= `lim', lpattern(dash) lcolor(lavender)), ///
                  xtitle("Share of Worldwide ``trans'_name' Research Output (%)", size(small)) ytitle("Share of Worldwide `fund_name' Science Research Output (%)", size(small)) ///
                  xlabel(0(`skip')`lim', labsize(vsmall)) ylabel(0(`skip')`lim', labsize(vsmall)) legend(off)
                graph export ../output/figures/bt_`type'_`trans'_`samp'_share_scatter.pdf, replace
            }
            corr sharefund sharetrans
        }
    }
end
    
program top_mesh_terms
    syntax, data(str) samp(str) samp_type(str)
    use ../external/`samp_type'_split/mesh_`data'_`samp'.dta, clear
    qui merge m:1  pmid using ../external/`samp_type'_filtered/all_jrnl_articles_`samp', assert(1 2 3) keep(3) nogen
    qui merge m:1 pmid using ../temp/list_of_pmids_last5yrs_`data'_`samp', keep(3) nogen
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
        li in 1/20
        mkmat article_wt perc cum_perc in 1/20, mat(top_`mesh'_`samp')
        mat top_`mesh'_`data'_`samp' = top_`mesh'_`samp' \ (.,`total', .)
        qui levelsof `mesh' in 1/3, local(`mesh'_terms_`data')
        qui gen rank = _n
        qui replace rank = 4 if rank > 3
        qui replace `mesh' = "other" if rank == 4
        qui gen inst = "total"
        gcollapse (sum) article_wt perc cum_perc, by(inst `mesh' rank)
        drop rank
        qui save ../temp/`mesh'_`data'_`samp', replace
        
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
        qui save ../temp/`mesh'_`data'_`samp', replace
    }
end

program output_tables
    syntax, data(str) samp(str)
    foreach file in top_jrnls top_country top_us_state top_area top_city_full top_inst top_mesh top_gen_mesh {
        qui matrix_to_txt, saving("../output/tables/`file'_`data'_`samp'.txt") matrix(`file'_`data'_`samp') ///
           title(<tab:`file'_`data'>) format(%20.4f) replace
         }
 end
** 
main
