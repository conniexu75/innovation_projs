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
    use if year >= 1945 using ../external/samp/cleaned_all_15jrnls.dta, clear
    gcontract pmid 
    drop _freq
    merge 1:1 pmid using ../external/pmids_jrnl/all_pmids, assert(1 2 3) keep(3) nogen
    save ../temp/pmids, replace
end
main
