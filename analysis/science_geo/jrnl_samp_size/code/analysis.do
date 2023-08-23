set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global country_name "countries"
    global us_state_name "US states"
    global area_name "US cities"
    global city_full_name "world cities"
    global inst_name "institutions"
    foreach samp in cns scisub demsci med { 
        local samp_type = cond(strpos("`samp'", "cns")>0 | strpos("`samp'","med")>0, "main", "robust")
        if "`samp'" == "med" { 
            local samp_type "clinical"
        }
        get_total_articles, samp(`samp') samp_type(`samp_type')
        foreach data in newfund {
            if "`samp'" == "med" {
                local data clin
            }
            di "SAMPLE IS : `samp' `data'"
                top_jrnls, data(`data') samp(`samp') 
                samp_size, data(`data') samp(`samp') 
                mat N_`samp' = nullmat(N_`samp') \ N_`data'_`samp'
            }
            mat N_samp = nullmat(N_samp) \ N_`samp'
            mat top_jrnls_`samp' =  nullmat(top_jrnls_`samp') , top_jrnls_`samp'_N
            if "`samp'" != "med" {
                mat top_jrnls =  nullmat(top_jrnls) \ top_jrnls_`samp'
            }
    }
    top_jrnls, data(newfund) samp(med)
    foreach file in top_jrnls N_samp top_jrnls_med {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }
end

program get_total_articles 
    syntax, samp(str) samp_type(str)
    use ../external/pmids/`samp'_all_pmids, clear
    if "`samp'" != "med" {
        merge 1:1 pmid using ../external/new_pt/cleaned_all_jrnl_base, keep(3) nogen
    }
    if "`samp'" == "med" {
        merge 1:1 pmid using ../external/new_pt/cleaned_clin_med_base, keep(3) nogen
    }
    // delete some weird metastudies that we can't cleanly get affiliations from
/*    drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
    drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279, 33264556, 33631065, 33306283, 33356051)
    drop if inlist(pmid, 34587383, 34260849, 34937145, 34914868, 33332779, 36286256, 28657871, 35353979, 33631066, 27959715)
    drop if inlist(pmid, 29045205, 27376580, 29800062)*/
    cap drop _merge
*    merge 1:1 pmid using ../external/wos/`samp'_appended, assert(1 2 3) 
*    qui drop if _merge == 2
*    tab _merge
*    keep if doc_type == "Article"
*    keep if strpos(doc_type, "Article")>0
   * drop if strpos(doc_type, "Retracted")>0
*    qui keep if _merge == 3
*    drop _merge
    if "`samp'" == "med" local samp_type "main"
    merge 1:1 pmid using ../external/pmids/`samp'_all_pmids, assert(2 3) keep(3) nogen
    replace year = pub_year if !mi(pub_year)
    preserve
    gcontract year journal_abbr, freq(num_articles)
    drop if journal_abbr == "annals"
    save ../temp/`samp'_counts, replace
    restore 
/*    if "`samp'"!= "med" {
        merge 1:m pmid using ../external/cleaned_samps/cleaned_all_fund_`samp', assert(1 3) keep(1) nogen keepusing(pmid)
        merge 1:m pmid using ../external/cleaned_samps/cleaned_all_dis_`samp', assert(1 3) keep(1) nogen keepusing(pmid)
        merge 1:m pmid using ../external/thera/contracted_pmids_thera, assert(1 2 3) keep(1) nogen keepusing(pmid)
        keep pmid year journal_abbr
        save ../output/`samp'_unmatched, replace
    }*/
    if "`samp'" == "med" {
        preserve
        merge 1:m pmid using ../external/openalex/cleaned_all_clin_med, assert(1 2 3) keep(1) nogen keepusing(pmid)
        save ../output/`samp'_unmatched, replace
        restore
        merge 1:m pmid using ../external/pmids/newfund_pmids, assert(1 2 3) keepusing(pmid cat)
        drop if _merge == 2
        drop if _merge == 3 & !inlist(cat, "fundamental", "diseases")
        drop _merge
*        merge 1:m pmid using ../external/thera/contracted_pmids_thera, assert(1 2 3) keepusing(pmid)
*        keep if _merge == 3 | !mi(cat) 
        save ../temp/cleaned_all_newfund_med, replace
    }
end
program top_jrnls
    syntax, data(str) samp(str) 
    if "`data'" == "newfund" & "`samp'" == "med" {
        use ../temp/cleaned_all_`data'_`samp', clear
        bys pmid: gen pmid_counter = _n == 1
    }
    else {
        use ../external/openalex/cleaned_all_`data'_`samp', clear
        bys pmid: gen pmid_counter = _n == 1
    }
    preserve
    gcollapse (sum) pmid_counter, by(journal_abbr year)
    qui merge 1:1 journal_abbr year using ../temp/`samp'_counts, assert(1 2 3) keep(2 3) nogen
    *gen percent_of_tot = pmid_counter/num_articles
    gcollapse (sum) num_fund = pmid_counter tot_articles = num_articles, by(journal_abbr)
    gen percent_of_tot = num_fund/tot_articles * 100
    gen order = 0
    replace order = 1 if inlist(journal_abbr, "science","nature","cell")
    qui hashsort -order -tot_articles
    li 
    mkmat num_fund,  mat(top_jrnls_`samp'_N)
    mkmat percent_of_tot,  mat(top_jrnls_`data'_`samp')
    mat top_jrnls_`samp' = nullmat(top_jrnls_`samp'), top_jrnls_`data'_`samp'
    restore
end 

program samp_size
    syntax, data(str) samp(str) 
    foreach t in all last5yrs {
        use ../external/openalex/cleaned_`t'_`data'_`samp', clear
        di "SAMPLE IS  `data' `samp' `t':"
        qui gunique pmid
        di "# articles = " r(unique)
        mat N_`data'_`samp'_`t' = r(unique)
        qui gunique pmid which_athr
        di "# athr-articles = " r(unique)
        qui gunique pmid which_athr which_affl if !mi(inst)
        di "# athr-affl-articles = " r(unique)
        mat N_`data'_`samp' = nullmat(N_`data'_`samp') , N_`data'_`samp'_`t'
    }
end
** 
main
