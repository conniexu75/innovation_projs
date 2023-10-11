set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global temp "/export/scratch/cxu_sci_geo/create_panel"
    make_panel
end
program make_panel
    import delimited ../external/clusters/text4.csv, clear
    save ../temp/clusters, replace

    use id pmid which_athr which_affl inst inst_id year journal_abbr cite_count country_code country city msacode msa_comb athr_id athr_name affl_wt cite_affl_wt cite_wt using ../external/openalex/cleaned_all_all_jrnls, clear
    merge m:1 athr_id year using ../temp/clusters, keep(1 3) nogen
    rename cluster_label field

    bys pmid: egen num_athrs = max(which_athr)
    bys pmid which_athr: egen num_affls = max(which_affl)
    
    // create unique affl_weight? 
    bys pmid which_athr msa_comb: gen affl_unq_msa = _n == 1
    bys pmid which_athr: egen num_unq_msa = total(affl_unq_msa)
    gen unq_affl_wt = 1/num_athrs * 1/num_unq_msa
    gen unq_cite_affl_wt = cite_wt * unq_affl_wt
    replace unq_cite_affl_wt = . if affl_unq_msa == 0
    replace unq_affl_wt = . if affl_unq_msa == 0

    // create paper weights by dividing by the number of authors on paper
    gen ppr_wt = 1/num_athrs
    assert ppr_wt == affl_wt if num_affls == 1
    gen cite_ppr_wt = cite_wt * ppr_wt
    replace cite_count = cite_count + 1  
    gen cite_cnt_wt = cite_count/num_athrs
    gen avg_cite = cite_count/(2022-year+1)
    
    // restrict to USA
    keep if country_code == "US" & !mi(msa_comb)
    
    // create alternative LHS variables
    bys pmid athr_id (which_athr which_affl): gen author_id = _n == 1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid athr_id which_athr msacode (which_affl): gen msa_id = _n == 1
    gen unq_ppr_wt = ppr_wt if msa_id == 1
    gen unq_cite_cnt_wt = cite_cnt_wt if msa_id == 1
    gen unq_cite_ppr_wt = cite_ppr_wt if msa_id == 1
    gen num_articles = 1
    bys pmid athr_id msa_comb year: gen unq_num_articles = _n == 1
    bys athr_id year msa_comb: gen msa_counter = _n == 1
    bys athr_id year: egen num_msas = total(msa_counter)
    

    // assign each researcher to a singular institution in a year
    // keep modal affiliation if multiple in one year
    bys athr_id: egen mode_msa = mode(msacode)
    drop if num_msas > 1 & msacode != mode_msa & !mi(mode_msa)
    drop msa_counter num_msas
    bys athr_id year msa_comb: gen msa_counter = _n == 1
    bys athr_id year: egen num_msas = total(msa_counter)
    bys athr_id pmid msa_comb: gen athr_pmid_cntr = _n == 1
    bys athr_id msa_comb year: egen avg_team_size = mean(num_athrs) if athr_pmid_cntr == 1
    bys athr_id msa_comb  year: egen avg_ann_cite = total(avg_cite) if athr_pmid_cntr == 1
    preserve
    gcollapse (sum) affl_wt cite_affl_wt ppr_wt cite_ppr_wt cite_cnt_wt num_articles unq* (mean) avg_team_size avg_cite = avg_ann_cite  , by(athr_id msa_comb field year)
    gen rand = rnormal(0,1)
    gsort athr_id year field rand
    gduplicates drop athr_id field year, force
    bys athr_id field year: gen name_id = _n == 1
    bys field year: egen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb field year: gen name_id = _n == 1
    bys msa_comb field year: egen msa_size = total(name_id)
    replace msa_size = msa_size - 1 if msa_size > 1
    gen cluster_shr = msa_size/tot_authors
    save ../output/athr_panel_full_comb, replace
    restore
    preserve
    gcollapse (sum) affl_wt cite_affl_wt ppr_wt cite_ppr_wt cite_cnt_wt num_articles unq* (mean) avg_team_size avg_cite = avg_ann_cite , by(athr_id msacode msa_comb field year)
    gen rand = rnormal(0,1)
    gsort athr_id year field rand
    gduplicates drop athr_id field year, force
    bys athr_id field year: gen name_id = _n == 1
    bys field year: egen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb field year: gen name_id = _n == 1
    bys msa_comb field year: egen msa_size = total(name_id)
    replace msa_size = msa_size - 1 if msa_size > 1
    gen cluster_shr = msa_size/tot_authors
    save ../output/athr_panel_full, replace
    restore
end

** 
main
