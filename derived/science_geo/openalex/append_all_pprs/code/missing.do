set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/openalex"

program main
    use ../external/athrs/list_of_works, clear
    count
    local N = round(r(N)/5000)
    di "`N'"
    local list
    forval i = 1/7000 {
        cap confirm file "/export/scratch/cxu_sci_geo/append_all_pprs/ppr`i'.dta"
        if _rc != 0 {
            *di "`i'"
            local list `list' "`i' "
        }
    }
    di "`list'"
end
main
