set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/clean_athr_inst_hist"

program main
    *append
    *merge_geo
    clean_panel
end
program append
    qui {
        forval i = 1/10966 {
            import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
            gen year = substr(pub_date, 1,4)
            destring year, replace
            gcontract athr_id  year inst_id, freq(num_times)
            drop if mi(inst_id)
            fmerge m:1 athr_id using ../external/athrs/list_of_athrs, assert(1 2 3) keep(3) nogen
            save ${temp}/ppr`i', replace
        }
    }
    clear
    forval i = 1/10966 {
        append using ${temp}/ppr`i'
    }
    gcollapse (sum) num_times, by(athr_id inst_id year)
    drop if athr_id == "A9999999999"
    save ${temp}/appended_pprs, replace
end

program merge_geo
    forval i = 1/17 {
        import delimited ../external/pprs/inst_geo_chars`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
        compress, nocoalesce
        save ${temp}/inst_geo_chars`i', replace
    }
    clear
    count
    forval i = 1/17 {
        di "`i'"
        append using ${temp}/inst_geo_chars`i'
        count
    }
    bys inst_id: egen has_parent = max(associated_rel == "parent")
    bys inst_id: gen num = _N 
    keep if has_parent == 0  | (has_parent == 1 & associated_rel == "parent" ) | num == 1
    ds associated* 
    foreach var in `r(varlist)' {
        replace `var' = "" if has_parent == 0
        replace `var' = "" if (strpos(associated, "University")>0 & strpos(associated, "System")>0 & associated_type == "education" & (type == "education" | type == "healthcare")) | inlist(associated, "University of London", "Wellcome Trust") | (strpos(associated, "Health")>0 & strpos(associated, "System")>0 & associated_type == "healthcare" & (type == "education" | type == "healthcare")) | (strpos(associated, "Higher")>0 & strpos(associated, "Education")>0 & associated_type == "education" & (type == "education" | type == "healthcare")) | strpos(associated, "Ministry of") > 0 | strpos(associated, "Board of")>0 | strpos(associated, "Government of")>0 | (strpos(associated, "Department of")>0 & country != "Russia")
        replace `var' = "" if country_code != associated_country
    }
    gduplicates drop inst_id associated_id, force
    replace inst = associated if strpos(associated, "University")>0 & strpos(associated, "System")>0 & associated_type == "education" & (type != "education" & type != "healthcare")
    replace inst = associated if inlist(associated, "Chinese Academy of Sciences", "Spanish National Research Council", "Max Planck Society", "National Research Council", "National Institutes of Health", "Harvard University")
    replace inst = associated if inlist(associated, "Leibniz Association", "Aix-Marseille University", "Indian Council of Agricultural Research", "Inserm", "Polish Academy of Sciences", "National Research Institute for Agriculture, Food and Environment") 
    replace inst = associated if inlist(associated, "Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions")
    replace inst = associated if inlist(associated, "Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
    replace inst = associated if inlist(associated, "French National Centre for Scientific Research")
    replace inst = associated if inlist(associated, "Fraunhofer Society", "Istituti di Ricovero e Cura a Carattere Scientifico",  "Claude Bernard University Lyon 1", "Atomic Energy and Alternative Energies Commission", "Japanese Red Cross Society, Japan") 
    replace inst = associated if inlist(associated, "Islamic Azad University, Tehran", "National Oceanic and Atmospheric Administratio", "French Institute for Research in Computer Science and Automation", "National Academy of Sciences of Ukraine", "National Institute for Nuclear Physics", "Assistance Publique – Hôpitaux de Paris") 
    replace inst = associated if inlist(associated, "Medical Research Council", "National Institute for Health Research", "Academia Sinica", "National Scientific and Technical Research Council","Czech Academy of Sciences", "Commonwealth Scientific and Industrial Research Organisation")
    replace inst = associated if inlist(associated, "Slovak Academy of Sciences", "Indian Council of Medical Research", "Council of Scientific and Industrial Research", "National Institute for Astrophysics", "Bulgarian Academy of Sciences", "Centers for Disease Control and Prevention", "National Institute of Technology")
    replace inst = associated if inlist(associated, "Helmholtz Association of German Research Centres", "Helios Kliniken", "Shriners Hospitals for Children", "Hungarian Academy of Sciences", "National Agriculture and Food Research Organization", "Australian Research Council")
    replace inst = associated if inlist(associated, "Agro ParisTech", "Veterans Health Administration", "Institut de Recherche pour le Développement", "Austrian Academy of Sciences", "Institutos Nacionais de Ciência e Tecnologia", "Chinese Academy of Forestry", "Chinese Academy of Tropical Agricultural Sciences")
    replace inst = associated if inlist(associated, "Instituto de Salud Carlos III", "National Aeronautics and Space Administration", "Ludwig Boltzmann Gesellschaft", "United States Air Force", "Centre Nouvelle Aquitaine-Bordeaux", "RIKEN", "Agricultural Research Council")
    replace inst = associated if inlist(associated, "Centro Científico Tecnológico - La Plata", "National Research Council Canada", "Royal Netherlands Academy of Arts and Sciences","Defence Research and Development Organisation", "Canadian Institutes of Health Research", "Italian Institute of Technology", "United Nations University")
    replace inst = associated if inlist(associated, "IBM Research - Thomas J. Watson Research Center", "Délégation Ile-de-France Sud","Grenoble Institute of Technology", "François Rabelais University", "Chinese Academy of Social Sciences", "National Science Foundation" , "Federal University of Toulouse Midi-Pyearénées")
    replace inst = associated if inlist(associated, "Chinese Center For Disease Control and Prevention", "Johns Hopkins Medicine", "Cancer Research UK", "Centre Hospitalier Universitaire de Bordeaux", "Puglia Salute", "Hospices Civils de Lyon", "Ministry of Science and Technology", "Servicio de Salud de Castilla La Mancha")
    replace inst = associated if inlist(associated, "Grenoble Alpes University","Arts et Metiers Institute of Technology", "University of Paris-Saclay", "Biomedical Research Council", "Senckenberg Society for Nature Research", "Centre Hospitalier Régional et Universitaire de Lille", "Schön Klinik Roseneck", "ESPCI Paris")
    replace inst = associated if inlist(associated, "National Academy of Sciences of Armenia", "University of the Philippines System", "Madrid Institute for Advanced Studies", "CGIAR", "Ministry of Science, Technology and Innovation", "Institut Polytechnique de Bordeaux")

    replace inst = associated if inlist(associated, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") & country == "Russia"
    replace inst = associated if inlist(associated, "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences") & country == "Russia" 
    replace inst = associated if inlist(associated, "Russian Academy")
    replace inst = associated if strpos(associated, "Agricultural Research Service -")>0
    // merge national institutions together
    replace associated = "French National Centre for Scientific Research" if inlist(inst,"Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions") | inlist(inst,"Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
    replace associated_id = "I1294671590" if associated =="French National Centre for Scientific Research"
    replace associated = "Russian Academy" if inlist(inst, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") | inlist(inst, "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences")
    replace associated_id = "I1313323035" if associated == "Russian Academy"
    replace associated  = "Agricultural Research Service" if strpos(inst, "Agricultural Research Service - ")>0
    replace associated_id = "I1312222531" if inst == "Agricultural Research Service"
    replace associated  = "Max Planck Society" if strpos(inst, "Max Planck")>0
    replace associated = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    replace associated_id = "I4210166203" if associated == "Max Planck Society"
    replace inst = "Johns Hopkins University" if strpos(inst, "Johns Hopkins")>0
    replace associated = "Johns Hopkins University" if strpos(associated, "Johns Hopkins")>0
    replace associated_id = "I145311948" if associated == "Johns Hopkins University"
    replace inst = "Stanford University" if inlist(inst, "Stanford Medicine", "Stanford Health Care")
    replace associated = "Stanford University" if inlist(associated, "Stanford Medicine", "Stanford Health Care")
    replace inst = "Northwestern University" if inlist(inst, "Northwestern Medicine")
    replace associated = "Northwestern University" if inlist(inst, "Northwestern Medicine")
    replace associated = "Harvard University" if inlist(inst, "Harvard Global Health Institute", "Harvard Pilgrim Health Care", "Harvard Affiliated Emergency Medicine Residency", "Harvard NeuroDiscovery Center")
    replace inst = subinstr(inst, " Health System", "", .) if strpos(inst, " Health System")>0 & (strpos(inst, "University")>0 | strpos(inst, "UC")>0)
    replace inst = subinstr(inst, " Medical System", "", .) if strpos(inst, " Medical System")>0 & (strpos(inst, "University")>0 | strpos(inst, "UC")>0)
    gduplicates drop inst_id, force
    rename associated new_inst
    rename associated_id new_id
    keep inst_id new_inst new_id region city country country_code type inst
    drop if mi(inst_id) 
    save ${temp}/all_inst_chars, replace
end 

program clean_panel
    use ${temp}/appended_pprs, clear
    gunique athr_id year
    local N = r(unique)
    fmerge m:1 inst_id using ${temp}/all_inst_chars, assert(2 3) keep(3) nogen
    replace inst_id = new_id if !mi(new_inst)
    replace inst = new_inst if !mi(new_inst)
    gduplicates tag athr_id inst_id year, gen(dup_entry)
    bys athr_id inst_id year: egen tot_times = sum(num_times) 
    replace num_times = tot_times
    drop if dup_entry > 0 & mi(new_inst)
    drop new_inst new_id dup_entry tot_times type
    gsort athr_id inst_id year country city
    gduplicates drop athr_id inst_id year, force
    // keep inst with the largest num_times in a year
    bys athr_id year: egen max_num_times = max(num_times)
    drop if num_times != max_num_times
    drop max_num_times
    
    // imputation process
    foreach loc in inst city country {
        cap drop has_mult same_as_after same_as_before has_before has_after
        // if there are mult in a year but sandwiched by the same, then choose that one 
        bys athr_id year: gen has_mult = _N > 1
        bys athr_id `loc' (year): gen same_as_after = year[_n+1]-year <= 3 & has_mult[_n+1]==0
        bys athr_id `loc' (year): gen same_as_before = year - year[_n-1] <= 3  & has_mult[_n-1]==0
        gen sandwiched = has_mult == 1 & same_as_after == 1 & same_as_before == 1
        bys athr_id year: egen has_sandwich = max(sandwiched)
        drop if has_sandwich ==1 & sandwiched == 0
        drop sandwiched has_sandwich
        bys athr_id year: replace has_mult = _N > 1
       
        // now we prioritize the year before
        bys athr_id `loc' (year): replace same_as_after = year[_n+1]-year <= 3 & has_mult[_n+1]==0
        bys athr_id `loc' (year): replace same_as_before = year - year[_n-1] <= 3  & has_mult[_n-1]==0
        bys athr_id year: egen has_before = max(same_as_before)
        drop if has_mult == 1 & has_before == 1 & same_as_before == 0
        bys athr_id year: replace has_mult = _N > 1
        // now do same for the year after 
        bys athr_id `loc' (year): replace same_as_after = year[_n+1]-year <= 3 & has_mult[_n+1]==0
        bys athr_id `loc' (year): replace same_as_before = year - year[_n-1] <= 3  & has_mult[_n-1]==0
        bys athr_id year: egen has_after = max(same_as_after)
        drop if has_mult == 1 & has_after == 1 & same_as_after == 0
        bys athr_id year: replace has_mult = _N > 1
    }

    // if there are sandwiched insts no mater what the year gap is
    hashsort athr_id year
    gen prev_inst = inst_id[_n-1]
    gen post_inst = inst_id[_n+1]
    gen sandwich = prev_inst == post_inst & prev_inst != inst_id if athr_id[_n-1] == athr_id[_n+1] & athr[_n-1] == athr_id
    replace inst_id = prev_inst if sandwich == 1
    replace inst = inst[_n-1] if sandwich == 1
    drop sandwich
    bys athr_id: egen modal_inst = mode(inst_id)
    bys athr_id year: replace has_mult = _N > 1
    gen mode_match = inst_id == modal_inst
    bys athr_id year: egen has_mode_match = max(mode_match)
    drop if has_mult == 1 & has_mode_match == 1 & mode_match == 0
    gen rand = rnormal(0,1)
    gsort athr_id year rand
    gduplicates drop athr_id year, force
    gisid athr_id year
    gunique athr_id year
    assert r(unique) == `N'
    keep athr_id inst_id year num_times inst country_code country city region

    // do some final cleaning
    drop if !inrange(year, 1945, 2023)
    save ../output/athr_panel, replace
    import delimited using ../external/geo/us_cities_states_counties.csv, clear varnames(1)
    gcontract stateshort statefull
    drop _freq
    drop if mi(stateshort)
    rename statefull region
    merge 1:m region using ../output/athr_panel, assert(1 2 3) keep(2 3) nogen
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
    replace msa_c_world = city + ", " + country_code if country_code != "US" & !mi(city) & !mi(country_code)
    compress, nocoalesce
    save ../output/athr_panel, replace

    replace athr_id = subinstr(athr_id, "A", "", .)
    destring athr_id, replace
    tsset athr_id year
    tsfill
    foreach var in inst_id inst country_code country city region msacode msa_comb msa_c_world msatitle {
        bys athr_id (year): replace  `var' = `var'[_n-1] if mi(`var') & !mi(`var'[_n-1])
    }
    tostring athr_id, replace
    replace athr_id = "A" + athr_id
    compress, nocoalesce
    save ../output/filled_in_panel, replace
end

main
