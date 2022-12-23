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
    global basic_name basic
    global translational_name trans
    global diseases_name dis
    global fundamental_name fund
    global therapeutics_name thera
    foreach samp in natsub demsci scijrnls {
        create_cat_samps, samp(`samp')
    }
end

program create_cat_samps
    syntax, samp(str)
    foreach cat in basic translational diseases fundamental therapeutics {
        use ../external/xwalk/`samp'_pmids_category_xwalk, clear
        keep if cat == "`cat'"
        gisid pmid
        save ../temp/`samp'_${`cat'_name}_pmids, replace

        foreach t in all last5yrs {
        use ../external/samp/cleaned_`t'_`samp', clear
        merge m:1 pmid using ../temp/`samp'_${`cat'_name}_pmids, assert(1 2 3) keep(3) nogen
        save ../output/cleaned_${`cat'_name}_`t'_`samp', replace
        }
        use ../external/samp/major_mesh_terms_`samp', clear
        merge m:1 pmid using ../temp/`samp'_${`cat'_name}_pmids, assert(1 2 3) keep(3) nogen
        save ../output/mesh_${`cat'_name}_`samp', replace
    }
end
** 
main
