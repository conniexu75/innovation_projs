set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/analyze_openalex"

program main
    merge_files
    split_sample
end
program merge_files 
    use ../external/openalex/openalex_merged, clear
    merge m:1 pmid using ../external/jrnls/cns_all_pmids.dta, assert(1 2 3) keep(1 3) nogen
    merge m:1 pmid using ../external/robust_jrnls/scisub_all_pmids.dta, assert(1 2 3 4) keep(1 3 4)  update
    merge m:1 pmid using ../external/robust_jrnls/demsci_all_pmids.dta, assert(1 2 3 4) keep(1 3 4) nogen update
    cap drop _merge
    save ${temp}/openalex_panel, replace

    // merge in wos 
    clear
    foreach samp in thera cns scisub demsci {
        append using ../external/wos/`samp'_appended
    }
    gduplicates drop pmid, force
    save ${temp}/wos_appended, replace

    clear
    forval i = 1/6 {
        append using ../external/openalex/inst_geo_chars`i'
    }
    gduplicates drop inst_id, force
    replace inst_id= subinstr(inst_id,  "https://openalex.org/", "", .)
    save ../output/all_inst_geo_chars, replace
    use ${temp}/openalex_panel, clear
    merge m:1 pmid using ${temp}/wos_appended, assert(1 2 3) keep(1 3) nogen keepusing(cite_count pub_mnth pub_year)
    tostring pub_year, replace
    gen date = subinstr(strlower(pub_mnth) + pub_year, " " , "",. )
    gen pub_date = date(date, "MDY")
    format pub_date %td
    drop date
    rename pub_date date
    merge m:1 inst_id using ../output/all_inst_geo_chars, assert(1  3) keep(1 3) nogen 
    save ${temp}/cleaned_all_newfund_jrnls, replace

    import delimited using ../external/geo/us_cities_states_counties.csv, clear varnames(1)
    gcontract stateshort statefull
    drop _freq
    drop if mi(stateshort)
    rename statefull region
    merge 1:m region using ${temp}/cleaned_all_newfund_jrnls, assert(1 2 3) keep(2 3)  nogen
    replace stateshort =  "DC" if region == "District of Columbia"
    replace stateshort =  "VI" if region == "Virgin Islands, U.S."
    gen us_state = stateshort if country_code == "US"
    replace city = "Saint Louis" if city == "St Louis"
    replace city = "Winston Salem" if city == "Winston-Salem"
    merge m:1 city us_state using ../external/geo/city_msa, assert(1 2 3) keep(1 3) nogen
    replace msatitle = "Washington-Arlington-Alexandria, DC-VA-MD-WV"  if us_state == "DC"
    replace msatitle = "New York-Newark-Jersey City, NY-NJ-PA" if city == "The Bronx" & us_state == "NY"
    replace msatitle = "Miami-Fort Lauderdale-West Palm Beach, FL" if city == "Coral Gables" & us_state == "FL"
    replace msatitle = "Springfield, MA" if city == "Amherst Center" 
    replace msatitle = "Hartford-West Hartford-East Hartford, CT" if city == "Storrs" & us_state == "CT"
    replace msatitle = "Tampa-St. Petersburg-Clearwater, FL" if city == "Temple Terrace" & us_state == "FL"
    replace msatitle = "San Francisco-Oakland-Haywerd, CA" if city == "Foster City" & us_state == "CA"
    gen msa_comb = msatitle
    replace  msa_comb = "Research Triangle Park, NC" if msa_comb == "Durham-Chapel Hill, NC" | msa_comb == "Raleigh, NC" | city == "Res Triangle Pk" | city == "Research Triangle Park" | city == "Res Triangle Park"
    replace  msa_comb = "Bay Area, CA" if inlist(msa_comb, "San Francisco-Oakland-Hayward, CA", "San Jose-Sunnyvale-Santa Clara, CA")
    gen msa_c_world = msa_comb
    replace msa_c_world = substr(msa_c_world, 1, strpos(msa_c_world, ", ")-1) + ", US" if country == "United States" & !mi(msa_c_world)
    replace msa_c_world = city + ", " + country_code if country_code != "US"

    //  we don't want to count broad and HHMI if they are affiliated with other institutions.
    cap drop athr_id
    bys pmid (which_athr): replace which_athr = _n
    bys pmid which_athr: gen athr_id = _n == 1
    bys pmid (which_athr): gen which_athr2 = sum(athr_id)
    cap drop which_athr athr_id
    rename which_athr2 which_athr
    bys pmid which_athr: gen num_affls = _N
    bys pmid which_athr: gen author_counter = _n == 1
    gen broad_affl = inst == "Broad Institute"
    gen hhmi_affl = inst == "Howard Hughes Medical Institute"
    gen only_broad = num_affls == 1 & broad_affl == 1
    bys pmid which_athr: egen has_broad_affl = max(broad_affl)
    replace has_broad_affl = 0 if only_broad == 1
    drop if inst == "Broad Institute" & only_broad == 0
    drop if num_affls > 1 & hhmi_affl == 1 & mi(inst)
    bys pmid which_athr: egen has_hhmi_affl = max(hhmi_affl)
    qui hashsort pmid which_athr which_affl
    cap drop which_athr athr_id
    bys pmid which_athr: gen athr_id = _n == 1
    bys pmid (which_athr): gen which_athr2 = sum(athr_id)
    drop which_athr athr_id
    rename which_athr2 which_athr

    bys pmid (which_athr): replace which_athr = _n
    bys pmid which_athr: replace num_affls = _N
    bys pmid: egen num_athrs = max(which_athr)
    gen affl_wt = 1/num_affls * 1/num_athrs
    qui gen years_since_pub = 2022-year+1
    qui gen avg_cite_yr = cite_count/years_since_pub
    qui bys pmid: replace avg_cite_yr = . if _n != 1
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt

    save ../output/cleaned_all_newfund_jrnls, replace
    keep if inrange(date, td(01jan2015), td(31mar2022)) & year >=2015
    drop cite_wt cite_affl_wt
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt
    save ../output/cleaned_last5yrs_newfund_jrnls, replace
end
program split_sample
    foreach samp in all last5yrs {
        preserve
        use ../output/cleaned_`samp'_newfund_jrnls, clear
        keep if inlist(journal_abbr, "cell", "science", "nature")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        qui replace cite_wt = cite_wt * r(unique)
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        save ../output/cleaned_`samp'_newfund_cns, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_cns, replace
        restore

        preserve
        use ../output/cleaned_`samp'_newfund_jrnls, clear
        keep if inlist(journal_abbr, "cell_stem_cell", "nat_biotech", "nat_cell_bio", "nat_genet", "nat_med", "nat_med", "nat_neuro", "neuron")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        qui replace cite_wt = cite_wt * r(unique)
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        save ../output/cleaned_`samp'_newfund_scisub, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_scisub, replace
        restore

        preserve
        use ../output/cleaned_`samp'_newfund_jrnls, clear
        keep if inlist(journal_abbr, "faseb", "jbc", "onco", "plos")
        drop cite_wt cite_affl_wt
        qui sum avg_cite_yr
        gen cite_wt = avg_cite_yr/r(sum)
        qui gunique pmid
        qui replace cite_wt = cite_wt * r(unique)
        gsort pmid cite_wt
        qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
        qui gen cite_affl_wt = affl_wt * cite_wt
        save ../output/cleaned_`samp'_newfund_demsci, replace
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_newfund_demsci, replace
        restore
    }
end

main
