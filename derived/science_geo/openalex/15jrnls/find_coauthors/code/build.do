set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/coauthors"

program main
    append_files
end

program append_files
    forval i = 10364/11000 {
        di "`i'"
        qui {
            import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited) delimiters(",")
            gen date = date(pub_date, "YMD")
            format date %td
            gen year = yofd(date)
            gcontract athr_id id year
            drop _freq
            save ${temp}/ppr`i', replace
            fmerge m:1 athr_id using ../external/athrs/list_of_athrs_15jrnls, assert(1 2 3) keep(3) nogen
            rename athr_id focal_athr
            joinby id using ${temp}/ppr`i'
            drop if focal_athr == athr_id
            count
            if r(N) > 0 {
                rename athr_id coauthor_id
                gcontract focal_athr year coauthor_id
                drop _freq
                compress, nocoalesce
                save ${temp}/coauthor`i', replace
                }
            }
    }
    /*
    clear
    forval i = 1/11442 {
        di "`i'"
        append using ${temp}/ppr`i'
    }
    drop if athr_id == "A9999999999"
    gcollapse (sum) num_times, by(athr_id inst_id qrtr)

    compress, nocoalesce
    save ${temp}/appended_pprs, replace*/
end
main
