set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/clean_openalex"

program main
    local samp all_jrnls
    local samp clin_med
    aggregate_insts
    foreach samp in all_jrnls clin_med {
        clean_titles, samp(`samp')
        clean_samps, samp(`samp')
        clean_mesh, samp(`samp')
    }
    split_sample
end

program aggregate_insts
    clear
    forval i = 1/7 {
        append using ../external/openalex/inst_geo_chars`i'
    }
    bys inst_id: egen has_parent = max(associated_rel == "parent")
    keep if has_parent == 0 | (has_parent == 1 & associated_rel == "parent")
    ds associated* 
    foreach var in `r(varlist)' {
        replace `var' = "" if has_parent == 0
    }
    gduplicates drop inst_id associated_id, force
    replace inst = associated if strpos(associated, "University")>0 & strpos(associated, "System")>0 & associated_type == "education" & type != "education"
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
    replace inst = associated if inlist(associated, "Agro ParisTech", "Veterans Health Administration", "Institut de Recherche pour le Développement", "Austrian Academy of Sciences", "Institutos Nacionais de Ciência e Tecnologia", "Chinese Academy of Forestry", "hinese Academy of Tropical Agricultural Sciences")
    replace inst = associated if inlist(associated, "Instituto de Salud Carlos III", "National Aeronautics and Space Administration", "Ludwig Boltzmann Gesellschaft", "United States Air Force", "Centre Nouvelle Aquitaine-Bordeaux", "RIKEN", "Agricultural Research Council")
    replace inst = associated if inlist(associated, "Centro Científico Tecnológico - La Plata", "National Research Council Canada", "Royal Netherlands Academy of Arts and Sciences","Defence Research and Development Organisation", "Canadian Institutes of Health Research", "Italian Institute of Technology", "United Nations University")
    replace inst = associated if inlist(associated, "IBM Research - Thomas J. Watson Research Center", "Délégation Ile-de-France Sud","Grenoble Institute of Technology", "François Rabelais University", "Chinese Academy of Social Sciences", "National Science Foundation" , "Federal University of Toulouse Midi-Pyrénées")
    replace inst = associated if inlist(associated, "Chinese Center For Disease Control and Prevention", "Johns Hopkins Medicine", "Cancer Research UK", "Centre Hospitalier Universitaire de Bordeaux", "Puglia Salute", "Hospices Civils de Lyon", "Ministry of Science and Technology", "Servicio de Salud de Castilla La Mancha")
    replace inst = associated if inlist(associated, "Grenoble Alpes University","Arts et Metiers Institute of Technology", "University of Paris-Saclay", "Biomedical Research Council", "Senckenberg Society for Nature Research", "Centre Hospitalier Régional et Universitaire de Lille", "Schön Klinik Roseneck", "ESPCI Paris")
    replace inst = associated if inlist(associated, "National Academy of Sciences of Armenia", "University of the Philippines System", "Madrid Institute for Advanced Studies", "CGIAR", "Ministry of Science, Technology and Innovation", "Institut Polytechnique de Bordeaux")

    replace inst = associated if inlist(associated, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") & country == "Russia"
    replace inst = associated if inlist(associated, "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences") & country == "Russia" 
    replace inst = associated if inlist(associated, "Russian Academy")
    replace inst = associated if strpos(associated, "Agricultural Research Service -")>0
    // merge national institutions together
    replace inst = "French National Centre for Scientific Research" if inlist(inst,"Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions") | inlist(inst,"Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
    replace associated_id = "I1294671590" if inst=="French National Centre for Scientific Research"
    replace inst = "Russian Academy" if inlist(inst, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") | inlist(inst, "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences")
    replace associated_id = "I1313323035" if inst == "Russian Academy"
    replace inst = "Agricultural Research Service" if strpos(inst, "Agricultural Research Service - ")>0
    replace associated_id = "I1312222531" if inst == "Agricultural Research Service"
    replace inst = "Max Planck Society" if strpos(inst, "Max Planck")>0
    replace inst = "Johns Hopkins University" if strpos(inst, "Johns Hopkins")>0
    replace inst = "Stanford University" if inlist(inst, "Stanford Medicine", "Stanford Health Care")
    replace inst = subinstr(inst, " Health System", "", .) if strpos(inst, " Health System")>0 & (strpos(inst, "University")>0 | strpos(inst, "UC")>0)
    replace inst = subinstr(inst, " Medical System", "", .) if strpos(inst, " Medical System")>0 & (strpos(inst, "University")>0 | strpos(inst, "UC")>0)
    gduplicates drop inst_id, force
    rename inst new_inst
    rename associated_id new_id
    keep inst_id new_inst new_id region city country country_code type
    drop if mi(inst_id) | mi(new_id)
    save ../output/all_inst_geo_chars, replace
end

program clean_titles
    syntax, samp(str)
    use pmid title id pub_type using ../external/openalex/openalex_`samp'_merged, clear
    keep if pub_type == "journal-article"
    replace title = stritrim(title)
    contract title id pmid
    gduplicates drop pmid, force
    drop _freq
    gisid pmid
    if "`samp'" == "all_jrnls" {
        merge 1:1 pmid using ../external/pmids_jrnl/newfund_pmids, keep(3) nogen keepusing(pmid journal_abbr)
    }
    if "`samp'" == "clin_med" {
        merge 1:1 pmid using ../external/pmids_jrnl/med_all_pmids, keep(3) nogen keepusing(pmid journal_abbr)
    }
    gen lower_title = strlower(title)
    drop if mi(title)
    drop if strpos(lower_title, "economic")>0
    drop if strpos(lower_title, "economy")>0
    drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
    drop if strpos(lower_title, "public health")>0
    drop if strpos(lower_title, "hallmarks")>0
    drop if strpos(lower_title, "government")>0
    drop if strpos(lower_title, "reform")>0
    *drop if strpos(lower_title , "quality")>0
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
    *drop if strpos(lower_title , " regulation")>0
    drop if strpos(lower_title , "the editor")>0
    drop if strpos(lower_title , "response : ")>0
    drop if strpos(lower_title , "letters")>0
    drop if lower_title == "response"
    drop if strpos(lower_title , "this week")>0
    drop if strpos(lower_title , "notes")>0
    drop if strpos(lower_title , "news ")>0
    drop if strpos(lower_title , "a note")>0
    drop if strpos(lower_title , "obituary")>0
    drop if strpos(lower_title , "review")>0
    *jdrop if strpos(lower_title , "women")>0
    drop if strpos(lower_title , "perspectives")>0
    drop if strpos(lower_title , "scientists")>0
    drop if strpos(lower_title , "books")>0
    drop if strpos(lower_title , "institution")>0
    drop if strpos(lower_title , "meeting")>0
    drop if strpos(lower_title , "university")>0
    drop if strpos(lower_title , "universities")>0
    drop if strpos(lower_title , "journals")>0
    drop if strpos(lower_title , "publication")>0
    drop if strpos(lower_title , "recent ")>0
    drop if strpos(lower_title , "costs")>0
    drop if strpos(lower_title , "challenges")>0
    drop if strpos(lower_title , "researchers")>0
    *drop if strpos(lower_title , "research")>0
    drop if strpos(lower_title , "perspective")>0
    drop if strpos(lower_title , "reply")>0
    drop if strpos(lower_title , " war")>0
    drop if strpos(lower_title , " news")>0
    drop if strpos(lower_title , "a correction")>0
    drop if strpos(lower_title , "academia")>0
    drop if strpos(lower_title , "society")>0
    drop if strpos(lower_title , "academy of")>0
    drop if strpos(lower_title , "nomenclature")>0
    drop if strpos(lower_title , "teaching")>0
    drop if strpos(lower_title , "education")>0
    drop if strpos(lower_title , "college")>0
    drop if strpos(lower_title , "academics")>0
    drop if strpos(lower_title , "political")>0
    drop if strpos(lower_title , "association for")>0
    drop if strpos(lower_title , "association of")>0
    drop if strpos(lower_title , "nuts")>0 & strpos(lower_title, "bolts")>0
    drop if strpos(lower_title , "response by")>0
    drop if strpos(lower_title , "societies")>0
    drop if strpos(lower_title, "health care")>0
    drop if strpos(lower_title, "health-care")>0
    drop if strpos(lower_title , "abstracts")>0
    drop if strpos(lower_title , "journal club")>0
    drop if strpos(lower_title , "curriculum")>0
/*    preserve
    contract lower_title journal_abbr  pmid
    gduplicates tag lower_title journal_abbr, gen(dup)
    keep if dup> 1
    drop _freq dup
    contract lower_title
    drop _freq
    save ../temp/possible_non_articles, replace
    restore
    merge m:1 lower_title using ../temp/possible_non_articles, assert(1 3) keep(1) nogen*/
    save ${temp}/openalex_`samp'_clean_titles, replace
end

program clean_samps
    syntax, samp(str)
    use pmid journal_abbr using ${temp}/openalex_`samp'_clean_titles, clear
    merge 1:m pmid using ../external/openalex/openalex_`samp'_merged, keep(3) nogen 
    gen date = date(pub_date, "YMD")
    format %td date
    drop pub_date
    bys pmid: egen min_date = min(date)
    replace date =min_date
    drop min_date
    cap drop author_id
    rename date pub_date
    gen pub_mnth = month(pub_date)
    gen year = year(pub_date)
    merge m:1 inst_id using ../output/all_inst_geo_chars, assert(1 2 3) keep(1 3) nogen 
    replace inst = new_inst if !mi(new_inst)
    replace inst_id = new_id if !mi(new_inst)
    save ${temp}/cleaned_all_`samp', replace
    
    import delimited using ../external/geo/us_cities_states_counties.csv, clear varnames(1)
    gcontract stateshort statefull
    drop _freq
    drop if mi(stateshort)
    rename statefull region
    merge 1:m region using ${temp}/cleaned_all_`samp', assert(1 2 3) keep(2 3)  nogen
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

    //  we don't want to count broad and HHMI if they are affiliated with other institutions.
    cap drop author_id 
    cap drop which_athr_counter num_which_athr min_which_athr which_athr2 
    bys pmid athr_id (which_athr which_affl): gen author_id = _n ==1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr: gen num_affls = _N
    gen broad_affl = inst == "Broad Institute"
    gen hhmi_affl = inst == "Howard Hughes Medical Institute"
    gen funder = (strpos(inst, "Trust")> 0 | strpos(inst, "Foundation")>0 | strpos(inst, "Fund")>0) & !inlist(type, "education", "facility", "healthcare")
    gen only_broad = num_affls == 1 & broad_affl == 1
    bys pmid which_athr: egen has_broad_affl = max(broad_affl)
    replace has_broad_affl = 0 if only_broad == 1
    drop if inst == "Broad Institute" & only_broad == 0
    drop if num_affls > 1 & hhmi_affl == 1 & mi(inst)
    bys pmid which_athr: egen has_hhmi_affl = max(hhmi_affl)
    drop if num_affls > 1 & hhmi_affl == 1 
    drop if num_affls > 1 & funder == 1
    qui hashsort pmid which_athr which_affl
    cap drop author_id
    bys pmid athr_id (which_athr which_affl): gen author_id = _n ==1
    bys pmid (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
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
    compress, nocoalesce
    save ../output/cleaned_all_`samp', replace
    preserve
    gcontract id pmid
    drop _freq
    save ${temp}/pmid_id_xwalk_`samp', replace
    restore

    keep if inrange(pub_date, td(01jan2015), td(31dec2022)) & year >=2015
    drop cite_wt cite_affl_wt
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    qui gunique pmid
    qui replace cite_wt = cite_wt * r(unique)
    gsort pmid cite_wt
    qui bys pmid: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gen cite_affl_wt = affl_wt * cite_wt
    compress, nocoalesce
    save ../output/cleaned_last5yrs_`samp', replace
end

program clean_mesh  
    syntax, samp(str)
    local end = cond("`samp'" == "all_jrnls", 142, 51)
    local suf = cond("`samp'" == "all_jrnls", "" ,"_clin")
    qui {
        forval i = 1/`end' {
            cap import delimited using ../external/openalex/mesh_terms`suf'`i', clear varn(1) bindquotes(strict)
            save ${temp}/mesh_terms`suf'`i', replace
        }
        clear 
        forval i = 1/`end' {
            cap append using ${temp}/mesh_terms`suf'`i'
        }
    }
    keep if is_major_topic == "TRUE" 
    gduplicates drop id term, force
    gen gen_mesh = term if strpos(term, ",") == 0 & strpos(term, ";") == 0
    replace gen_mesh = term if strpos(term, "Models")>0
    replace gen_mesh = subinstr(gen_mesh, "&; ", "&",.)
    gen rev_mesh = reverse(term)
    replace rev_mesh = substr(rev_mesh, strpos(rev_mesh, ",")+1, strlen(rev_mesh)-strpos(rev_mesh, ","))
    replace rev_mesh = reverse(rev_mesh)
    replace gen_mesh = rev_mesh if mi(gen_mesh)
    drop rev_mesh
    contract id gen_mesh, nomiss
    save ${temp}/contracted_gen_mesh_`samp', replace
    merge m:1 id using ${temp}/pmid_id_xwalk_`samp', assert(1 2 3) keep(3) nogen 
    cap drop _freq
    if "`samp'" == "all_jrnls" {
        merge m:1 pmid using ../external/pmids_jrnl/newfund_pmids, keep(3) nogen keepusing(pmid)
    }
    save ../output/contracted_gen_mesh_`samp', replace
end

program split_sample
    foreach samp in all last5yrs {
        preserve
        use ../output/cleaned_`samp'_all_jrnls, clear
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
        use ../output/cleaned_`samp'_all_jrnls, clear
        keep if inlist(journal_abbr, "cell_stem_cell", "nat_biotech", "nat_cell_bio", "nat_genet", "nat_med", "nat_med", "nat_neuro", "neuron", "nat_chem_bio")
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
        use ../output/cleaned_`samp'_all_jrnls, clear
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

        preserve
        use ../output/cleaned_`samp'_clin_med, clear
        gcontract pmid
        drop _freq
        save ../output/list_of_pmids_`samp'_clin_med,  replace
        restore
    } 
    // split mesh terms
    use ../output/contracted_gen_mesh_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ../output/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/contracted_gen_mesh_newfund_`samp', replace
        restore
    }
end

main
