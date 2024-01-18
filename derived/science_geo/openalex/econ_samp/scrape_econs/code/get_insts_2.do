set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/scrape_econs"

program main
    append_files
end
program append_files
    qui {
        foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
            import delimited using "../output/`j'", stringcols(_all) clear varn(1) bindquotes(strict)
            gen journal_abbr = "`j'"
            save ${temp}/`j', replace
        }
        clear
        foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
            append using ${temp}/`j'
        }
    }
    destring which_athr, replace
    destring which_affl, replace
    destring cite_count, replace
    gduplicates drop  id which_athr which_affl inst_id , force
    gduplicates drop  id which_athr inst_id , force
    gduplicates tag id which_athr which_affl, gen(dup)
    drop if dup == 1 & mi(inst)
    drop dup 
    gsort id athr_id which_athr
    gduplicates drop id athr_id inst_id, force
    bys id athr_id which_athr : gen which_athr_counter = _n == 1
    bys id athr_id: egen num_which_athr = sum(which_athr_counter)
    gen mi_inst = mi(inst)
    bys id athr_id: egen has_nonmi_inst = min(mi_inst)  
    replace has_nonmi_inst = has_nonmi_inst == 0
    drop if mi(inst) & num_which_athr > 1 & has_nonmi_inst
    drop which_athr_counter num_which_athr
    bys id athr_id which_athr : gen which_athr_counter = _n == 1
    bys id athr_id: egen num_which_athr = sum(which_athr_counter)
    cap destring which_athr, replace
    bys id athr_id: egen min_which_athr = min(which_athr)
    replace which_athr = min_which_athr if num_which_athr > 1
    gduplicates drop id which_athr inst_id, force
    bys id which_athr: gen author_id = _n == 1
    bys id: gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys id which_athr (which_affl) : replace which_affl = _n 
    gisid id which_athr which_affl
    save ../output/econ_jrnls_merged, replace
    gcontract inst_id
    drop _freq
    drop if mi(inst_id)
    save ../output/list_of_insts, replace
end
main
