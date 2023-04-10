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
    prep_data, data(clin) samp(med) samp_type(clinical)
    foreach samp in cns scisub demsci {
        di "OUTPUT START"
        local samp_type = cond(strpos("`samp'" , "cns")>0 | strpos("`samp'", "med")>0, "main", "robust")
        foreach data in fund dis thera {
            di "SAMPLE IS `samp' `data':" 
            prep_data, data(`data') samp(`samp') samp_type(`samp_type')
        }
        foreach type in cleaned_all cleaned_last5yrs list_of_pmids list_of_pmids_last5yrs {
            clear 
            append using ../output/`type'_fund_`samp'
            append using ../output/`type'_dis_`samp'
            append using ../output/`type'_thera_`samp'
            save ../output/`type'_newfund_`samp', replace
        }
    }
end

program prep_data
    syntax, data(str) samp(str) samp_type(str)
    if "`data'" == "thera" {
        use ../external/thera_full_samp/cleaned_all_thera, clear
        merge m:1 pmid using ../external/thera_xwalk/thera_pmids, assert(2 3) keep(3) nogen
        merge m:1 pmid using ../external/wos/thera_appended, assert(1 2 3) keep(3) nogen 
        if "`samp'" == "cns" { 
            keep if inlist(journal_abbr, "Cell", "Nature", "Science")
        }
        if "`samp'" == "scisub" {
            keep if inlist(journal_abbr, "Cell Stem Cell", "Nat Biotechnol", "Nat Cell Biol", "Nat Chem Biol", "Nat Genet", "Nat Med", "Nat Neurosci", "Neuron")
        }
        if "`samp'" == "demsci" {
            keep if inlist(journal_abbr, "FASEB J", "Oncogene", "PLoS One", "J Biol Chem")
        }
        if "`samp'" == "noplos" {
            keep if inlist(journal_abbr, "FASEB J", "Oncogene", "J Biol Chem")
        }
    }
    else {
        use ../external/`samp_type'_split/cleaned_`data'_all_`samp', clear
    }
    drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
    drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279, 33264556, 33631065, 33306283, 33356051)
    drop if inlist(pmid, 34587383, 34260849, 34937145, 34914868, 33332779, 36286256, 28657871, 35353979, 33631066, 27959715)
    drop if inlist(pmid, 29045205, 27376580, 29800062)
    qui gunique pmid 
    local N = r(unique)
    gunique pmid if strpos(affiliation, "From ")==1 | (strpos(affiliation, "(")>0 & strpos(affiliation, ")")>0)
    di "Droped UNCLEANALBE TRIALS = " r(unique)/`N'*100
    gen need_to_fill =  strpos(affiliation, "From ")==1 | (strpos(affiliation, "(")>0 & strpos(affiliation, ")")>0)
    preserve
    gcontract pmid journal_abbr date year if need_to_fill == 1
    merge 1:m pmid using ../external/wos_affils/cleaned_wos_`samp', assert(1 2 3) keep(3) nogen
    rename (which_affil which_author) (which_affiliation which_athr)
    drop _freq
    gen filled = 1
    save ../temp/fill_`data'_`samp', replace
    restore
    drop if need_to_fill == 1
    append using ../temp/fill_`data'_`samp'
    replace affiliation = institution +", " + city+ ", " + country if mi(affiliation) & filled == 1
    replace affiliation = "" if strpos(affiliation, "@")> 0
