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
    local N = r(N)/5000
    di "`N'"
    forval i = 1/`N' {
        cap confirm file "/export/scratch/cxu_sci_geo/scrape_econ_inst/openalex_authors`i'.csv"
        if _rc != 0 {
            di "`i'"
        }
    }
end
main
