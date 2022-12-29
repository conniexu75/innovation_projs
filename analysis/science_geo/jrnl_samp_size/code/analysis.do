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
    foreach samp in cns_med scisub { 
        local samp_type = cond(strpos("`samp'", "cns")>0 | strpos("`samp'","med")>0, "main", "robust")
        get_total_articles, samp(`samp') samp_type(`samp_type')
        foreach data in fund dis thera {
        di "SAMPLE IS : `samp' `data'"
            top_jrnls, data(`data') samp(`samp') 
            samp_size, data(`data') samp(`samp') 
        }

        mat top_jrnls_`samp' =  nullmat(top_jrnls_`samp') , top_jrnls_`samp'_N
        mat top_jrnls =  nullmat(top_jrnls) \ top_jrnls_`samp'
    }
    foreach file in top_jrnls {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }
end

program get_total_articles 
    syntax, samp(str) samp_type(str)
    use ../external/`samp_type'_filtered/all_jrnl_articles_`samp'Q1, clear
    // delete some weird metastudies that we can't cleanly get affiliations from
    qui drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
    qui drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279)
    cap drop _merge
    merge 1:1 pmid using ../external/wos/`samp'_appended, assert(1 2 3) // need to pull in all pmids from wos // to do after i scrape all wos
    qui drop if _merge == 2
    tab _merge
    keep if strpos(doc_type, "Article")>0
    drop if strpos(doc_type, "Retracted")>0
    qui keep if _merge == 3
    drop _merge
    merge 1:1 pmid using ../external/`samp_type'_total/`samp'_all_pmids, assert(2 3) keep(3) nogen
    replace year = pub_year if !mi(pub_year)
    gcontract year journal_abbr, freq(num_articles)
    save ../temp/`samp'_counts, replace
end

program top_jrnls
    syntax, data(str) samp(str) 
    use ../external/cleaned_samps/cleaned_all_`data'_`samp', clear
    preserve
    gcollapse (sum) pmid_counter, by(journal_abbr year)
    qui merge 1:1 journal_abbr year using ../temp/`samp'_counts, assert(1 2 3) keep(2 3) nogen
    gen percent_of_tot = pmid_counter/num_articles
    gcollapse (mean) avg_articles = pmid_counter avg_perc = percent_of_tot num_articles, by(journal_abbr)
    gen order = 0
    replace order = 1 if inlist(journal_abbr, "science","nature","cell")
    qui hashsort -order -num_articles
    qui replace avg_perc = avg_perc * 100
    li 
    mkmat num_articles,  mat(top_jrnls_`samp'_N)
    mkmat avg_perc ,  mat(top_jrnls_`data'_`samp')
    mat top_jrnls_`samp' = nullmat(top_jrnls_`samp'), top_jrnls_`data'_`samp'
    restore
end 

program samp_size
    syntax, data(str) samp(str) 
    foreach t in all last5yrs {
        use ../external/cleaned_samps/cleaned_`t'_`data'_`samp', clear
        di "SAMPLE IS  `data' `samp' `t':"
        qui gunique pmid
        di "# articles = " r(unique)
        qui gunique pmid which_athr
        di "# athr-articles = " r(unique)
        qui gunique pmid which_athr which_affiliation if !mi(affiliation)
        di "# athr-affl-articles = " r(unique)
    }
end
** 
main
