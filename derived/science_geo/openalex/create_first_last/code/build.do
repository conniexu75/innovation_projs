set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/clean_openalex"

program main
    foreach samp in all_jrnls clin_med {
        create_firstlast, samp(`samp')
    }
    split_sample
end

program create_firstlast 
    syntax, samp(str)
    use ../external/openalex/cleaned_all_`samp', clear
    bys pmid: egen first_athr = min(which_athr)
    bys pmid: egen last_athr = max(which_athr)
    keep if which_athr == first_athr | which_athr == last_athr
    qui hashsort pmid which_athr which_affl
    cap drop author_id 
    cap drop num_athrs 
    drop affl_wt avg_cite_yr years_since_pub cite_wt cite_affl_wt
    bys pmid athr_id (which_athr which_affl): gen author_id = _n ==1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr: replace num_affls = _N
    bys pmid: egen num_athrs = max(which_athr)
    gen affl_wt = 1/num_affls * 1/num_athrs
    qui gen years_since_pub = 2022-year+1
    qui gen avg_cite_yr = cite_count/years_since_pub
    qui bys pmid: replace avg_cite_yr = . if _n != 1
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    local articles = r(unique)
    qui replace cite_wt = cite_wt *`articles' 
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt

    qui sum affl_wt
    assert round(r(sum)-`articles') == 0
    qui sum cite_affl_wt
    assert round(r(sum)-`articles') == 0
    
    compress, nocoalesce
    cap drop len
    gen len = length(inst)
    qui sum len
    local n = r(max)
    recast str`n' inst, force
    save ../output/cleaned_all_`samp', replace

    keep if inrange(pub_date, td(01jan2015), td(31dec2022)) & year >=2015
    drop cite_wt cite_affl_wt
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    local articles = r(unique)
    qui replace cite_wt = cite_wt *`articles' 
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt
    qui sum affl_wt
    assert round(r(sum)-`articles') == 0
    qui sum cite_affl_wt
    assert round(r(sum)-`articles') == 0
    
    compress, nocoalesce
    save ../output/cleaned_last5yrs_`samp', replace
end

program split_sample
    foreach samp in all last5yrs {
        preserve
        use ../output/cleaned_`samp'_all_jrnls, clear
        keep if inlist(journal_abbr, "cell", "science", "nature")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        local articles = r(unique)
        qui replace cite_wt = cite_wt *`articles' 
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        qui sum affl_wt
        assert round(r(sum)-`articles') == 0
        qui sum cite_affl_wt
        assert round(r(sum)-`articles') == 0
    
        save ../output/cleaned_`samp'_newfund_cns, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_cns, replace
        restore

        preserve
        use ../output/cleaned_`samp'_all_jrnls, clear
        keep if inlist(journal_abbr, "cell_stem_cell", "nat_biotech", "nat_cell_bio", "nat_genet", "nat_med", "nat_med", "nat_neuro", "neuron", "nat_chem_bio")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        local articles = r(unique)
        qui replace cite_wt = cite_wt *`articles' 
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        qui sum affl_wt
        assert round(r(sum)-`articles') == 0
        qui sum cite_affl_wt
        assert round(r(sum)-`articles') == 0
    
        save ../output/cleaned_`samp'_newfund_scisub, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_scisub, replace
        restore

        preserve
        use ../output/cleaned_`samp'_all_jrnls, clear
        keep if inlist(journal_abbr, "faseb", "jbc", "onco", "plos")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        local articles = r(unique)
        qui replace cite_wt = cite_wt *`articles' 
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        qui sum affl_wt
        assert round(r(sum)-`articles') == 0
        qui sum cite_affl_wt
        assert round(r(sum)-`articles') == 0
    
        save ../output/cleaned_`samp'_newfund_demsci, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_demsci, replace
        restore

        preserve
        use ../output/cleaned_`samp'_clin_med, clear
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_clin_med,  replace
        restore
    } 
    // split mesh terms
    use ../external/openalex/contracted_gen_mesh_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ../output/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/contracted_gen_mesh_newfund_`samp', replace
        restore
    }
   // split concepts 
    use ../external/openalex/concepts_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ../output/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/concepts_newfund_`samp', replace
        restore
    }
end

main
