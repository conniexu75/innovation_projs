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
global analysis_samp "/export/scratch/cxu_sci_geo/create_panel/output"

program main
    append
end

program append
    qui {
        forval i = 112/10966 {
            import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
            keep if pub_type == "dissertation" | pub_type_crossref == "dissertation"
            if _N > 0 {
                gen date = date(pub_date, "YMD")
                format date %td
                gen qrtr = qofd(date)
                gen year = yofd(date)
                gcontract athr_id  qrtr year inst_id pub_date, freq(num_times)
                *drop if mi(inst_id)
                fmerge m:1 athr_id using ../external/athrs/list_of_athrs, assert(1 2 3) keep(3) nogen
                save ${temp}/ppr`i', replace
            }
        }
    }
    clear
    forval i = 1/10966 {
        di "`i'"
        cap append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gcollapse (sum) num_times, by(athr_id inst_id qrtr year)
    hashsort athr_id year -inst_id
    gduplicates drop athr_id year, force
    rename (inst_id qrtr year) (phd_inst_id phd_qrtr phd_year)
    drop num_times
    gduplicates tag athr_id, gen(dup)
    keep if dup == 0
    gisid athr_id
    drop dup
    save ${output}/appended_pprs, replace
end

main
