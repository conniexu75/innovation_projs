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
    foreach samp in 15jrnls {
        create_firstlast, samp(`samp')
    }
    split_sample
end

program create_firstlast 
    syntax, samp(str)
    if "`samp'" == "15jrnls" {
        use id pmid which_athr which_affl pub_date year jrnl cite_count front_only body_only patent_count athr_id athr_name  stateshort region inst_id country_code country city us_state msacode msatitle msa_comb msa_c_world inst using ../external/openalex/cleaned_all_`samp', clear
    }
    if "`samp'" == "clin_med" {
        use  ../external/openalex/cleaned_all_`samp', clear
        drop cite_wt cite_affl_wt impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr affl_wt 
    }
/*    if "`samp'" == "15jrnls" {
        merge m:1 athr_id year using ${year_insts}/filled_in_panel_year, assert(1 2 3) keep(3) nogen
        gduplicates drop id athr_id inst_id, force
    }*/
    bys id: egen first_athr = min(which_athr)
    bys id: egen last_athr = max(which_athr)
    keep if which_athr == first_athr | which_athr == last_athr
    qui hashsort id which_athr which_affl
    cap drop author_id 
    cap drop num_athrs 
    bys id athr_id (which_athr which_affl): gen author_id = _n ==1
    bys id (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    cap drop num_affls
    bys id which_athr: gen num_affls = _N
    bys id: egen num_athrs = max(which_athr)
    if "`samp'" == "15jrnls" {
        assert num_affls == 1
        qui sum num_athrs
        assert r(max) == 2
    }
    gen affl_wt = 1/num_affls * 1/num_athrs
    qui gen years_since_pub = 2022-year+1
    qui gen avg_cite_yr = cite_count/years_since_pub
    qui gen avg_pat_yr = patent_count/years_since_pub
    qui gen avg_frnt_yr = front_only/years_since_pub
    qui gen avg_body_yr = body_only/years_since_pub
    qui bys id: replace avg_cite_yr = . if _n != 1
    qui bys id: replace avg_pat_yr = . if _n != 1
    qui bys id: replace avg_frnt_yr = . if _n != 1
    qui bys id: replace avg_body_yr = . if _n != 1
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum) // each article is no longer weighted 1 
    qui sum avg_pat_yr
    gen pat_wt = avg_pat_yr/r(sum)
    qui sum avg_frnt_yr
    gen frnt_wt = avg_frnt_yr/r(sum)
    qui sum avg_body_yr
    gen body_wt = avg_body_yr/r(sum)
    bys jrnl: egen tot_cite_N = total(cite_wt)
    gsort id cite_wt
    qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gsort id pat_wt
    qui bys id: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
    gsort id frnt_wt
    qui bys id: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
    gsort id body_wt
    qui bys id: replace body_wt = body_wt[_n-1] if mi(body_wt)

    qui gunique id
    local articles = r(unique)
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
    qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
    qui gen body_adj_wt  = affl_wt * body_wt * `articles'

    // now give each article a weight based on their journal impact factor 
    gen impact_fctr = . 
    replace impact_fctr = 60.9 if jrnl == "Nature"
    replace impact_fctr = 37.4 if jrnl == "Nature Genetics"
    replace impact_fctr = 27.7 if jrnl == "Nature Neuroscience"
    replace impact_fctr = 15.6 if jrnl == "Nature Chemical Biology"
    replace impact_fctr = 26.6 if jrnl == "Nature Cell Biology"
    replace impact_fctr = 59.1 if jrnl == "Nature Biotechnology"
    replace impact_fctr = 69.4 if jrnl == "Nature Medicine"
    replace impact_fctr = 54.5 if jrnl == "Science"
    replace impact_fctr = 57.5 if jrnl == "Cell"
    replace impact_fctr = 24.9 if jrnl == "Cell stem cell"
    replace impact_fctr = 18.6 if jrnl == "Neuron"
    replace impact_fctr = 8.8 if jrnl == "Oncogene"
    replace impact_fctr = 5.2 if jrnl == "The FASEB Journal"
    replace impact_fctr = 4.8 if jrnl == "Journal of Biological Chemistry"
    replace impact_fctr = 3.8 if jrnl == "PLoS One"
    replace impact_fctr = 35.3 if jrnl == "annals"
    replace impact_fctr = 15.88 if jrnl == "bmj"
    replace impact_fctr = 81.4 if jrnl == "jama"
    replace impact_fctr = 118.1 if jrnl == "lancet"
    replace impact_fctr = 115.7 if jrnl == "nejm"
       
    qui bys id: gen id_cntr = _n == 1
    qui bys jrnl: gen first_jrnl = _n == 1
    qui bys jrnl: egen jrnl_N = total(id_cntr)
    qui sum impact_fctr if first_jrnl == 1
    gen impact_shr = impact_fctr/r(sum) // weight that each journal gets
    gen reweight_N = impact_shr * `articles' // adjust the N of each journal to reflect impact factor
    replace  tot_cite_N = tot_cite_N * `articles'
    gen impact_wt = reweight_N/jrnl_N // after adjusting each journal weight we divide by the number of articles in each journal to assign new weight to each paper
    gen impact_affl_wt = impact_wt * affl_wt  
    gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles' 
    gen impact_cite_affl_wt = impact_cite_wt * affl_wt 
    foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt pat_adj_wt  frnt_adj_wt body_adj_wt {
        sum `wt'
        assert round(r(sum)-`articles') == 0
    }
    compress, nocoalesce
    cap drop len
    gen len = length(inst)
    qui sum len
    local n = r(max)
    recast str`n' inst, force
    save ../output/cleaned_all_`samp', replace

    keep if inrange(pub_date, td(01jan2015), td(31dec2022)) & year >=2015
    drop cite_wt cite_affl_wt impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr pat_wt pat_adj_wt frnt_wt body_wt frnt_adj_wt body_adj_wt
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui sum avg_pat_yr
    gen pat_wt = avg_pat_yr/r(sum)
    qui sum avg_frnt_yr
    gen frnt_wt = avg_frnt_yr/r(sum)
    qui sum avg_body_yr
    gen body_wt = avg_body_yr/r(sum)
    bys jrnl: egen tot_cite_N = total(cite_wt)
    gsort id cite_wt
    qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gsort id pat_wt
    qui bys id: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
    gsort id frnt_wt
    qui bys id: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
    gsort id body_wt
    qui bys id: replace body_wt = body_wt[_n-1] if mi(body_wt)
    gunique id 
    local articles = r(unique)
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
    qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
    qui gen body_adj_wt  = affl_wt * body_wt * `articles'
    
    qui bys jrnl: gen first_jrnl = _n == 1
    qui bys jrnl: egen jrnl_N = total(id_cntr)
    qui sum impact_fctr if first_jrnl == 1
    gen impact_shr = impact_fctr/r(sum)
    gen reweight_N = impact_shr * `articles'
    replace  tot_cite_N = tot_cite_N * `articles'
    gen impact_wt = reweight_N/jrnl_N
    gen impact_affl_wt = impact_wt * affl_wt
    gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
    gen impact_cite_affl_wt = impact_cite_wt * affl_wt

    foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt pat_adj_wt frnt_adj_wt body_adj_wt {
        sum `wt'
        assert round(r(sum)-`articles') == 0
    }
    compress, nocoalesce
    save ../output/cleaned_last5yrs_`samp', replace
end

program split_sample
    foreach samp in all last5yrs {
        preserve
        use ../output/cleaned_`samp'_15jrnls, clear
        keep if inlist(jrnl, "Cell", "Science", "Nature")
        drop cite_wt cite_affl_wt impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr pat_wt pat_adj_wt frnt_wt body_wt frnt_adj_wt body_adj_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui sum avg_pat_yr
        gen pat_wt = avg_pat_yr/r(sum)
        qui sum avg_frnt_yr
        gen frnt_wt = avg_frnt_yr/r(sum)
        qui sum avg_body_yr
        gen body_wt = avg_body_yr/r(sum)
        bys jrnl: egen tot_cite_N = total(cite_wt)
        gsort id cite_wt
        qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        gsort id pat_wt
        qui bys id: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
        gsort id frnt_wt
        qui bys id: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
        gsort id body_wt
        qui bys id: replace body_wt = body_wt[_n-1] if mi(body_wt)
        gunique id 
        local articles = r(unique)
        qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
        qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
        qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
        qui gen body_adj_wt  = affl_wt * body_wt * `articles'
        
        qui bys jrnl: gen first_jrnl = _n == 1
        qui bys jrnl: egen jrnl_N = total(id_cntr)
        qui sum impact_fctr if first_jrnl == 1
        gen impact_shr = impact_fctr/r(sum)
        gen reweight_N = impact_shr * `articles'
        replace  tot_cite_N = tot_cite_N * `articles'
        gen impact_wt = reweight_N/jrnl_N
        gen impact_affl_wt = impact_wt * affl_wt
        gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
        gen impact_cite_affl_wt = impact_cite_wt * affl_wt

        foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt pat_adj_wt frnt_adj_wt body_adj_wt {
            sum `wt'
            assert round(r(sum)-`articles') == 0
        }
        save ../output/cleaned_`samp'_newfund_cns, replace
        gcontract id
        drop _freq
        save ../output/list_of_ids_`samp'_newfund_cns, replace
        restore

        preserve
        use ../output/cleaned_`samp'_15jrnls, clear
        keep if inlist(jrnl, "Cell stem cell", "Nature Biotechnology", "Nature Cell Biology", "Nature Genetics", "Nature Medicine", "Nature Neuroscience", "Neuron", "Nature Chemical Biology")
        drop cite_wt cite_affl_wt impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr pat_wt pat_adj_wt frnt_wt body_wt frnt_adj_wt body_adj_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui sum avg_pat_yr
        gen pat_wt = avg_pat_yr/r(sum)
        qui sum avg_frnt_yr
        gen frnt_wt = avg_frnt_yr/r(sum)
        qui sum avg_body_yr
        gen body_wt = avg_body_yr/r(sum)
        bys jrnl: egen tot_cite_N = total(cite_wt)
        gsort id cite_wt
        qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        gsort id pat_wt
        qui bys id: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
        gsort id frnt_wt
        qui bys id: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
        gsort id body_wt
        qui bys id: replace body_wt = body_wt[_n-1] if mi(body_wt)
        gunique id 
        local articles = r(unique)
        qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
        qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
        qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
        qui gen body_adj_wt  = affl_wt * body_wt * `articles'
        
        qui bys jrnl: gen first_jrnl = _n == 1
        qui bys jrnl: egen jrnl_N = total(id_cntr)
        qui sum impact_fctr if first_jrnl == 1
        gen impact_shr = impact_fctr/r(sum)
        gen reweight_N = impact_shr * `articles'
        replace  tot_cite_N = tot_cite_N * `articles'
        gen impact_wt = reweight_N/jrnl_N
        gen impact_affl_wt = impact_wt * affl_wt
        gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
        gen impact_cite_affl_wt = impact_cite_wt * affl_wt

        foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt pat_adj_wt frnt_adj_wt body_adj_wt {
            sum `wt'
            assert round(r(sum)-`articles') == 0
        }
        save ../output/cleaned_`samp'_newfund_scisub, replace
        gcontract id
        drop _freq
        save ../output/list_of_ids_`samp'_newfund_scisub, replace
        restore

        preserve
        use ../output/cleaned_`samp'_15jrnls, clear
        keep if inlist(jrnl, "The FASEB Journal", "Journal of Biological Chemistry", "Oncogene", "PLoS One")
        drop cite_wt cite_affl_wt impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr pat_wt pat_adj_wt frnt_wt body_wt frnt_adj_wt body_adj_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui sum avg_pat_yr
        gen pat_wt = avg_pat_yr/r(sum)
        qui sum avg_frnt_yr
        gen frnt_wt = avg_frnt_yr/r(sum)
        qui sum avg_body_yr
        gen body_wt = avg_body_yr/r(sum)
        bys jrnl: egen tot_cite_N = total(cite_wt)
        gsort id cite_wt
        qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        gsort id pat_wt
        qui bys id: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
        gsort id frnt_wt
        qui bys id: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
        gsort id body_wt
        qui bys id: replace body_wt = body_wt[_n-1] if mi(body_wt)
        gunique id 
        local articles = r(unique)
        qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
        qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
        qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
        qui gen body_adj_wt  = affl_wt * body_wt * `articles'
        
        qui bys jrnl: gen first_jrnl = _n == 1
        qui bys jrnl: egen jrnl_N = total(id_cntr)
        qui sum impact_fctr if first_jrnl == 1
        gen impact_shr = impact_fctr/r(sum)
        gen reweight_N = impact_shr * `articles'
        replace  tot_cite_N = tot_cite_N * `articles'
        gen impact_wt = reweight_N/jrnl_N
        gen impact_affl_wt = impact_wt * affl_wt
        gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
        gen impact_cite_affl_wt = impact_cite_wt * affl_wt

        foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt pat_adj_wt frnt_adj_wt body_adj_wt {
            sum `wt'
            assert round(r(sum)-`articles') == 0
        }
        save ../output/cleaned_`samp'_newfund_demsci, replace
        gcontract id
        drop _freq
        save ../output/list_of_ids_`samp'_newfund_demsci, replace
        restore

/*        preserve
        use ../output/cleaned_`samp'_clin_med, clear
        gcontract id
        drop _freq
        save ../output/list_of_ids_`samp'_clin_med,  replace
        restore*/
    } 
    // split mesh terms
    use ../external/openalex/contracted_gen_mesh_15jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 id using ../output/list_of_ids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/contracted_gen_mesh_newfund_`samp', replace
        restore
    }
   // split concepts 
    use ../external/openalex/concepts_15jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 id using ../output/list_of_ids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/concepts_newfund_`samp', replace
        restore
    }
end
main
