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
    append_pmids
    get_doi
end
program append_pmids
    clear
    foreach samp in cns scisub demsci {
        append using ../external/pmids/list_of_pmids_newfund_`samp'
    }
    save ../output/list_of_pmids_newfund_jrnls, replace 
end

program get_doi
    clear
    foreach samp in cns scisub demsci {
        append using ../external/wos/`samp'_appended
    }
    merge 1:1 pmid using ../output/list_of_pmids_newfund_jrnls, assert(1 3) keep(3) nogen
    keep pmid doi
    save ../output/list_of_doi_newfund_jrnls, replace
end
main
