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
    append_files
end
program append_files
    clear
    local filelist: dir "../output/" files "openalex_authors*.dta"
    foreach file in `filelist' {
        append using ../output/`file'
    }
    gduplicates drop  pmid which_athr which_affl inst_id , force
    gduplicates drop  pmid which_athr inst_id , force
    destring pmid, replace
    bys pmid which_athr (which_affl): replace which_affl = _n
    gisid pmid which_athr which_affl
    save ../output/openalex_merged, replace

    gcontract inst_id
    drop _freq
    drop if mi(inst_id)
    save ../output/list_of_insts, replace
end

main
