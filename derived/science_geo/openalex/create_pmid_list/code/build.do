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
    get_newfund_pmids
    get_clin_pmids
end
program get_newfund_pmids
    // these are jouranl articles from pubmed
    use ../external/pmids/cleaned_all_jrnl_base, clear
    merge 1:1 pmid using ../external/xwalk/newfund_pmids, assert(1 2 3) keep(3) nogen
    gcontract pmid
    drop _freq
    save ../output/list_of_pmids_newfund_jrnls, replace 
end

program get_clin_pmids
    use ../external/pmids/cleaned_clin_med_base, clear
    merge 1:1 pmid using ../external/xwalk/med_all_pmids, assert(1 2 3) keep(3) nogen
    gcontract pmid
    drop _freq
    save ../output/list_of_pmids_clin_med, replace 
end
