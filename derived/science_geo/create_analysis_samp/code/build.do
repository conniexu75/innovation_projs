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
    global output "/export/scratch/cxu_sci_geo/create_panel/output"
    global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
    global qrtr_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist"
    foreach t in year { 
        create_mesh_xw, time(`t')
        make_panel, time(`t') firstlast(1)
        make_panel, time(`t') 
    }
end

program create_mesh_xw
    syntax, time(string)
    use id pmid athr_id athr_name year pub_date using ../external/openalex/cleaned_all_all_jrnls, clear
    gen qrtr = qofd(pub_date)
    gcontract pmid athr_id `time' 
    drop _freq
    save ${temp}/athr_pmid_xw_`time', replace
    use ../external/openalex/concepts_all_jrnls.dta, clear
    joinby pmid using  ${temp}/athr_pmid_xw_`time'
    preserve
    collapse (sum) score , by(athr_id `time' term)
    hashsort athr_id `time' -score
    bys athr_id `time': gen drop = _n > 2 
    drop if drop == 1
    by athr_id `time' : gen which = _n
    drop score drop
    reshape wide term, i(athr_id `time') j(which)
    save ${temp}/athr_concept_`time', replace
    restore
    use ../external/openalex/contracted_gen_mesh_all_jrnls.dta, clear
    joinby pmid using  ${temp}/athr_pmid_xw_`time'
    preserve
    gcontract athr_id qualifier `time'
    hashsort athr_id `time' -_freq
    bys athr_id `time': gen drop = _n > 2 
    drop if drop == 1
    by athr_id `time' : gen which = _n
    drop _freq drop
    reshape wide qualifier, i(athr_id `time') j(which)
    save ${temp}/athr_qualifier_`time', replace
    restore
    preserve
    gcontract athr_id gen_mesh `time'
    hashsort athr_id `time' -_freq
    bys athr_id `time': gen drop = _n > 2 
    drop if drop == 1
    by athr_id `time' : gen which = _n
    drop _freq drop
    reshape wide gen_mesh, i(athr_id `time') j(which)
    save ${temp}/athr_mesh_`time', replace
    restore
end

program make_panel
    syntax, time(string) [, firstlast(int 0)]
    import delimited ../external/clusters/text4.csv, clear
    drop cluster_name
    replace athr_id = subinstr(athr_id, "A", "", .)
    destring athr_id, replace
    tsset athr_id year
    tsfill
    tostring athr_id, replace
    replace athr_id = "A" + athr_id
    bys athr_id (year): replace cluster_label = cluster_label[_n-1] if mi(cluster_label) & !mi(cluster_label[_n-1])
    save ../temp/clusters, replace

    use id pmid which_athr which_affl pub_date year journal_abbr cite_count athr_id athr_name impact_fctr country_code msa_comb msa_c_world inst inst_id msacode using ../external/openalex/cleaned_all_all_jrnls, clear
    local suf = "" 
    if `firstlast' == 1 {
        use id pmid which_athr which_affl pub_date year journal_abbr cite_count athr_id athr_name impact_fctr country_code msa_comb msa_c_world inst inst_id msacode using ../external/firstlast/cleaned_all_all_jrnls, clear
        local suf = "_firstlast" 
    }
    gen qrtr = qofd(pub_date)
    merge m:1 athr_id year using ../temp/clusters, assert(1 2 3) keep(3) nogen
    merge m:1 id using ../external/patents/patent_ppr_cnt, assert(1 2 3) keep(1 3) nogen keepusing(patent_count front_only body_only)
    rename cluster_label field

    bys pmid athr_id (which_athr which_affl): gen author_id = _n == 1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2

    bys pmid which_athr: gen num_affls = _N
    assert num_affls == 1
    bys pmid: gegen num_athrs = max(which_athr)
    gen affl_wt = 1/num_affls * 1/num_athrs
    local date  date("`c(current_date)'", "DMY")
    if "`time'" == "qrtr" {
        gen time_since_pub = qofd(`date') - `time'+1
        gen avg_cite = cite_count/time_since_pub
        gen avg_pat = patent_count/time_since_pub
        gen avg_frnt = front_only/time_since_pub
        gen avg_body = body_only/time_since_pub
    }
    if "`time'" == "year" {
        gen time_since_pub = yofd(`date') - `time'+1
        gen avg_cite = cite_count/time_since_pub
        gen avg_pat = patent_count/time_since_pub
        gen avg_frnt = front_only/time_since_pub
        gen avg_body = body_only/time_since_pub
    }
    bys pmid: replace avg_cite = . if _n != 1
    bys pmid: replace avg_pat = . if _n != 1
    bys pmid: replace avg_frnt = . if _n != 1
    bys pmid: replace avg_body = . if _n != 1
    sum avg_cite
    gen cite_wt = avg_cite/r(sum)
    bys journal_abbr: gegen tot_cite_N = total(cite_wt)
    sum avg_pat
    gen pat_wt = avg_pat/r(sum)
    sum avg_frnt
    gen frnt_wt = avg_frnt/r(sum)
    sum avg_body
    gen body_wt = avg_body/r(sum)
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gsort pmid pat_wt
    qui bys pmid: replace pat_wt = pat_wt[_n-1] if mi(pat_wt)
    gsort pmid frnt_wt
    qui bys pmid: replace frnt_wt = frnt_wt[_n-1] if mi(frnt_wt)
    gsort pmid body_wt
    qui bys pmid: replace body_wt = body_wt[_n-1] if mi(body_wt)
    gunique pmid
    local articles = r(unique)
    qui gen pat_adj_wt = affl_wt * pat_wt * `articles'
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    qui gen frnt_adj_wt  = affl_wt * frnt_wt * `articles'
    qui gen body_adj_wt  = affl_wt * body_wt * `articles'
    qui bys pmid: gen pmid_cntr = _n == 1
    qui bys journal_abbr: gen first_jrnl = _n == 1
    qui by journal_abbr: gegen jrnl_N = total(pmid_cntr)
    qui sum impact_fctr if first_jrnl == 1
    gen impact_shr = impact_fctr/r(sum)
    gen reweight_N = impact_shr * `articles'
    replace  tot_cite_N = tot_cite_N * `articles'
    gen impact_wt = reweight_N/jrnl_N
    gen impact_affl_wt = impact_wt * affl_wt
    gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
    gen impact_cite_affl_wt = impact_cite_wt * affl_wt
    foreach v in affl_wt cite_affl_wt pat_adj_wt impact_affl_wt impact_cite_affl_wt frnt_adj_wt body_adj_wt {
       qui sum `v'
       assert round(r(sum)-`articles') == 0
    }
    // restrict to USA
    keep if country_code == "US" & !mi(msa_comb)

    preserve
    gcontract pmid `time' athr_id msa_comb
    drop _freq
*    merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time' , assert(1 2 3) keep(3) nogen keepusing(msa_comb)
    rename athr_id focal_id
    save ${temp}/focal_list, replace
    rename focal_id athr_id 
    rename msa_comb coathr_msa
    save ${temp}/coauthors, replace
    restore

    preserve
    use ${temp}/focal_list,clear
    joinby pmid using ${temp}/coauthors
    drop if focal_id == athr_id
    gcontract focal_id `time' msa_comb athr_id coathr_msa
    drop _freq
    keep if coathr_msa == msa_comb
    gcontract focal_id `time', freq(num_coauthors_same_msa)
    rename focal_id athr_id
    save ${temp}/coauthor_in_msa_`time', replace
    restore

    // get avg team size
    bys athr_id pmid : gen athr_pmid_cntr = _n == 1
    bys athr_id `time': gegen avg_team_size = mean(num_athrs) if athr_pmid_cntr == 1
    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt pat_adj_wt pat_wt patent_count impact_affl_wt impact_cite_affl_wt frnt_adj_wt body_adj_wt front_only body_only (mean) avg_team_size  (firstnm) field , by(athr_id msa_comb `time')
        merge m:1 athr_id `time' using ${temp}/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt pat_adj_wt pat_wt patent_count frnt_adj_wt body_adj_wt front_only body_only impact_affl_wt impact_cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msa_comb `time' year)
        merge m:1 athr_id `time' using ${temp}/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        // make into balanced panel
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    bys athr_id `time': gen name_id = _n == 1
    bys `time': gegen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb `time': gen name_id = _n == 1
    bys msa_comb `time': gegen msa_size = total(name_id)
    replace msa_size = msa_size - 1  if msa_size > 1
    replace msa_size = msa_size - num_coauthors_same_msa  
    gen cluster_shr = msa_size/tot_authors
    drop name_id

    gen top_15 = !mi(affl_wt)
    bys athr_id year: gegen has_top_15 = max(top_15)
    bys athr_id msa_comb `time': gen name_id = _n == 1 if has_top_15 == 1
    bys msa_comb `time': gegen unbal_msa_size = total(name_id) 
    replace unbal_msa_size = unbal_msa_size - 1 if unbal_msa_size > 1
    replace unbal_msa_size = unbal_msa_size - num_coauthors_same_msa 
    drop if mi(cite_affl_wt) | mi(affl_wt) 
    replace cite_affl_wt = 0 if mi(cite_affl_wt)
    replace affl_wt = 0 if mi(affl_wt)

    merge 1:1 athr_id `time' using ${temp}/athr_concept_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_mesh_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_qualifier_`time', assert(1 2 3) keep(1 3) nogen
    foreach var in term1 term2 gen_mesh1 gen_mesh2 qualifier_name1 qualifier_name2 {
        bys athr_id (`time') : replace `var' = `var'[_n-1] if mi(`var') & !mi(`var'[_n-1])
    }
    save ${output}/athr_panel_full_comb_`time'`suf', replace
    restore
    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt pat_adj_wt pat_wt patent_count impact_affl_wt impact_cite_affl_wt front_only body_only frnt_adj_wt body_adj_wt (mean) avg_team_size  (firstnm) field , by(athr_id msacode msa_comb  `time')
        merge m:1 athr_id `time' using ${temp}/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt frnt_adj_wt body_adj_wt body_only front_only pat_adj_wt pat_wt patent_count impact_affl_wt impact_cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msacode msa_comb  `time' year)
        merge m:1 athr_id `time' using ${temp}/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        // make into balanced panel
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    bys athr_id `time': gen name_id = _n == 1
    bys `time': gegen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb `time': gen name_id = _n == 1
    bys msa_comb `time': gegen msa_size = total(name_id)
    replace msa_size = msa_size - 1 
    replace msa_size = msa_size - num_coauthors_same_msa  
    gen cluster_shr = msa_size/tot_authors
    drop name_id
    
    gen top_15 = !mi(affl_wt)
    bys athr_id year: gegen has_top_15 = max(top_15)
    bys athr_id msa_comb `time': gen name_id = _n == 1 if has_top_15 == 1
    bys msa_comb `time': gegen unbal_msa_size = total(name_id) 
    replace unbal_msa_size = unbal_msa_size - 1 if unbal_msa_size > 1
    replace unbal_msa_size = unbal_msa_size - num_coauthors_same_msa 
    drop if mi(cite_affl_wt) | mi(affl_wt) 
    replace cite_affl_wt = 0 if mi(cite_affl_wt)
    replace affl_wt = 0 if mi(affl_wt)

    merge 1:1 athr_id `time' using ${temp}/athr_concept_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_mesh_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_qualifier_`time', assert(1 2 3) keep(1 3) nogen
    foreach var in term1 term2 gen_mesh1 gen_mesh2 qualifier_name1 qualifier_name2 {
        bys athr_id (`time') : replace `var' = `var'[_n-1] if mi(`var') & !mi(`var'[_n-1])
    }
    save ${output}/athr_panel_full_`time'`suf', replace
    restore
end

** 
main
