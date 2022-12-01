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
    global samp select_jrnl
    global basic_name basic
    global translational_name trans
    global diseases_name dis
    global fundamental_name fund
    global therapeutics_name thera
    create_cat_samps
end

program create_cat_samps
foreach cat in basic translational diseases fundamental therapeutics {
        use ../external/xwalk/pmids_category_xwalk, clear
        keep if cat == "`cat'"
        gisid pmid
        save ../temp/${`cat'_name}_pmids, replace

        foreach samp in all last5yrs {
        use ../external/samp/cleaned_`samp'_${samp}, clear
        merge m:1 pmid using ../temp/${`cat'_name}_pmids, assert(1 2 3) keep(3) nogen
        save ../output/cleaned_${`cat'_name}_`samp'_${samp}, replace
        }
    }
end
** 
main
