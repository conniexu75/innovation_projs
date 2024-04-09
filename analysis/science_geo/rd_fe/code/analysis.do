set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global movers "/export/scratch/cxu_sci_geo/movers"
global overall_fund tot_fund tot_fed_fund tot_bus_fund tot_inst_fund tot_state_fund tot_nonprof_fund 
global external_fund_source contracts_fund grants_fund
global science_fund med_sch_expend clin_trial_expend fed_ls_fund fed_ls_hs_fund fed_ls_bio_fund hhs_ls_bio_fund hhs_ls_fund hhs_ls_hs_fund nonfed_ls_fund nonfed_ls_bio_fund nonfed_ls_hs_fund ls_fund hs_fund bio_fund ls_cap_expend perc_fed_fund_ls perc_hhs_fund_ls perc_ls_cap 
global rd_type basic_expend basic_fed_expend applied_expend applied_fed_expend dev_expend perc_expend_basic perc_basic_fed 
global other_fund expend_salaries expend_capital expend_fed expend_nonfed perc_sal perc_cap rd_index
global vars $overall_fund $external_fund_source $science_fund $rd_type $other_fund

program main
    merge_data, samp(year)
    merge_data, samp(year_firstlast)
end

program merge_data
    syntax, samp(str)
    use if analysis_cond == 1 & inrange(year, 1945, 2022)  using ${movers}/mover_temp_`samp' , clear  
    merge m:1 athr_id using ${movers}/mover_xw, assert(1 2 3) keep(3) nogen
    keep athr_id inst field year msa_comb impact_cite_affl_wt msa_size which_place inst_id move_year
    hashsort athr_id year
    gen rel = year - move_year
    merge m:1 athr_id move_year using ${movers}/dest_origin_changes, keep(3) nogen
    hashsort athr_id year
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gen ln_y = ln(impact_cite_affl_wt)
    forval i = 1/18 {
        gen lag`i' = 1 if rel == -`i'
        gen lead`i' = 1 if rel == `i'
    }
    ds lead* lag*
    foreach var in `r(varlist)' {
        replace `var' = 0 if mi(`var')
        replace `var' = `var'*msa_ln_y_diff
    }
    gen treat = msa_ln_y_diff if rel == 0  
    replace treat = 0 if mi(treat)
    local leads
    local lags
    forval i = 1/18 {
        local leads `leads' lead`i'
        local lags lag`i' `lags'
    }
    gunique athr_id 
    local num_movers = r(unique)
    mat drop _all
    reghdfe ln_y `lags' treat `leads' , absorb(year field msa field#year field#msa inst_fes = inst athr_fes = athr_id) vce(cluster inst) residuals
    gcontract inst_id inst_fes
    drop _freq
    drop if mi(inst_fes)
    rename inst_fes b
    save ../temp/inst_fes, replace

    import delimited using ../external/rd/herd_2010_2022, clear
    merge 1:1 inst_id using ../external/xw/inst_names, assert(2 3) keep(3) nogen
    drop _freq
    merge 1:1 inst_id using ../external/xw/herd_oa_xw, assert(2 3) keep(3) nogen
    rename inst_id herd_id
    rename matched_oa_inst_id inst_id
    save ../temp/merged_data, replace

    merge 1:1 inst_id using ../temp/inst_fes.dta, assert(1 2 3) keep(3) nogen
    foreach var in $vars {
        qui sum `var', d
        replace `var' = (`var'-r(mean))/r(sd) 
    }
    sum b, d
    replace b= (b-r(mean))/r(sd)
    foreach var in $vars { 
        reg b `var'
        estimates store `var'
    }
    label variable tot_fed_fund "Federal Gov't" 
    label variable tot_bus_fund "Businesses" 
    label variable tot_inst_fund "Institution" 
    label variable tot_state_fund "State and Local Gov't" 
    label variable tot_nonprof_fund "Nonprofit" 
    label variable tot_fund "Total R&D Expenditures" 
    
    label variable contracts_fund "Contracts"
    label variable grants_fund "Grants"

    label variable med_sch_expend "Spent on Med School R&D"
    label variable clin_trial_expend "Spent on Clinical Trials"
    label variable fed_ls_fund "Life Sciences Expenditures from Federal Sources"
    label variable hhs_ls_fund "Life Sciences Expenditures from HHS"
    label variable nonfed_ls_fund "Life Sciences Expenditures from  Non-Federal Sources"
    label variable fed_ls_hs_fund "Health Sciences Expenditures from Federal Sources"
    label variable hhs_ls_hs_fund "Health Sciences Expenditures from HHS"
    label variable nonfed_ls_hs_fund "Health Sciences Expenditures from Non-Federal Sources"
    label variable fed_ls_bio_fund "Biological and Biomedical Expenditures from Federal Sources"
    label variable hhs_ls_bio_fund "Biological and Biomedical Expenditures from HHS"
    label variable nonfed_ls_bio_fund "Biological and Biomedical Expenditures from Non-Federal Sources"
    label variable ls_fund "Life Sciences Expenditures"
    label variable hs_fund "Health Sciences Expenditures"
    label variable bio_fund "Biological and Biomedical Expenditures"
    label variable ls_cap_expend "Capitalized R&D Equipment for Life Sciences"
    label variable perc_fed_fund_ls "% Life Sciences Spending from Federal Sources"
    label variable perc_hhs_fund_ls "% Life Sciences Spending Spending from HHS"
    label variable perc_ls_cap "% Capitalized R&D Equipment Spent on Life Sciences"
    label variable perc_ls_biohs "% Life Sciences Spending that's Health Sciences & Biological and Biomedical"

    label variable basic_expend "Spending on Basic Research"
    label variable basic_fed_expend "Federal Spending on Basic Research"
    label variable applied_expend "Spending on Applied Research"
    label variable dev_expend "Spending on Experimental Development Research"
    label variable applied_fed_expend "Federal Spending on Applied Research"
    label variable dev_expend "Spending on Federal Applied Research"
    label variable perc_expend_basic "% Spent on Basic Research"
    label variable perc_basic_fed "% Basic Research Spending that's Federal"

    label variable expend_salaries "Spent on Salaries"
    label variable expend_capital "Spent on Capitalized Equipment"
    label variable expend_fed "Federal $ Spent on Capitalized Equipment"
    label variable expend_nonfed "Nonfederal Federal $ Spent on Capitalized Equipment"
    label variable perc_sal "% Spent on Salaries"
    label variable perc_cap "% Spent on Capitalized Equipment"
    label variable rd_index "R&D Index"

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
end
** 
main
