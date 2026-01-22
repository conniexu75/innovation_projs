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
    get_split
end
program get_split 
    use ../external/pmids/openalex_all_jrnls_merged.dta, clear
    keep if inlist(jrnl, "Science", "Nature", "Cell", "Neuron", "Nature Genetics") | inlist(jrnl, "Nature Medicine", "Nature Biotechnology", "Nature Neuroscience", "Nature Cell Biology", "Nature Chemical Biology") | inlist(jrnl, "Cell stem cell", "PLoS ONE", "Journal of Biological Chemistry", "Oncogene", "The FASEB Journal")
    compress, nocoalesce
    save ../output/openalex_15jrnls_merged, replace 
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_athrs_15jrnls, replace

    use ../external/pmids/openalex_all_jrnls_merged.dta, clear
    drop if inlist(jrnl, "Science", "Nature", "Cell", "Neuron", "Nature Genetics") | inlist(jrnl, "Nature Medicine", "Nature Biotechnology", "Nature Neuroscience", "Nature Cell Biology", "Nature Chemical Biology") | inlist(jrnl, "Cell stem cell", "PLoS ONE", "Journal of Biological Chemistry", "Oncogene", "The FASEB Journal")
    compress, nocoalesce
    save ../output/openalex_rest_merged, replace 
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    fmerge 1:1 athr_id using ../output/list_of_athrs_15athrs, assert(1 2 3) keep(1) nogen
    save ../output/list_of_athrs_rest, replace
end

main
