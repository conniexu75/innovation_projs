set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global country_name "countries"
    global us_state_name "US states"
    global area_name "US cities"
    global city_full_name "world cities"
    global inst_name "institutions"
    foreach samp in cns med scisub cns_med {
        di "OUTPUT START"
        local samp_type = cond(strpos("`samp'" , "cns")>0 | strpos("`samp'", "med")>0, "main", "robust")
        foreach data in fund dis thera {
        di "SAMPLE IS `samp' `data':" 
            prep_data, data(`data') samp(`samp') samp_type(`samp_type')
        }
    }
end

program prep_data
    syntax, data(str) samp(str) samp_type(str)
    use ../external/`samp_type'_split/cleaned_`data'_all_`samp', clear
    qui {
        merge m:1 pmid using ../external/`samp_type'_filtered/all_jrnl_articles_`samp'Q1, assert(1 2 3) keep(3) nogen
        merge m:1 pmid using ../external/wos/`samp'_appended, assert(1 2 3) keep(3) nogen 
        keep if strpos(doc_type, "Article")>0
        drop if strpos(doc_type, "Retracted")>0
        replace year = pub_year if !mi(pub_year)
        drop pub_year
        cap drop affil
        cap drop _merge
        replace affiliation = strtrim(affiliation)
        replace affiliation = "" if affiliation == "The authors' affiliations are listed in the Appendix."
        replace affiliation = "" if affiliation == "."
        replace affiliation = "" if strpos(affiliation, "@")>0 & mi(institution)
        gen mi_affl = mi(affiliation)
        bys pmid which_athr: gen which_mi_affl = sum(mi_affl)
        drop if which_mi_affl > 1
        drop which_mi_affl mi_affl
        // we don't want to count broad and HHMI if they are affiliated with other institutions. 
        bys pmid which_athr: gen athr_id = _n == 1
        bys pmid (which_athr): gen which_athr2 = sum(athr_id)
        drop which_athr athr_id
        rename which_athr2 which_athr
        bys pmid which_athr: gen num_affls = _N
        bys pmid which_athr: gen author_counter = _n == 1
        replace num_affls = . if num_affls == 1 & mi(affiliation)
        replace institution = "Broad" if strpos(affiliation, "Broad Institute of MIT and Harvard") > 0 | strpos(affiliation, "Broad Institute") > 0
        gen only_broad = num_affls == 1 & broad_affl == 1
        bys pmid which_athr: egen has_broad_affl = max(broad_affl)
        replace has_broad_affl = 0 if only_broad == 1
        drop if institution == "Broad" & only_broad == 0
        bys pmid which_athr: replace num_affls = _N
        cap rename hmmi_affl hhmi_affl
        replace hhmi_affl = 1 if strpos(affiliation, "Howard Hughes") > 0 | strpos(affiliation, "HHMI") > 0 

        // the below can be moved to server
        replace institution = "HHMI-Janelia" if hhmi_affl == 1 & strpos(affiliation, "Janelia") > 0 
        replace hhmi_affl = 0 if institution == "HHMI-Janelia"
        replace institution = "HHMI" if hhmi_affl == 1 & mi(institution) & num_affls == 1 & city == "Cambridge"
        drop if num_affls > 1 & hhmi_affl == 1 & mi(institution) 
        bys pmid which_athr: egen has_hhmi_affl = max(hhmi_affl)
        qui hashsort pmid which_athr which_affiliation
        bys pmid which_athr: gen athr_id = _n == 1
        bys pmid (which_athr): gen which_athr2 = sum(athr_id)
        drop which_athr athr_id
        rename which_athr2 which_athr
        bys pmid which_athr: replace which_affiliation = _n
        bys pmid which_athr: replace num_affls = _N
        bys pmid which_athr institution: gen inst_counter = _n == 1 if !mi(institution)
        bys pmid which_athr: egen num_insts = total(inst_counter)
        gen mi_inst = mi(institution)
        bys pmid which_athr: egen has_mi_inst = max(mi_inst)
        drop if inst_counter != 1 & num_affls > 1 & num_insts == 1 & has_mi_inst == 0
        bys pmid which_athr: replace which_affiliation = _n
        bys pmid which_athr: replace num_affls = _N
        bys pmid: egen num_athrs = max(which_athr)
        gen affl_wt = 1/num_athrs * 1/num_affls
        replace journal_abbr = "Science" if journal == "Science"
        replace journal_abbr = "BMJ" if journal == "British medical journal (Clinical research ed.)"
        replace journal_abbr = "annals" if journal_abbr == "Ann Intern Med"
        replace journal_abbr = "nejm" if journal_abbr == "N Engl J Med"
        replace journal_abbr = "nat_biotech" if journal_abbr == "Nat Biotechnol"
        replace journal_abbr = "nat_cell_bio" if journal_abbr == "Nat Cell Bio"
        replace journal_abbr = "nat_chem_bio" if journal_abbr == "Nat Chem Bio"
        replace journal_abbr = "nat_genet" if journal_abbr == "Nat Genet"
        replace journal_abbr = "nat_med" if journal_abbr == "Nat Med"
        replace journal_abbr = "faseb" if journal_abbr == "FASEB J"
        replace journal_abbr = "jbc" if journal_abbr == "J Biol Chem"
        replace journal_abbr = "onco" if journal_abbr == "Oncogene"
        replace journal_abbr = "plos" if journal_abbr == "PLoS One"
        replace journal_abbr = "cell_stem_cell" if journal_abbr == "Cell Stem Cell"
        replace journal_abbr = "nat_neuro" if journal_abbr == "Nat Neurosci"
        replace journal_abbr = "neuron" if journal_abbr == "Neuron"
        replace journal_abbr = lower(journal_abbr)
        cap drop _merge
    }
    qui gen mi_affl = mi(affiliation)
    qui bys pmid: egen all_mi_affl = min(mi_affl)
    gunique pmid
    gunique pmid if all_mi_affl == 1
    qui drop if all_mi_affl == 1
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
    qui {
        gen us_city = city if country == "United States"  & !inlist(city, "Center")
        gen area = us_city
        replace area = "Boston-Cambridge" if inlist(us_city, "Boston", "Cambridge")
        replace area = "Bay Area"  if (inlist(us_city, "Stanford", "San Francisco", "Berkeley", "Palo Alto") | inlist(us_city, "Mountain View", "San Jose", "Oakland", "Sunnyvale", "Cupertino", "Menlo Park") | inlist(us_city, "South San Francisco" , "Foster City")) & us_state == "CA" 
        replace area = "San Diego-La Jolla" if inlist(us_city, "La Jolla", "San Diego")
        replace area = "Bethesda-DC" if inlist(us_city, "Bethesda", "Washington")
        replace area = "Research Triangle" if inlist(us_city, "Durham", "Chapel Hill", "Raleigh", "Research Triangle Park", "Cary" , "RTP")
        gen city_country = area + ", " + country if !mi(area) & !mi(country)
        replace city_country = city + ", " + country if !mi(city) & mi(city_country) & !mi(country)
        replace city_country = "Uncoded cities in " + country if mi(city_country) & !mi(country)
        rename city_country city_full
    }
    qui bys pmid: gen pmid_counter = _n == 1
    qui rename institution inst
    cap drop _merge
    qui gen years_since_pub = 2022-year+1
    qui gen avg_cite_yr = cite_count/years_since_pub
    qui bys pmid: replace avg_cite_yr = . if _n != 1
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt
    qui save ../output/cleaned_all_`data'_`samp', replace

    qui keep if inrange(date, td(01jan2015), td(31mar2022))
    drop cite_wt 
    qui sum avg_cite_yr
    qui gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui replace cite_affl_wt = affl_wt * cite_wt
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
    qui save ../output/cleaned_last5yrs_`data'_`samp', replace
  
    preserve
    qui gcontract pmid year
    drop _freq
    qui save ../output/list_of_pmids_last5yrs_`data'_`samp', replace
    restore
end
** 
main
