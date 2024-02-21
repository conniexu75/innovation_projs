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
    use ../external/ids/list_of_works, clear
    count
    local N = round(r(N)/5000)
    di "`N'"
    local list
    forval i = 1/`N' {
        cap confirm file "/export/scratch/cxu_sci_geo/scrape_full_athr_hist2/openalex_authors`i'.csv"
        if _rc != 0 {
            *di "`i'"
            local list `list' "`i' "
        }
    }
    di "`list'"
end
main
