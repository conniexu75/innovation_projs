set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/herd"

program main
   import_data 
   create_openalex_xw
end

program import_data 
    forval i = 1972/2022 {
        import delimited ../external/herd/herd_`i'.csv, clear stringcols(_all)
        save ${temp}/`i', replace 
    }
    // clean herd 2010-2022
    // inst ids: keep inst_id hbcu_flag med_sch_flag hhe_flag toi_code hdg_code toc_code inst_name_long inst_city inst_zip inst_state_code
    clear
    forval i = 2010/2022 {
        use ${temp}/`i', clear
        keep inst_id hbcu_flag med_sch_flag hhe_flag toi_code hdg_code toc_code inst_name_long inst_city inst_zip inst_state_code questionnaire_no row column data 
        destring inst_id, replace
        gen question = "tot_fed_fund" if  questionnaire_no == "01.a" 
        replace question = "tot_state_fund" if  questionnaire_no == "01.b" 
        replace question = "tot_bus_fund" if  questionnaire_no == "01.c" 
        replace question = "tot_nonprof_fund" if  questionnaire_no == "01.d" 
        replace question = "tot_inst_fund" if  questionnaire_no == "01.e" 
        replace question = "tot_fund" if  questionnaire_no == "01.g" & row == "Total"
        replace question = "contracts_fund" if  questionnaire_no == "03" & row == "Contracts"
        replace question = "grants_fund" if  questionnaire_no == "03" & row == "Grants, reimbursements, and other agreements"
        replace question = "med_sch_expend" if  questionnaire_no == "04" & row == "Total"
        replace question = "clin_trial_expend" if  questionnaire_no == "05" & row == "Total"
        replace question = "basic_expend" if  questionnaire_no == "06.a" & row == "Basic research" & column == "Total"
        replace question = "basic_fed_expend" if  questionnaire_no == "06.a" & row == "Basic research" & column == "Federal"
        replace question = "dev_expend" if questionnaire_no == "06.c" & row == "Development" & column == "Total"
        replace question = "applied_expend" if questionnaire_no == "06.b" & row == "Applied research" & column == "Total"
        replace question = "applied_fed_expend" if questionnaire_no == "06.b" & row == "Applied research" & column == "Federal"
        replace question = "subrecipient_fund" if  questionnaire_no == "07.e" & row == "All" & column == "Total"
        replace question = "subrecipient_sent" if  questionnaire_no == "08.e" & row == "All" & column == "Total"
        replace question = "fed_ls_hs_fund" if questionnaire_no == "09D03" & row == "Life sciences, health sciences" & column == "Total"
        replace question = "hhs_ls_hs_fund" if questionnaire_no == "09D03" & row == "Life sciences, health sciences" & column == "HHS"
        replace question = "fed_ls_bio_fund" if questionnaire_no == "09D02" & row == "Life sciences, biological and biomedical sciences" & column == "Total"
        replace question = "hhs_ls_bio_fund" if questionnaire_no == "09D02" & row == "Life sciences, biological and biomedical sciences" & column == "HHS"
        replace question = "fed_ls_fund" if questionnaire_no == "09D06" & row == "Life sciences, all" & column == "Total"
        replace question = "hhs_ls_fund" if questionnaire_no == "09D06" & row == "Life sciences, all" & column == "HHS"
        replace question = "nonfed_ls_fund" if  questionnaire_no == "11D06" & row == "Life sciences, all" & column == "Total"
        replace question = "nonfed_ls_hs_fund" if  questionnaire_no == "11D03" & row == "Life sciences, health sciences" & column == "Total"
        replace question = "nonfed_ls_bio_fund" if  questionnaire_no == "11D02" & row == "Life sciences, biological and biomedical sciences" & column == "Total"
        replace question = "expend_salaries" if  questionnaire_no == "12.a" 
        replace question = "expend_capital" if  questionnaire_no == "12.c" 
        replace question = "ls_cap_expend" if questionnaire_no == "14D06" & row == "Life sciences, all" & column == "Total"
        replace question = "expend_fed" if questionnaire_no == "14K" & row == "All" & column == "Federal"
        replace question = "expend_nonfed" if questionnaire_no == "14K" & row == "All" & column == "Nonfederal"
        keep if !mi(question)
        gen year = `i'
        save ${temp}/herd_`i', replace
    }
    clear
    forval i = 2010/2022 {
        append using  ${temp}/herd_`i'
    }
    gen med_sch = 1 if med_sch_flag == "T"
    drop med_sch_flag toi_code
    destring *_flag, replace
    destring *_code, replace
    gen public = toc_code ==1 
    preserve
    collapse (max) hbcu_flag med_sch hhe_flag public (firstnm) hdg_code inst_name_long inst_city inst_state_code inst_zip, by(inst_id)
    gisid inst_id
    save ../temp/inst_chars_xw, replace
    contract inst_id inst_name_long inst_city inst_state_code
    save ../temp/inst_names, replace
    restore
    keep inst_id data year question 
    destring data, replace
    reshape wide data ,i(inst_id year) j(question) string
    rename data* *
    merge m:1 inst_id using ../temp/inst_chars_xw, assert(3) keep(3) nogen
    gen perc_expend_basic = basic_expend/tot_fund
    gen perc_basic_fed = basic_fed_expend/basic_expend
    gen perc_fed_fund_ls = fed_ls_fund / tot_fed_fund
    gen perc_hhs_fund_ls = hhs_ls_fund / fed_ls_fund
    gen perc_sal =expend_salaries/tot_fund
    gen perc_cap =expend_capital/tot_fund
    gen perc_ls_cap = ls_cap_expend / expend_capital
    save ../temp/herd_2010_2022, replace
end

program  create_openalex_xw
    use ../external/openalex/all_inst_geo_chars, clear
    keep if country_code == "US"
    keep new_inst_id new_inst region city new_inst 
    rename new_inst_id inst_id
    rename new_inst inst
    rename region state
    rename inst_id oa_inst_id
    gduplicates drop oa_inst_id, force
    save ../temp/openalex_inst, replace
end

main
