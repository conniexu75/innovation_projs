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
    global insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"
    foreach t in qrtr {
        create_mesh_xw, time(`t')
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
    syntax, time(string)
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

    use id pmid which_athr which_affl pub_date year journal_abbr cite_count athr_id athr_name using ../external/openalex/cleaned_all_all_jrnls, clear
    gen qrtr = qofd(pub_date)
    merge m:1 athr_id `time' using ${insts}/filled_in_panel_`time', assert(1 2 3) keep(3) nogen
    merge m:1 athr_id year using ../temp/clusters, assert(1 2 3) keep(3) nogen
    rename cluster_label field
    gduplicates drop pmid athr_id inst_id, force

    bys pmid athr_id (which_athr which_affl): gen author_id = _n == 1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2

    bys pmid which_athr: gen num_affls = _N
    bys pmid: egen num_athrs = max(which_athr)
    gen affl_wt = 1/num_affls * 1/num_athrs
    local date  date("`c(current_date)'", "DMY")
    if "`time'" == "qrtr" {
        gen time_since_pub = qofd(`date') - `time'+1
        gen avg_cite = cite_count/time_since_pub
    }
    if "`time'" == "year" {
        gen time_since_pub = yofd(`date') - `time'+1
        gen avg_cite = cite_count/time_since_pub
    }
    bys pmid: replace avg_cite = . if _n != 1
    sum avg_cite
    gen cite_wt = avg_cite/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt
    
    // restrict to USA
    keep if country_code == "US" & !mi(msa_comb)
   
    // get avg team size
    drop author_id
    bys pmid athr_id (which_athr which_affl): gen author_id = _n == 1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid athr_id which_athr msacode (which_affl): gen msa_id = _n == 1
    bys athr_id year msa_comb: gen msa_counter = _n == 1
    bys athr_id year: egen num_msas = total(msa_counter)
    bys athr_id pmid msa_comb: gen athr_pmid_cntr = _n == 1
    bys athr_id msa_comb `time': egen avg_team_size = mean(num_athrs) if athr_pmid_cntr == 1

    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msa_comb `time')
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msa_comb `time' year)
        // make into balanced panel
        merge m:1 athr_id `time' using ${insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    bys athr_id `time': gen name_id = _n == 1
    bys `time': egen tot_authors = total(name_id)
    bys field `time': egen tot_authors_field = total(name_id)
    drop name_id
    bys athr_id msa_comb `time': gen name_id = _n == 1
    bys msa_comb `time': egen msa_size = total(name_id)
    replace msa_size = msa_size - 1 if msa_size > 1
    gen cluster_shr = msa_size/tot_authors
    drop name_id
    bys athr_id field msa_comb `time': gen name_id_field = _n == 1
    bys msa_comb field `time': egen msa_size_field = total(name_id)
    replace msa_size_field = msa_size_field -1 
    gen field_cluster_shr = msa_size_field/tot_authors_field
    drop if mi(cite_affl_wt) | mi(affl_wt) 
    merge 1:1 athr_id `time' using ${temp}/athr_concept_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_mesh_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_qualifier_`time', assert(1 2 3) keep(1 3) nogen
    foreach var in term1 term2 gen_mesh1 gen_mesh2 qualifier_name1 qualifier_name2 {
        bys athr_id (`time') : replace `var' = `var'[_n-1] if mi(`var') & !mi(`var'[_n-1])
    }
    save ../output/athr_panel_full_comb_`time', replace
    restore
    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msacode msa_comb  `time')
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size  (firstnm) field , by(athr_id msacode msa_comb  `time' year)
        // make into balanced panel
        merge m:1 athr_id `time' using ${insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    bys athr_id `time': gen name_id = _n == 1
    bys `time': egen tot_authors = total(name_id)
    bys field `time': egen tot_authors_field = total(name_id)
    drop name_id
    bys athr_id msa_comb `time': gen name_id = _n == 1
    bys msa_comb `time': egen msa_size = total(name_id)
    replace msa_size = msa_size - 1 if msa_size > 1
    gen cluster_shr = msa_size/tot_authors
    drop name_id
    bys athr_id field msa_comb `time': gen name_id_field = _n == 1
    bys msa_comb field `time': egen msa_size_field = total(name_id)
    replace msa_size_field = msa_size_field -1 
    gen field_cluster_shr = msa_size_field/tot_authors_field
    drop if mi(cite_affl_wt) | mi(affl_wt) 
    merge 1:1 athr_id `time' using ${temp}/athr_concept_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_mesh_`time', assert(1 2 3) keep(1 3) nogen
    merge 1:1 athr_id `time' using ${temp}/athr_qualifier_`time', assert(1 2 3) keep(1 3) nogen
    foreach var in term1 term2 gen_mesh1 gen_mesh2 qualifier_name1 qualifier_name2 {
        bys athr_id (`time') : replace `var' = `var'[_n-1] if mi(`var') & !mi(`var'[_n-1])
    }
    save ../output/athr_panel_full_`time', replace
    restore
end

** 
main
