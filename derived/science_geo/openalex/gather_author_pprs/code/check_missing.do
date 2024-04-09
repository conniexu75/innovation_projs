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
    check_missing
end
program check_missing
    use ../output/list_of_athrs.dta, clear
    count
    local N = ceil(r(N)/500)
    forval i = 1/`N' {
        cap import delimited ../output/works`i'.csv, clear
        if _rc != 0 {
            di "`i'"
        }
    }
end



main