*    drop if strpos(affiliation, "From ")==1 | (strpos(affiliation, "(")>0 & strpos(affiliation, ")")>0)
    cap drop _merge
    //some extra clean metadata
    replace city = strreverse(strtrim(substr(strreverse(inst), 1, strpos(strreverse(inst),",")-1))) if strpos(inst, "University of California,")>0
    foreach c in "San Francisco" "Rochester" "St Louis" "Newton" "Newcastle upon Tyne" "Bristol" "Liverpool" "Salisbury" "West Roxbury" "Birmingham" "Keighley" "Denver" "Winston-Salem" "Murray" "Bronx" "Pittsburgh" "Omaha" "Houston" "Chicago" "La Jolla" "Miami" "Cleveland" "Nashville" "Baltimore"  "Phoenix" "San Diego" "Durham" "Minneapolis" "Seattle" "Framingham" "Palo Alto" "Philadelphia" "St. Louis" "Charlestown" "Brookline" "Oakland" "Detroit" "Loma Linda" "Abbott Park" "Frederick" "Hyattsville" "Silver Spring" "Santa Monica" "Los Angeles" "Calverton" "Weston" "Bloomington" "Dalals" "Prague" "Cincinnati" "Bilthoven" "Leeds" "Manchester" "Cardiff" "Menlo Park" "Nottingham" "Sutton" "Gloucester" "Copenhagen" "Oxford" "Bethesda" "Dundee" "Toronto" "Glasgow" "London" "Gothenburg" "Boston" "York" "Cambridge" "Southampton" "Padua" "Medford" "Maywood" "Belfast" "Seville" "Genova" "Crowley" "Kensington" "Newtown" "Brisbane" "Bialystok" "Newcastle" {
        replace city = "`c'" if strpos(affiliation, "`c'") > 0 & mi(city) 
    }
    foreach i in "Unite de Pharmacologie Clinique" "Jaeb Center for Health Research" "NRG Oncology"{
        replace inst = "`i'" if strpos(affiliation, "`i'")>0 & mi(city)
    }
    replace country = "United States" if inlist(city, "San Francisco", "Rochester", "St Louis", "Newton", "West Roxbury") 
    replace country = "United Kingdom" if inlist(city, "Newcastle upon Tyne", "Bristol","Salisbury", "Liverpool")     
    replace city = "Saint Louis" if city == "St Louis" | city == "St. Louis" 
    replace city = "Soborg" if strpos(affiliation, "Søborg")>0 | strpos(affiliation, "SA¸borg")>0
    replace city = "Newcastle" if strpos(strlower(affiliation), "newcastle") > 0 & strpos(strlower(affiliation), "upon")>0 & strpos(strlower(affiliation), "tyne")>0
    replace city = "Winston Salem" if city == "Winston-Salem"
    replace city = "Nairobi" if inst == "Kenya Meidcal Research Institute"
    replace city = "Los Angeles" if inst == "University of California, Los Angeles"
    replace city = "Boston" if inst == "Harvard Medical School" 
    replace city = "Boston" if inst == "Brigham and Women's Hospital" 
    replace inst = "Harvard University" if strpos(inst, "Harvard")
    replace inst = "NIHR" if strpos(inst, "NIHR")
    replace inst = "Stanford University" if strpos(inst, "Stanford")
    replace city = "Bethesda" if inst == "NIH" & mi(city)
    replace city = "Foster City" if inst == "Gilead Sciences"
    replace country = strtrim(strproper(country))
    replace country = "United States" if country == "Usa"
    replace country = "United Kingdom" if inlist(country, "England", "Scotland", "Wales", "Ireland", "Uk")
    replace country = "Central African Republic" if country == "Cent Afr Republ"
    replace country = "Cote Ivoire" if strpos(country, "Ivoire")>0 | country == "Ivory Coast"
    replace country = "Saint Lucia" if country == "St Lucia"
    replace country = "United Arab Emirates" if country == "U Arab Emirates"
    replace country = "Trinidad Tobago" if strpos(country, "Trinidad")>0 & strpos(country, "Tobago")>0
    replace country = "Vietnam" if country == "Viet Nam"
    replace country = "Dominican Republic" if country == "Dominican Rep"

    replace institution = subinstr(institution, "Univ", "University", .) if strpos(institution, "Univer")==0 & strpos(institution, "Univ")>0
    replace institution = subinstr(institution, "Hosp", "Hospital", .) if strpos(institution, "Hospital")==0 & strpos(institution, "Hosp")>0
    replace institution = subinstr(institution, "Canc", "Cancer", .) if strpos(institution, "Cancer")==0
    replace institution = subinstr(institution, "Ctr", "Center",.) if strpos(institution, "Center")==0
    replace institution = "NIH" if inlist(institution, "NIAID", "NIA", "NINDS", "NIMH", "NIAMSD" , "NIDA", "NIDDKD", "NIEHS", "NINR" ) & country == "United States"

    replace institution = "University at Buffalo" if strpos(affiliation, "University") > 0 & strpos(affiliation, "at Buffalo")>0
    replace institution = "Texas A&M" if strpos(affiliation, "A&M") & country == "United States"
    replace institution = "NYU" if strpos(institution, "NYU")>0 & country == "United States"
    replace institution = subinstr(institution, "University", "University", .) if strpos(institution, "University of")==0 & strpos(institution, "University") == 1
    replace institution = "MD Anderson" if strpos(institution, "MD Anderson") > 0
    replace institution = "CDC" if institution == "Center Dis Control & Prevent"
    replace institution = "Institut Pasteur" if strpos(affiliation, "Pasteur")> 0 & strpos(affiliation, "Inst")>0 & country == "France"
    replace institution = "Chinese Academy of Sciences" if strpos(affiliation, "CAS") > 0 & country == "China"
    replace institution = "Ragon Institute" if strpos(affiliation, "Ragon Institute")>0
    replace institution = "" if institution == "IRCCS"
    foreach i in "Humanitas" "Candiolo Cancer Institute" "European Institute of Oncology" "Istituto Nazionale dei Tumori" "Istituto di Ricerche Farmacologiche Mario Negri" "Burlo Garofolo" "San Raffaele Sci Inst" "Associaz Oasi Maria Santissima" "Regina Elena National Cancer Institute"{
        replace institution = "`i'" if strpos(affiliation, "`i'")>0 
        }
    replace affiliation = subinstr(affiliation, "A¹", "u", .)
    replace institution = "Candiolo Cancer Institute" if strpos(affiliation, "IRCCS")>0 & strpos(affiliation, "FPO")>0
    replace institution = "San Matteo Foundation" if strpos(affiliation, "San Matteo")>0 & (strpos(affiliation, "Fonda")>0 | strpos(affiliation, "Foundation")>0|strpos(affiliation, "Fdn")>0)
    replace institution = "San Raffaele Sci Inst" if strpos(affiliation, "San Raffaele")>0 & strpos(affiliation, "Sci")>0 & strpos(affiliation, "Inst")>0
    foreach hosp in "San Martino" "San Matteo" "San Raffaele" "Bambino Gesu" {
        replace institution = "`hosp'"+ " Hospital" if strpos(affiliation, "`hosp'")>0 & (strpos(affiliation, "Osped")>0 | strpos(affiliation , "Hosp")>0) & country == "Italy"
    }
    replace institution = "Peking University" if strpos(affiliation, "Peking Univ")>0
    replace institution = "Chinese Academy of Medical Sciences" if (strpos(affiliation, "Chinese Acad")>0 & strpos(affiliation, "Med" )>0 & strpos(affiliation, "Sci")>0) | (strpos(affiliation, "Peking Union")>0 & strpos(affiliation, "Med")>0)
    replace institution = "California State University" if strpos(affiliation, "California State University")>0 
    replace institution = "University of California, San Francisco" if institution == "University of San Francisco"
    replace institution = "University of California, San Francisco" if strpos(affiliation, "UCSF")>0 & us_state == "CA" 
    replace institution = "University of California, Los Angeles" if strpos(affiliation, "UCLA")>0 & us_state == "CA" 
    replace institution = "University of California, Irvine" if strpos(affiliation, "UCI")>0 & us_state == "CA" 
    replace institution = "University of California, Merced" if strpos(affiliation, "UC Merced")>0 & us_state == "CA" 

    replace institution = "University of California, Davis" if strpos(affiliation, "UC Davis")>0 & us_state == "CA" 
    replace institution = "University of California, Santa Barbara" if strpos(affiliation, "UCSB")>0 & us_state == "CA" 
    replace institution = "University of California, San Diego" if (strpos(affiliation, "UCSD")>0|(strpos(affiliation, "Univ")>0 & strpos(affiliation, "Calif")>0 &strpos(affiliation, "San Diego")>0 )) & us_state == "CA" 
    replace institution = "University of California, Santa Cruz" if strpos(affiliation, "UC Santa Cruz")>0 & us_state == "CA" 
    replace institution = "University of California, " + city if institution == "University Calif" | institution == "University of California"    
    replace institution = subinstr(institution, "Calif", "California",.) if strpos(institution, "California")==0
        foreach cal in "Berkeley" "Los Angeles" "Santa Barbara" "San Diego" "Davis" "Irvine" "Santa Cruz" "Riverside" "Merced" "San Francisco" {
            replace institution = "University of California, `cal'" if strpos(affiliation, "University of California `cal'") > 0
            replace institution = "University of California, `cal'" if strpos(affiliation, "University of California-`cal'") > 0
            replace institution = "University of California, `cal'" if strpos(affiliation, "University of California, `cal'") > 0
            replace institution = "University of California, `cal'" if strpos(affiliation, "University of California at `cal'") > 0
            replace institution = "University of California, `cal'" if strpos(affiliation, "Univ") > 0 & strpos(affiliation, "Calif")>0 & strpos(affiliation, "`cal'")>0
            replace institution = "University of California, `cal'" if strpos(affiliation, "UC `cal'") > 0
            replace institution = "University of California, `cal'" if strpos(affiliation, "University of California") > 0 & strpos(affiliation, "`cal'")>0& mi(institution)
        }
        replace institution = "University of Southern California" if institution == "University Southern California"
        replace institution = subinstr(institution, "University" ,"University of",.) if strpos(institution, "of")==0 & strpos(institution, "at")==0 & strpos(institution, "University")==1
        replace institution = "Washington University in St. Louis" if strpos(affiliation, "Washington Univ")>0 & city == "Saint Louis"
        replace institution = "University of Oxford" if strpos(affiliation, "Oxford Univ")>0
        replace institution = "University of Cambridge" if strpos(affiliation, "Cambridge Univ")>0
        replace institution = "Massachusetts Institute of Technology" if institution == "MIT"
        replace institution = "The Rockefeller University" if institution == "Rockefeller University"
        replace institution = "University of Texas, Medical Branch at Galveston" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Medical Branch")> 0 & strpos(affiliation, "Galveston")> 0
        replace institution = "University of Texas, Health Science Center at Houston" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Health")> 0 & strpos(affiliation, "Houston")> 0
        replace institution = "University of Texas, Health Science Center at San Antonio" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Health")> 0 & strpos(affiliation, "San Antonio")> 0
        foreach tex in "Arlington"  "Austin" "Dallas" "El Paso"  "Permian Basin" "Rio Grande Valley" "San Antonio" "Tyler" "Southwestern Medical Center" "Houston" {
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation,"`tex'") > 0
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "UT")>0 & strpos(affiliation,"`tex'") > 0 & us_state == "TX"
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas") > 0 & city == "`tex'"
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "University Texas")>0 & strpos(affiliation, "`tex'") > 0
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas-`tex'") > 0
            replace institution = "University of Texas, `tex'" if strpos(affiliation, "UT `tex'") > 0
            replace country = "United States" if institution == "University of Texas, `tex'"
            replace us_state = "TX" if institution == "University of Texas, `tex'"
        }
        replace institution = "University of Texas, Southwestern Medical Center" if strpos(affiliation, "University of Texas") >0 & (strpos(affiliation, "Southwestern") >0 | strpos(affiliation, "SW")>0)
        replace institution = "University of Texas, Southwestern Medical Center" if strpos(institution, "University of Texas") >0 & (strpos(institution, "Southwestern") >0 | strpos(institution, "SW")>0)
        replace institution = "University of Wisconsin" if strpos(affiliation , "Univ")>0 & strpos(affiliation , "Wisconsin")>0 & us_state == "WI" 
        replace institution = "California Institute of Technology" if strpos(strlower(affiliation), "caltech")>0
        replace institution = "Max Planck" if strpos(affiliation, "Max Planck")>0 & country == "Germany"
        replace institution = "University of College London" if strpos(affiliation, "UCL")>0 & strpos(affiliation , "London")>0
        replace institution = "Medical Research Council" if strpos(institution, "MRC") >0 & country == "United Kingdom"
        replace institution = "CNRS" if (strpos(institution, "CNRS")>0 | strpos(strlower(affiliation), "centre national de la recherche scientifique"))>0 & country == "France"
        replace institution = "Memorial Sloan-Kettering Cancer Center" if strpos(affiliation, "Kettering") > 0 & strpos(affiliation, "Univ")==0
        replace institution = "MD Anderson" if strpos(affiliation, "MD Anderson")>0
        replace institution = "Brigham and Women's Hospital" if institution == "Brigham & Womens Hospital"
        replace institution = subinstr(institution, "&", "and",.)
        replace institution = subinstr(institution, "Sci", "Science", .) if strpos(institution, "Science")==0
        replace institution = subinstr(institution, "Inst", "Institute", .) if strpos(institution, "Institute")==0
        replace institution = subinstr(institution, "Hosp", "Hospital", .) if strpos(institution, "Hospital")==0
        replace institution = subinstr(institution, "Technol", "Technology", .) if strpos(institution, "Technology")==0
        replace institution = subinstr(institution, "Therapeut", "Therapeutics", .) if strpos(institution, "Therapeutics")==0
        replace institution = subinstr(institution, "Pharmaceut", "Pharmaceuticals", .) if strpos(institution, "Pharmaceuticals")==0
        replace institution = subinstr(institution, "Syst", "System", .) if strpos(institution, "System")==0
        replace institution = subinstr(institution, "Phys", "Physics", .) if strpos(institution, "Physics")==0
        replace institution = subinstr(institution, "Infirm", "Infirmary", .) if strpos(institution, "Infirmary")==0
        replace institution = subinstr(institution, "Mil ", "Military ", .) if strpos(institution, "Military")==0
        replace institution = subinstr(institution, "Psychiat", "Psychiarty", .) if strpos(institution, "Pyschiatry")==0
        replace institution = subinstr(institution, "Technical", "Tech", .) if strpos(institution, "Technical")>0
        replace institution = subinstr(institution, "Technology", "Tech", .) if strpos(institution, "Technology")>0
        replace institution = subinstr(institution, "Agr", "Agriculture", .) if strpos(institution, "Agriculture")==0
        replace institution = subinstr(institution, "Hlth", "Health", .) if strpos(institution, "Health")==0
        replace institution = subinstr(institution, "Dis ", "Disease", .) if strpos(institution, "Disease")==0
        replace institution = subinstr(institution, "Clin", "Clinic", .) if strpos(institution, "Clinic")==0
        replace institution = subinstr(institution, "Mol Biol", "Molecular Biology", .) 
        replace institution = subinstr(institution, "Biol", "Biology", .) if strpos(institution, "Biology")==0
        replace institution = subinstr(institution, "Natl", "National", .) if strpos(institution, "National")==0
        replace institution = subinstr(institution, "Res", "Research", .) if strpos(institution, "Research")==0
        replace institution = subinstr(institution, "Fed", "Federal", .) if strpos(institution, "Federal")==0
        replace institution = subinstr(institution, "Sch", "School", .) if strpos(institution, "School")==0 
        replace institution = subinstr(institution, "Agcy", "Agency", .) if strpos(institution, "Agency")==0 
        replace institution = subinstr(institution, "Publ", "Public", .) if strpos(institution, "Public")==0 
        replace institution = subinstr(institution, "Fdn", "Foundation", .) if strpos(institution, "Foundation")==0 
        replace institution = subinstr(institution, "Dist", "District", .) if strpos(institution, "District")==0 
        replace institution = subinstr(institution, "Govt", "Government", .) if strpos(institution, "Government")==0
        replace institution = subinstr(institution, "Collaborat", "Collaborative", .) if strpos(institution, "Collaborative")==0
        replace institution = subinstr(institution, "Vet Clinic", "Veterinary Clinic", .) 
        replace institution = subinstr(institution, "St. ", "St ", .) 
        replace institution = subinstr(institution, "Centre ", "Center", .) 
        replace institution = subinstr(institution, "Acad", "Academy of", .) if strpos(institution, "Academy")==0 & strpos(strreverse(institution), "dacA")!=1
        replace institution = subinstr(institution, "Acad", "Academy", .) if strpos(institution, "Academy")==0 
        replace institution = subinstr(institution, "Assoc", "Associates", .) if strpos(institution, "Associates")==0 
        replace institution = subinstr(institution, "Oncol", "Oncology", .) if strpos(institution, "Oncology")==0 
        replace institution = "Weizmann Institute of Science" if institution == "Weizmann Institute Science"
        replace institution = subinstr(institution, "Sciences", "Science",.)
        replace institution = "RAS" if strpos(institution, "Russian Academy of Science")>0 & country == "Russia"
        replace institution = "Cornell University" if strpos(institution, "Weill Cornell")>0
        replace institution = subinstr(institution, "Medicine",  "Med", .)
        replace institution = subinstr(institution, "Medical",  "Med", .)
        replace institution = subinstr(institution, "Laboratories", "Labs",.)
        replace institution = subinstr(institution, "Coll ", "University",.) if strpos(institution, "University")==0 
        replace institution = subinstr(institution, " Coll", "University",.) if strpos(institution, "University")==0 
        replace institution = subinstr(institution, "College", "University",.) if strpos(institution, "University")==0 & strpos(institution, "College")>0
        replace institution = subinstr(institution, "Universityege", "University",.)
        replace institution = "Duke-NUS" if strpos(affiliation, "Duke")>0 & strpos(affiliation, "Singapore")>0
        replace institution = "Duke-NUS" if strpos(affiliation, "Duke")>0 & strpos(affiliation, "NUS")>0
        replace institution = "PSL" if strpos(affiliation, "Paris")>0 & strpos(affiliation, "Science")>0 & strpos(affiliation, "Lett")>0

    merge m:1 pmid using ../external/`samp_type'_filtered/all_jrnl_articles_`samp'Q1, assert(1 2 3) keep(3) nogen 
    if "`data'"!="thera" & "`data'" != "clin" {
        merge m:1 pmid using ../external/thera_xwalk/thera_pmids, assert(1 2 3) keep(1) keepusing(pmid) nogen
    }
    if "`data'" == "clin" {
        merge m:1 pmid which_athr which_affiliation using ../external/fill_mi_insts/filled_in_insts, assert(1 2 3) keep(1 3) nogen
        replace institution = test_inst if !mi(test_inst) & mi(institution)
    }
    merge m:1 pmid using ../external/wos/`samp'_appended, assert(1 2 3) keep(3) nogen 
*    keep if strpos(doc_type, "Article")>0
    keep if doc_type == "Article"
    drop if strpos(doc_type, "Retracted")>0
     gen lower_title = strlower(title) 
     drop if strpos(lower_title, "economic")>0
     drop if strpos(lower_title, "economy")>0
     drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
     drop if strpos(lower_title, "health care")>0
     drop if strpos(lower_title, "health-care")>0
     drop if strpos(lower_title, "public health")>0
     drop if strpos(lower_title, "government")>0
     drop if strpos(lower_title, "reform")>0
     drop if strpos(lower_title , "quality")>0
     drop if strpos(lower_title , "equity")>0
     drop if strpos(lower_title , "payment")>0
     drop if strpos(lower_title , "politics")>0
     drop if strpos(lower_title , "policy")>0
     drop if strpos(lower_title , "comment")>0
     drop if strpos(lower_title , "guideline")>0
     drop if strpos(lower_title , "professionals")>0
     drop if strpos(lower_title , "physician")>0
     drop if strpos(lower_title , "workforce")>0
     drop if strpos(lower_title , "medical-education")>0
     drop if strpos(lower_title , "medical education")>0
     drop if strpos(lower_title , "funding")>0
     drop if strpos(lower_title , "conference")>0
     drop if strpos(lower_title , "insurance")>0
     drop if strpos(lower_title , "fellowship")>0
     drop if strpos(lower_title , "ethics")>0
     drop if strpos(lower_title , "legislation")>0
     drop if strpos(lower_title , " regulation")>0
    replace journal_abbr = "Science" if journal == "Science"
    replace journal_abbr = "BMJ" if journal == "British medical journal (Clinical research ed.)"
    replace journal_abbr = "annals" if journal_abbr == "Ann Intern Med"
    drop if journal_abbr ==  "annals"
    replace journal_abbr = "nejm" if journal_abbr == "N Engl J Med"
    replace journal_abbr = "nat_biotech" if journal_abbr == "Nat Biotechnol"
    replace journal_abbr = "nat_cell_bio" if journal_abbr == "Nat Cell Biol"
    replace journal_abbr = "nat_chem_bio" if journal_abbr == "Nat Chem Biol"
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
    replace year = pub_year if !mi(pub_year)
    drop pub_year
    cap drop affil
    cap drop _merge
    replace affiliation = strtrim(affiliation)
    replace affiliation = "" if strpos(affiliation,"The authors' affiliations are listed in the") > 0
    replace affiliation = "" if strpos(affiliation,"Joint first authors") > 0
    replace affiliation = "" if strpos(affiliation,"Joint senior authors") > 0
    replace affiliation = "" if affiliation == "."
    replace affiliation = "" if strpos(affiliation, "@")>0 & mi(institution)
    replace affiliation = "" if affiliation == "and."
    replace affiliation = "" if affiliation == "and"
    replace affiliation = "" if affiliation == "Universi"
    gen mi_affl = mi(affiliation)
    bys pmid which_athr: gen which_mi_affl = sum(mi_affl)
    drop if which_mi_affl > 1 & mi(filled) 
    drop which_mi_affl mi_affl
    // we don't want to count broad and HHMI if they are affiliated with other institutions. 
    bys pmid which_athr: gen athr_id = _n == 1
    bys pmid (which_athr): gen which_athr2 = sum(athr_id)
    drop which_athr athr_id
    rename which_athr2 which_athr
    bys pmid which_athr: gen num_affls = _N
    bys pmid which_athr: gen author_counter = _n == 1
    replace num_affls = . if num_affls == 1 & mi(affiliation)
    replace institution = "Broad" if strpos(affiliation, "Broad Institute of MIT and Harvard") > 0 | strpos(affiliation, "Broad Inst") > 0
    gen only_broad = num_affls == 1 & broad_affl == 1
    bys pmid which_athr: egen has_broad_affl = max(broad_affl)
    replace has_broad_affl = 0 if only_broad == 1
    drop if institution == "Broad" & only_broad == 0
    bys pmid which_athr: replace num_affls = _N
    cap rename hmmi_affl hhmi_affl
    replace hhmi_affl = 1 if strpos(affiliation, "Howard Hughes") > 0 | strpos(affiliation, "HHMI") > 0 

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
    cap drop _merge
    
    qui gen mi_affl = mi(affiliation)
    qui bys pmid: egen all_mi_affl = min(mi_affl)
    gunique pmid
    gunique pmid if all_mi_affl == 1
    qui drop if all_mi_affl == 1
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
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
    
    qui bys pmid: gen pmid_counter = _n == 1
    *qui rename institution inst
    gen inst = strlower(institution)
    replace inst = subinword(inst, "of", "",.)
    replace inst = subinword(inst, "a ofa", "",.)
    replace inst = subinword(inst, "de", "",.)
    replace inst = subinword(inst, "do", "",.)
    replace inst = subinword(inst, "fur", "",.)
    replace inst = subinword(inst, "for", "",.)
    replace inst = subinword(inst, "der", "",.)
    replace inst = subinword(inst, "in", "",.)
    replace inst = subinword(inst, "at", "",.)
    replace inst = subinword(inst, "foundation", "",.)
    replace inst = subinword(inst, "co", "",.)
    replace inst = subinstr(inst, " ltd", "",.)
    replace inst = subinstr(inst, " llc", "",.)
    replace inst = subinstr(inst, "  ", " ",.)
    replace inst = subinstr(inst, "-", "",.)
    replace inst = subinstr(inst, "+", "",.)
    replace inst = subinstr(inst, "'", "",.)
    replace inst = subinstr(inst, ",", "",.)
    replace inst = subinstr(inst, ".", "",.)
    replace inst = subinstr(inst, "xi an", "xian",.)
    replace inst = subinstr(inst, "universities", "university", .) 
    replace inst = subinstr(inst, "universitat", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universiteit", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universite", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universita", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universidade", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universidad", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universiti", "university", .) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "univeristy", "university",.) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "universisty", "university",.) if strpos(inst, "university") == 0
    replace inst = subinstr(inst, "hospitals", "hospital",.) 
    replace inst = subinstr(inst, "institutes", "institute",.) 
    replace inst = subinword(inst, "zentrum" , "center", .)
    replace inst = subinword(inst, "centre" , "center", .)
    replace inst = subinword(inst, "centro" , "center", .)
    gen uni = 1 if strpos(inst, "university") > 0
    replace inst = "university " + strtrim(subinstr(subinstr(inst, "university","",.), "  ", " ", .))  if uni == 1 
    replace inst = "chinese academy science" if inst == "university chinese academy science"
    replace inst = "eth zurich" if strpos(inst, "eth zurich")>0 
    replace inst = "eth zurich" if inst == "eth"
    replace inst = "ecole polytech federal lausanne" if (strpos(inst, "ecole polytech")> 0 & strpos(inst, "federal lausanne")>0) | inst == "epfl"
    replace inst = "european molecular biology lab" if inst == "embl"
    replace inst = "erasmus med center" if inst == "erasmus mc"
    replace inst = "fmi" if strpos(inst, "friedrich miescher institute biomed")>0
    replace inst = "genentech" if strpos(inst, "genentech")>0
    replace inst = "basel university" if strpos(inst, "univer")>0  & strpos(inst, "basel")>0
    replace inst = "zurich university" if (strpos(inst, "univer")>0  & strpos(inst, "zurich")>0) | strpos(inst, "uzh")>0 & country == "Switzerland"
    replace inst = "baylor university" if strpos(inst, "baylor")> 0 & strpos(inst, "university")>0
    replace inst = "university heidelberg" if strpos(inst, "heidelberg")> 0 & strpos(inst, "university")>0
    replace inst = "university heinrich heine" if strpos(inst, "heinrich heine")> 0 & strpos(inst, "university")>0
    replace inst = "university center hamburg" if strpos(inst, "center hamburg")> 0 & strpos(inst, "university")>0
    replace inst = "robert koch institute" if strpos(inst, "robert koch institute")>0 | strpos(inst, "kochinstitute")>0
    replace inst = "university munich" if inlist(inst, "university ludwig maximilians munchen") | (strpos(inst, "ludwig")>0&strpos(inst, "maxi")>0&strpos(inst, "university")>0)
    replace inst = "university tech munich" if inlist(inst, "university technische munchen")
    replace inst = "mt sinai" if strpos(inst, "sinai")>0 & (strpos(inst, "mount")>0|strpos(inst, "mt")>0)
    replace inst = "illumina" if strpos(inst, "illumina")>0 
    replace inst = "japan science and tech agency" if strpos(inst, "japan science and tech agency")>0 
    replace inst = "la jolla institute immunology" if strpos(inst, "la jolla institute immun")>0 
    replace inst = "massachusetts general hospital" if inlist(inst, "massachusetts gen hospital") 
    replace inst = "beth israel" if strpos(inst, "beth israel")>0 
    replace inst = "walter and eliza hall" if strpos(inst, "walter")>0 & strpos(inst, "eliza")>0 & country == "Australia"
    replace inst = subinword(inst, "munchen", "munich", .)
    replace inst = strtrim(subinstr(subinstr(inst, "hospital", "",.), "  ", " ", .)) if uni == 1 & strpos(inst, "hospital")>0
    replace inst = strtrim(subinstr(subinstr(inst, "med", "",.), "school","",.)) + " university" if strpos(inst, "med")>0 & strpos(inst, "school")>0 & strpos(inst, "university")==0
    replace inst = strtrim(subinstr(subinstr(inst, "med", "",.), "school","",.))  if strpos(inst, "med")>0 & strpos(inst, "school")>0 & strpos(inst, "university")>0
    replace inst = strtrim(subinstr(inst, "med", "",.))  if strpos(inst, "med")>0 & strpos(inst, "university")>0
    replace inst = "university washington st louis" if strpos(inst, "st louis") > 0 & strpos(inst, "university")>0
    replace inst = "10x genomics" if strpos(inst, "10x") > 0 & strpos(inst, "genom")>0
    replace inst = "23andme" if strpos(inst, "23andme")>0
    replace inst = "nasa" if strpos(inst, "nasa")> 0
    replace inst = "roche" if strpos(inst, "roche")> 0
    replace inst = "sanofi" if strpos(inst, "sanofi")> 0
    replace inst = "genetics" if strpos(inst, "genet")>0 & strpos(inst, "genetics")==0
    replace inst = "nih" if inlist(inst, "nci", "nhgri", "nhlbi")>0
    replace inst = "conicet" if strpos(inst, "conicet")>0 & country == "Argentina"
    replace inst = subinword(inst, "neurosci", "neuroscience",.) if strpos(inst, "neuroscience")==0
    replace inst = subinword(inst, "pathol", "pathology",.) if strpos(inst, "pathology")==0
    replace inst = subinword(inst, "department", "dept",.) 
    replace inst = subinword(inst, "anatomical", "anat",.) 
*    replace inst = subinstr(inst, substr(inst, strpos(inst, "hospital")+8, strlen(inst)),"",.) if strpos(inst, "hospital")>0
*    replace inst = subinstr(inst, substr(inst, strpos(inst, "university")+10, strlen(inst)),"",.) if strpos(inst, "university")>0 & strpos(inst, "university")!=1
    replace inst = subinstr(inst, substr(inst, strpos(inst, "lab")+3, strlen(inst)),"",.) if strpos(inst, "lab")>0
    replace inst = subinstr(inst, "university", " university",.) if strpos(inst, " university") ==0& strpos(inst, "university")!=1
    replace inst = subinstr(inst, "university", "university ",.) if strpos(inst, "university ") ==0& strpos(inst, "university")==1
    replace inst = subinstr(inst, "  ", " ",.)
    replace inst = strtrim(inst)
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
    preserve
    qui gcontract pmid 
    drop _freq
    qui save ../output/list_of_pmids_`data'_`samp', replace
    restore

    qui keep if inrange(date, td(01jan2015), td(31mar2022)) & year >=2015
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
