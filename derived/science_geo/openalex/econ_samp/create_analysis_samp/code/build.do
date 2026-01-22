set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global year_insts "/export/scratch/cxu_sci_geo/create_econ_inst_hist"
    foreach t in year { 
        make_panel, time(`t') 
    }
end

program make_panel
    syntax, time(string) [, firstlast(int 0)]
    use id which_athr which_affl pub_date year journal_abbr cite_count athr_id athr_name impact_fctr country_code msa_comb msa_c_world inst inst_id msacode using ../external/openalex/cleaned_all_econs, clear
    local suf = "" 
    if `firstlast' == 1 {
        use id which_athr which_affl pub_date year journal_abbr cite_count athr_id athr_name impact_fctr country_code msa_comb msa_c_world inst inst_id msacode using ../external/firstlast/cleaned_all_all_jrnls, clear
        local suf = "_firstlast" 
    }
    gen qrtr = qofd(pub_date)

    bys id athr_id (which_athr which_affl): gen author_id = _n == 1
    bys id (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2

    bys id which_athr: gen num_affls = _N
    assert num_affls == 1
    bys id: gegen num_athrs = max(which_athr)
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
    bys id: replace avg_cite = . if _n != 1
    sum avg_cite
    gen cite_wt = avg_cite/r(sum)
    gsort id cite_wt
    qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gunique id
    local articles = r(unique)
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    qui bys id: gen id_cntr = _n == 1
    // restrict to USA
    keep if country_code == "US" & !mi(msa_comb)

    preserve
    gcontract id `time' athr_id msa_comb
    drop _freq
*    merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time' , assert(1 2 3) keep(3) nogen keepusing(msa_comb)
    rename athr_id focal_id
    save ../temp/focal_list, replace
    rename focal_id athr_id 
    rename msa_comb coathr_msa
    save ../temp/coauthors, replace
    restore

    preserve
    use ../temp/focal_list,clear
    joinby id using ../temp/coauthors
    drop if focal_id == athr_id
    gcontract focal_id `time' msa_comb athr_id coathr_msa
    drop _freq
    keep if coathr_msa == msa_comb
    gcontract focal_id `time', freq(num_coauthors_same_msa)
    rename focal_id athr_id
    save ../temp/coauthor_in_msa_`time', replace
    restore

    // get avg team size
    bys athr_id id : gen athr_pmid_cntr = _n == 1
    bys athr_id `time': gegen avg_team_size = mean(num_athrs) if athr_pmid_cntr == 1
    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size , by(athr_id msa_comb `time')
        merge m:1 athr_id `time' using ../temp/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size , by(athr_id msa_comb `time' year)
        merge m:1 athr_id `time' using ../temp/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
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
    save ../output/athr_panel_full_comb_`time'`suf', replace
    restore
    preserve
    if "`time'" == "year" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size, by(athr_id msacode msa_comb  `time')
        merge m:1 athr_id `time' using ../temp/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    if "`time'" == "qrtr" {
        gcollapse (sum) affl_wt cite_affl_wt (mean) avg_team_size, by(athr_id msacode msa_comb  `time' year)
        merge m:1 athr_id `time' using ../temp/coauthor_in_msa_`time', assert(1 3) keep(1 3) nogen
        replace num_coauthors_same_msa = 0 if mi(num_coauthors_same_msa)
        // make into balanced panel
        merge m:1 athr_id `time' using ${`time'_insts}/filled_in_panel_`time', assert(1 2 3) keep(2 3) nogen
    }
    bys athr_id `time': gen name_id = _n == 1
    bys `time': gegen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb `time': gen name_id = _n == 1
    bys msa_comb `time': gegen msa_size = total(name_id)
    replace msa_size = msa_size - 1 if msa_size > 1
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
    save ../output/athr_panel_full_`time'`suf', replace
    restore
end

** 
main
