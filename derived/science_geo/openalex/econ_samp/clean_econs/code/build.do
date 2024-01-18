set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/clean_econs"
global output "/export/scratch/cxu_sci_geo/clean_econs"
global year_insts "/export/scratch/cxu_sci_geo/create_econ_inst_hist"

program main
    local samp all_jrnls
    local samp clin_med
    merge_econ
    aggregate_insts
    clean_samps
end
program merge_econ
    foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
        import delimited using ../external/openalex/`j', clear varn(1) bindquotes(strict)
        gen journal_abbr = "`j'"
        save ../temp/`j', replace
    }

    clear
    foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
        append using ../temp/`j'
    }
    save ../temp/econs_merged, replace
end

program aggregate_insts
    import delimited using ../external/openalex/inst_geo_chars1, clear varn(1) bindquotes(strict)
    bys inst_id: gegen has_parent = max(associated_rel == "parent")
    keep if has_parent == 0  | (has_parent == 1 & associated_rel == "parent" ) 
    gen new_inst = ""
    gen new_inst_id = ""
    foreach var in inst inst_id {
        replace new_`var' =  `var' if has_parent == 0
        replace new_`var' = `var' if ((strpos(associated, "Universit")>0|strpos(associated, "College")|strpos(associated, "Higher Education")) & strpos(associated, "System")>0 & associated_type == "education" & (type == "education" | type == "healthcare")) | inlist(associated, "University of London", "Wellcome Trust") | (strpos(associated, "Health")>0 & strpos(associated, "System")>0 & associated_type == "healthcare" & (type == "education" | type == "healthcare")) | strpos(associated, "Ministry of") > 0 | strpos(associated, "Board of")>0 | strpos(associated, "Government of")>0 | (strpos(associated, "Department of")>0 & country != "Russia")
        replace new_`var' = `var' if country_code != associated_country
    }
    replace associated = "" if !mi(new_inst)
    replace associated_id = "" if !mi(new_inst_id)
    gduplicates drop inst_id new_inst_id, force
    foreach s in "" "_id" {
        replace new_inst`s' = associated`s' if strpos(associated, "University")>0 & strpos(associated, "System")>0 & associated_type == "education" & (type != "education" & type != "healthcare")
        replace new_inst`s' = associated`s' if inlist(associated, "Chinese Academy of Sciences", "Spanish National Research Council", "Max Planck Society", "National Research Council", "National Institutes of Health", "Harvard University")
        replace new_inst`s' = associated`s' if inlist(associated, "Leibniz Association", "Aix-Marseille University", "Indian Council of Agricultural Research", "Inserm", "Polish Academy of Sciences", "National Research Institute for Agriculture, Food and Environment") 
        replace new_inst`s' = associated`s' if inlist(associated, "Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions")
        replace new_inst`s' = associated`s' if inlist(associated, "Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
        replace new_inst`s' = associated`s' if inlist(associated, "French National Centre for Scientific Research")
        replace new_inst`s' = associated`s' if inlist(associated, "Fraunhofer Society", "Istituti di Ricovero e Cura a Carattere Scientifico",  "Claude Bernard University Lyon 1", "Atomic Energy and Alternative Energies Commission", "Japanese Red Cross Society, Japan") 
        replace new_inst`s' = associated`s' if inlist(associated, "Islamic Azad University, Tehran", "National Oceanic and Atmospheric Administratio", "French Institute for Research in Computer Science and Automation", "National Academy of Sciences of Ukraine", "National Institute for Nuclear Physics", "Assistance Publique – Hôpitaux de Paris") 
        replace new_inst`s' = associated`s' if inlist(associated, "Medical Research Council", "National Institute for Health Research", "Academia Sinica", "National Scientific and Technical Research Council","Czech Academy of Sciences", "Commonwealth Scientific and Industrial Research Organisation")
        replace new_inst`s' = associated`s' if inlist(associated, "Slovak Academy of Sciences", "Indian Council of Medical Research", "Council of Scientific and Industrial Research", "National Institute for Astrophysics", "Bulgarian Academy of Sciences", "Centers for Disease Control and Prevention", "National Institute of Technology")
        replace new_inst`s' = associated`s' if inlist(associated, "Helmholtz Association of German Research Centres", "Helios Kliniken", "Shriners Hospitals for Children", "Hungarian Academy of Sciences", "National Agriculture and Food Research Organization", "Australian Research Council")
        replace new_inst`s' = associated`s' if inlist(associated, "Agro ParisTech", "Veterans Health Administration", "Institut de Recherche pour le Développement", "Austrian Academy of Sciences", "Institutos Nacionais de Ciência e Tecnologia", "Chinese Academy of Forestry", "Chinese Academy of Tropical Agricultural Sciences")
        replace new_inst`s' = associated`s' if inlist(associated, "Instituto de Salud Carlos III", "National Aeronautics and Space Administration", "Ludwig Boltzmann Gesellschaft", "United States Air Force", "Centre Nouvelle Aquitaine-Bordeaux", "RIKEN", "Agricultural Research Council")
        replace new_inst`s' = associated`s' if inlist(associated, "Centro Científico Tecnológico - La Plata", "National Research Council Canada", "Royal Netherlands Academy of Arts and Sciences","Defence Research and Development Organisation", "Canadian Institutes of Health Research", "Italian Institute of Technology", "United Nations University")
        replace new_inst`s' = associated`s' if inlist(associated, "IBM Research - Thomas J. Watson Research Center", "Délégation Ile-de-France Sud","Grenoble Institute of Technology", "François Rabelais University", "Chinese Academy of Social Sciences", "National Science Foundation" , "Federal University of Toulouse Midi-Pyearénées")
        replace new_inst`s' = associated`s' if inlist(associated, "Chinese Center For Disease Control and Prevention", "Johns Hopkins Medicine", "Cancer Research UK", "Centre Hospitalier Universitaire de Bordeaux", "Puglia Salute", "Hospices Civils de Lyon", "Ministry of Science and Technology", "Servicio de Salud de Castilla La Mancha")
        replace new_inst`s' = associated`s' if inlist(associated, "Grenoble Alpes University","Arts et Metiers Institute of Technology", "University of Paris-Saclay", "Biomedical Research Council", "Senckenberg Society for Nature Research", "Centre Hospitalier Régional et Universitaire de Lille", "Schön Klinik Roseneck", "ESPCI Paris")
        replace new_inst`s' = associated`s' if inlist(associated, "National Academy of Sciences of Armenia", "University of the Philippines System", "Madrid Institute for Advanced Studies", "CGIAR", "Ministry of Science, Technology and Innovation", "Institut Polytechnique de Bordeaux")

        replace new_inst`s' = associated`s' if inlist(associated, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") & country == "Russia"
        replace new_inst`s' = associated`s' if inlist(associated, "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences") & country == "Russia" 
        replace new_inst`s' = associated`s' if inlist(associated, "Russian Academy")
        replace new_inst`s' = associated`s' if strpos(associated, "Agricultural Research Service -")>0
    }
    // merge national institutions together
    replace new_inst = "French National Centre for Scientific Research" if inlist(inst,"Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions") | inlist(inst,"Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
    replace new_inst = "French National Centre for Scientific Research" if inlist(new_inst,"Institut des Sciences Biologiques", "Institut de Chimie", "Institut des Sciences Humaines et Sociales", "Institut National des Sciences de l'Univers", "Institut des Sciences de l'Ingénierie et des Systèmes", "Institut Écologie et Environnement", "Institut de Physique", "Institut National des Sciences Mathématiques et de leurs Interactions") | inlist(new_inst,"Institut National de Physique Nucléaire et de Physique des Particules", "Institut des Sciences de l'Information et de leurs Interactions")
    replace new_inst_id = "I1294671590" if new_inst =="French National Centre for Scientific Research"
    replace new_inst = "Russian Academy" if inlist(inst, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") | inlist(inst, "Russian Academy of Sciences", "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences") & country == "Russia"
    replace new_inst = "Russian Academy" if inlist(new_inst, "Department of Biological Sciences", "Department of Chemistry and Material Sciences", "Department of Energy, Engineering, Mechanics and Control Processes","Department of Agricultural Sciences", "Division of Historical and Philological Sciences", "Department of Mathematical Sciences", "Department of Physiological Sciences") | inlist(new_inst,"Russian Academy of Sciences", "Department of Earth Sciences", "Physical Sciences Division", "Department of Global Issues and International Relations", "Department of Medical Sciences", "Department of Social Sciences") & country == "Russia"
    replace new_inst_id = "I1313323035" if new_inst  == "Russian Academy"
    replace new_inst  = "Agricultural Research Service" if strpos(inst, "Agricultural Research Service - ")>0
    replace new_inst_id = "I1312222531" if new_inst == "Agricultural Research Service"
    replace new_inst  = "Max Planck Society" if strpos(inst, "Max Planck")>0
    replace new_inst  = "Max Planck Society" if strpos(associated, "Max Planck")>0
    replace new_inst_id = "I149899117" if new_inst == "Max Planck Society"
    replace new_inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    replace new_inst_id = "I48633490" if new_inst == "Mass General Brigham"
    replace new_inst = "Johns Hopkins University" if strpos(inst, "Johns Hopkins")>0
    replace new_inst = "Johns Hopkins University" if strpos(associated, "Johns Hopkins")>0
    replace new_inst_id = "I145311948" if new_inst == "Johns Hopkins University"
    replace new_inst = "Stanford University" if inlist(inst, "Stanford Medicine", "Stanford Health Care", "Stanford Synchrotron Radiation Lightsource", "Stanford Blood Center")
    replace new_inst = "Stanford University" if inlist(associated, "Stanford Medicine", "Stanford Health Care")
    replace new_inst_id = "I97018004" if new_inst == "Stanford University"
    replace new_inst = "Northwestern University" if inlist(inst, "Northwestern Medicine")
    replace new_inst = "Northwestern University" if inlist(associated, "Northwestern Medicine")
    replace new_inst_id = "I111979921" if new_inst == "Northwestern University"
    replace new_inst = "Harvard University" if inlist(inst, "Harvard Global Health Institute", "Harvard Pilgrim Health Care", "Harvard Affiliated Emergency Medicine Residency", "Harvard NeuroDiscovery Center")
    replace new_inst_id = "I136199984" if new_inst == "Harvard University"
    // health systems
    replace new_inst = "University of Virginia" if strpos(inst, "University of Virginia") > 0 & (strpos(inst, "Hospital") >0 | strpos(inst, "Medical")>0 | strpos(inst, "Health")>0)
    replace new_inst_id = "I51556381" if new_inst == "University of Virginia"
    replace new_inst = "University of Missouri" if strpos(inst, "University of Missouri" ) > 0 & (strpos(inst, "Hospital") >0 | strpos(inst, "Medical")>0 | strpos(inst, "Health")>0)
    replace new_inst_id = "I76835614" if new_inst == "University of Missouri"
    replace new_inst = "Baylor University" if strpos(inst, "Baylor University Medical Center")>0
    replace new_inst_id = "I157394403" if new_inst == "Baylor University"
    replace new_inst = "Columbia University" if strpos(inst, "Columbia University Irving Medical Center")>0
    replace new_inst_id = "I78577930" if new_inst == "Columbia University"
    gen edit = 0
    foreach s in "Health System" "Clinic" "Hospital" "Medical Center" {
        replace new_inst = subinstr(inst, "`s'", "", .) if (strpos(inst, "University")>0 | strpos(inst, "UC")>0) & strpos(inst, "`s'") > 0 & edit == 0 & country_code == "US"
        replace edit = 1 if  (strpos(inst, "University")>0 | strpos(inst, "UC")>0) & strpos(inst, "`s'") > 0 &  country_code == "US"
    }
    replace new_inst = strtrim(new_inst)
    bys new_inst (edit) : replace new_inst_id = new_inst_id[_n-1] if edit == 1 & !mi(new_inst_id[_n-1])  & city == city[_n-1]
    replace new_inst = associated if !mi(associated) & mi(new_inst) & has_parent == 1 & type == "facility" & associated_type == "education"
    replace new_inst_id = associated_id if !mi(associated_id) & mi(new_inst_id) & has_parent == 1 & type == "facility" & associated_type == "education"
    replace new_inst = inst if mi(new_inst)
    replace new_inst_id = inst_id if mi(new_inst_id)
    gduplicates tag inst_id, gen(dup)
    gen diff = inst_id != new_inst_id
    bys inst_id : gegen has_new = max(diff)
    drop if dup > 0 & diff == 0 & has_new == 1
    gduplicates drop inst_id, force
    keep inst_id inst new_inst new_inst_id region city country country_code type 
    drop if mi(inst_id) 
    save ${output}/all_inst_geo_chars, replace
end

program clean_samps
    use ../temp/econs_merged, clear
    // clean date variables
    gen date = date(pub_date, "YMD")
    format %td date
    drop pub_date
    bys id: gegen min_date = min(date)
    replace date =min_date
    drop min_date
    cap drop author_id
    rename date pub_date
    gen pub_mnth = month(pub_date)
    gen year = year(pub_date)
    gen qrtr = qofd(pub_date)
    keep if inrange(year, 1945, 2022)
    // fix some wrong institutions
    replace inst = "Johns Hopkins University" if strpos(raw_affl , "Bloomberg School of Public Health")>0 & inst == "Bloomberg (United States)"
    merge m:1 inst_id using ${output}/all_inst_geo_chars, assert(1 2 3) keep(1 3) nogen 
    replace inst = new_inst if !mi(new_inst)
    replace inst_id = new_inst_id if !mi(new_inst)
    replace inst = "Johns Hopkins University" if  strpos(inst, "Johns Hopkins")>0
    replace inst_id = "I145311948" if inst == "Johns Hopkins University"
    replace inst = "Stanford University" if inlist(inst, "Stanford Medicine", "Stanford Health Care")
    replace inst = "Northwestern University" if inlist(inst, "Northwestern Medicine")
    replace inst = "National Institutes of Health" if  inlist(inst, "National Cancer Institute", "National Eye Institute", "National Heart, Lung, and Blood Institute", "National Human Genome Research Institute") | ///
              inlist(inst, "National Institute on Aging", "National Institute on Alcohol Abuse and Alcoholism", "National Institute of Allergy and Infectious Diseases", "National Institute of Arthritis and Musculoskeletal and Skin Diseases") | ///
                        inlist(inst, "National Institute of Biomedical Imaging and Bioengineering", "National Institute of Child Health and Human Development", "National Institute of Dental and Craniofacial Research") | ///
                                  inlist(inst, "National Institute of Diabetes and Digestive and Kidney Diseases", "National Institute on Drug Abuse", "National Institute of Environmental Health Sciences", "National Institute of General Medical Sciences", "National Institute of Mental Health", "National Institute on Minority Health and Health Disparities") | ///
                                            inlist(inst, "National Institute of Neurological Disorders and Stroke", "National Institute of Nursing Research", "National Library of Medicine", "National Heart Lung and Blood Institute", "National Institutes of Health")
    cap drop author_id 
    cap drop which_athr_counter num_which_athr min_which_athr which_athr2 
    bys id athr_id (which_athr which_affl): gen author_id = _n ==1
    bys id (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys id which_athr: gen num_affls = _N
    cap drop region
    cap drop inst_id
    cap drop country
    cap drop country_code
    cap drop city
    cap drop inst
    cap drop new_inst new_inst_id
    merge m:1 athr_id year using ${year_insts}/filled_in_panel_year, assert(1 2 3) keep(3) nogen
    gduplicates drop id athr_id inst_id, force
    /*drop if inlist(inst, "American Economic Association", "Hoover Institution", "Center for Economic and Policy Research", "National Bureau of Economic Research", "Abdul Latif Jameel Poverty Action Lab", "Institute for Fiscal Studies") & num_affls > 1 
    bys id which_athr: replace num_affls = _N
    drop if strpos(inst, "Foundation") > 0  & num_affls > 1 
    bys id which_athr: replace num_affls = _N
    drop if strpos(inst, "Center") > 0  & num_affls > 1 
    drop if strpos(inst, "Centre") > 0  & num_affls > 1 
    drop if strpos(inst, "Council") > 0  & num_affls > 1 
    bys athr_id inst_id: gen in_yr = _n == 1
    by athr_id inst_id : egen tot_in_yr =  total(in_yr)
    hashsort athr_id year inst_id -tot_in_yr*/
    *gduplicates drop id athr_id year, force
*    drop region inst_id country country_code city inst

    // wt_adjust articles 
    qui hashsort id which_athr which_affl
    cap drop author_id
    bys id athr_id (which_athr which_affl): gen author_id = _n ==1
    bys id (which_athr which_affl): gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys id which_athr: replace num_affls = _N
    assert num_affls == 1
    bys id: gegen num_athrs = max(which_athr)
    gen affl_wt = 1/num_affls * 1/num_athrs // this just divides each paper by the # of authors on the paper
    // now give each article a weight based on their ciatation count 
    qui gen years_since_pub = 2022-year+1
    qui gen avg_cite_yr = cite_count/years_since_pub
    qui bys id: replace avg_cite_yr = . if _n != 1
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum) // each article is no longer weighted 1 
    bys journal_abbr: gegen tot_cite_N = total(cite_wt)
    gsort id cite_wt
    qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    qui gunique id
    local articles = r(unique)
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    gen impact_fctr = . 
    replace impact_fctr = 9.1 if journal_abbr == "aejae"
    replace impact_fctr = 7.1 if journal_abbr == "aejep"
    replace impact_fctr = 6.6 if journal_abbr == "aejmac"
    replace impact_fctr = 2.4 if journal_abbr == "aejmicro"
    replace impact_fctr = 12.7 if journal_abbr == "aer"
    replace impact_fctr = 8.1 if journal_abbr == "aerinsights"
    replace impact_fctr = 7.5 if journal_abbr == "econometrica"
    replace impact_fctr = 4.2 if journal_abbr == "ej"
    replace impact_fctr = 1.9 if journal_abbr == "ier"
    replace impact_fctr = 4.8 if journal_abbr == "jeea"
    replace impact_fctr = 10.4 if journal_abbr == "jpe"
    replace impact_fctr = 2.1 if journal_abbr == "qe"
    replace impact_fctr = 21.5 if journal_abbr == "qje"
    replace impact_fctr = 7.1 if journal_abbr == "restud"
    replace impact_fctr = 8.7 if journal_abbr == "restat"
    bys id: gen id_cntr = _n == 1
    bys journal_abbr: gen first_jrnl = _n == 1
    by journal_abbr: gegen jrnl_N = total(id_cntr)
    sum impact_fctr if first_jrnl == 1
    gen impact_shr = impact_fctr/r(sum)
    gen reweight_N = impact_shr * `articles'
    replace tot_cite_N = tot_cite_N * `articles'
    gen impact_wt = reweight_N/jrnl_N
    gen impact_affl_wt = impact_wt * affl_wt
    gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
    gen impact_cite_affl_wt = impact_cite_wt * affl_wt
    foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt {
        qui sum `wt'
        assert round(r(sum)-`articles') == 0
     }
    compress, nocoalesce
    gen len = length(inst)
    qui sum len
    local n = r(max)
    recast str`n' inst, force
    cap drop n mi_inst has_nonmi_inst population len
    save ${output}/cleaned_all_econs, replace

    keep if inrange(pub_date, td(01jan2015), td(31dec2022)) & year >=2015
    drop cite_wt cite_affl_wt  impact_wt impact_affl_wt impact_cite_wt impact_cite_affl_wt tot_cite_N reweight_N jrnl_N first_jrnl impact_shr 
    qui sum avg_cite_yr
    gen cite_wt = avg_cite_yr/r(sum)
    bys journal_abbr: gegen tot_cite_N = total(cite_wt)
    gsort id cite_wt
    qui bys id: replace cite_wt = cite_wt[_n-1] if mi(cite_wt)
    gunique id
    local articles = r(unique)
    qui gen cite_affl_wt = affl_wt * cite_wt * `articles'
    qui bys journal_abbr: gen first_jrnl = _n == 1
    qui by journal_abbr: gegen jrnl_N = total(id_cntr)
    qui sum impact_fctr if first_jrnl == 1
    gen impact_shr = impact_fctr/r(sum)
    gen reweight_N = impact_shr * `articles'
    replace  tot_cite_N = tot_cite_N * `articles'
    gen impact_wt = reweight_N/jrnl_N
    gen impact_affl_wt = impact_wt * affl_wt
    gen impact_cite_wt = reweight_N * cite_wt / tot_cite_N * `articles'
    gen impact_cite_affl_wt = impact_cite_wt * affl_wt
    foreach wt in affl_wt cite_affl_wt impact_affl_wt impact_cite_affl_wt {
        qui sum `wt'
        assert round(r(sum)-`articles') == 0
     }
    compress, nocoalesce
    save ${output}/cleaned_last5yrs_econs, replace
end

main
