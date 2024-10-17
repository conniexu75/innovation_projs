set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
here, set

program main
    foreach samp in science nature cell neuron nat_genet nat_med nat_biotech nat_neuro nat_cell_bio nat_chem_bio cell_stem_cell plos jbc oncogene faseb { 
        qui get_total_articles, samp(`samp') 
        di "SAMPLE IS : `samp'"
        top_jrnls, samp(`samp') 
        mat top_jrnls =  nullmat(top_jrnls) \ top_jrnls_`samp'
    }
    samp_size
    foreach file in top_jrnls {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }
end

program get_total_articles 
    syntax, samp(str) 
    import delimited using ../external/full/openalex_authors_`samp'.csv, clear
    drop if mi(pmid) | mi(id)
    replace title = stritrim(title)
    gen date = date(pub_date, "YMD")
    format %td date
    drop pub_date
    bys pmid: egen min_date = min(date)
    replace date =min_date
    drop min_date 
    rename date pub_date
    gen year = year(pub_date)
    replace title = stritrim(title)
    contract title id pmid jrnl year
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
    gcontract year jrnl, freq(num_articles)
    save ../temp/`samp'_counts, replace
    restore 
end

program top_jrnls
    syntax, samp(str) 
    qui {
        use ../external/newfund/cleaned_all_15jrnls, clear
        replace jrnl = "PLoS ONE" if jrnl == "PloS one"
        gen jrnl_abbr = "cell" if jrnl == "Cell"
        replace jrnl_abbr = "cell_stem_cell" if jrnl == "Cell stem cell"
        replace jrnl_abbr = "jbc" if jrnl == "Journal of Biological Chemistry"
        replace jrnl_abbr = "nature" if jrnl == "Nature"
        replace jrnl_abbr = "nat_biotech" if jrnl == "Nature Biotechnology"
        replace jrnl_abbr = "nat_cell_bio" if jrnl == "Nature Cell Biology"
        replace jrnl_abbr = "nat_chem_bio" if jrnl == "Nature Chemical Biology"
        replace jrnl_abbr = "nat_genet" if jrnl == "Nature Genetics"
        replace jrnl_abbr = "nat_med" if jrnl == "Nature Medicine"
        replace jrnl_abbr = "nat_neuro" if jrnl == "Nature Neuroscience"
        replace jrnl_abbr = "neuron" if jrnl == "Neuron"
        replace jrnl_abbr = "oncogene" if jrnl == "Oncogene"
        replace jrnl_abbr = "plos" if jrnl == "PLoS ONE"
        replace jrnl_abbr = "science" if jrnl == "Science"
        replace jrnl_abbr = "faseb" if jrnl == "The FASEB Journal"
        keep if jrnl_abbr == "`samp'"
        bys pmid: gen pmid_counter = _n == 1
        preserve
        gcollapse (sum) pmid_counter, by(jrnl year)
        qui merge 1:1 jrnl year using ../temp/`samp'_counts, assert(1 2 3) keep(2 3) nogen
        *gen percent_of_tot = pmid_counter/num_articles
        gcollapse (sum) num_fund = pmid_counter tot_articles = num_articles
        gen percent_of_tot = num_fund/tot_articles * 100
    }
    li 
    mkmat num_fund,  mat(top_jrnls_`samp'_N)
    mkmat percent_of_tot,  mat(top_jrnls_`samp')
    mat top_jrnls_`samp' = nullmat(top_jrnls_`samp'), top_jrnls_`samp'_N
    restore
end 

program samp_size
    foreach t in all last5yrs {
        use ../external/newfund/cleaned_`t'_15jrnls, clear
        di "SAMPLE IS  `t':"
        qui gunique pmid
        di "# articles = " r(unique)
        qui gunique pmid which_athr
        di "# athr-articles = " r(unique)
        qui gunique pmid which_athr which_affl if !mi(inst)
        di "# athr-affl-articles = " r(unique)
    }
end
** 
main
