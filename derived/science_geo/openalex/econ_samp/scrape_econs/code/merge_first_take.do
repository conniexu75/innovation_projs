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
    qui {
        forval i = 1/142 {
            import delimited using ../output/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict)
            gen n = `i'
            save ${temp}/openalex_authors`i', replace
        }
        clear
        forval i = 1/142 {
            append using ${temp}/openalex_authors`i'
        }
    }
    destring pmid, replace
    destring which_athr, replace
    destring which_affl, replace
    destring cite_count, replace
    gduplicates drop  pmid which_athr which_affl inst_id , force
    gduplicates drop  pmid which_athr inst_id , force
    gduplicates tag pmid which_athr which_affl, gen(dup)
    drop if dup == 1 & mi(inst)
    drop dup 
    gsort pmid athr_id which_athr
    gduplicates drop pmid athr_id inst_id, force
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    gen mi_inst = mi(inst)
    bys pmid athr_id: egen has_nonmi_inst = min(mi_inst)  
    replace has_nonmi_inst = has_nonmi_inst == 0
    drop if mi(inst) & num_which_athr > 1 & has_nonmi_inst
    drop which_athr_counter num_which_athr
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    cap destring which_athr, replace
    bys pmid athr_id: egen min_which_athr = min(which_athr)
    replace which_athr = min_which_athr if num_which_athr > 1
    gduplicates drop pmid which_athr inst_id, force
    bys pmid which_athr: gen author_id = _n == 1
    bys pmid: gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr (which_affl) : replace which_affl = _n 
    gisid pmid which_athr which_affl
    save ${temp}/openalex_all_jrnls_merged, replace

    // repeat for clin med
    qui {
        forval i = 1/51 {
            import delimited ../output/openalex_authors_clin`i', stringcols(_all) clear bindquotes(strict)
            save ${temp}/openalex_authors_clin`i', replace
        }
        clear
        forval i = 1/51 {
            append using ${temp}/openalex_authors_clin`i'
        }
    }
    destring pmid, replace
    destring which*, replace
    destring cite_count, replace
    gduplicates drop  pmid which_athr which_affl inst_id , force
    gduplicates drop  pmid which_athr inst_id , force
    gduplicates tag pmid which_athr which_affl, gen(dup)
    drop if dup == 1 & mi(inst)
    drop dup 
    gsort pmid athr_id which_athr
    gduplicates drop pmid athr_id inst_id, force
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    gen mi_inst = mi(inst)
    bys pmid athr_id: egen has_nonmi_inst = min(mi_inst)  
    replace has_nonmi_inst = has_nonmi_inst == 0
    drop if mi(inst) & num_which_athr > 1 & has_nonmi_inst
    drop which_athr_counter num_which_athr
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    cap destring which_athr, replace
    bys pmid athr_id: egen min_which_athr = min(which_athr)
    replace which_athr = min_which_athr if num_which_athr > 1
    gduplicates drop pmid which_athr inst_id, force
    bys pmid which_athr: gen author_id = _n == 1
    bys pmid: gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr (which_affl) : replace which_affl = _n 
    gisid pmid which_athr which_affl
    save ${temp}/openalex_clin_med_merged, replace

/*    append using ../output/openalex_newfund_jrnls_merged
    gcontract inst_id
    drop _freq
    drop if mi(inst_id)
    save ../output/list_of_insts, replace*/
end
main
