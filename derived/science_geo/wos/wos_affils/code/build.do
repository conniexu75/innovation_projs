 set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/wos_affils"

program main
    foreach samp in  demsci // {med cns thera scisub { //demsci {
        create_xwalks, samp(`samp')
 *       get_orcid, samp(`samp')
*        clean_affil, samp(`samp')
*       combine_insts, samp(`samp') 
    }
    clear
 /*   foreach samp in med cns thera scisub { //demsci {
        append using ../output/linked_orcid_`samp'
        }
        save ../output/linked_orcid_all_jrnls*/
/*    gcollapse (sum) _freq, by(institution)
    drop if mi(institution)
    save ${temp}/all_insts, replace*/
end

program create_xwalks
    syntax, samp(str)
    use  ../external/samp/`samp'_appended, clear
    keep if doc_type == "Article"
    rename author raw_author
    gen author = raw_author
    split author, p("; ")
    drop if mi(raw_author)
    drop author
    keep author* pmid
    greshape long author, i(pmid) j(which_athr) 
    drop if mi(author)
    gduplicates drop pmid author, force
    bys pmid (which_athr): replace which_athr = _n 
    split author, p(", ")
    drop author3
    replace author1 = strtrim(author1)
    replace author2 = strtrim(author2)
    rename (author1 author2) (last_name first_name)
    replace last_name = strproper(last_name) 
    replace first_name = strproper(first_name) 
    gduplicates tag pmid last_name, gen(mult_last_name)
    save ${temp}/author_names_`samp', replace
    
    // get orcid
    use ../external/samp/`samp'_appended, clear
    keep if doc_type == "Article"
    drop if mi(orcid)
    keep pmid orcid
    split orcid, p("; ")
    drop orcid
    sreshape long orcid, i (pmid) j(which_athr) missing(drop)
    split orcid, p("/")
    drop orcid 
    rename (orcid1 orcid2) (name orcid)
    split name, p(", ")
    rename name1 last_name
    rename name2 list_first_name
    drop which_athr
    gduplicates drop pmid name, force
    save ${temp}/orcid_`samp', replace
    
    // get researcherid
    use ../external/samp/`samp'_appended, clear
    keep if doc_type == "Article"
    drop if mi(researcher_id)
    keep pmid researcher_id 
    split researcher_id, p("; ")
    drop researcher_id
    sreshape long researcher_id, i (pmid) j(which_athr) missing(drop)
    split researcher_id, p("/")
    drop researcher_id 
    rename (researcher_id1 researcher_id2) (name researcher_id)
    split name, p(", ")
    rename name1 last_name
    rename name2 list_first_name
    drop which_athr
    gduplicates drop pmid name, force
    save ${temp}/researcher_id_`samp', replace


/*    use if inrange(pub_year, 2013, 2015) using ../external/samp/`samp'_appended, clear
    keep if doc_type == "Article"
    rename affil raw_affil 
    gen affil = raw_affil
    split affil , p("; [") 
    drop affil
    keep affil* pmid
    sreshape long affil, i(pmid) j(which_affil_grp) missing(drop)
    split affil, p("] ")
    rename (affil1 affil2) (authors affiliation)
    replace authors = subinstr(authors, "[","", .)
    replace authors = subinstr(authors, "]","",.)
    replace authors = strtrim(authors)
    replace affiliation = strtrim(affiliation)
    split authors, p("; ")
    split affiliation, p(";")
    rename affiliation group_affiliation 
    sreshape long affiliation, i(pmid which_affil_grp authors*) j(which_affil) missing(drop)
    replace affiliation = strtrim(affiliation)
    save ${temp}/author_affiliations_`samp', replace */
end     

program get_orcid
    syntax, samp(str)
    use ${temp}/author_names_`samp',clear
    joinby pmid last_name using ${temp}/orcid_`samp', unmatched(master)
    keep if mult_last_name == 0 | (mult_last_name > 0 & substr(list_first_name, 1,1) == substr(first_name, 1,1))
    gduplicates tag pmid last_name, gen(still_mult)
    drop if still_mult > 0 & substr(list_first_name, strpos(list_first_name, " ")+1,1) == strupper(substr(first_name, 2,1)) & strpos(list_first_name, " ") > 0
*    gduplicates drop pmid last_name orcid, force
    keep pmid which_athr author last_name first_name name orcid list_first_name
    replace last_name = strlower(last_name)
    gunique pmid author
    local tot = r(N)
    gunique pmid author if !mi(orcid)
    di "% we have orcid = " r(N)/`tot'*100
    keep if !mi(orcid)
    count
    save ../output/linked_orcid_`samp', replace
    

end
program clean_affil
    syntax, samp(str)
    qui {
        import delimited ../external/geo/country_list.csv, varnames(1) clear
        qui glevelsof name, local(country_names)
        qui glevelsof code, local(country_abbrs)
        gen no_comma = substr(name,1,strpos(name,",")-1)
        preserve
        drop if mi(no_comma) | no_comma == "Korea"
        glevelsof no_comma, local(more_country_names)
        restore
        save ${temp}/countries, replace

        import delimited ../external/geo/us_cities_states_counties.csv, varnames(1) clear
        glevelsof statefull, local(state_names)
        glevelsof stateshort, local(state_abbr)
        gen city_state = city + ", " + stateshort + ", " + statefull
        qui glevelsof city_state, local(uscity_names)
        qui glevelsof city, local(uscity)
        foreach s in `state_abbr' {
            qui glevelsof city, local(`s'_cities)
        }
        save ${temp}/us_cities_states_counties, replace 
        gcontract stateshort statefull
        drop _freq
        drop if mi(stateshort)
        save ${temp}/state_abbr_xwalk, replace
        
        import delimited ../external/geo/world-cities_csv.csv, varnames(1) clear
        keep name country
        rename name city
        replace city = ustrregexra(ustrnormalize(city,"nfd"), "\p{Mark}", "")
        gen city_name = city + ", " + country
        drop if country == "United States"
        qui glevelsof city_name if country != "India" , local(big_country)
        qui glevelsof city if country == "United Kingdom", local(uk_cities) 
        qui glevelsof city if country == "India" & city !="Indi" & city !=  "Un" , local(india_cities)
        save ${temp}/world_cities, replace 
        
        import excel ../external/geo/ZIP_CBSA_122021.xlsx, firstrow clear
        keep zip cbsa usps_zip_pref_city usps_zip_pref_state
        replace usps_zip_pref_city = strproper(usps_zip_pref_city)
        save ${temp}/zip_city, replace
        gcontract zip usps_zip_pref_city usps_zip_pref_state
        rename usps_zip_pref_state state_zip
        rename usps_zip_pref_city city_zip 
        drop _freq
        save ${temp}/list_zips, replace

        import delimited ../external/geo/wikipedia-iso-country-codes.csv, clear
        keep english alpha*
        rename (englis alpha2code alpha3code) (country_name alpha2 alpha3)
        save ${temp}/country2_3_xwalk, replace
    }

    di "Done creating xwalks"
    
    use ${temp}/author_affiliations_`samp', clear
    drop if mi(affiliation)
    gen edit_affiliation = affiliation
    gen rev = strreverse(affiliation)
    // countries
    gen comp = strtrim(strreverse(substr(rev, 1, strpos(rev, ",")-1)))
    gen country = ""
    
    foreach c in "Burkina Faso" "Cape Verde" "Costa Rica" "Cote Ivoire" "Dominican Rep" "East Timor" "El Salvador" "Equatorial Guinea" "Guinea Bissau" "Marshall Islands" "New Zealand" "North Korea" "South Korea" "St Lucia" "San Marino" "Saudi Arabia" "Sierra Leone" "Solomon Islands" "South Africa" "South Sudan" "Sri Lanka" "Trinidad Tobago" "Papua N Guinea" "Bosnia & Herceg" "U Arab Emirates" "Cent Afr Republ" "Czech Republic" "Faroe Islands" "Peoples R China"{
        replace country = "`c'" if strpos(comp, "`c'")>0
    }
    replace country = strtrim(strreverse(substr(strreverse(comp), 1, strpos(strreverse(comp), " ") - 1))) if mi(country) 
    replace country = comp if mi(country) & strpos(comp, " ") == 0
    replace edit_affiliation = subinstr(edit_affiliation, country, "",.)
    replace country = "China" if country == "Peoples R China"
    drop comp
   // institution 
    foreach var in affiliation edit_affiliation {
         replace `var' = subinword(`var', "Univ", "University", .)
         replace `var' = subinword(`var', "Hosp", "Hospital", .)
         replace `var' = subinword(`var', "Cent", "Central", .)
         replace `var' = subinword(`var', "Ctr", "Center", .)
    }
    gen institution = substr(affiliation, 1, strpos(affiliation, ",")-1)
    replace edit_affiliation = subinstr(edit_affiliation, institution + ",", "", .)
    //us state
    replace rev = strreverse(edit_affiliation)
    gen comp = strtrim(strreverse(substr(rev, 1, strpos(rev, ",")-1)))
    gen zip = ustrregexs(0) if ustrregexm(comp, "[0-9][0-9][0-9][0-9][0-9]") & country == "USA"
    foreach var in comp edit_affiliation {
        replace `var' = subinstr(`var', " "+zip,"",.) if !mi(zip)
    }
    replace rev = strreverse(edit_affiliation)
    gen us_state = strtrim(comp) if country == "USA" 
    replace edit_affiliation = subinstr(edit_affiliation, ", "+us_state,"",.) if !mi(us_state)
    drop comp 

    replace rev = strreverse(edit_affiliation)
    gen city = strtrim(strreverse(substr(rev, 1, strpos(rev, ",")-1))) if country == "USA"
    replace city = strtrim(edit_affiliation) if strpos(edit_affiliation, ",")==0 & country == "USA"
    
   // world cities
    foreach c in `big_country' {
        local city_name = substr("`c'", 1, strpos("`c'",",")-1)
        local country_name = substr("`c'", strpos("`c'",",")+2, strlen("`c'")) 
        replace city = "`city_name'" if strpos(affiliation, "`c'") > 0 & city == ""
        replace city = "`city_name'" if  strpos(affiliation, "`city_name'") > 0 & city == "" & country == "`country_name'" 
    }
    foreach c in `uk_cities' {
        replace city = "`c'" if strpos(affiliation, "`c'") > 0 & inlist(country, "England", "Ireland", "Scotland", "Wales") & mi(city)
    }

    foreach c in "Glasgow" "Edinburgh" "Aberdeen" "Dundee" "East Kilbride" "Paisley" "Livingston" "Cumbernauld" "Hamilton" "Kirkcaldy" "Ayr" "Perth" "Greenock" "Kilmarnock" "Inverness" "Dunfermline" "Glenrothes" "Airdrie" "Stirling" {
        replace city = "`c'" if strpos(affiliation, "`c'") >0 & country == "Scotland" & mi(city)
    }
    foreach c in "Newcastle" "Truro" "Ipswich" "Gloucester" "Exeter" "Harrow" "Hoddesdon" "Horsham" "Northwood" "Sutton" "Uxbridge" "Hinxton" "Sandwich" "Norfolk" "Stoke" "Huntingdon" "Swindon" "Hartfield" "Taunton" "Coventry" "Durham" "Dorchester" "Dudley" "Hatfield" "Greenford" "Papworth Everard" "Harlow" "Evesham" "Keele" "Brentford" "Marlborough" "Derby" "Aurora" "Hurley" "Sunderland" "Cheadle" "Stanmore" "Guildford" "Withington" "Wirral" "Colchester" "Dartford" "Corby" "Hexham" "Droitwich Spa" "Faringdon" "Escrick" "Surrey" "Torquay"  "Sherwood" "Chinnor" "Stockton" "West Midlands" "Westcliff" "Crewe" "Gillingham" "Lewisham" "Tooting" "Chertsey" "Leytonstone" "Wythenshawe" "North Somerset" "Gateshead" "Southend" "Cramlington" "Colindale" "Frimley" "Harrogate" "High Wycombe" "Kings Lynn" "Ashton Under Lyne" "Hereford" "Ashington" "Burton Upon Trent" {
        replace city = "`c'" if strpos(affiliation, "`c'") >0 & country == "England" & mi(city)
    }

    foreach c in "Milan" "Padua" "Naples" "Reggio Emilia" "Citta S Angelo" "Aviano" "Pozzilli" "Reggio Di Calabria" "Ranica" "Troina" "Cotignola" "Meldola" "Ispra" "Laquila" "Tricase" "Santa Maria Imbaro" {
        replace city = "`c'" if strpos(affiliation, "`c'") >0 & country == "Italy" & mi(city)
    }
    foreach c in "Parkville" "Carlton" "Darlinghurst" "New Lambton" "Crawley" "Malvern" "Bedford Pk" "St Lucia" "Concord" "Kensington" "St Leonards" "Prahran" "Woodville" "Nedlands" "Westmead" "Box Hill" "Concord" "Nepean" "Kings Cross" "Burwood" "Strathfield" "Chermside" "Kingswood" "Nambour" "Kogarah" "Subiaco" "Herston" "Herston" "N Ryde" "Woolloongabba" "Robina" "Wacol" "Camperdown" "Douglas" "Indooroopilly" "Collingwood" "Murdoch" "Birtinya" "Sippy Downs" "Douglas" "Newtown" "Gosford" "Campbelltown" "Edgecliff" "Balmain" "Glebe" "Bruce" "Wallsend" "Hawthorn" "Ipswich" "Bentley" "Kelvin Grove" "Macquarie" "Kurralta Pk" "Redcliffe" "Buudoora" "St Marys" "North Melbourn" "Footscray" "Waurn Ponds" "Seventeen Mile Rocks" "Austin" "Alexandria" "Black Town" "Phillip" "Springfield" "Sunshine Coast" "Blackwood" "Chatswood" "Belconnen" "Fitzroy" "Fortitude Valley" "Auchenflower" "Casuarina" "Elizabeth Vale" "Mlton" "Mawson Lakes" "Archerlield" "Daw Pk" "Broadmeadows" {
    replace city = "`c'" if strpos(affiliation, "`c'") >0 & country == "Australia" & mi(city)
    }

    foreach c in `india_cities' {
       replace city = "`c'" if strpos(affiliation, "`c'") > 0 & country == "India" 
    }
    replace city = "Indi" if strpos(affiliation, "Indi,")>0 & country == "India" & mi(city)
    foreach c in "Manipal" "Sawangi" "Gurugram" "Bengalore" "Trivandrum"  "Sawangi" "Gurugram" "Pondicherry" "Ahmadabad" "Madras" "Kochi" "Gotri" "Gandhinagar" "Nasik" "Midnapore" "Rourkela" "Baroda" "Gurugam" "Sevagram" "Kurnool" "Mewat" "Kolencherry" "Bathinda" "Bombay" "Mysuru" "Udupi" "Suri" "Kolkata" "Curugram"  "Alappuzha" "Gurugrain" "Guragon" "Gadchiroli" "Dispur" "Gauhati" "Kozikhode" "Angamaly" "Kottyam" "Perinthalmana" "Rangareddy" "Vijaywada" "Porvorim" "Sufi" "Sangath" "Shahdara" "Mookkannur" "Ahmednagar" "Ernakulam" "Vishakhapatnam" "Mahara" "Davangere" "Socorro" "Bengarulu" "Bardez" "Gaziabad" "Chakradhapur" "W Bengal" "Sneha" {
       replace city = "`c'" if strpos(affiliation, "`c'") > 0 & country == "India" 
    }
    replace city = "Mumbai" if strpos(affiliation, "Mumbay")>0 & country ==  "India"
    replace city = "Mumbai" if strpos(affiliation, "Mimbai")>0 & country ==  "India"
    replace city = "Kolkata" if strpos(affiliation, "Kolkota")>0 & country ==  "India"

    replace city = "Munich" if strpos(affiliation, "Munchen") > 0 & country == "Germany" & mi(city)
    replace city = "Munich" if strpos(affiliation, "Neuherberg") > 0 & country == "Germany" & mi(city)
    replace city = "Munich" if strpos(affiliation, "Muenchen") > 0 & country == "Germany" & mi(city)
    replace city = "Tel Aviv" if strpos(affiliation, "Tel-Aviv") > 0 & mi(city)

    foreach c in "Mizan Teferi" "Debremarkos" "Debre Berhan" "Arba Minch" "Ambo" "Dessie" "Nekemte" "Wolaita Sodo" "Dilla" "Jimma" "Geneva" "Frankfurt" "Marburg" "Cologne" "Giessen" "Ludwigshafen" "Ingelheim" "Grosshansdorf" "Biberach" "Bad Kosen" "Martinsried" "Berg" "Neuherberg" "Birkenfeld" "Plon" "Homberg" "Limburg" "Bad Krozingen" "Borstel" "Bernau" "Ainring" "Bad Berka" "Bad Bevensen" "Grunheide" "Leibniz" "Brandenburg Havel" "Beelitz" "Aarhus" "Hillerod" "Hellerup" "Koge" "Clermont Ferrand" "Clermont Ferrand" "Gencay" "St Etienne" "St Denis" "Boulogne" "Boulogne" "St Maurice" "St Denis" "Le Kremlin Bicetre" "St Cloud" "St Pierre" "St Louis" "Antwerp" "Ghent" "Louvain" "Alken" "Hong Kong" "Xinxiang" "Xian" "Xuzhou" "Ganzhou" "Maoming" "Yaan" "Macau" "Chongzhou" "Mianzhu" "Huludao" "Shandong" "Luzhou" "Longyan" "Kaizhou" "Xingyi" "Tongling" "Liaoling" "Yunnan" "Guizhou" "huaian" "Liaoning" "Lianyungang" "Liuzhou" "Puer" "Zhongwei" "Huawei" "Qingxu" "Garching " "Oberpfaffenhofen" "Munich" "Walldof" "Gottingen" "Munster" "Stechlin" "Tuebingen" "Julich" "Heidelberg" "Crete" "Montreal" "Mekelle" "Debre Markos" "Samara" "St Petersburg" "Gothenburgh" "Rio De Janeiro" "Lodz" "Dar Es Salaam" "Wroclaw" "Seville" "Jazan" "Mansoura" "Palikir" "Mansoura" "DEM REP" "Alma Ata" "St John" "Abidjan" "Soborg" "Dubai" "Manhica" "Abu Dhabi" "Bilthoven" "Cheongju" "Chandigarh" "Gothenburg" "Chilly Mazarin" "Peradeniya" "Sudbury" "Bandar Tun Razak" "Mtubatuba" "Queretaro" "Santo Domingo" "Delhi" "Tel Hashomer" "Nablus" "St Gallen" "Safat" "Birzeit" "Ramallah" "Mysore" "Baracaldo" "Gentofte" "Goyang" "Krems" "Minsk" "New Delhi" "Kubang Kerian" "Bonheiden" "Hail" "Shahrekord" "Jaipur" "Maragheh" "Ikoyi" "Bhubaneswar" "Swansea" "Bialystok" "Tromso" "Tirunelveli" "Chitwan" "Dharan" "Fajara" "Kharkov" "San Sebastian" "Fife" "Thiruvarur" "Woldia" "Al Khuwair" "Holbaek" "Lucknow" "Nizhnii Novgorod" "Oporto" "Port Au Prince" "Rehovot" "Tucuman" "Ramtha" "Wolkite" "Lalitpur" "Hail" "Quarter" "Bale Robe" "Galway" "Ivano Frankivsk" "Maragheh" "Pulawy" "Shertogenbosch" "Viangchan" "Gadong" "Beer Sheva" "Bobo Dioulasso" "Bhubaneswar" "Cherbourg" "Taoyuan" "Ife" "Kolkata" "Aksum" "Vijayapur" "Sulaimaniyah" "Shahroud" "Sharjah" "Al Ain" "Gjovik" "Gyeongju" "Jahram" "Kasaragod" "Jigjiga" "Hradec Kralova"  {
        replace city = "`c'" if strpos(affiliation, "`c'") >0 & mi(city)
    }
    replace city = substr(strtrim(edit_affiliation), 1, strlen(strtrim(edit_affiliation))-1) if mi(city) & strpos(strtrim(edit_affiliation), ",") == strlen(strtrim(edit_affiliation))
    save ${temp}/cleaned_cities_`samp', replace
     
    keep pmid which* authors* country institution zip us_state city
    drop authors
    sreshape long authors, i(pmid which_affil_grp which_affil country institution zip us_state city) j(which_author) missing(drop)
    hashsort pmid authors
    drop which_affil_grp
    bys pmid authors: gen id_tmp = _n == 1
    bys pmid: replace which_author = sum(id_tmp)
    bys pmid which_author which_affil: replace id_tmp = _n == 1
    bys pmid which_author : replace which_affil = sum(id_tmp)
    compress ,nocoalesce
    save ${temp}/cleaned_wos_`samp', replace
end

program combine_insts
    syntax, samp(str)
    use ${temp}/cleaned_wos_`samp', clear
    contract institution
    save ${temp}/`samp'_insts, replace
end

program create_inst_xwalk
    use ${temp}/all_insts, clear
    gen new_inst = ""
    replace new_inst = subinstr(institution, "Univ", "University", .) if (strpos(institution, "Univ ")>0 | strpos(institution, " Univ")>0)&strpos(institution, "University")==0

end
main
