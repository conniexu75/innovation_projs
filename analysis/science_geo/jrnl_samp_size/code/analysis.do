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
    foreach samp in cns scisub demsci { 
        get_total_articles, samp(`samp') 
        di "SAMPLE IS : `samp'"
        top_jrnls, data(newfund) samp(`samp') 
        samp_size, data(newfund) samp(`samp') 
        mat N_`samp' = nullmat(N_`samp') \ N_newfund_`samp'
        mat N_samp = nullmat(N_samp) \ N_`samp'
        mat top_jrnls_`samp' =  nullmat(top_jrnls_`samp') , top_jrnls_`samp'_N
        if "`samp'" != "med" {
            mat top_jrnls =  nullmat(top_jrnls) \ top_jrnls_`samp'
            }
    }
    foreach file in top_jrnls N_samp {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }
end

program get_total_articles 
    syntax, samp(str) 
    use if pub_type == "journal-article" using ../external/full_openalex/openalex_all_jrnls_merged, clear
    merge m:1 pmid using ../external/pmids/`samp'_all_pmids, assert(1 2 3) keep(3) keepusing(journal_abbr) nogen
    replace title = stritrim(title)
    gen date = date(pub_date, "YMD")
    format %td date
    drop pub_date
    bys pmid: egen min_date = min(date)
    replace date =min_date
    drop min_date 
    rename date pub_date
    gen year = year(pub_date)
    contract title id pmid journal_abbr year
    gduplicates drop pmid, force
    drop _freq
    gisid pmid
    drop if mi(title)
    gen lower_title = strlower(title)
    drop if strpos(lower_title, "economic")>0
    drop if strpos(lower_title, "economy")>0
    drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
    drop if strpos(lower_title, "public health")>0
    drop if strpos(lower_title, "hallmarks")>0
    drop if strpos(lower_title, "government")>0
    drop if strpos(lower_title, "reform")>0
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
    drop if strpos(lower_title , "the editor")>0
    drop if strpos(lower_title , "response : ")>0
    drop if strpos(lower_title , "letters")>0
    drop if lower_title == "response"
    drop if strpos(lower_title , "this week")>0
    drop if strpos(lower_title , "notes")>0
    drop if strpos(lower_title , "news ")>0
    drop if strpos(lower_title , "a note")>0
    drop if strpos(lower_title , "obituary")>0
    drop if strpos(lower_title , "review")>0
    drop if strpos(lower_title , "perspectives")>0
    drop if strpos(lower_title , "scientists")>0
    drop if strpos(lower_title , "books")>0
    drop if strpos(lower_title , "institution")>0
    drop if strpos(lower_title , "meeting")>0
    drop if strpos(lower_title , "university")>0
    drop if strpos(lower_title , "universities")>0
    drop if strpos(lower_title , "journals")>0
    drop if strpos(lower_title , "publication")>0
    drop if strpos(lower_title , "recent ")>0
    drop if strpos(lower_title , "costs")>0
    drop if strpos(lower_title , "challenges")>0
    drop if strpos(lower_title , "researchers")>0
    drop if strpos(lower_title , "perspective")>0
    drop if strpos(lower_title , "reply")>0
    drop if strpos(lower_title , " war")>0
    drop if strpos(lower_title , " news")>0
    drop if strpos(lower_title , "a correction")>0
    drop if strpos(lower_title , "academia")>0
    drop if strpos(lower_title , "society")>0
    drop if strpos(lower_title , "academy of")>0
    drop if strpos(lower_title , "nomenclature")>0
    drop if strpos(lower_title , "teaching")>0
    drop if strpos(lower_title , "education")>0
    drop if strpos(lower_title , "college")>0
    drop if strpos(lower_title , "academics")>0
    drop if strpos(lower_title , "political")>0
    drop if strpos(lower_title , "association for")>0
    drop if strpos(lower_title , "association of")>0
    drop if strpos(lower_title , "nuts")>0 & strpos(lower_title, "bolts")>0
    drop if strpos(lower_title , "response by")>0
    drop if strpos(lower_title , "societies")>0
    drop if strpos(lower_title, "health care")>0
    drop if strpos(lower_title, "health-care")>0
    drop if strpos(lower_title , "abstracts")>0
    drop if strpos(lower_title , "journal club")>0
    drop if strpos(lower_title , "curriculum")>0
    drop if strpos(lower_title , "women in science")>0
    drop if inlist(lower_title, "random samples", "sciencescope", "through the glass lightly", "equipment", "women in science",  "correction", "the metric system")
    drop if inlist(lower_title, "convocation week","the new format", "second-quarter biotech job picture", "gmo roundup") 
    preserve
    cap drop _freq
    contract lower_title journal_abbr pmid
    gduplicates tag lower_title journal_abbr, gen(dup)
    keep if dup > 0 & journal_abbr != "jbc"
    keep pmid
    gduplicates drop
    save ../temp/possible_non_articles_`samp', replace
    restore
    merge 1:1 pmid using ../temp/possible_non_articles_`samp', assert(1 3) keep(1) nogen
    preserve
    gcontract year journal_abbr, freq(num_articles)
    drop if journal_abbr == "annals"
    save ../temp/`samp'_counts, replace
    restore 
    if "`samp'"!= "med" {
        merge 1:1 pmid using ../external/newfund/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(1) nogen keepusing(pmid)
        keep pmid year journal_abbr
        save ../output/`samp'_unmatched, replace
    }
    if "`samp'" == "med" {
        preserve
        merge 1:m pmid using ../external/newfund/, assert(1 2 3) keep(1) nogen keepusing(pmid)
        save ../output/`samp'_unmatched, replace
        restore
        merge 1:m pmid using ../external/pmids/newfund_pmids, assert(1 2 3) keepusing(pmid cat)
        drop if _merge == 2
        drop if _merge == 3 & !inlist(cat, "fundamental", "diseases")
        drop _merge
        save ../temp/cleaned_all_newfund_med, replace
    }
end
program top_jrnls
    syntax, data(str) samp(str) 
    use ../external/newfund/cleaned_all_`data'_`samp', clear
    bys pmid: gen pmid_counter = _n == 1
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
        use ../external/newfund/cleaned_`t'_`data'_`samp', clear
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
