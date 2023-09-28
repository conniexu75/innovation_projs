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
        clean_concepts, samp(`samp')
    }
    split_sample
end

program aggregate_insts
    qui {
        forval i = 1/8 {
            cap import delimited using ../external/openalex/inst_geo_chars`i', clear varn(1) bindquotes(strict)
            save ${temp}/inst_geo_chars`i', replace
        }
        clear 
        forval i = 1/8 {
            cap append using ${temp}/inst_geo_chars`i'
        }
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
    drop if mi(title)
    gen lower_title = stritrim(subinstr(subinstr(subinstr(subinstr(strlower(title), `"""', "", .), ".", "",.)), " :", ":",.), "'", "", .)
    drop if strpos(lower_title, "accountable care")>0 | strpos(title, "ACOs")>0
    drop if lower_title == "response"
    drop if strpos(lower_title , "nuts")>0 & strpos(lower_title, "bolts")>0
    foreach s in "economic" "economy" "public health" "hallmarks" "government" "reform" "equity" "payment" "politics" "policy" "policies" "comment" "guideline" "profession's" "interview" "debate" "profesor" "themes:"  "professionals" "physician" "workforce" "medical-education"  "medical education" "funding" "conference" "insurance" "fellowship" "ethics" "legislation" "the editor" "response : " "letters" "this week" "notes" "news " "a note" "obituary"  "review" "perspectives" "scientists" "book" "institution" "meeting" "university" "universities" "journals" "publication" "recent " "costs" "challenges" "researchers" "perspective" "reply" " war" " news" "a correction" "academia" "society" "academy of" "nomenclature" "teaching" "education" "college" "academics"  "political" "association for" "association of" "response by" "societies" "health care" "health-care"  "abstracts" "journal club" "curriculum" "women in science" "report:" "letter:" "editorial:" "lesson" "awards" "doctor" "nurse" "health workers" " story"  "case report" "a brief history" "lecture " "career" "finance" "criticism" "critique" "discussion" "world health" "workload" "compensation" "educators" "war" "announces" "training programmes" "nhs" "nih" "national institutes of health" "address" "public sector" "private sector" "government" "price" "reflections" "health care" "healthcare" "health-care" " law" "report" "note on" "insurer" "health service research" "error" "quality of life" {
        drop if strpos(lower_title, "`s'")>0
    }
    gen strp = substr(lower_title, 1, strpos(lower_title, ": ")) if strpos(lower_title, ": ") > 0
    bys strp journal_abbr : gen tot_strp = _N
    foreach s in "letter:" "covid-19:" "snapshot:" "editorial:" "david oliver:" "offline:" "helen salisbury:" "margaret mccartney:" "book:" "response:" "letter from chicago:" "a memorable patient:" "<i>response</i> :" "reading for pleasure:" "partha kar" "venus:" "matt morgan:" "bad medicine:" "nota bene:" "cohort profile:" "size matters:" "usa:" "cell of the month:" "living on the edge:" "enhanced snapshot:" "world view:" "science careers:" "clare gerada:" "rammya mathew:" "endpiece:" "role model:" "quick uptakes:" "webiste of the week:" "tv:" "press:" "brief communication:" "essay:" "clinical update:" "assisted dying:" "controversies in management:" "health agencies update:" "the bmj awards 2020:" "lesson of the week:" "ebola:" "media:" "management for doctors:" "monkeypox:" "profile:" "the bmj awards 2017:" "the world in medicine:" "the bmj awards 2021:" "when i use a word . . .:" "personal paper:"  "clinical decision making:" "how to do it:" "10-minute consultation:" "frontline:" "when i use a word:" "medicine as a science:" "personal papers:" "miscellanea:" "the lancet technology:" {
        drop if strpos(lower_title, "`s'") == 1 & tot_strp > 1
    }
    drop if inlist(lower_title, "random samples", "sciencescope", "through the glass lightly", "equipment", "women in science",  "correction", "the metric system")
    drop if inlist(lower_title, "convocation week","the new format", "second-quarter biotech job picture", "gmo roundup")
    drop if strpos(lower_title, "annals ")==1
    drop if strpos(lower_title, "a fatal case of")==1
    drop if strpos(lower_title, "a case of ")==1
    drop if strpos(lower_title, "case ")==1
    drop if strpos(lower_title, "a day ")==1
    drop if strpos(lower_title,"?")>0
    preserve
    contract lower_title journal_abbr  pmid
    gduplicates tag lower_title journal_abbr, gen(dup)
    keep if dup> 0 & journal_abbr != "jbc"
    keep pmid
    gduplicates drop
    save ../temp/possible_non_articles_`samp', replace
    restore
    merge m:1 pmid using ../temp/possible_non_articles_`samp', assert(1 3) keep(1) nogen
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
    replace inst = "Johns Hopkins University" if strpos(raw_affl , "Bloomberg School of Public Health")>0 & inst == "Bloomberg (United States)"
    merge m:1 inst_id using ../output/all_inst_geo_chars, assert(1 2 3) keep(1 3) nogen 
    replace inst = new_inst if !mi(new_inst)
    replace inst_id = new_id if !mi(new_inst)
    replace inst = "Johns Hopkins University" if  strpos(inst, "Johns Hopkins")>0
    replace inst_id = "I145311948" if inst == "Johns Hopkins University"
    replace inst = "Stanford University" if inlist(inst, "Stanford Medicine", "Stanford Health Care")
    replace inst = "Northwestern University" if inlist(inst, "Northwestern Medicine")
    replace inst = "National Institutes of Health" if  inlist(inst, "National Cancer Institute", "National Eye Institute", "National Heart, Lung, and Blood Institute", "National Human Genome Research Institute") | ///
              inlist(inst, "National Institute on Aging", "National Institute on Alcohol Abuse and Alcoholism", "National Institute of Allergy and Infectious Diseases", "National Institute of Arthritis and Musculoskeletal and Skin Diseases") | ///
                        inlist(inst, "National Institute of Biomedical Imaging and Bioengineering", "National Institute of Child Health and Human Development", "National Institue of Dental and Craniofacial Research") | ///
                                  inlist(inst, "National Institute of Diabetes and Digestive and Kidney Diseases", "National Institute on Drug Abuse", "National Institute of Environmental Health Sciences", "National Institute of General Medical Sciences", "National Institute of Mental Health", "National Institute on Minority Health and Health Disparities") | ///
                                            inlist(inst, "National Institute of Neurological Disorders and Stroke", "National Institute of Nursing Research", "National Library of Medicine", "National Heart Lung and Blood Institute", "National Institutes of Health")
    // extras
    gen is_lancet = strpos(raw_affl, "The Lancet")>0
    gen is_london = raw_affl == "London, UK." |  raw_affl == "London."
    gen is_bmj = (strpos(raw_affl, "BMJ")>0 | strpos(raw_affl, "British Medical Journal")>0)
    gen is_jama = strpos(raw_affl, " JAMA")>0 & mi(inst)
    gen is_editor = strpos(raw_affl, " Editor")>0 | strpos(raw_affl, "Editor ")>0
    bys pmid: gegen has_lancet = max(is_lancet)
    bys pmid: gegen has_london = max(is_london)
    bys pmid: gegen has_bmj = max(is_bmj)
    bys pmid: gegen has_jama = max(is_jama)
    bys pmid: gegen has_editor = max(is_jama)
    drop if has_lancet == 1 | has_london == 1 | has_bmj == 1 | has_jama == 1 | has_editor == 1
    drop is_lancet is_london is_bmj is_jama is_editor has_lancet has_london has_bmj has_jama has_editor
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
    

    // drop if author_id is <  5000000000
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num

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
    gen len = length(inst)
    qui sum len
    local n = r(max)
    recast str`n' inst, force
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
    local end = cond("`samp'" == "all_jrnls", 143, 51)
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
    gduplicates drop id term qualifier_name, force
    gen gen_mesh = term if strpos(term, ",") == 0 & strpos(term, ";") == 0
    replace gen_mesh = term if strpos(term, "Models")>0
    replace gen_mesh = subinstr(gen_mesh, "&; ", "&",.)
    gen rev_mesh = reverse(term)
    replace rev_mesh = substr(rev_mesh, strpos(rev_mesh, ",")+1, strlen(rev_mesh)-strpos(rev_mesh, ","))
    replace rev_mesh = reverse(rev_mesh)
    replace gen_mesh = rev_mesh if mi(gen_mesh)
    drop rev_mesh
    contract id gen_mesh qualifier_name, nomiss
    save ${temp}/contracted_gen_mesh_`samp', replace
    merge m:1 id using ${temp}/pmid_id_xwalk_`samp', assert(1 2 3) keep(3) nogen 
    cap drop _freq
    if "`samp'" == "all_jrnls" {
        merge m:1 pmid using ../external/pmids_jrnl/newfund_pmids, keep(3) nogen keepusing(pmid)
    }
    save ../output/contracted_gen_mesh_`samp', replace
end

program clean_concepts
    syntax, samp(str)
    local end = cond("`samp'" == "all_jrnls", 143, 51)
    local suf = cond("`samp'" == "all_jrnls", "" ,"_clin")
    qui {
        forval i = 1/`end' {
            cap import delimited using ../external/openalex/concepts`suf'`i', clear varn(1) bindquotes(strict)
            save ${temp}/concepts`suf'`i', replace
        }
        clear 
        forval i = 1/`end' {
            cap append using ${temp}/concepts`suf'`i'
        }
    }
    gunique id
    *bys id: egen min_level = min(level)
    *bys id level: egen max_score = max(score)
    *keep if min_level == level & max_score == score
    *gunique id
    gduplicates drop id term, force
    *keep id term
    save ${temp}/concepts_`samp', replace
    merge m:1 id using ${temp}/pmid_id_xwalk_`samp', assert(1 2 3) keep(3) nogen 
    cap drop _freq
    if "`samp'" == "all_jrnls" {
        merge m:1 pmid using ../external/pmids_jrnl/newfund_pmids, keep(3) nogen keepusing(pmid)
    }
    save ../output/concepts_`samp', replace
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
   // split concepts 
    use ../output/concepts_all_jrnls, clear
    foreach samp in cns scisub demsci {
        preserve
        merge m:1 pmid using ../output/list_of_pmids_all_newfund_`samp', assert(1 2 3) keep(3) nogen
        save ../output/concepts_newfund_`samp', replace
        restore
    }
end

main
