set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
here, set

global country_name "countries"
global us_state_name "US states"
global area_name "US cities"
global city_full_name "cities"
global inst_name "institutions"
global msatitle_name "MSAs"
global msa_comb_name "MSAs"
global msa_world_name "cities"
global msa_c_world_name "cities"

program main
    di "OUTPUT START"
    foreach athr_type in first_last all {
    if "`athr_type'" == "first_last" local fol "fl"
    if "`athr_type'" == "all" local fol "all"
        foreach var in impact_cite_affl_wt {
            di "CNS: `var'"
            athr_loc, data(newfund) samp(cns) wt_var(`var') fol(`fol')
            di "ALL: `var'"
            athr_loc, data(all) samp(15jrnls) wt_var(`var') fol(`fol')
        }
        qui output_tables, data(newfund) samp(cns) fol(`fol')
        qui output_tables, data(all) samp(jrnls) fol(`fol')
    }
end

program athr_loc
    syntax, data(str) samp(str)  wt_var(str) fol(str)
    local athr = cond("`fol'" == "fl", "", "_all")
    local suf = ""
    if "`wt_var'" == "cite_affl_wt" local suf "_wt"
    if "`wt_var'" == "impact_cite_affl_wt" local suf "_if_wt"
    if "`wt_var'" == "pat_adj_wt" local suf "_pat"
    if "`wt_var'" == "frnt_adj_wt" local suf "_frnt"
    if "`wt_var'" == "body_adj_wt" local suf "_body"
    if "`data'" == "all" {
        use ../external/`fol'/cleaned_last5yrs_`samp', clear 
    }
    else if "`data'" != "all" {
        use ../external/`fol'/cleaned_last5yrs_`data'_`samp', clear 
    }
    replace inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    local end 20
    replace `wt_var' = log(`wt_var')
    foreach loc in country msa_c_world inst msa_comb us_state {
        if "`loc'" == "inst" & ("`wt_var'" != "pat_adj_wt" & "`wt_var'" != "body_adj_wt") {
            local end 50
        }
        preserve
        if inlist("`loc'", "us_state", "area", "msatitle", "msa_comb") {
            qui keep if country == "United States"
        }
        gen num_pprs = 1 
        bys `loc' year: egen tot_pprs = total(num_pprs)
        collapse (sum) `wt_var' num_pprs (mean) tot_pprs , by(athr_id `loc' year)
        collapse (mean) `wt_var' [fw = num_pprs], by(`loc')
        tw hist `wt_var' , frac bin(50) color(ebblue%50) ytitle("Share of ${`loc'_name}") xtitle("Log Avg. Productivity")
        graph export ../output/figures/dist_`loc'.pdf, replace
        qui hashsort -`wt_var' 
        li if mi(`loc')
        qui drop if mi(`loc')
        gen rank = _n 
        save ../temp/rankings_`loc'`suf'`athr', replace
        drop rank
        qui count
        local rank_end = min(r(N),`end') 
        li `loc' `wt_var' in 1/`rank_end'
        di "Total articles: `total'"
        qui save ../temp/`loc'_rank_`data'_`samp'`suf'`athr', replace
        restore
    }
end

    
program output_tables
    syntax, data(str) samp(str) fol(str)
    local athr = cond("`fol'" == "fl", "", "_all")
    cap mat if_comb`athr' = top_country_jrnls_if_wt`athr' \ top_msa_c_world_jrnls_if_wt`athr'
    cap matrix_to_txt, saving("../output/tables/if_comb`athr'.txt") matrix(if_comb`athr') title(<tab:if_comb`athr'>) format(%20.4f) replace
    cap mat body_comb`athr' = top_country_jrnls_body`athr' \ top_msa_c_world_jrnls_body`athr' \ top_inst_jrnls_body`athr'
    cap matrix_to_txt, saving("../output/tables/body_comb`athr'.txt") matrix(body_comb`athr') title(<tab:body_comb`athr'>) format(%20.4f) replace
    cap mat if_comb_cns`athr' = top_country_cns_if_wt`athr' \ top_msa_c_world_cns_if_wt`athr'
    cap matrix_to_txt, saving("../output/tables/if_comb_cns`athr'.txt") matrix(if_comb_cns`athr') title(<tab:if_comb_cns`athr'>) format(%20.4f) replace
    cap mat body_comb_cns`athr' = top_country_cns_body`athr' \ top_msa_c_world_cns_body`athr' \ top_inst_cns_body`athr'
    cap matrix_to_txt, saving("../output/tables/body_comb_cns`athr'.txt") matrix(body_comb_cns`athr') title(<tab:body_comb_cns`athr'>) format(%20.4f) replace
    foreach file in top_inst {
        cap qui matrix_to_txt, saving("../output/tables/`file'_`samp'_wt`athr'.txt") matrix(`file'_`samp'_wt`athr') ///
           title(<tab:`file'_`samp'_wt`athr'>) format(%20.4f) replace
        cap qui matrix_to_txt, saving("../output/tables/`file'_`samp'_if_wt`athr'.txt") matrix(`file'_`samp'_if_wt`athr') ///
           title(<tab:`file'_`samp'_if_wt`athr'>) format(%20.4f) replace
        cap qui matrix_to_txt, saving("../output/tables/`file'_`samp'_body`athr'.txt") matrix(`file'_`samp'_body`athr') ///
           title(<tab:`file'_`samp'_body`athr'>) format(%20.4f) replace
         }
 end
** 
main
