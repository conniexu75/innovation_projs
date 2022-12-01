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
    global city_country_name "world cities"
    global institution_name "institutions"
    global samp select_jrnl 
    qui get_total_articles
    foreach data in basic translational {
        avg_affiliations, data(`data')
    }
    foreach data in basic translational {
        top_jrnls, data(`data')
        athr_loc, data(`data')
        calc_broad_hhmi, data(`data')
        qui top_inst_trends, data(`data')
        qui top_mesh_terms, data(`data')
        qui output_tables, data(`data')
    }
    qui comp_basic_trans
end

program get_total_articles 
    use ../external/filtered/all_jrnl_articles_select_jrnl, clear
    *drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
    *drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279)
    save ../temp/all_jrnl_articles_select_jrnl, replace
*    use ../external/total/select_jrnls_pmids, clear
*    merge m:1 pmid using ../temp/all_jrnl_articles_select_jrnl, assert(1 3) keep(3) nogen
*    save ../temp/select_jrnls_pmids, replace

end

program avg_affiliations
    syntax, data(str)
    use ../external/samp/cleaned_all_`data'_${samp}, clear
    qui {
        merge m:1  pmid using ../external/filtered/all_jrnl_articles_select_jrnl, assert(1 2 3) keep(3) nogen
        merge m:1 pmid using ../external/total/select_jrnls_pmids, assert(2 3) keep(3) nogen
        *gen year = year(date)
        cap drop affil
        replace affiliation = strtrim(affiliation)
        replace affiliation = "" if affiliation == "The authors' affiliations are listed in the Appendix."
        replace affiliation = "" if affiliation == "."
        replace affiliation = "" if strpos(affiliation, "@")>0 & mi(institution)
        gen mi_affl = mi(affiliation)
        bys pmid which_athr: gen which_mi_affl = sum(mi_affl)
        drop if which_mi_affl > 1
        drop which_mi_affl mi_affl
        replace institution = "Novartis" if pmid == 28753431
        replace institution = "Bernhard-Nocht-Institute" if strpos(affiliation, "Bernhard") > 0 & strpos(affiliation, "Nocht")> 0 & strpos(affiliation, "Institute")>0

        foreach i in "Bundeswehr" "Irrua Specialist Teaching Hospital" "Bioqual" "Institute for Health Metrics and Evaluation" "National Institute of Public Health" "African Population and Health Research Center" ///
          "Chinese Center for Disease Control and Prevention" "London School of Hygiene & Tropical Medicine" "Alcohol, Drug Abuse, and Mental Health Administration" "Hopital Beaujon" ///
          "Institute for Research in Biomedicine" "St Bartholomew's Hospital" "Institute of Bioinformatics" "Basel Institute for Immunology" "Beijing Genomics Institute" "NHS Blood and Transplant" ///
          "Polyphor AG" "Denali Therapeutics" "Gustave Roussy Cancer Campus" "Lustgarten Foundation Pancreatic Cancer Research Laboratory" "BioNTech" "PTC Therapeutics" "deCODE Genetics" ///
          "Africa Health Research Institute" "German Center for Infection Research" "QIMR Berghofer Medical Research Institute" "Army Medical Research Institute of Infectious Diseases" "Biogen" ///
          "The Cancer Cell Map Initiative" "Guangdong Provincial Center for Disease Control and Prevention" "Neoleukin Therapeutics" "Beijing Proteome Research Center" "Sun Yat-sen University" ///
          "Academy for Scientific and Innovative Research" "Massachusetts Department of Public Health" "Chinese Academy of Medical Sciences" "BC Cancer" "Global Virus Network" "KiTZ" ///
          "Humanitas Clinical and Research Center" "Candiolo Cancer Institute" "Northwell Health" "National Centre for Disease Control" "Peter MacCallum Cancer Centre" "Cancer Cell Map Initiative"  ///
          "Peter MacCallum Cancer Centre" "Cancer Therapeutics CRC" "IRCCS" "Infinity Pharmaceuticals" "Oncology Institute of Southern Switzerland" ///
          "Walter and Eliza Hall Institute" "Guangdong Provincial Institution of Public Health" "Netherlands Cancer Institute" "Sinovac Biotech" "Sustainable Sciences Institute" "University of Torino" ///
          "Illumina" "innate Pharma" "Tel-Aviv University" "La Jolla Institute for Allergy and Immunology" "Kenema Government Hospital" "Public Health Scotland" "Commonwealth Scientific and Industrial Research Organisation" ///
          "Helmholtz Innovation Lab BaoBab" "National Centre for Infectious Diseases" "Persiaran Institusi" "Environment and Climate Change Canada" "Peking University" "Lunenfeld-Tanenbaum Research Institute" "INGM" "FLI" ///
          "Institut de Biologie Physico-Chimique" "Northeast Structural Genomics Consortium" "Community Research Advisors Group" "Salk Institute" "Isis Pharmaceuticals" "A*STAR Institute of Medical Biology" ///
          "AGIOS Pharmaceuticals" "AP-HP" "University and Hospital Trust of Verona" "Duke-NUS Medical School" "Acuitas Therapeutics" "Adaptive Biotechnologies" "Aeras" "Alliance International for Medical Action" ///
          "Almazov Federal Medical Research Centre" "BIOQUAL" "Baker Heart & Diabetes Institute" "Baylor Genetics" "Baylor Institute for Immunology Research" "Beijing Institute of Respiratory Medicine" ///
          "Beijing Key Laboratory of New Molecular Diagnostics Technology" "Capital Medical University" "Benaroya Research Institute" "Berlin Institute for Medical Systems Biology" ///
          "Max Delbrueck Center for Molecular Medicine" "23andMe" "Visterra Inc." "Vitalant Research Institute" "Tulane National Primate Research Center" "Aetna" "Tokyo Metropolitan Institute of Public Health" "Francis Crick Institute" ///
          "Argonne National Laboratory" "Washington State Department of Health" "Institute of Molecular Genetics of the Czech Academy of Sciences" "Centre Hospitalier Universitaire de Treichville and Treichville University Hospital" {
            replace institution = "`i'" if strpos(affiliation, "`i'")>0 & mi(institution)
        }
        replace institution = institution + " " + country if institution == "Ministry of Health" & !mi(country)
        replace institution = "Francis Crick Institute" if institution == "The Francis Crick Institute"
        replace institution = "University of North Carolina at Chapel Hill" if strpos(affiliation, "University of North Carolina")> 0
        replace institution = "NHS Blood and Transplant" if strpos(affiliation, "National Health Service Blood and Transplant")>0 & mi(institution)

        replace institution = "Chinese Academy of Medical Sciences" if strpos(affiliation, "Peking Union Medical College")>0
        replace institution = "Chinese Academy of Sciences" if strpos(affiliation, "Institute of Basic Medical Sciences")>0
        replace institution = "INSERM" if strpos(affiliation, "National Institute for Health and Medical Research")> 0
        replace institution = "University Medical Center Utrecht" if strpos(affiliation, "University Medical Centre Utrecht")> 0
        replace institution = "Tel Aviv University" if institution == "Tel-Aviv University"
        replace institution = "University College London" if strpos(affiliation, "UCL")>0 & mi(institution)
        replace institution = "University of Hamburg" if strpos(affiliation, "Universitatsklinikum Hamburg")>0 
        replace institution = "University of Munich" if strpos(affiliation, "LMU Munich")>0  & mi(institution)
        replace institution = "University of Munich" if strpos(affiliation, "Ludwig Maximilians University")>0 & mi(institution)
        replace institution = "University of Munich" if strpos(affiliation, "Ludwig-Maximilians Universitat")>0 & mi(institution)
        replace institution = "Peking University" if strpos(affiliation, "Peking")>0 & strpos(affiliation, "University")>0
        replace country = "China" if institution == "Peking University"
        replace city = "Beijing" if institution == "Peking University" 
        replace country = "China" if strpos(affiliation, "PRC") & mi(country)
        replace country = "China" if strpos(affiliation, "P.R.C.") & mi(country)
        replace city = "Beijing" if strpos(affiliation, "Beijing")>0 & country == "China"
        replace city = "Xi'an" if strpos(affiliation, "Xi'An")>0 & country == "China"
        replace city = "Xi'an" if strpos(affiliation, "Xi'an")>0 & country == "China"
        replace city = "Hong Kong" if strpos(affiliation, "Hong Kong")>0
        replace country = "China" if city == "Hong Kong"
        replace city = "Yunnan" if strpos(affiliation, "Yunnan")>0 & country == "China"
        replace city = "Shanghai" if strpos(affiliation, "Shanghai")>0 & country == "China"
        replace city = "Shandong" if strpos(affiliation, "Shandong")>0 & country == "China"
        replace city = "Guangdong" if strpos(affiliation, "Guangdong")>0 & country == "China"
        replace city = "Suzhou" if strpos(affiliation, "Suzhou")>0 & country == "China"
        replace city = "Xuzhou" if strpos(affiliation, "Xuzhou")>0 & country == "China"
        replace city = "Yangling" if strpos(affiliation, "Yangling")>0 & country == "China"
        replace city = "Sichaun" if strpos(affiliation, "Sichuan")>0 & country == "China"
        replace city = "Changchun" if strpos(affiliation, "Changchun")>0 & country == "China"
        replace country = "United Kingdom" if (strpos(affiliation, "London")>0 | strpos(affiliation, "Glasgow") > 0 | strpos(affiliation, "Liverpool")>0) & mi(country)
        replace city = "London" if strpos(affiliation, "London")>0 &country == "United Kingdom" 
        replace city = "Cambridge" if strpos(affiliation, "Cambridge")>0 & mi(city)         
        replace city = "DC" if strpos(affiliation, "DC")>0 & mi(city) & country == "United States"
        replace city = "Boston" if strpos(affiliation, "Boston")>0 & mi(city) & country == "United States"
        replace city = "Bethesda" if strpos(affiliation, "Bethesda")>0 & mi(city) & country == "United States"
        replace city = "Gig Harbor" if strpos(affiliation, "Gig Harbor")>0 & mi(city) & country == "United States"
        replace city = "Foster City" if strpos(affiliation, "Foster City")>0 & mi(city) & country == "United States"
        replace city = "New York" if strpos(affiliation, "NY")>0 & mi(city) & country == "United States"
        replace city = "Saint Louis" if strpos(affiliation, "St Louis")>0 & mi(city) & country == "United States"
        replace city = "Saint Paul" if strpos(affiliation, "St Paul")>0 & mi(city) & country == "United States"
        replace city = "Atlanta" if strpos(affiliation, "Atlanta")>0 & mi(city) & country == "United States"
        replace city = "Argonne" if strpos(affiliation, "Argonne")>0 & mi(city) & country == "United States"
        replace city = "Chapel Hill" if institution == "University of North Carolina at Chapel Hill" 
        replace city = "Moscow" if strpos(affiliation, "Moscow")>0 & mi(city) & country == "Russia"
        replace city = "Derio" if strpos(affiliation, "Derio")>0 & mi(city) & country == "Spain"
        replace city = "Glasgow" if strpos(affiliation, "Glasgow")>0 & mi(city) & country == "United Kingdom"
        replace city = "Tarrytown" if strpos(affiliation, "Tarrytown")>0 & mi(city) & country == "United States"
        gen is_lancet = strpos(affiliation, "The Lancet")>0
        gen is_london = (affiliation == "London." | affiliation == "London, UK.") & mi(institution) 
        gen is_bmj = (strpos(affiliation, "BMJ")>0| strpos(affiliation, "British Medical Journal")>0) & mi(institution)
        gen is_jama = strpos(affiliation, "JAMA.")>0
        gen is_editor = strpos(affiliation, "Associate Editor")>0
        bys pmid: egen has_lancet = max(is_lancet)
        bys pmid: egen has_london = max(is_london)
        bys pmid: egen has_bmj = max(is_bmj)
        bys pmid: egen has_jama = max(is_jama)
        bys pmid: egen has_editor = max(is_jama)
        preserve 
        drop if has_lancet == 1 | has_london == 1 | has_bmj == 1 | has_jama == 1 | has_editor == 1
        gcontract pmid
        drop _freq
        merge 1:1  pmid using ../temp/all_jrnl_articles_select_jrnl, assert(1 2 3) keep(2 3) nogen
        save ../temp/all_jrnl_articles_select_jrnl, replace
        merge 1:1 pmid using ../external/total/select_jrnls_pmids, assert(2 3) keep(3) nogen
        gcontract year journal_abbr, freq(num_articles)
        save ../temp/${samp}_counts, replace
        restore
        drop if has_lancet == 1 | has_london == 1 | has_bmj == 1 | has_jama == 1 | has_editor == 1
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
        /*replace institution = "Wellcome Genome Campus" if strpos(affiliation, "Wellcome Trust Sanger Institute")> 0 | strpos(affiliation, "Sanger Institute")>0
        replace institution = "Wellcome Genome Campus" if strpos(affiliation, "Genome Campus")> 0 & strpos(affiliation, "Wellcome")>0
        replace institution = "University of Cambridge" if strpos(affiliation, "University of Cambridge") > 0 
        replace institution = "University of Cambridge" if strpos(affiliation, "Wellcome Trust-MRC Cambridge Stem Cell Institute") > 0 
        replace institution = "University of Cambridge" if strpos(affiliation, "Wellcome Trust-Medical Research Council Cambridge Stem Cell Institute") > 0 
        replace institution = "University of Cambridge" if strpos(affiliation, "Wellcome Trust-MRC Institute of Metabolic Science") > 0 
        replace institution = "University of Edinburgh" if strpos(affiliation, "University of Edinburgh")>0
        replace institution = "University of Edinburgh" if strpos(affiliation, "Wellcome Trust Center for Cell Biology")>0
        replace institution = "University of Oxford" if strpos(affiliation, "University of Oxford")>0
        replace institution = "University of Oxford" if strpos(affiliation, "Wellcome Trust Centre for Human Genetics")>0
        replace institution = "University of Manchester" if strpos(affiliation, "University of Manchester")> 0
        replace institution = "University College London" if strpos(affiliation, "University College London")> 0
        replace institution = "Memorial Sloan-Kettering Cancer Center" if strpos(affiliation, "Sloan") > 0 & strpos(affiliation, "Kettering")>0 & mi(institution)
        replace institution = "Scripps Research Institute" if strpos(affiliation, "Scripps")>0 & strpos(affiliation, "Research")>0 & mi(institution)*/
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
    }
    bys pmid: gen pmid_counter = _n == 1
    qui save ../temp/cleaned_all_`data'_${samp}, replace
    preserve
    gcollapse (mean) num_athrs num_affls, by(year)
    tw line num_affls year, xlabel(1988(2)2022, angle(45) labsize(vsmall)) ytitle("Average Number of Affiliations per Author", size(small)) xtitle(Year, size(small)) ylabel(1(0.2)2, labsize(vsmall))
    qui graph export ../output/figures/avg_affls_overtime_`data'_${samp}.pdf, replace
    qui graph export ../output/figures/avg_affls_overtime_`data'_${samp}.png, replace
    tw line num_athrs year, xlabel(1988(2)2022, angle(45) labsize(vsmall)) ytitle("Average Number of Authors per Article", size(small)) xtitle(Year, size(small)) ylabel(0(5)50, labsize(vsmall))
    qui graph export ../output/figures/avg_athrs_overtime_`data'_${samp}.pdf, replace
    qui graph export ../output/figures/avg_athrs_overtime_`data'_${samp}.png, replace
    restore
    qui keep if inrange(date, td(01jan2015), td(31mar2022))
    cap drop _merge
    gunique pmid
    gunique pmid which_athr
    gunique pmid which_athr which_affiliation if !mi(affiliation)
    qui save ../temp/cleaned_last5yrs_`data'_${samp}, replace
    preserve
    qui gcontract pmid year
    drop _freq
    qui save ../temp/list_of_pmids_last5yrs_`data', replace
    restore
end

program top_jrnls
    syntax, data(str)
    use ../temp/cleaned_all_`data'_${samp}, clear
    preserve
    gcollapse (sum) pmid_counter, by(journal_abbr year)
    qui merge 1:1 journal_abbr year using ../temp/${samp}_counts, assert(1 2 3) keep(3) nogen
    gen percent_of_tot = pmid_counter/num_articles
    gcollapse (mean) avg_articles = pmid_counter avg_perc = percent_of_tot, by(journal_abbr)
    qui hashsort -avg_articles
    qui replace avg_perc = avg_perc * 100
    li 
    mkmat avg_articles avg_perc, mat(top_jrnls_`data')
    restore
end 

program athr_loc
    syntax, data(str)
    use ../temp/cleaned_last5yrs_`data'_${samp}, clear
    foreach loc in country us_state area city_country institution {
        qui gunique pmid //which_athr //if !mi(affiliation)
        qui sum affl_wt
        local total = round(r(sum))
        *local total = r(unique)
        qui sum affl_wt if !mi(`loc') 
        local denom = r(sum) 
        preserve
        if inlist("`loc'", "us_state", "area") {
            qui keep if country == "United States"
        }
        gcollapse (sum) affl_wt, by(`loc')
        qui hashsort -affl_wt 
        qui gen perc = affl_wt / `total' * 100
        li if mi(`loc')
        qui drop if mi(`loc')
        qui gen cum_perc = sum(perc) 
        li `loc' perc in 1/20
        mkmat affl_wt perc cum_perc in 1/20, mat(top_`loc')
        mat top_`loc'_`data' = top_`loc' \ (.,`total', .)
        qui levelsof `loc' in 1/2
        global top2_`loc'_`data' "`r(levels)'"
        if inlist("`loc'", "institution", "city_country") {
            qui levelsof `loc' in 1/20
            global `loc'_`data' "`r(levels)'"
        }
        qui gen cat = "first" if _n == 1
        qui levelsof `loc' if _n == 1
        global `loc'_first "`r(levels)'"
        qui levelsof `loc' if _n == 2
        global `loc'_second "`r(levels)'"
        qui replace cat = "second" if _n == 2
        qui replace cat = "rest of top 10" if inrange(_n,3,10)
        qui replace cat = "remaining" if mi(cat)
        keep `loc' cat
        qui save ../temp/`loc'_rank_`data'_${samp}, replace
        restore
    }
end

program calc_broad_hhmi
   syntax, data(str)
   use ../temp/cleaned_last5yrs_`data'_${samp}, clear
   qui gunique pmid which_athr
   local num_athrs = r(unique)
   qui gunique pmid which_athr if country == "United States"
   local num_athrs_US = r(unique)
   foreach i in broad hhmi {
       qui gunique pmid which_athr if has_`i'_affl == 1
       local num_`i' = r(unique)
       di `num_`i'' " authors of " `num_athrs' " are " "`i' affiliated or " `num_`i''/`num_athrs'*100 " percent"
       qui gunique pmid which_athr if has_`i'_affl == 1 & country == "United States"
       local num_`i'_US = r(unique)
       di `num_`i'_US' " US authors of " `num_athrs_US' " are " "`i' affiliated or " `num_`i'_US'/`num_athrs_US'*100 " percent"
       // hhmi has to be us
       preserve
       keep if country == "United States"
       qui gunique pmid which_athr if has_`i'_affl == 1 & institution == "Stanford University" 
       local num_`i'_stanford = r(unique)
       di `num_`i'_stanford' " stanford authors of " `num_`i'_US' " are " "`i' affiliated or " `num_`i'_stanford'/`num_`i'_US'*100 " percent"
       qui gunique pmid which_athr if has_`i'_affl == 1 & institution == "Harvard University" 
       local num_`i'_harvard = r(unique)
       di `num_`i'_harvard' " harvard authors of " `num_`i'_US' " are " "`i' affiliated or " `num_`i'_harvard'/`num_`i'_US'*100 " percent"
       restore
       if "`i'" == "broad" {
           preserve
           keep if inlist(institution, "Harvard University", "Massachusetts Institute of Technology", "Boston Children's Hospital", "Dana Farber Cancer Institute", "Massachusetts General Hospital", "Brigham and Women's Hospital", "Beth Israel Deaconess Medical Center")
           qui gunique pmid which_athr if has_`i'_affl == 1 
           local num_athrs_broad = r(unique)
           qui gunique pmid which_athr if has_`i'_affl == 1 & institution == "Harvard University" 
           local num_`i'_harvard = r(unique)
           di `num_`i'_harvard' " harvard authors of " `num_athrs_broad' " are " "`i' affiliated or " `num_`i'_harvard'/`num_athrs_broad'*100 " percent"
           qui gunique pmid which_athr if has_`i'_affl == 1 & institution == "Massachusetts Institute of Technology" 
           local num_`i'_mit= r(unique)
           di `num_`i'_mit' " mit authors of " `num_athrs_broad' " are " "`i' affiliated or " `num_`i'_mit'/`num_athrs_broad'*100 " percent"
           restore 
        }
    }
end

program top_inst_trends
    syntax, data(str)
    use ../temp/cleaned_all_`data'_${samp}, clear
    qui bys pmid year: gen counter = _n == 1
    qui bys year: egen tot_in_yr = total(counter)
    preserve
    keep if which_athr == 1
    qui replace affl_wt = 1/num_affls
    gcollapse (sum) affl_wt (mean) tot_in_yr, by(institution year)
    qui gen perc = affl_wt/tot_in_yr * 100
    keep if inlist(institution, "Harvard University", "Stanford University", "University of California, San Francisco", "NIH")
    tw  (line perc year if institution == "Harvard University") || ///
        (line perc year if institution == "University of California, San Francisco") || ///
        (line perc year if institution == "Stanford University") || ///
        (line perc year if institution == "NIH") , xlabel(1988(2)2022, labsize(small) angle(45)) xtitle("Year", size(small)) ytitle("% of output", size(small)) ylabel(0(1)5, labsize(vsmall)) ///
        legend(on ring(1) pos(6) rows(2) label(1 "Harvard") label(2 "UCSF") label(3 "Stanford") label(4 "NIH")) 
    qui graph export ../output/figures/trends1988_2022_`data'.pdf, replace
    qui graph export ../output/figures/trends1988_2022_`data'.png, replace
    restore

    foreach loc in country us_state area city_country institution {
        preserve
        qui merge m:1 `loc' using ../temp/`loc'_rank_`data'_${samp}, assert(1 3) keep(1 3) nogen
        qui egen year_bin  = cut(year),  at(1988 1990 1992 1994 1996 1998 2000 2002 2004 2006 2008 2010 2012 2014 2016 2018 2020 2022 2024)
        *qui egen year_bin = cut(year),  at(1988 1992 1996 2000 2004 2008 2012 2016 2020 2024) 
        keep if which_athr == 1
        qui replace affl_wt = 1/num_affls
        local year_var year_bin
        qui bys pmid `year_var': replace counter = _n == 1
        qui bys `year_var': egen tot_in_`year_var' = total(counter)
        qui replace cat = "remaining" if mi(cat)
        collapse (sum) affl_wt (mean) tot_in_`year_var' (firstnm) `loc' , by(cat `year_var')
        qui gen perc = affl_wt/tot_in_`year_var' * 100
        qui bys `year_var': egen tot = sum(perc)
        qui replace tot = round(tot)
        assert tot==100
        qui drop tot
        label define cat 1 ${`loc'_first} 2 ${`loc'_second} 3 "Rest of the top 10 ${`loc'_name}" 4 "Remaining places"
        label var cat cat
        qui gen group = 1 if cat == "first"
        qui replace group = 2 if cat == "second"
        qui replace group = 3 if cat == "rest of top 10" 
        qui replace group = 4 if cat == "remaining"
        qui hashsort `year_var' -group
        qui bys `year_var': gen stack_perc = sum(perc)
        keep cat `year_var' `loc' perc group stack_perc
        local stacklines
        qui xtset group `year_var' 
        qui levelsof group, local(cats)
        local items = `r(r)'
        foreach x of local cats {
           colorpalette HTML purple, n(`items') nograph
           local stacklines `stacklines' area stack_perc `year_var' if group == `x', fcolor("`r(p`x')'") lcolor(black) lwidth(*0.2) || 
        }
        qui gen labely = . 
        qui gen rev_group = -group
        qui bys `year_var' (rev_group): replace labely = perc / 2 if group == 4
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] if group == 3
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 2
        qui bys `year_var' (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] if group == 1
        qui gen labely_lab = "Everywhere else" if group == 4
        qui replace labely_lab = "Rest of the top 10 ${`loc'_name}" if group == 3
        qui replace labely_lab = ${`loc'_second} if group == 2
        qui replace labely_lab = ${`loc'_first} if group == 1
        qui replace labely_lab = subinstr(labely_lab, "United States", "US", .)
        qui replace labely_lab = subinstr(labely_lab, "United Kingdom", "UK", .)
        graph tw `stacklines' (scatter labely `year_var' if `year_var' ==2022, ms(smcircle) ///
          msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
          ytitle("Percent of Published Papers", size(small)) xtitle("Year", size(small)) xlabel(1988(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
          graphregion(margin(r+25)) plotregion(margin(zero)) ///
          legend(off label(1 ${`loc'_first}) label(2 ${`loc'_second}) label(3 "Rest of the top 10 ${`loc'_name}") label(4 "Remaining places") ring(1) pos(6) rows(2))
        qui graph export ../output/figures/`loc'_stacked_`data'_${samp}.pdf, replace
        qui graph export ../output/figures/`loc'_stacked_`data'_${samp}.png, replace
        restore
    }
end 

program comp_basic_trans
    foreach type in city_country institution {
        global top_20 : list global(`type'_basic) | global(`type'_translational)
        use ../temp/cleaned_last5yrs_basic_${samp}, clear
        gen type = "basic"
        append using ../temp/cleaned_last5yrs_translational_${samp}
        replace type = "translational" if mi(type)
        gen to_keep = 0
        foreach i of global top_20 {
            replace to_keep = 1 if `type' == "`i'" 
        }
        gcollapse (sum) affl_wt (mean) to_keep, by(`type' type)
        drop if mi(`type')

        hashsort type -affl_wt
        by type: gen rank = _n 
        keep if to_keep == 1
        qui sum rank
        local rank_lmt = r(max) 
        reshape wide affl_wt rank, i(`type') j(type) string
        gen onebasic = _n
        gen onetranslational = _n 
        // institution labels
        cap replace institution = "CalTech" if institution == "California Institute of Technology"
        cap replace institution = "CDC" if institution == "Centers for Disease Control and Prevention"
        cap replace institution = "Columbia" if institution == "Columbia University"
        cap replace institution = "Cornell" if institution == "Cornell University"
        cap replace institution = "Duke" if institution == "Duke University"
        cap replace institution = "Harvard" if institution == "Harvard University"
        cap replace institution = "JHU" if institution == "Johns Hopkins University"
        cap replace institution = "Rockefeller Univ." if institution == "The Rockefeller University"
        cap replace institution = "MIT" if institution == "Massachusetts Institute of Technology"
        cap replace institution = "Memorial Sloan" if institution == "Memorial Sloan-Kettering Cancer Center"
        cap replace institution = "NYU" if institution == "New York University"
        cap replace institution = "Stanford" if institution == "Stanford University"
        cap replace institution = "UCL" if institution == "University College London"
        cap replace institution = "UC Berkeley" if institution == "University of California, Berkeley"
        cap replace institution = "UCLA" if institution == "University of California, Los Angeles"
        cap replace institution = "UCSD" if institution == "University of California, San Diego"
        cap replace institution = "UCSF" if institution == "University of California, San Francisco"
        cap replace institution = "UChicago" if institution == "University of Chicago"
        cap replace institution = "UMich" if institution == "University of Michigan"
        cap replace institution = "UPenn" if institution == "University of Pennsylvania"
        cap replace institution = "Yale" if institution == "Yale University"
        cap replace institution = "Wash U" if institution == "Washington University in St. Louis"

        // cities
        cap replace city_country = subinstr(city_country, "United States", "US",.)
        cap replace city_country = subinstr(city_country, "United Kingdom", "UK",.)
        local lmt = 20
        gen lab = `type' if rankbasic <= `lmt' | ranktranslational<= `lmt'
        egen clock = mlabvpos(rankbasic ranktranslational)
        cap replace clock = 4 if city_country == "Los Angeles, US"
        cap replace clock = 11 if institution == "University of Cambridge"
        local rank_lmt = 20
        tw scatter rankbasic ranktranslational if inrange(rankbasic , 1,`rank_lmt') & inrange(ranktranslational ,1,`rank_lmt'), ///
          mlabel(lab) mlabsize(vsmall) mlabcolor(black) mlabvp(clock) || ///
          (line onebasic onetranslational if onebasic <= `rank_lmt', lpattern(dash) lcolor(lavender)), ///
          xtitle("Translational Science Output Rank", size(small)) ytitle("Basic Science Output Rank", size(small)) ///
          xlabel(1(1)`rank_lmt', labsize(vsmall)) ylabel(1(1)`rank_lmt', labsize(vsmall)) xsc(reverse) ysc(reverse) legend(off)
        graph export ../output/figures/bt_`type'_scatter.pdf, replace
        graph export ../output/figures/bt_`type'_scatter.png, replace
    }
end
    
program top_mesh_terms
    syntax, data(str)
    use ../external/samp/major_mesh_terms_`data'_${samp}.dta, clear
    qui merge m:1  pmid using ../external/samp/jrnl_articles_`data', assert(1 2 3) keep(3) nogen
    qui merge m:1 pmid using ../temp/list_of_pmids_last5yrs_`data', keep(3) nogen
    qui gunique pmid
    local total_articles = r(unique)
    qui replace mesh = subinstr(mesh, "=Y>","",.)
    qui replace mesh = subinstr(mesh, "=N>","",.)
    qui gen gen_mesh = mesh if strpos(mesh, ",") == 0 & strpos(mesh, ";") == 0
    qui replace gen_mesh = mesh if strpos(mesh, "Models") > 0
    qui replace gen_mesh = subinstr(gen_mesh, "&; ", "&",.)
    qui gen rev_mesh = reverse(mesh)
    qui replace rev_mesh = substr(rev_mesh, strpos(rev_mesh, ",")+1, strlen(rev_mesh)-strpos(rev_mesh, ","))
    qui replace rev_mesh = reverse(rev_mesh)
    qui replace gen_mesh = rev_mesh if mi(gen_mesh) 
    qui drop rev_mesh
    preserve
    qui gcontract pmid mesh, nomiss
    qui save ../temp/contracted_mesh_`data', replace
    restore
    gcontract pmid gen_mesh, nomiss
    qui save ../temp/contracted_gen_mesh_`data', replace

    foreach mesh in mesh gen_mesh {
        use ../temp/contracted_`mesh'_`data', clear
        qui bys pmid: gen wt = 1/_N
        qui bys pmid: gen num_`mesh' = _N
        sum num_`mesh'
        cap drop _freq
        gcollapse (sum) article_wt = wt , by(`mesh')
        qui hashsort -article_wt
        qui gen perc = article_wt/`total_articles'*100
        qui gen cum_perc = sum(perc) 
        qui sum article_wt
        local total = round(r(sum))
        li in 1/20
        mkmat article_wt perc cum_perc in 1/20, mat(top_`mesh')
        mat top_`mesh'_`data' = top_`mesh' \ (.,`total', .)
        qui levelsof `mesh' in 1/3, local(`mesh'_terms_`data')
        qui gen rank = _n
        qui replace rank = 4 if rank > 3
        qui replace `mesh' = "other" if rank == 4
        qui gen institution = "total"
        gcollapse (sum) article_wt perc cum_perc, by(institution `mesh' rank)
        drop rank
        qui save ../temp/`mesh'_`data', replace
        
        use ../temp/cleaned_last5yrs_`data'_${samp}, clear
        gcollapse (sum) affl_wt , by(pmid institution)
        qui joinby pmid using ../temp/contracted_`mesh'_`data'
        qui bys pmid institution : gen num_`mesh' = _N
        qui gen article_wt = affl_wt * 1/num_`mesh'
        qui keep if inlist(institution, "Harvard University", "Stanford University", "University of California, San Francisco", "NIH")
        gen keep_`mesh' = 0
        foreach m in ``mesh'_terms_`data'' {
            qui replace keep_`mesh' = 1 if `mesh' == "`m'"
        }
        qui replace `mesh' = "other" if keep_`mesh' == 0
        gcollapse (sum) article_wt , by(institution `mesh')
        qui bys institution : egen tot = total(article_wt)
        qui hashsort institution -article_wt
        gen perc = article_wt/tot
        gen cum_perc = sum(perc)
        drop tot
        append using ../temp/`mesh'_`data'
        qui save ../temp/`mesh'_`data', replace
    }
end

program output_tables
    syntax, data(str)
    foreach file in top_jrnls top_country top_us_state top_area top_city_country top_institution top_mesh top_gen_mesh {
        qui matrix_to_txt, saving("../output/tables/`file'_`data'.txt") matrix(`file'_`data') ///
           title(<tab:`file'_`data'>) format(%20.4f) replace
         }
 end
** 
main
