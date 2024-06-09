set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/scrape_athr_inst_hist"

program main
    append_files
end
program append_files
    qui {
/*        forval i = 1/10966 {
            import delimited using ../output/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
            gcontract inst_id
            drop _freq
            drop if mi(inst_id)
            save ${temp}/inst`i', replace
        }*/
        clear
        forval i = 1/10966 {
            append using ${temp}/inst`i'
            gduplicates drop
        }
    }
    save ../output/list_of_insts.dta, replace
end
main
