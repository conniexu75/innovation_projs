set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/append_all_pprs"
global output "/export/scratch/cxu_sci_geo/append_all_pprs/output"

program main
    append
end

program append
        forval i = 7900/8000 {
            di "`i'"
            qui {
                import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
                fmerge m:1 athr_id using ../external/athrs/list_of_athrs, assert(1 2 3) keep(3) nogen
                if _N > 0 {
                    gen date = date(pub_date, "YMD")
                    format date %td
                    gen len = strlen(jrnl)
                    qui sum len
                    recast str`r(max)' jrnl, force
                    gcontract athr_id id inst_id pub_date jrnl 
                    drop _freq
                    save ${temp}/ppr`i', replace
                }
            }
        }
    clear
    forval i = 1/1999 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs1, replace
    clear
    forval i = 2000/3999 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs2, replace
    clear
    forval i = 4000/5999 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs3, replace
    clear
    forval i = 6000/7999 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs4, replace
    clear
    forval i = 8000/9999 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs5, replace
    clear
    forval i = 10000/10966 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates drop
    save ${output}/appended_pprs6, replace
    clear
    forval i = 2/6 {
        use ${output}/appended_pprs`i', clear
        gen date = date(pub_date, "YMD")
        gen year = yofd(date)
        gcontract athr_id year, nomiss
        drop _freq
        compress , nocoalesce
        save ${temp}/athr_yrs`i', replace
    }
    clear
    forval i = 1/6 {
        append using ${temp}/athr_yrs`i'
    }
    gduplicates drop 
    save ${output}/appended_athr_yrs, replace
end

main
