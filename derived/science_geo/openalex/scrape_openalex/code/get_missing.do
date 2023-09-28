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
    use ../temp/openalex_all_jrnls_merged, clear
    gcontract pmid
    drop _freq
    merge 1:1 pmid using ../external/pmids/cleaned_all_jrnl_base.dta, keep(2) nogen
    save ../output/missed_openalex, replace

    use ../temp/openalex_clin_med_merged, clear
    gcontract pmid
    drop _freq
    merge 1:1 pmid using ../external/pmids/cleaned_clin_med_base.dta, keep(2) nogen
    save ../output/missed_openalex_clin,replace 
end
main
