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
    *append_athrs
    append_clin_athrs
end
program append_athrs
    use if year >= 1945 using ../external/pmids/cleaned_all_all_jrnls.dta, clear
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_athrs, replace
end

program append_clin_athrs
    use if year >= 1945 using ../external/pmids/cleaned_all_clin_med.dta, clear
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_clin_athrs, replace
end
main
