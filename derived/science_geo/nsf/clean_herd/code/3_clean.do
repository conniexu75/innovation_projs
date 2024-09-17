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
global perc_expend_basic_name "% of Total Spending on Basic R&D"
global perc_basic_fed "% of Basic Funding from Federal Sources"
global perc_hhs_fund_ls "% of Federal Life Science Funding from HHS"
global perc_sal "% of Spending on Salaries"
global perc_cap "% of Spending on Capital Expenditures"
global perc_ls_biohs "% of Life Science Spending that's Health Science/Biomedical"
global applied_expend "Applied R&D Expenditure (1000s)"
global basic_expend "Basic R&D Expenditure (1000s)"
global basic_fed_expend "Federal Basic R&D Expenditure (1000s)"
global dev_expend "Developmental Experimental R&D Expenditure (1000s)"
global expend_capital "Capitalized Equipment Expenditure (1000s)"
global expend_salaries "Salaries, wages, and fringe benefits Expenditure (1000s)"
global ls_fund "Life Sciences Expenditure (1000s)"
global ls_cap_fund "Life Sciences Capital Equipment Expenditure (1000s)"
global hs_fund "Health Sciences Expenditure (1000s)"
global bio_fund "Biological and Biomedical Expenditure (1000s)"
program main
    import_data
    summarize_data
end

program import_data 
    import delimited inst_names_matched_name_state.csv, clear
    drop if match_score == 0
    keep inst_id matched_oa_inst_id
    save ../temp/herd_oa_xw, replace

    use ../temp/herd_2010_2022, clear 
    merge m:1 inst_id using ../temp/inst_chars_xw, assert(3) keep(3) nogen
    destring inst_id, replace
    merge m:1 inst_id using ../temp/herd_oa_xw, assert(1 3) keep(3)  nogen
    gen ls_fund = nonfed_ls_fund + fed_ls_fund
    gen hs_fund = fed_ls_hs_fund + nonfed_ls_hs_fund
    gen bio_fund = fed_ls_bio_fund + nonfed_ls_bio_fund
    gen perc_ls_biohs = (hs_fund+bio_fund)/ls_fund 
    bys inst_id : egen total_funding = mean(tot_fund)
    bys inst_id : gen num_years =  _N
    gen phd_granting = hdg_code == 1
    gen ba_granting = hdg_code == 3
    gen ma_granting = hdg_code == 2
    gen prof_granting = hdg_code == 6
    save ../output/herd_2010_2022, replace 
end

program summarize_data
    gunique inst_id 
    ds inst_* matched* *granting hbcu_flag med_sch hhe_flag public, not
    local var `r(varlist)'
    collapse (mean) `var' (max) *granting hbcu_flag med_sch hhe_flag public , by(inst_id) 
    save ../output/collapse_herd_2010_2022, replace
    foreach var in hbcu_flag med_sch public phd_granting ba_granting ma_granting prof_granting {
        replace `var' = 0 if mi(`var')
        sum `var'
        mat inst_stats = nullmat(inst_stats) , r(mean)
    }
    ds hbcu_flag med_sch hhe_flag public inst_id *_granting, not
    foreach var in  `r(varlist)' {  
        qui sum `var', d
        local N = r(N)
        local mean : dis %3.2f r(mean)
        local med : dis %3.2f r(p50)
        local p5 : dis %3.2f r(p5)
        local p95 : dis %3.2f r(p95)
        local p1 = r(p1)
        local p99 = r(p99)
        tw hist `var' if inrange(`var', `p1',`p99'), frac ytitle("Share of Institutions", size(small)) bin(50) legend(on order(-  "N = `N'" ///
                                                                                        "mean = `mean'" ///
                                                                                        "median = `med'" ///
                                                                                        "p5 = `p5'" ///
                                                                                        "p95 = `p95'") pos(1) region(fcolor(none)) ring(0) size(small)) xtitle("${`var'_name}", size(small)) ylab(, labsize(small)) xlab(, labsize(small))
        graph export ../output/`var'_dist.pdf , replace
    }

end
main
