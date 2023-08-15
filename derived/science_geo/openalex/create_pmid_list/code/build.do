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
    use ../external/pmids/cleaned_all_jrnl_base, clear
    merge 1:1 pmid using ../external/wos/all_jrnls_appended.dta, assert(1 2 3) keep(3) nogen 
    merge 1:1 pmid using ../external/xwalk/newfund_pmids, assert(1 2 3) keep(3) nogen
    gen lower_title = strlower(title)
    drop if strpos(lower_title, "economic")>0
    drop if strpos(lower_title, "economy")>0
    drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
    drop if strpos(lower_title, "health care")>0
    drop if strpos(lower_title, "health-care")>0
    drop if strpos(lower_title, "public health")>0
    drop if strpos(lower_title, "government")>0
    drop if strpos(lower_title, "reform")>0
    drop if strpos(lower_title , "quality")>0
    drop if strpos(lower_title , "equity")>0
    drop if strpos(lower_title , "payment")>0
    drop if strpos(lower_title , "politics")>0
    drop if strpos(lower_title , "policy")>0
    drop if strpos(lower_title , "comment")>0
    drop if strpos(lower_title , "guideline")>0
    drop if strpos(lower_title , "professionals")>0
    drop if strpos(lower_title , "physician")>0
    drop if strpos(lower_title , "workforce")>0
    drop if strpos(lower_title , "medical-education")>0
    drop if strpos(lower_title , "medical education")>0
    drop if strpos(lower_title , "funding")>0
    drop if strpos(lower_title , "conference")>0
    drop if strpos(lower_title , "insurance")>0
    drop if strpos(lower_title , "fellowship")>0
    drop if strpos(lower_title , "ethics")>0
    drop if strpos(lower_title , "legislation")>0
    drop if strpos(lower_title , " regulation")>0
    gcontract pmid
    drop _freq
    save ../output/list_of_pmids_newfund_jrnls, replace 
end

program get_clin_pmids
    use ../external/pmids/cleaned_clin_med_base, clear
    merge 1:1 pmid using ../external/wos/med_appended.dta, assert(1 2 3) keep(3) nogen 
    merge 1:1 pmid using ../external/xwalk/med_all_pmids, assert(1 2 3) keep(3) nogen
    gen lower_title = strlower(title)
    drop if strpos(lower_title, "economic")>0
    drop if strpos(lower_title, "economy")>0
    drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
    drop if strpos(lower_title, "health care")>0
    drop if strpos(lower_title, "health-care")>0
    drop if strpos(lower_title, "public health")>0
    drop if strpos(lower_title, "government")>0
    drop if strpos(lower_title, "reform")>0
    drop if strpos(lower_title , "quality")>0
    drop if strpos(lower_title , "equity")>0
    drop if strpos(lower_title , "payment")>0
    drop if strpos(lower_title , "politics")>0
    drop if strpos(lower_title , "policy")>0
    drop if strpos(lower_title , "comment")>0
    drop if strpos(lower_title , "guideline")>0
    drop if strpos(lower_title , "professionals")>0
    drop if strpos(lower_title , "physician")>0
    drop if strpos(lower_title , "workforce")>0
    drop if strpos(lower_title , "medical-education")>0
    drop if strpos(lower_title , "medical education")>0
    drop if strpos(lower_title , "funding")>0
    drop if strpos(lower_title , "conference")>0
    drop if strpos(lower_title , "insurance")>0
    drop if strpos(lower_title , "fellowship")>0
    drop if strpos(lower_title , "ethics")>0
    drop if strpos(lower_title , "legislation")>0
    drop if strpos(lower_title , " regulation")>0
    gcontract pmid
    drop _freq
    save ../output/list_of_pmids_clin_med, replace 
end
main
