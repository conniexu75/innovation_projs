set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000

program main
    use ../external/pmids/all_newfund_pmids, clear
    count
    local N = round(r(N)/5000)
    di "`N'"
    local list
    forval i = 1/`N' {
        cap confirm file "../output/openalex_authors`i'.csv"
        if _rc != 0 {
            *di "`i'"
            local list `list' "`i' "
        }
    }
    di "`list'"
end
main
