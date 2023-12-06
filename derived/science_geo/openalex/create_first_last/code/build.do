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
global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
global output "/export/scratch/cxu_sci_geo/create_first_last"
program main
    foreach samp in all_jrnls clin_med {
        create_firstlast, samp(`samp')
    }
    split_sample
end

program create_firstlast 
    syntax, samp(str)
    if "`samp'" == "all_jrnls" {
        use id pmid which_athr  which_affl pub_date year journal_abbr cite_count athr_id athr_name has_broad_affl has_hhmi_affl using ../external/openalex/cleaned_all_`samp', clear
    }
    if "`samp'" == "clin_med" {
        use  ../external/openalex/cleaned_all_`samp', clear
        drop affl_wt cite_affl_wt num_athrs num_affl years_since_pub avg_cite_yr cite_wt
    }
    drop if inlist(id , "W2016575029", "W2331065494", "W4290207833", "W4290198809" , "W4290206947" , "W4290293465")
    drop if inlist(id , "W4290277360", "W4290357912", "W4214483051", "W1978139107" , "W2045742772" , "W2049314578")
    drop if inlist(id, "W1994190235","W2580449060", "W2082429191", "W2022687771", "W2040385059" , "W4229906281")
    drop if inlist(id, "W4255455244" , "W1980313477", "W3048657354", "W1980462544")
    drop if inlist(id, "W2002595366", "W2102489389", "W2001810314", "W4231356616", "W4230789027", "W2080003482", "W2107959600", "W2400624566" )
    drop if inlist(id, "W4236962498", "W2084870845", "W2784316575", "W2955291917", "W2474836229")
    drop if inlist(pmid, 13297012,13741605,13854582,14394134,20241600,21065007)
    replace pmid = 15164053 if id == "W2103225674"
    replace pmid = 27768894 if id == "W4242360498"
    replace pmid = 5963230 if id == "W3083842255"
    replace pmid = 4290025 if id == "W2007714458"
    replace pmid = 9157877 if id == "W1988665546"
    replace pmid = 11689469 if id == "W2148194696" 
    replace pmid = 12089445 if id == "W3205595473"
    replace pmid = 13111194 if id == "W2737242062"
    replace pmid = 13113233 if id == "W2050270632"
    bys pmid: gen counter = _n == 1
    bys pmid: gen num_pmid = sum(counter)
    drop if num_pmid > 1
    drop counter num_pmid
    if "`samp'" == "all_jrnls" {
        merge m:1 athr_id year using ${year_insts}/filled_in_panel_year, assert(1 2 3) keep(3) nogen
        gduplicates drop pmid athr_id inst_id, force
    }
    bys pmid: egen first_athr = min(which_athr)
    bys pmid: egen last_athr = max(which_athr)
    keep if which_athr == first_athr | which_athr == last_athr
    qui hashsort pmid which_athr which_affl
    cap drop author_id 
    cap drop num_athrs 
    bys pmid athr_id (which_athr which_affl): gen author_id = _n ==1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr: gen num_affls = _N
    bys pmid: egen num_athrs = max(which_athr)
    if "`samp'" == "all_jrnls" {
        assert num_affls == 1
        qui sum num_athrs
        assert r(max) == 2
    }
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
    save ${output}/cleaned_all_`samp', replace

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
    save ${output}/cleaned_last5yrs_`samp', replace
end

program split_sample
    foreach samp in all last5yrs {
        preserve
        use ${output}/cleaned_`samp'_all_jrnls, clear
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
    
        save ${output}/cleaned_`samp'_newfund_cns, replace
        gcontract pmid
        drop _freq
        save ${output}/list_of_pmids_`samp'_newfund_cns, replace
        restore

        preserve
        use ${output}/cleaned_`samp'_all_jrnls, clear
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
    
        save ${output}/cleaned_`samp'_newfund_scisub, replace
        gcontract pmid
        drop _freq
        save ${output}/list_of_pmids_`samp'_newfund_scisub, replace
        restore

        preserve
        use ${output}/cleaned_`samp'_all_jrnls, clear
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
    
        save ${output}/cleaned_`samp'_newfund_demsci, replace
        gcontract pmid
        drop _freq
        save ${output}/list_of_pmids_`samp'_newfund_demsci, replace
        restore

        preserve
        use ${output}/cleaned_`samp'_clin_med, clear
        gcontract pmid
        drop _freq
        save ${output}/list_of_pmids_`samp'_clin_med,  replace
        restore
    } 
    // split mesh terms
    use ../external/openalex/contracted_gen_mesh_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ${output}/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ${output}/contracted_gen_mesh_newfund_`samp', replace
        restore
    }
    use ../external/openalex/contracted_gen_mesh_clin_med, clear
    merge m:1 pmid using ${output}/list_of_pmids_all_clin_med, keep(3) nogen
    save ${output}/contracted_gen_mesh_clin_med, replace
   // split concepts 
    use ../external/openalex/concepts_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ${output}/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ${output}/concepts_newfund_`samp', replace
        restore
    }
    use ../external/openalex/concepts_clin_med, clear
    merge m:1 pmid using ${output}/list_of_pmids_all_clin_med, keep(3) nogen
    save ${output}/concepts_clin_med, replace
end

main
