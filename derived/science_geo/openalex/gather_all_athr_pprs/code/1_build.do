set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/gather_author_ppr"

program main
    get_athrs
end
program get_athrs 
    use ../external/pmids/openalex_all_jrnls_merged.dta, clear
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_athrs, replace
end

main
