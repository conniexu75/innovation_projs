set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/dissertations"
global output "/export/scratch/cxu_sci_geo/dissertations/output"

program main
    append
end

program append
    qui {
        forval i = 10501/10966 {
            import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
            fmerge m:1 athr_id using ../external/athrs/list_of_athrs, assert(1 2 3) keep(3) nogen
            gen lwr_title = strlower(title)
            destring which_athr, replace
            bys id: egen num_athrs = max(which_athr)
            keep if pub_type == "dissertation" | pub_type_crossref == "dissertation" | strpos(lwr_title, "dissertation") > 0 | (mi(doi) & mi(jrnl) & num_athrs == 1)
            gen dissertation_tag = pub_type == "dissertation" | pub_type_crossref == "dissertation"
            if _N > 0 {
                gen date = date(pub_date, "YMD")
                format date %td
                gen year = yofd(date)
                gcontract athr_id  id lwr_title year inst_id pub_date dissertation_tag
                drop _freq
                save ${temp}/ppr`i', replace
            }
        }
    }
    stop 
    clear
    forval i = 1/10966 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gduplicates tag athr_id, gen(dup)
    bys athr_id: egen has_dissertation = max(dissertation_tag)
    drop if dup > 0 & has_dissertation == 1 & dissertation_tag == 0
    drop dup
    gduplicates tag athr_id, gen(dup)
    hashsort athr_id year -inst_id
    gduplicates drop athr_id  , force
    rename (inst_id year) (phd_inst_id phd_year)
    gisid athr_id
    drop dup
    save ${output}/appended_pprs, replace
end

main
