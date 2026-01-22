set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global overall_fund tot_fund tot_fed_fund tot_bus_fund tot_inst_fund tot_state_fund tot_nonprof_fund 
global external_fund_source contracts_fund grants_fund
global science_fund med_sch_expend clin_trial_expend fed_ls_fund nonfed_ls_fund ls_cap_expend 
global rd_type basic_expend basic_fed_expend applied_expend applied_fed_expend 
global other_fund expend_salaries expend_capital 
global vars $overall_fund  $science_fund $rd_type $external_fund_source $other_fund 

program main
    merge_data, samp(year_second)
end

program merge_data
    syntax, samp(str)
    use  ../external/mover/mover_temp_`samp' , clear  
    merge m:1 athr_id using ../external/mover/mover_xw_`samp', assert(1 2 3) keep(3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    bys inst_id athr_id: gen athr_tag = _n == 1 & analysis_cond == 1
    bys inst_id: egen num_athrs = total(athr_tag)
    keep if num_athrs>=25
    reghdfe ln_y, absorb(inst_fes = inst_id athr_fes = athr_id year_fes = year) residual
    gcontract inst_id inst_fes
    drop _freq
    drop if mi(inst_fes)
    save ../temp/inst_fes, replace

    use ../external/samp/athr_panel_full_comb_`samp', clear
    gcollapse (sum) body_adj_wt, by(inst_id)
    save ../temp/pat_measure, replace 

    import delimited using ../external/rd/herd_2010_2022, clear
    merge 1:1 inst_id using ../external/xw/inst_names, assert(2 3) keep(3) nogen
    drop _freq
    merge 1:1 inst_id using ../external/xw/herd_oa_xw, assert(1 2 3) keep(3) nogen
    rename inst_id herd_id
    rename matched_oa_inst_id inst_id
    save ../temp/merged_data, replace
    merge 1:1 inst_id using ../temp/inst_fes.dta, assert(1 2 3) keep(3) nogen
    merge 1:1 inst_id using ../temp/pat_measure.dta, assert(1 2 3) keep(3) nogen
    foreach var in $vars {
        qui sum `var', d
        replace `var' = (`var'-r(mean))/r(sd) 
    }
    sum inst_fes, d
    replace inst_fes= (inst_fes-r(mean))/r(sd)
    foreach var in $vars { 
        reg inst_fes `var'
        estimates store `var'
    }
    label variable tot_fed_fund "R&D From Federal Gov't ($)" 
    label variable tot_bus_fund "R&D From Businesses ($)" 
    label variable tot_inst_fund "R&D From Institution ($)" 
    label variable tot_state_fund "R&D From State and Local Gov't ($)" 
    label variable tot_nonprof_fund "R&D From Nonprofits ($)" 
    label variable tot_fund "Total R&D Expenditures ($)" 
    
    label variable contracts_fund "R&D From Contracts ($)"
    label variable grants_fund "R&D From Grants ($)"

    label variable med_sch_expend "Med School R&D ($)"
    label variable clin_trial_expend "Clinical Trial R&D ($)"
    label variable fed_ls_fund "Life Sciences Federal R&D ($)"
    label variable hhs_ls_fund "Life Sciences Expenditures from HHS"
    label variable nonfed_ls_fund "Life Sciences Non-Federal R&D ($)"
    label variable fed_ls_hs_fund "Health Sciences Expenditures from Federal Sources"
    label variable hhs_ls_hs_fund "Health Sciences Expenditures from HHS"
    label variable nonfed_ls_hs_fund "Health Sciences Expenditures from Non-Federal Sources"
    label variable fed_ls_bio_fund "Biological and Biomedical Expenditures from Federal Sources"
    label variable hhs_ls_bio_fund "Biological and Biomedical Expenditures from HHS"
    label variable nonfed_ls_bio_fund "Biological and Biomedical Expenditures from Non-Federal Sources"
    label variable ls_fund "Life Sciences R&D ($)"
    label variable hs_fund "Health Sciences Expenditures"
    label variable bio_fund "Biological and Biomedical Expenditures"
    label variable ls_cap_expend "Capitalized Life Sciences Equipment R&D ($)"
    label variable perc_fed_fund_ls "% Life Sciences Spending from Federal Sources"
    label variable perc_hhs_fund_ls "% Life Sciences Spending Spending from HHS"
    label variable perc_ls_cap "% Capitalized R&D Equipment Spent on Life Sciences"
    label variable perc_ls_biohs "% Life Sciences Spending that's Health Sciences & Biological and Biomedical"

    label variable basic_expend "Basic Research R&D ($)"
    label variable basic_fed_expend "Basic Research Federal R&D ($)"
    label variable applied_expend "Applied Research R&D ($)"
    label variable dev_expend "Spending on Experimental Development Research"
    label variable applied_fed_expend "Applied Research Federal R&D ($)"
    label variable dev_expend "Spending on Federal Applied Research"
    label variable perc_expend_basic "% Spent on Basic Research"
    label variable perc_basic_fed "% Basic Research Spending that's Federal"

    label variable expend_salaries "R&D Personnel Salaries ($)"
    label variable expend_capital "All Capitalized Equipment R&D ($)"
    label variable expend_fed "Federal $ Spent on Capitalized Equipment"
    label variable expend_nonfed "Nonfederal Federal $ Spent on Capitalized Equipment"
    label variable perc_sal "% Spent on Salaries"
    label variable perc_cap "% Spent on Capitalized Equipment"
    label variable rd_index "HERD R&D Index"
    label variable body_adj_wt "Prevalence of Fundamental Research Cited in Patents"

    coefplot ($overall_fund), drop(_cons) xline(0) title("Sources of R&D Expenditures", size(small)) xlab(, labsize(small)) ylab(, labsize(small)) 
    graph export ../output/figures/overall_fund_`samp'.pdf, replace
    
    coefplot ($external_fund_source), drop(_cons) xline(0) title("Sources of External Funding", size(small)) xlab(, labsize(small)) ylab(, labsize(small)) 
    graph export ../output/figures/external_fund_`samp'.pdf, replace
    
    coefplot ($science_fund), drop(_cons) xline(0) title("Science-Related Expenditures", size(small)) xlab(-0.2(0.05)0.2, labsize(small)) ylab(, labsize(small)) 
    graph export ../output/figures/science_fund_`samp'.pdf, replace

    coefplot ($rd_type), drop(_cons) xline(0) title("R&D Expenditures by Type of Research", size(small)) xlab(, labsize(small)) ylab(, labsize(small)) 
    graph export ../output/figures/rd_type_`samp'.pdf, replace
    
    coefplot ($other_fund), drop(_cons) xline(0) title("Other Spending Statistics", size(small)) xlab(, labsize(small)) ylab(, labsize(small)) 
    graph export ../output/figures/other_fund_`samp'.pdf, replace

    coefplot ($vars), drop(_cons) xline(0) title("", size(small)) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) 
    graph export ../output/figures/place_correlates_`samp'.pdf, replace
end
** 
main
