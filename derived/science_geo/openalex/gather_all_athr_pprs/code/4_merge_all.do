set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/gather_all_athr_pprs"

program main
    append_pprs
end
program append_pprs
/*    use ../output/list_of_athrs,clear 
    count
    local N = ceil(r(N)/500)
    forval i = 1/`N' {
        import delimited using "${temp}/works`i'", clear
        cap ds v2
        if _rc ==0 {
            keep v2
            rename v2 id
        }
        if _rc != 0 { 
            keep v1 
            rename v1 id
        }
        drop if mi(id)
        replace id = subinstr(id, "//openalex.org", "", .)
        replace id = subinstr(id, "/", "", .)
        save ${temp}/works`i', replace
    }*/

        clear
        forval i = 6001/6403 {
           append using ${temp}/works`i'
           gduplicates drop
        }
        save ../output/list_of_works7, replace
end



main
