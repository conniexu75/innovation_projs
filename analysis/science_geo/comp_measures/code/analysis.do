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
    global city_full_name "world cities"
    global msatitle_name "MSAs"
    global msa_world_name "metropolitan areas"
    global msa_c_world_name "metropolitan areas"
    global inst_name "institutions"
    comp_vars, samp(all_all_jrnls) var1(affl_wt) var2(cite_affl_wt)
    comp_vars, samp(all_all_jrnls) var1(affl_wt) var2(impact_cite_affl_wt)

    comp_vars, samp(all_all_jrnls) var1(pat_adj_wt) var2(frnt_adj_wt)
    comp_vars, samp(all_all_jrnls) var1(pat_adj_wt) var2(body_adj_wt)
    mat corr_var = corr_uw_wt \ corr_uw_if_wt 
    mat corr_pat = corr_pat_frnt \ corr_pat_body 
    mat corr_measures = corr_var \ corr_pat
    foreach file in corr_var corr_pat corr_measures {
        matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
          title(<tab:`file'>) format(%20.4f) replace
    }
end

program comp_vars
    syntax, samp(str) var1(str) var2(str)
    local suf1 = ""
    local suf2 = ""
    forval i = 1/2 {
        if "`var`i''" == "affl_wt" local suf`i' "_uw"
        if "`var`i''" == "cite_affl_wt" local suf`i' "_wt"
        if "`var`i''" == "impact_affl_wt" local suf`i' "_if"
        if "`var`i''" == "impact_cite_affl_wt" local suf`i' "_if_wt"
        if "`var`i''" == "pat_adj_wt" local suf`i' "_pat"
        if "`var`i''" == "frnt_adj_wt" local suf`i' "_frnt"
        if "`var`i''" == "body_adj_wt" local suf`i' "_body"
    }
    foreach type in  country msa_c_world inst {
        use ../external/cleaned_samps/cleaned_`samp', clear
        preserve 
        gcollapse (sum) `var1' `var2', by(`type')
        drop if mi(`type')
        qui sum `var1'
        gen share1 = `var1'/round(r(sum)) * 100
        qui sum `var2'
        gen share2 = `var2'/round(r(sum)) * 100
        hashsort -`var1'
        gen rank1 = _n
        hashsort -`var2'
        gen rank2 = _n
        // inst labels
        cap replace inst = "Caltech" if inst == "california institute tech"
        cap replace inst = "CDC" if inst == "cdc"
        cap replace inst = "Columbia" if inst == "columbia university"
        cap replace inst = "Cornell" if inst == "cornell university"
        cap replace inst = "Duke" if inst == "duke university"
        cap replace inst = "Harvard" if inst == "Harvard University"
        cap replace inst = "JHU" if inst == "johns hopkins university"
        cap replace inst = "Rockefeller Univ." if inst == "university the rockefeller"
        cap replace inst = "MIT" if inst == "Massachusetts Institute of Technology"
        cap replace inst = "Memorial Sloan" if inst == "memorial sloan-kettering cancer center"
        cap replace inst = "MGH" if inst == "massachusetts general hospital"
        cap replace inst = "NYU" if inst == "new York university"
        cap replace inst = "Stanford" if inst == "Stanford University"
        cap replace inst = "UCL" if inst == "university college london"
        cap replace inst = "Berkeley" if inst == "University of California, Berkeley"
        cap replace inst = "UCLA" if inst == "university california los angeles"
        cap replace inst = "UCSD" if inst == "university california san diego"
        cap replace inst = "UCSF" if inst == "university california san francisco"
        cap replace inst = "UChicago" if inst == "university chicago"
        cap replace inst = "UMich" if inst == "university michigan"
        cap replace inst = "UPenn" if inst == "university pennsylvania"
        cap replace inst = "Yale" if inst == "university yale"
        cap replace inst = "Harvard" if inst == "university harvard"
        cap replace inst = "Stanford" if inst == "university stanford"
        cap replace inst = "CAS" if inst == "Chinese Academy of Sciences"
        cap replace inst = "Oxford" if inst == "University of Oxford"
        cap replace inst = "Cambridge" if inst == "university cambridge"
        cap replace inst = "UT Dallas" if inst == "university texas dallas"
        cap replace inst = "UMich" if inst == "university michigan ann arbor"
        cap replace inst = "Dana Farber" if inst == "dana farber cancer institute"
        cap replace inst = "Max Planck" if inst == "Max Planck Society"
        cap replace inst = "NIH" if inst == "National Institutes of Health"
        cap replace inst = "DeepMind" if inst == "deepmind"
        cap replace inst = "Brigham and Women's" if inst == "Brigham and Women's Hospital"
        cap replace inst = "Chinese Academy of Medical Sciences" if inst == "chinese academy med science"
        cap replace inst = "Chinese CDC" if inst == "china cdc"
        cap replace inst = "Jinyintan Hospital" if inst == "jinyintan hospital"

        // shorter us uk cor cities msa
        foreach i in  msa_c_world {
            cap replace `i' = subinstr(`i', "United States", "US",.)
            cap replace `i'= subinstr(`i', "GB", "UK",.)
        }
        // labeling 
        gen lab_share = "" 
        replace lab_share = substr(lab_share, 1, strpos(lab_share, ",")-1) if strpos("`type'", "msa")>0
        replace lab_share = `type' if (inlist(rank1, 1, 2, 3,4, 8, 10) | inlist(rank2, 1, 2, 3,4, 7) | inlist(`type', "DeepMind", "Jinyintan Hospital", "CDC", "Philadelphia-Camden-Wilmington, US", "Seattle-Tacoma-Bellevue, US", "Houston-The Woodlands-Sugar Land, US", "San Jose-Sunnyvale-Santa Clara, US") | inlist(`type', "San Diego-Carlsbad, US", "Oxford, UK", "Washington-Arlington-Alexandria, US"))
        replace lab_share = "" if inlist(lab_share, "chinese center diseasecontrol and prevent","university washington", "San Diego-La Jolla, US", "Max Planck" , "Yale", "Cambridge, UK", "Philadelphia-Camden-Wilmington, US", "Cambridge, UK") | inlist(lab_share,"Seattle-Tacoma-Bellevue, US", "Houston-The Woodlands-Sugar Land, US", "Los Angeles-Long Beach-Anaheim, US") | strpos(lab_share, "Karolinska")>0 | strpos(lab_share, "Atlanta")>0
        replace lab_share = strproper(lab_share) if inlist(lab_share, "pfizer", "DeepMind", "Jinyintan Hospital")
        egen clock = mlabvpos(rank1 rank2)
        cap replace clock = 2 if inlist(lab_share, "Oxford, UK", "San Jose-Sunnyvale-Santa Clara, US")
        cap replace clock = 12 if inlist(lab_share, "Seattle, US", "Beijing, China")
        cap replace clock = 6 if inlist(lab_share, "London, UK")
        cap replace clock = 9 if inlist(lab_share, "New York-Newark-Jersey City, US")
        cap replace clock = 3 if inlist(lab_share,"Chinese Academy of Medical Sciences", "Boston-Cambridge-Newton, US", "Bethesda-DC, US", "Oxford, UK", "Brigham and Women's", "UCSF", "Berkeley") | inlist(lab_share, "Stanford", "NIH", "CAS", "MIT") 
        cap replace clock = 3 if inlist(lab_share,"Pfizer", "DeepMind", "Beijing, China", "New York-Newark-Jersey City", "San Diego-Carlsbad, US", "San Francisco-Oakland-Hayward, US") 
        cap replace clock = 4 if inlist(lab_share,"CDC", "Jinyintan Hospital", "Chinese CDC", "Bethesda-DC, US", "Washington-Arlington-Alexandria, US") 
           
        qui corr share1 share2  if !mi(share1) & !mi(share2)
        local corr : di %3.2f r(rho)
        mat corr`suf1'`suf2' = nullmat(corr`suf1'`suf2') , r(rho)
        local pos = 5
        sum share1
        local max = r(max)
        sum share2
        local max = max(r(max),`max')
        local skip 1 
        gen one = _n
        gen zero = _n-1
        tw scatter share1 share2 if !mi(share1) & !mi(share2), ///
          mlabel(lab_share) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
          (line zero zero if zero <= `max', lpattern(dash) lcolor(lavender)), ///
          xtitle("`var2'", size(small)) ytitle("`var1'", size(small)) ///
          xlabel(0(`skip')`max', labsize(vsmall)) ylabel(0(`skip')`max', labsize(vsmall)) legend(on order(- "Correlation = `corr'") size(vsmall) pos(`pos') ring(0) region(lwidth(none)))
        graph export ../output/figures/`type'`suf1'`suf2'.pdf, replace
    restore
    }
end
** 
main
