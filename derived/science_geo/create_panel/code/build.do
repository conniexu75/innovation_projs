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
    *create_athr_ids
    make_panel
end

program create_athr_ids
    // lets first work with 2002 and then backtrack the earlier dates. 2002 onward we mainly have full_names of people 
    // like how c, voisine = cindy voisine most likely 
    use if which_athr == 1 & country == "United States" & !mi(msa_comb) & year < 2002 using ../external/samp/cleaned_all_newfund_jrnls.dta, clear
    save ${temp}/pre_2002, replace
    use if year >= 2002 & which_athr == 1 & country == "United States" & !mi(msa_comb) using ../external/samp/cleaned_all_newfund_jrnls.dta, clear
    qui {
*        drop  if journal_abbr == "plos" | journal_abbr == "jbc" | journal_abbr == "oncogene" | journal_abbr == "faseb"
        keep pmid which* last_name first_name journal_abbr date us_state city zip inst year keywords city_full msatitle msa_comb  num_affls affl_wt cite_affl_wt  cite_count cite_wt journal_abbr
        replace last_name = strlower(last_name)
        joinby pmid last_name using ../external/wos/linked_orcid_all_jrnls, unmatched(master)
        rename name wos_name
        rename list_first_name list_first_name_orcid
        replace orcid = subinstr(orcid, ";","",.)
        gduplicates drop pmid which_athr orcid, force
        gduplicates tag pmid which_athr, gen(dup_joinby)
        drop if dup > 0 & substr(list_first_name_orcid,1,1) != substr(first_name, 1,1)
        drop dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
        drop if dup > 0 & substr(list_first_name_orcid,1,3) != substr(first_name, 1,3) & year >=2002
        drop if dup > 0 & year < 2002
        gen matches = list_first_name_orcid == first_name
        bys pmid which_athr: egen has_match = max(matches)
        drop if has_match == 1 & list_first_name_orcid != first_name & dup >0
        drop dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
        * about 27% have orcid
        drop _merge dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
        gen has_space = strpos(first_name, " ") >0 
        gen wos_has_space = strpos(list_first_name, " ") >0 
        bys pmid which_athr: egen wos_spaces = max(wos_has_space)
        drop if dup > 0 & substr(list_first_name,strpos(first_name," ")+1,1) !=  substr(first_name,strpos(list_first_name, " ")+1,1) & year >=2002 &   wos_spaces == 1 & has_space == 1
        drop dup_joinby has_space wos_has_space wos_spaces
        gduplicates tag pmid which_athr, gen(dup_joinby)
    }
    count if dup >0
    qui {
        drop if dup > 0
        gisid pmid which_athr
        drop dup_joinby

        joinby pmid last_name using ../external/wos/linked_researcher_id_all_jrnls, unmatched(master)
        replace wos_name = name if mi(wos_name)
        drop name has_match
        replace list_first_name = strreverse(substr(strreverse(list_first_name), 2, strlen(list_first_name))) if substr(strreverse(list_first_name), 1,1) == "."
        replace researcher_id = subinstr(researcher_id, ";","",.)
        gduplicates drop pmid which_athr researcher_id , force
        gduplicates tag pmid which_athr, gen(dup_joinby)
        drop if dup > 0 & substr(list_first_name,1,1) != substr(first_name, 1,1)
        drop dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
        drop if dup > 0 & substr(list_first_name,1,3) != substr(first_name, 1,3) & year >=2002
        drop if dup > 0 & year < 2002
        gen matches_researcher_id = list_first_name == first_name
        bys pmid which_athr: egen has_match = max(matches_researcher_id)
        drop if has_match == 1 & list_first_name != first_name & dup >0
        drop dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
        gen has_space = strpos(first_name, " ") >0 
        gen wos_has_space = strpos(list_first_name, " ") >0 
        bys pmid which_athr: egen wos_spaces = max(wos_has_space)
        drop if dup > 0 & substr(list_first_name,strpos(first_name," ")+1,1) !=  substr(first_name,strpos(list_first_name, " ")+1,1) & year >=2002 &   wos_spaces == 1 & has_space == 1
        drop dup_joinby
        gduplicates tag pmid which_athr, gen(dup_joinby)
    }
    count if dup >0
    
    drop if dup > 0
    drop has_space wos_has_space wos_spaces


    split first_name , parse(" ")
    rename first_name raw_first_name
    gen first_initial = ""
    qui ds first_name*
    foreach v in `r(varlist)' {
        replace `v' = substr(`v', 1,1)
        replace first_initial = first_initial + `v' + " "
    }
    replace first_initial = strtrim(first_initial)
    gen athr = strlower(first_initial + ", " + last_name)
    gen full_name = strlower(raw_first_name + ", " + last_name)
    cap drop name counter
    gen name = ""
    gen which_person = . 
    bys full_name orcid:  gen orcid_counter = _n == 1 if !mi(orcid)
    gsort full_name -orcid -orcid_counter
    by full_name: gen orcid_sum = sum(orcid_counter) if !mi(orcid)
    replace which_person = orcid_sum if !mi(orcid)
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if !mi(orcid)
    gen filled_orcid = !mi(orcid)

    bys full_name researcher_id:  gen researcher_id_counter = _n == 1 if !mi(researcher_id) 
    gsort full_name -researcher_id -researcher_id_counter
    by full_name: gen researcher_id_sum = sum(researcher_id_counter) if !mi(researcher_id)
    replace which_person =  researcher_id_sum if !mi(researcher_id) & mi(orcid)
    replace name = subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if !mi(researcher_id) & mi(orcid)
    gen filled_researcher = !mi(researcher_id) & mi(orcid)


    gen no_full_name = full_name == athr
    bys pmid: egen has_missing_full_name = max(no_full_name)
    drop if has_missing_full_name == 1
    drop has_missing_full_name

    bys full_name : gen id = _n == 1
    bys full_name : gen num_affiliations = _N
    bys full_name pmid : gen counter = _n == 1
    bys full_name: egen num_entries = total(counter)
    // this solves people like A J, Thomas which represents Andrew J, Thomas and Ashley J, Thomas
    by full_name: replace id = 1 if _n == 1 & id == 0
    bys full_name us_state: gen state_counter= _n == 1
    bys full_name: egen affiliated_states = total(state_counter)
    replace which_person = 1 if affiliated_states==1
    gen old = 1 if  affiliated_states==1
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if affiliated_states == 1  & mi(name)
    // now if each full name is only associated with one place in a year, then its one person
    bys full_name year us_state: gen mult_state_id = _n ==1 // id the start of each new state a person is affiliated with in a year
    bys full_name pmid (year msa_comb): gen pmid_id =  _n == 1 
    bys full_name pmid: gen has_mult_affiliations = _N > 1 & pmid_id == 1 // for a name, is there more than one affiliation for a pmid ?
    bys full_name: egen num_unique = sum(has_mult_affiliations) 
    replace which_person = 1 if mi(name) &   num_unique == num_entries & num_entries == 1
    replace old = 1 if mi(old) & num_unique == num_entries & num_entries == 1
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if  mi(name) &   num_unique == num_entries & num_entries == 1
    // now we deal with people with multiple entries
    // assume that those people with two entries? are probably the same person

    replace which_person = 1 if mi(name) & num_entries == 2
    replace old = 1 if mi(old) & num_entries == 2
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if  mi(name) & num_entries == 2
    // people who only have 2 unique institutes, grad school then post grad school are probably the same
    bys full_name inst: gen inst_id = _n == 1 &  pmid_id == 1
    bys full_name : egen num_insts = sum(inst_id)
    replace which_person = 1 if mi(name) & num_insts == 2
    replace old = 1 if mi(old) & num_insts == 2
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if  mi(name) & num_insts == 2 
    // now people in 2 states
    gsort full_name year pmid msa_comb
    bys full_name pmid: egen pmid_grp = sum(pmid_id)
    bys full_name us_state: gen state_id = _n == 1 &  pmid_grp == 1
    bys full_name : egen num_states = sum(state_id)
    replace which_person = 1 if mi(name) & num_states == 2
    replace old = 1 if mi(old) & num_states == 2
    replace name =  subinstr(substr(full_name, 1, strpos(full_name, ",")-1)+"_"+strlower(last_name)+string(which_person) , " ", "_",.) if  mi(name) & num_states == 2 
    preserve
    keep if !mi(name)
    save ${temp}/first_batch, replace
    restore
    drop if !mi(name)
    save ${temp}/second_batch, replace
    //  now we start id-ing people based on the number of entries in the first year
    cap drop id
    bys full_name: egen min_year = min(year) 
    gsort full_name year pmid msa_comb
    bys full_name year msa_comb: gen id = _n == 1 
    bys full_name year (msa_comb): replace which_person = _n if pmid_id == 1 & min_year == year  & mi(which_person) & id == 1 
    bys full_name pmid (which_person) : replace which_person = which_person[_n-1] if mi(which_person)
    bys full_name (which_person) : replace which_person = which_person[_n-1] if msa_comb == msa_comb[_n-1]  & mi(name)
    gsort full_name year pmid msa_comb which_person
    by full_name : replace which_person = which_person[_n-1] if mi(which_person) & msa_comb == msa_comb[_n-1]  & mi(name)
    by full_name: gen year_gap = year - year[_n-1]
    cap drop min_year
    bys full_name: egen min_year = min(year) if mi(which_person)
    save ${temp}/second_batch, replace
    
    // we need to figure out multiplie affiliations try aaron h, nile as test case. do we duplciate ? 
    use ${temp}/first_batch ,clear 
    drop if mi(name)
    cap drop counter
    cap keep pmid which_* cite_count msa_comb name year  pmid_id pmid_grp journal_abbr last_name raw_first_name first_initial
    replace first_initial = strlower(subinstr(first_initial, " ", "",.))
    gegen name_grp = group(name)
    bys name_grp: gen name_id = _n == 1
    gen rev_pmid_id = - pmid_id
    bys name_grp msa_comb (year pmid rev_pmid_id): gen place_id = _n == 1 if pmid_id == 1
    gen num_move_id = place_id
    by name_grp : replace num_move_id = . if _n == 1
    by name_grp : egen places = sum(place_id) 
    gen move = places > 1
    by name_grp: egen mover = max(move)
    by name_grp: egen num_moves = sum(num_move_id)
    cap drop num_move_id
    count if mover == 1 & name_id==1 
    local num_movers = r(N)
    count if num_moves > 0 & name_id==1
    assert r(N) == `num_movers'
    // too complicated so we drop people with more than one move.. which is less than 0.06 percent of movers (4.5%)
    by name_grp: egen min_year = min(year)
    by name_grp: egen max_year = max(year)
    gen origin = pmid_grp == 1 if min_year == year
    gen dest = pmid_grp == 1 if max_year == year
    bys pmid which_athr: gen num_affls = _N
    gen affl_wt = 1/num_affls
    // cluster size = # of scientists in area / total scientists
    // first find denominator
    // reweight
    bys pmid year: gen counter = _n == 1
    bys year: egen tot_in_year = total(counter)
    bys pmid (which_affiliation): replace cite_count = . if _n !=1
    qui bys year: egen tot_cites_in_year = total(cite_count)
    gen cite_wt = cite_count/ tot_cites_in_year * tot_in_year
    hashsort pmid cite_wt
    qui by pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gen cite_affl_wt = affl_wt * cite_wt
    preserve
    bys name year: gen name_year = _n == 1
    gcollapse (sum) name_year cite_affl_wt, by(name)
    qui sum cite_affl_wt, d
    keep if cite_affl_wt >= r(p90) 
    save ${temp}/first_batch_p90.dta, replace
    restore
    save ${temp}/first_batch_full.dta, replace
    foreach samp in full p90 {
        use ${temp}/first_batch_full.dta, clear
        gen to_expand = . 
        replace to_expand = 1 if origin == 1 & num_affls > 1 & mover == 1
        bys name: egen expand = max(to_expand)
        bys name (year msa_comb pmid rev_pmid_id): gen suf = _n if origin == 1 & mover == 1 & num_affls > 1
        by name: egen expand_n = max(suf)
        expand expand_n if origin==.  &  mover == 1 , gen(expanded)

        replace suf = suf-1
        tostring suf, replace
        tostring name_grp, replace
        bys name year (expanded): gen expanded_suf = sum(expanded)
        tostring expanded_suf, replace
        replace name_grp = name_grp+"_"+suf if origin==1 & mover == 1 & num_affls > 1
        replace name_grp = name_grp+"_"+expanded_suf if origin==. & mover == 1 & expand == 1  
        gen expanded_wt = cite_affl_wt 
        replace expanded_wt = cite_affl_wt/expand_n if origin == . & mover == 1 & expand == 1
        gen expanded_affl_wt = affl_wt 
        replace expanded_affl_wt = affl_wt/expand_n if origin == . & mover == 1 & expand == 1
        // up to here gives us our original prep_analysis_dataset
        gcollapse (sum) cite_affl_wt expanded_wt affl_wt expanded_affl_wt (mean) mover origin dest , by(name_grp msa_comb year name last_name raw_first_name first_initial)
        bys name_grp year: gen name_id = _n == 1
        bys year: egen tot_authors = total(name_id)
        drop name_id
        bys name_grp msa_comb year: gen name_id = _n == 1
        bys msa_comb year: egen msa_size = total(name_id)
        replace msa_size = msa_size - 1
        gen cluster_shr = msa_size/tot_authors
        if "`samp'" == "p90" {
            merge m:1 name using ${temp}/first_batch_p90, assert(1 3) keep(3) nogen
        }
        save ../output/athr_panel_`samp', replace
        gcontract last_name raw_first_name first_initial
        replace last_name = strproper(last_name)
        drop _freq
        gen setnb = _n 
        rename (raw_first_name last_name) (first last)
        split first, parse(" ") limit(2)
        rename first2 middle
        replace middle = substr(middle, 1,1)
        gen name1 = strlower(last) + " " + first_initial
        gen name2 = . 
        gen name3 = . 
        gen name4 = . 
        gen name5 = . 
        gen name6 = . 
        gen MedlineSearch = "(" + `"""' +last + " " + first + `"""' + "[au]" +" AND 2002:2022[dp])" 
        drop first1 first_initial
        save ../output/athr_list_`samp', replace
        order setnb first middle last name1 name2 name3 name4 name5 name6 MedlineSearch
        export delimited ../output/athr_list_`samp', replace
    }
end
program make_panel
    use ../external/openalex/cleaned_all_newfund_jrnls, clear
    drop if mi(msa_comb)
    keep if country_code == "US"
    bys pmid: gen pmid_id =1
    gen rev_pmid_id = -pmid_id
    bys athr_id msa_comb (year pmid rev_pmid_id): gen place_id = _n == 1 if pmid_id == 1
    by athr_id: egen places = sum(place_id) 
    gen move = places > 1
    by athr_id : egen mover = max(move)
    gcollapse (sum) cite_affl_wt affl_wt (mean) mover , by(athr_id msa_comb year athr_name)
    bys athr_id year: gen name_id = _n == 1
    bys year: egen tot_authors = total(name_id)
    drop name_id
    bys athr_id msa_comb year: gen name_id = _n == 1
    bys msa_comb year: egen msa_size = total(name_id)
    replace msa_size = msa_size - 1
    gen cluster_shr = msa_size/tot_authors
    save ../output/athr_panel_full, replace
end

** 
main
