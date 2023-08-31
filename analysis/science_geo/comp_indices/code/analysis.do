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
    global msa_world_name "metropolitan areas"
    global msa_c_world_name "metropolitan areas"
    global inst_name "institutions"
    foreach samp in cns scisub demsci { 
        local samp_type = cond(strpos("`samp'", "cns")>0 | strpos("`samp'","med")>0, "main", "robust")
/*        foreach data in newfund {
        di "SAMPLE IS : `samp' `data'"
            foreach var in affl_wt cite_affl_wt {
                athr_loc, data(`data') samp(`samp') wt_var(`var')
            }
            qui output_tables, data(`data') samp(`samp') 
        }
        corr_wt, samp(`samp')*/
        foreach var in affl_wt cite_affl_wt {
            qui comp_w_fund, samp(`samp')  wt_var(`var')
        }
    }
/*    foreach file in corr_wt {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }*/
end

program athr_loc
    syntax, data(str) samp(str)  wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    use ../external/cleaned_samps/cleaned_last5yrs_`data'_`samp', clear
    cap drop type
    foreach loc in country msa_c_world inst {
        qui gunique pmid //which_athr //if !mi(affiliation)
        replace `loc' = "harvard university" if "`loc'" == "university harvard"
        replace `loc' = "stanford university" if "`loc'" == "university stanford"
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
        if inlist("`loc'", "inst", "city_full", "msatitle", "msa_world", "msa_c_world") {
            qui levelsof `loc' in 1/`rank_end'
            global `loc'_`data'_`samp' "`r(levels)'"
        }
        qui gen rank_grp = "first" if _n == 1
        qui levelsof `loc' if _n == 1
        global `loc'_first_`data'_`samp' "`r(levels)'"
        qui levelsof `loc' if _n == 2
        global `loc'_2_`data'_`samp' "`r(levels)'"
        qui replace rank_grp = "second" if _n == 2
        qui replace rank_grp = "rest of top 10" if inrange(_n,3,10)
        qui replace rank_grp = "remaining" if mi(rank_grp)
        keep `loc' perc rank_grp
        qui save ../temp/`loc'_rank_`data'_`samp'`suf', replace
        restore
    }
end

program corr_wt 
    syntax, samp(str) 
    foreach loc in country  msa_c_world inst {
        use ../temp/`loc'_rank_newfund_`samp',clear
        gen cat = "unwt"
        append using ../temp/`loc'_rank_newfund_`samp'_wt
        replace cat = "wt" if mi(cat)
        drop rank_grp
        reshape wide perc, i(`loc') j(cat) string
        qui corr percunwt percwt
        local corr = r(rho)
        mat corr_wt_`samp' = nullmat(corr_wt_`samp') , `corr'
    }
    mat corr_wt = nullmat(corr_wt) \ corr_wt_`samp'
end

program comp_w_fund
    syntax, samp(str) wt_var(str)
    local suf = cond("`wt_var'" == "cite_affl_wt", "_wt", "") 
    foreach trans in clin {
         local fund_name "Fundamental Science"
         if "`trans'" == "dis"  local `trans'_name "Disease"
         if "`trans'" == "clin"  local `trans'_name "Clinical"
         if "`trans'" == "thera"  local `trans'_name "Therapeutics"
         if "`trans'" == "nofund"  local `trans'_name "Translational Science"
         foreach type in  msa_c_world inst {
            qui {
                *global top_20 : list global(`type'_newfund_`samp') | global(`type'_`trans'_`samp')
                use ../external/cleaned_samps/cleaned_last5yrs_newfund_`samp', clear
                cap drop type
                gen s_type = "fund"
                append using ../external/cleaned_samps/cleaned_last5yrs_`trans'_med
                cap drop type
                rename s_type type
                drop if journal_abbr == "annals"
                replace type = "trans" if mi(type)
                gen to_keep = 1
                /*foreach i of global top_20 {
                    replace to_keep = 1 if `type' == "`i'" 
                }*/
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
                save ../temp/`type'`suf', replace
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
                replace lab_share = substr(lab_share, 1, strpos(lab_share, ",")-1) if strpos("`loc'", "msa")>0
                replace lab_share = `type' if (inlist(rankfund, 1, 2, 3,4, 8, 10) | inlist(ranktrans, 1, 2, 3,4, 7) | inlist(`type', "DeepMind", "Jinyintan Hospital", "CDC", "Philadelphia-Camden-Wilmington, US", "Seattle-Tacoma-Bellevue, US", "Houston-The Woodlands-Sugar Land, US", "San Jose-Sunnyvale-Santa Clara, US") | inlist(`type', "San Diego-Carlsbad, US", "Oxford, UK", "Washington-Arlington-Alexandria, US"))
                replace lab_share = "" if inlist(lab_share, "chinese center diseasecontrol and prevent","university washington", "San Diego-La Jolla, US", "Max Planck" , "Yale", "Cambridge, UK", "Philadelphia-Camden-Wilmington, US", "Cambridge, UK") | inlist(lab_share,"Seattle-Tacoma-Bellevue, US", "Houston-The Woodlands-Sugar Land, US", "Los Angeles-Long Beach-Anaheim, US") | strpos(lab_share, "Karolinska")>0 | strpos(lab_share, "Atlanta")>0
                replace lab_share = strproper(lab_share) if inlist(lab_share, "pfizer", "DeepMind", "Jinyintan Hospital")
                egen clock = mlabvpos(rankfund ranktrans)
                cap replace clock = 2 if inlist(lab_share, "Oxford, UK", "San Jose-Sunnyvale-Santa Clara, US")
                cap replace clock = 12 if inlist(lab_share, "Seattle, US", "Beijing, China")
                cap replace clock = 6 if inlist(lab_share, "London, UK")
                cap replace clock = 9 if inlist(lab_share, "New York-Newark-Jersey City, US")
                cap replace clock = 3 if inlist(lab_share,"Chinese Academy of Medical Sciences", "Boston-Cambridge-Newton, US", "Bethesda-DC, US", "Oxford, UK", "Brigham and Women's", "UCSF", "Berkeley") | inlist(lab_share, "Stanford", "NIH", "CAS", "MIT") 
                cap replace clock = 3 if inlist(lab_share,"Pfizer", "DeepMind", "Beijing, China", "New York-Newark-Jersey City", "San Diego-Carlsbad, US", "San Francisco-Oakland-Hayward, US") 
                cap replace clock = 4 if inlist(lab_share,"CDC", "Jinyintan Hospital", "Chinese CDC", "Bethesda-DC, US", "Washington-Arlington-Alexandria, US") 
               
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
                  xtitle("Share of Worldwide ``trans'_name' Research Output (%)", size(small)) ytitle("Share of Worldwide `fund_name' Research Output (%)", size(small)) ///
                  xlabel(0(`skip')`max', labsize(vsmall)) ylabel(0(`skip')`max', labsize(vsmall)) legend(on order(- "Correlation = `corr'") size(vsmall) pos(`pos') ring(0) region(lwidth(none)))
                if "`samp'" == "cns" {
                    graph export ../output/figures/bt_`type'_`trans'_`samp'`suf'_share_scatter.pdf, replace
                }
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
