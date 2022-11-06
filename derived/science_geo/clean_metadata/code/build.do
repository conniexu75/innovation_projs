set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000

program main
global samp select_jrnl
foreach type in  basic translational { 
    append_metadata, data(`type')
    clean_mesh, data(`type')
    clean_date, data(`type')
    clean_journal, data(`type')
    clean_pubtype, data(`type')
    clean_authors, data(`type')
    clean_affls, data(`type')
    save ../temp/pre_reshape_`type'_${samp}, replace
    reshape_mult_affiliations, data(`type')
    reshape_mesh_terms, data(`type')
    clean_geo_affls, data(`type')
}
end

program append_metadata
    syntax, data(str)
	local filelist: dir "../external/samp" files "`data'_${samp}*"
	local i = 1
	foreach file of local filelist {
		import delimited pmid date mesh journal affil athrs pt gr using "../external/samp/`file'", clear
		tostring pmid, replace
		drop if inlist(pmid, "pmid", "v1", "NA")
		destring pmid, replace
		local name = subinstr("`file'",".csv","",.)
		local namelist `namelist' `name'
        compress, nocoalesce
		save ../temp/`name', replace 
	} 
	clear 
	foreach file of local namelist {
		append using ../temp/`file'
	}
    compress, nocoalesce
    gduplicates drop pmid, force
	save "../output/master_`data'_${samp}_appended.dta", replace
end

program clean_mesh
    syntax, data(str)
    use ../output/master_`data'_${samp}_appended, clear
	gen mesh_na = mesh == "NA"
	tab mesh_na
    drop mesh_na
	replace mesh = subinstr(mesh, char(34), "", .)
    replace mesh = subinstr(mesh, "<MeshHeadingList>","",.)
    replace mesh = subinstr(mesh, "</MeshHeadingList>","",.)
	split mesh, p("</MeshHeading>")	
	rename mesh raw_mesh
	gegen nterms = noccur(raw_mesh), string("<MeshHeading>")
	qui sum nterms
	local max_nterms = r(max)
	forval x=1/`max_nterms' {
        replace mesh`x' = "" if strpos(mesh`x', "MajorTopicYN=Y") == 0
        cap assert mi(mesh`x')
        if !_rc {
            drop mesh`x'
        }
        cap gen descriptor_start = strpos(mesh`x', "<DescriptorName")+42
        cap gen descriptor_end  = strpos(mesh`x', "</DescriptorName")
        cap gen descriptor_len = descriptor_end - descriptor_start
        cap gen desc_mesh`x' = substr(mesh`x', descriptor_start, descriptor_len)
        cap replace mesh`x' = subinstr(mesh`x',substr(mesh`x',1, descriptor_end+16), "", .)
        cap drop descriptor*
        cap rename mesh`x' mesh`x'_
        cap split mesh`x'_, p("</QualifierName>")
        cap rename mesh`x'_ raw_mesh`x'
    }
    qui ds mesh*_*
    foreach var in `r(varlist)' {
        replace `var' = "" if strpos(`var', "MajorTopicYN=N") > 0
        cap gen maj_start = strpos(`var', "MajorTopicYN=Y")
        cap gen maj_len = strlen(`var') - (maj_start + 15)
        cap replace `var' = substr(`var', maj_start + 15, maj_len + 1) if maj_start > 0
        cap drop maj_*
        local prefix = substr("`var'", 1,strpos("`var'", "_")-1)
        cap replace `var' = desc_`prefix' + ", " + `var' if !mi(`var')
        cap assert(mi`var')
        if !_rc {
            drop  `var'
        }
    }
    qui ds mesh*_*
    foreach var in `r(varlist)' {
        local prefix = substr("`var'", 1,strpos("`var'", "_")-1)
        cap replace desc_`prefix' = "" if !mi(`var')
    } 
    drop raw_* 
    rename (desc_mesh*) (mesh*_0)
    qui compress mesh*, nocoalesce
	/*local max_1 = `max_nterms' - 1
	forval i = 1/`max_1' {
		local j = `i' + 1
		forval k = `j'/`max_nterms' {
			qui replace mesh`i' = mesh`k' if mesh`i' == "" & mesh`k' != ""
			qui replace mesh`k' = "" if mesh`k' == mesh`i'
		}
		qui compress mesh`i', nocoalesce
	}*/
    save ../temp/cleaned_mesh_`data'_${samp}, replace
    drop mesh*
end

program clean_date
    syntax, data(str)
	rename date date_raw
	gen start = strpos(date_raw, "<Year>") + 6
	gen y = substr(date_raw, start, 4)
	destring y, replace
	drop start

	gen start = strpos(date_raw, "<Month>") + 7
	gen m = substr(date_raw, start, 2)
	destring m, replace
	drop start

	gen start = strpos(date_raw, "<Day>") + 5
	gen d = substr(date_raw, start, 2)
	destring d, replace
	drop start

	gen date = mdy(m, d, y)
	format date  %td
	drop d m y
    save ../temp/cleaned_date_`data'_${samp}, replace
end

program clean_journal
    syntax, data(str)
	gen journal_na = journal == "NA"
	tab journal_na

	ren journal journal_raw
	gen start = strpos(journal_raw, "<Title>") + 7
	gen end = strpos(journal_raw, "</Title>")
	gen len = end-start

	gen journal = substr(journal_raw, start, len) if start != 7
	drop start end len

	gen start = strpos(journal_raw, "<ISOAbbreviation>") + 17
	gen end = strpos(journal_raw, "</ISOAbbreviation>")
	gen len = end-start

	gen journal_abbr = substr(journal_raw, start, len) if start != 17
	drop start end len
    if "`data'" == "basic" {
        keep if inlist(journal_abbr, "Cell", "Nature", "Science")
    }
    save ../temp/cleaned_jrnl_`data'_${samp}, replace
end

program clean_pubtype
    syntax, data(str)
    use ../temp/cleaned_jrnl_`data'_${samp},clear 
	gen pt_na = pt == "NA"
	tab pt_na
    drop pt_na
	replace pt = subinstr(pt, char(34), "", .)
    replace pt = subinstr(pt, "</PublicationTypeList>", "",.)
    replace pt = subinstr(pt, "<PublicationTypeList> ", "",.)
    split pt, p("</PublicationType>")
	ren pt raw_pt
    qui ds pt*
    local pts `r(varlist)'
    local num_pts : list sizeof pts
    gen start = .
    forval i = 1/`num_pts' { 
        replace start = strpos(pt`i', ">")+1
        replace pt`i' = substr(pt`i', start, strlen(pt`i')-start+1)
    }
    gen to_drop = 0
    gen pub_type = ""
    forval i = 1/`num_pts' {
       replace to_drop = 1 if inlist(pt`i', "Autobiography", "Biography", "Case Reports", "Classical Article", "Comment", "Comparative Study", "Congress", "Dataset", "Editorial")
       replace to_drop = 1 if inlist(pt`i', "Evaluation Study", "Historical Article", "Introductory Journal Article", "Letter" , "News", "Clinical Conference", "Practice Guideline", "Guideline")
       replace to_drop = 1 if inlist(pt`i', "Meta-Analysis", "Personal Narrative", "Portrait", "Published Erratum", "Retracted Publication", "Review", "Video-Audio Media", "Webcast", "Legal Case")
       replace to_drop = 1 if inlist(pt`i', "Retraction of Publication", "Twin Study", "Systematic Review", "Address" , "Bibliography", "Consensus Development Conference" , "Consensus Development        Conference, NIH")
       replace to_drop = 1 if inlist(pt`i', "Corrected and Republished Article", "Duplicate Publication","Interactive Tutorial", "Expression of Concern", "Lecture","Multicenter Study", "Patient          Education Handout" , "Validation Study") 
        replace pub_type = "Journal Article" if pt`i' == "Journal Article"
        replace pub_type = "Clinical Study" if strpos(pt`i', "Clinical Study")
        replace pub_type = "Clinical Trial" if strpos(pt`i', "Clinical Trial")
        replace pub_type = pt`i' if mi(pub_type)
    }
	drop if to_drop == 1
    save ../temp/cleaned_pubtype_`data'_${samp}, replace
end

program clean_authors
    syntax, data(str)
	use ../temp/cleaned_pubtype_`data'_${samp},clear 
	rename athrs athrs_raw
	gen athrs = athrs_raw
	replace athrs = subinstr(athrs, char(34), "", .)
	replace athrs = subinstr(athrs, "<AuthorList CompleteYN=Y>","",.)
	split athrs, p("</Author> ")
	gegen num_athrs = noccur(athrs), string("<Author ValidYN=Y>")
	qui sum num_athrs
	local max_authors = r(max)
	foreach var in last_name first_name affiliation {
		gen `var'_start = .
		gen `var'_end = . 
	}
	forval i = 1/`max_authors' {
		replace athrs`i' = subinstr(athrs`i', "<Author ValidYN=Y>    ","",.)
		replace last_name_start = strpos(athrs`i', "<LastName>") + 10
		replace last_name_end = strpos(athrs`i', "</LastName>")
		gen last_name`i' = substr(athrs`i', last_name_start, last_name_end-last_name_start)
		replace first_name_start = strpos(athrs`i', "<ForeName>") + 10
		replace first_name_end = strpos(athrs`i', "</ForeName>")
		gen first_name`i' = substr(athrs`i', first_name_start, first_name_end-first_name_start)
		replace affiliation_start = strpos(athrs`i', "<AffiliationInfo>") + 17
		replace affiliation_end = strrpos(athrs`i', "</AffiliationInfo>")
		gen affiliation`i' = substr(athrs`i',affiliation_start, affiliation_end- affiliation_start)
		gegen num_affiliations`i' = noccur(athrs`i'), string("<Affiliation>")
	}
    save ../temp/cleaned_authors_`data'_${samp}, replace
end

program clean_affls
    syntax, data(str)
    use ../temp/cleaned_authors_`data'_${samp},clear 
    missings dropvars, force
	foreach var in last_name first_name affiliation {
		cap drop `var'_start `var'_end 
	}
	
	qui ds affiliation*
	foreach var in `r(varlist)' {
		rename `var' `var'_
		split `var'_, p("</AffiliationInfo>")

		rename `var'_ `var'_raw
	}
	qui ds affiliation*
	foreach var in `r(varlist)' {
		replace `var' = subinstr(`var', "<AffiliationInfo>      <Affiliation>","",.)
		replace `var' = subinstr(`var', "</Affiliation>    </AffiliationInfo>","",.)
		replace `var' = subinstr(`var', "<Affiliation>","",.)
		replace `var' = subinstr(`var', "</Affiliation>","",.)
		replace `var' = subinstr(`var', "</AffiliationInfo>","",.)
		replace `var' = subinstr(`var', "<AffiliationInfo>","",.)
	}
	gegen most_affiliations = rowmax(num_affiliations*)
end

program reshape_mult_affiliations
    syntax, data(str)
    use ../temp/pre_reshape_`data'_${samp}, clear
    keep if pub_type == "Journal Article"
    sum most_affiliations
    local most = r(max)
    forval i = 1/`most' {
        local vars `vars' affiliation@_`i'
    }
	cap drop *_raw athrs* num_affiliations* journal_na mesh* gr num_athrs nterms pub_type most_affiliations 
	*keep pmid *name* affiliation*
	sreshape long last_name first_name `vars', i(pmid journal date journal_abbr) j(which_athr) missing(drop all) 	
    drop if mi(first_name) & mi(last_name)
	sreshape long affiliation_, i(pmid which_athr last_name first_name) j(which_affiliation) missing(drop)
	rename affiliation_ affiliation
	*drop if mi(affiliation)
    compress, nocoalesce
	save ../output/pmid_author_affiliation_list_`data'_${samp}, replace		
end

program reshape_mesh_terms
    syntax, data(str)
    *use ../temp/pre_reshape_`data'_${samp}, clear
    *keep if pub_type == "Journal Article"
    use ../temp/cleaned_mesh_`data'_${samp}, clear
    keep pmid mesh*
    cap drop mesh_na mesh_raw
    local max = 0
    qui ds mesh*
    local vars `r(varlist)'
    foreach var in `vars' {
       local suf = substr("`var'", strpos("`var'", "_")+1, strlen("`var'")-strpos("`var'","_"))
       if `suf' > `max' {
           local max = `suf'
       }
    }
    local vars ""
    forval i = 0/`max' {
        local vars `vars' mesh@_`i'
    }
    sreshape long `vars', i(pmid) j(which_mesh) missing(drop)
    sreshape long mesh_, i(pmid which_mesh) j(add_mesh) missing(drop)
    drop which_mesh add_mesh
    bys pmid: gen which_mesh = _n
    rename mesh_ mesh
    replace mesh = subinstr(mesh, "&amp", "&", .)
    compress, nocoalesce
    save ../output/major_mesh_terms_`data'_${samp}, replace
end

program clean_geo_affls
    syntax, data(str)
    import delimited ../external/geo/country_list.csv, varnames(1) clear
    qui glevelsof name, local(country_names)
    qui glevelsof code, local(country_abbrs)
    gen no_comma = substr(name,1,strpos(name,",")-1)
    preserve
    drop if mi(no_comma) | no_comma == "Korea"
    glevelsof no_comma, local(more_country_names)
    restore
    save ../temp/countries, replace

    import delimited ../external/geo/us_cities_states_counties.csv, varnames(1) clear
    glevelsof statefull, local(state_names)
    glevelsof stateshort, local(state_abbr)
    gen city_state = city + ", " + stateshort + ", " + statefull
    qui glevelsof city_state, local(uscity_names)
    qui glevelsof city, local(uscity)
    foreach s in `state_abbr' {
        qui glevelsof city, local(`s'_cities)
    }
    save ../temp/us_cities_states_counties, replace 
    gcontract stateshort statefull
    drop _freq
    drop if mi(stateshort)
    save ../temp/state_abbr_xwalk, replace
    
    import delimited ../external/geo/world-cities_csv.csv, varnames(1) clear
    keep name country
    rename name city
    replace city = ustrregexra(ustrnormalize(city,"nfd"), "\p{Mark}", "")
    gen city_name = city + ", " + country
    drop if country == "United States"
    qui glevelsof city_name, local(big_country)
    save ../temp/world_cities, replace 
    
    import excel ../external/geo/ZIP_CBSA_122021.xlsx, firstrow clear
    keep zip cbsa usps_zip_pref_city usps_zip_pref_state
    replace usps_zip_pref_city = strproper(usps_zip_pref_city)
    save ../temp/zip_city, replace
    gcontract zip usps_zip_pref_city usps_zip_pref_state
    rename usps_zip_pref_state state_zip
    rename usps_zip_pref_city city_zip 
    drop _freq
    save ../temp/list_zips, replace

    import delimited ../external/geo/wikipedia-iso-country-codes.csv, clear
    keep english alpha*
    rename (englis alpha2code alpha3code) (country_name alpha2 alpha3)
    save ../temp/country2_3_xwalk, replace

    import delimited ../external/geo/research_institution_rank.csv, clear
    drop *rank*
    replace institution = subinstr(institution, "*", "", .)
    replace institution = strtrim(institution)
    keep institution country 
    rename country alpha3
    merge m:1 alpha3 using ../temp/country2_3_xwalk, keep(1 3) nogen
    drop alpha3
    rename alpha2 country
    save ../temp/list_of_institutions, replace

    import delimited ../external/geo/world-universities.csv, clear
    keep v1 v2 
    rename (v1 v2) (country institution)
    order institution country 
    save ../temp/universities, replace
    append using ../temp/list_of_institutions
    gduplicates drop institution country , force
    replace institution = subinstr(institution, `"""', "", .)
    rename country code
    merge m:1 code using ../temp/countries, assert(1 2 3) keep(1 3) nogen 
    replace country_name = no_comma if !mi(no_comma)
    replace country_name = name if mi(country_name)
    qui glevelsof institution, local(institutions)
    save ../temp/institutions, replace 

    gduplicates tag institution, gen(dup)
    keep if dup == 0 
    drop dup 
    save ../temp/unique_institutions, replace

    use ../output/pmid_author_affiliation_list_`data'_${samp}, clear
    replace affiliation = subinstr(affiliation , "&amp;","&",.)
    replace affiliation = "" if strpos(affiliation, "listed in the supplementary materials") > 0 | strpos(affiliation, "supplementary materials") > 0

    replace affiliation = ustrregexra(ustrnormalize(affiliation,"nfd"), "\p{Mark}", "")
    replace affiliation = subinstr(affiliation, "é", "e",.)
    replace affiliation = subinstr(affiliation, "Univ.", "University",.)
    replace affiliation = subinstr(affiliation, "Ã¼", "u",.)
    replace affiliation = subinstr(affiliation, "A¼", "u",.)
    replace affiliation = subinstr(affiliation, "Ã¤", "a", .)
    replace affiliation = subinstr(affiliation, "A¡", "a", .)
    replace affiliation = subinstr(affiliation, "A³","o",.)
    replace affiliation = subinstr(affiliation, "A¯", "u", .)
    replace affiliation = subinstr(affiliation, "A£", "a", .)
    replace affiliation = subinstr(affiliation, "A§", "c", .)
	replace affiliation = subinstr(affiliation, "A§", "c", .)
	replace affiliation = subinstr(affiliation, "A´", "o", .)
	replace affiliation = subinstr(affiliation, "A¤", "a", .)
	replace affiliation = subinstr(affiliation, "A¶", "o", .)
	replace affiliation = subinstr(affiliation, "A©", "e", .)
	replace affiliation = subinstr(affiliation, "A¥", "a", .)
    replace affiliation = subinstr(affiliation, "A¢", "a", .)
    replace affiliation = subinstr(affiliation, "A±", "u", .)

	
    split affiliation , parse("; " "[2]" "[3]" "[4]" "[5]" "[6]" "[7]")
    rename affiliation affiliation0
    drop affiliation0
	sreshape long affiliation, i(pmid which_athr which_affiliation last_name first_name) j(add_to_affiliation) missing(drop)
    replace add_to_affiliation = add_to_affiliation - 1
    replace which_affiliation = which_affiliation + add_to_affiliation
    replace affiliation= subinstr(affiliation, "1] ", "", .)
    save ../temp/pmid_author_affiliation_list_expanded_`data'_${samp}, replace
    drop add_to_affiliation

    gen edit_affiliation = affiliation

    gen country = "" 
    gen ncountries = 0
    foreach c in " U.K." " UK." " USA." " UK " " USA "  " USA" "England" `country_names' `more_country_names' "South Korea" "Republic of Korea" " USSR" " Russia" " UK" {
        qui replace ncountries = ncountries + 1 if strpos(affiliation, "`c'") > 0
        qui replace country = "`c'" if strpos(affiliation, "`c'") > 0 & country == ""
        qui replace country = "`c'" if country != "" & strpos(affiliation, "`c'") > 0 & strpos(affiliation, "`c'") > strpos(affiliation, country)
        if "`c'" == "Lebanon" {
            qui replace country = "United States" if strpos(affiliation, "Dartmouth") > 0
        }
        if "`c'" == "Israel" {
            qui replace country = "United States" if strpos(affiliation, "Beth Israel") > 0
        }
        if "`c'" == "India" {
            qui replace country = "United States" if strpos(affiliation, "Indiana") > 0
        }
        if "`c'" == "Jersey" {
           qui replace country = "United States" if substr(affiliation, strpos(affiliation, "`c'")-4,3) == "New" & country == "Jersey"
        }
        if "`c'" == "Georgia" {
           qui replace country = "United States" if strpos(affiliation, "Atlanta")>0  |  strpos(affiliation, "Athens")>0 | strpos(affiliation, "Augusta") > 0
        }
    }
    replace country = "Taiwan" if strpos(affiliation, "Taiwan") >0
    replace country = "Germany" if strpos(affiliation, ", FRG") > 0 
    replace country = "Germany" if strpos(affiliation , "Max-Planck")>0 & mi(country)
    replace country = "Germany" if strpos(affiliation , "Max Planck")>0 & mi(country)
    replace affiliation = subinstr(affiliation, "Max-Planck", "Max Planck", .)
    qui replace edit_affiliation = subinword(edit_affiliation, country, "",.) if !mi(country)
    replace country = "South Korea" if country == "Republic of Korea"
    replace country = "South Korea" if country == "Korea, Republic of"
    replace country = "South Korea" if strpos(affiliation, "Korea")>0
    replace country = "South Korea" if mi(country) & strpos(affiliation, "Seoul") > 0
    replace country = "Japan" if mi(country) & strpos(affiliation, "Tokyo") > 0
    replace country = "Russia" if country == "Russian Federation"
    replace country = "Russia" if country == "USSR"
    replace country = "United Kingdom" if inlist(country,  " U.K.", " UK.", " UK ", "England") 
    replace country = "United Kingdom" if strpos(affiliation, "Scotland") > 0
    replace country = "United States" if inlist(country, " USA.", " USA ", " USA") 
    replace country = "United States" if mi(country) & (strpos(affiliation, "Harvard University") > 0 | strpos(affiliation, "Stanford University") > 0 | strpos(affiliation, "Johns Hopkins University")> 0)
    save ../temp/cleaned_countries_`data'_${samp}, replace
    
    use ../temp/cleaned_countries_`data'_${samp}, clear
    gen us_state = ""
    gen nstates = 0
    foreach s in `state_names' {
        qui replace nstates = nstates + 1 if strpos(affiliation, "`s'") > 0
        qui replace country = "United States" if strpos(affiliation, "`s'") > 0 & country == ""
        qui replace us_state = "`s'" if country == "United States" & strpos(affiliation, "`s'") > 0
        qui replace us_state = "`s'" if us_state!= "" & strpos(affiliation, "`s'") > 0 & strpos(affiliation, "`s'") > strpos(affiliation, us_state)
    }
    qui replace edit_affiliation = subinstr(edit_affiliation, us_state, "",.) if !mi(us_state)
    gen statefull = us_state 
    merge m:1 statefull using ../temp/state_abbr_xwalk, assert(1 2 3) keep(1 3) nogen
    replace us_state = stateshort if !mi(statefull)
	replace us_state = "MO" if strpos(affiliation, "Washington University") > 0 & strpos(affiliation, "Western Washington University") == 0 & strpos(affiliation, "George Washington University") == 0 & strpos(affiliation, "Central Washington University") > 0
	replace us_state = "DC" if strpos(affiliation, " DC ") > 0 & country == "United States"
    replace us_state = "NJ" if strpos(affiliation, "Princeton University") > 0
    replace us_state = "WA" if strpos(affiliation, "Alaska Fisheries Science Center") > 0
    save ../temp/cleaned_states_`data'_${samp}, replace

    use ../temp/cleaned_states_`data'_${samp}, clear
    gen city = ""
    local i = 1
    foreach c in `uscity_names' { 
        di "`i'"
        local city_name = substr("`c'", 1, strpos("`c'",",")-1)
        local state = substr("`c'", strpos("`c'",",")+2, strlen("`c'")) 
        local state_short = substr("`state'",1,2)
        local state_long = substr("`state'", strpos("`state'", ",")+2, strlen("`state'"))
        local city_state = substr("`c'",1, strpos("`c'", ",")+3)
        local city_statelon = "`city_name'" + ", " + "`state_long'"
        qui replace country = "United States" if strpos(affiliation, "`city_state'") > 0 & country == ""
        qui replace us_state = "`state_short'" if country == "United States" & strpos(affiliation, "`city_state'") > 0 & us_state== ""
        qui replace city = "`city_name'" if strpos(affiliation, "`city_state'") > 0 & country == "United States"
        qui replace country = "United States" if strpos(affiliation, "`city_statelon'") > 0 & country == ""
        qui replace us_state = "`state_short'" if country == "United States" & strpos(affiliation, "`city_statelon'") > 0 & us_state== ""
        qui replace city = "`city_name'" if strpos(affiliation, "`city_statelon'") > 0 & country == "United States"
        qui replace city = "`city_name'" if  strpos(affiliation, "`city_name'") > 0 & city == "" & us_state == "`state_short'" & !inlist("`city_name'", "Center", "University", "LA")
        local i = `i' + 1 
    }
    replace city = "New York" if strpos(affiliation, "New York, New York") > 0 | strpos(affiliation, "New York, NY") > 0 
    replace city = "Chevy Chase" if strpos(affiliation, "Chevy Chase") > 0 & us_state == "MD" 
    replace city = "Stanford" if strpos(affiliation, "Stanford University") > 0 
    replace city = "Houston" if strpos(affiliation, "Anderson Cancer Center") > 0  | strpos(affiliation, "M.D. Anderson") > 0 | strpos(affiliation, "M. D. Anderson") > 0 | strpos(affiliation, "MD Anderson") > 0
	replace city = "Saint Louis" if strpos(affiliation, "Washington University") > 0 & strpos(affiliation, "Western Washington University") == 0 & strpos(affiliation, "George Washington University") == 0
	replace city = "Saint Paul" if (strpos(affiliation, "St. Paul") | strpos(affiliation, "St Paul")) > 0 & us_state == "MN" 
	replace city = "Saint Louis" if (strpos(affiliation, "St. Louis") | strpos(affiliation, "St Louis")) > 0 & us_state == "MO" 
    replace city = "Princeton" if strpos(affiliation, "Princeton University") > 0
    foreach s in `state_abbr' {
        replace us_state = "`s'" if country == "United States" & strpos(affiliation, ", `s'") > 0 & mi(us_state)
    }
    // do zip
    gen zip = ustrregexs(0) if ustrregexm(affiliation, "[0-9][0-9][0-9][0-9][0-9][\.]") & country == "United States"
    replace zip = ustrregexs(0) if ustrregexm(affiliation, "[0-9][0-9][0-9][0-9][0-9][\-]") & country == "United States" & mi(zip)
    replace zip = ustrregexs(0) if ustrregexm(affiliation, "[0-9][0-9][0-9][0-9][0-9][\,]") & country == "United States" & mi(zip)
    replace zip = ustrregexs(0) if ustrregexm(affiliation, "[a-zA-Z]+[\s][0-9][0-9][0-9][0-9][0-9][\,]") & country == "United States" & mi(zip)
    qui gen zip_len = strlen(zip) 
    assert zip_len == 0 | zip_len == 6
    replace zip =  substr(zip, 1, strlen(zip)-1)
    replace zip = "92093" if zip == "02093"
    replace zip = "92037" if zip == "10010" & strpos(affiliation , "North Torrey Pines Road")> 0
    merge m:1 zip using  ../temp/list_zips, assert(1 2 3) keep(1 3) 
    replace us_state = state_zip if mi(us_state) & !mi(state_zip)
    replace country = "United States" if !mi(us_state)
    replace country = "United States" if mi(city) & !mi(city_zip)
    replace city = city_zip if mi(city) & !mi(city_zip)
    save ../temp/cleaned_uscities_`data'_${samp}, replace
    *replace us_state = state_zip if !mi(zip) & _merge == 3 
    *replace city = city_zip if !mi(zip) & _merge == 3
    // world cities
    foreach c in `big_country' {
        local city_name = substr("`c'", 1, strpos("`c'",",")-1)
        local country_name = substr("`c'", strpos("`c'",",")+2, strlen("`c'")) 
        replace country = "`country_name'" if strpos(affiliation, "`c'") > 0 & country == ""
        replace city = "`city_name'" if strpos(affiliation, "`c'") > 0 & city == ""
        replace city = "`city_name'" if  strpos(affiliation, "`city_name'") > 0 & city == "" & country == "`country_name'" 
    }
	
	// US fixes
	replace city= "Philadelphia" if strpos(affiliation , "University of Pennsylvania")>0
    replace city = "University Park" if strpos(affiliation, "Pennsylvania State University") > 0
    replace city = "King of Prussia" if strpos(affiliation, "King of Prussia, Pennsylvania") > 0
    replace city = "West Point" if strpos(affiliation, "West Point, Pennsylvania") >0
    replace city = "Philadelphia" if strpos(affiliation, "Philadelphia, Pennsylvania") > 0 | (strpos(affiliation, "Philadelphia") > 0 & us_state == "PA")
    replace city = "Piitsburgh" if strpos(affiliation, "Pittsburgh, Pennsylvania") > 0
	// UK fixes
    replace city = "Cambridge" if strpos(affiliation, "Cambridge, UK") > 0
    replace country = "United Kingdom" if strpos(affiliation, "Cambridge, UK") > 0
    replace country = "United Kingdom" if strpos(affiliation, "University of Cambridge") > 0
    replace city = "Cambridge" if strpos(affiliation, "University of Cambridge") > 0
    replace city = "Hinxton" if strpos(affiliation, "Hinxton") > 0 & mi(city)
    replace city = "Oxford" if strpos(affiliation, "Oxford, UK") > 0
    replace country = "United Kingdom" if strpos(affiliation, "Oxford, UK") > 0
    replace country = "United Kingdom" if strpos(affiliation, "University of Oxford") > 0
	replace city = "Oxford" if strpos(affiliation, "University of Oxford") > 0
    replace city = "London" if strpos(affiliation, "London") > 0 & strpos(affiliation, "UK") >0 & mi(city)
    replace city = "Edinburgh" if strpos(affiliation, "Edinburgh") > 0  & country == "United Kingdom" & mi(city)
    replace city = "Glasgow" if strpos(affiliation, "Glasgow") > 0 & country == "United Kingdom" & mi(city)
	
	//Germany fixes
	replace city = "Cologne" if strpos(affiliation, "Cologne, Germany") > 0  & mi(city)
    replace city = "Garching bei Munchen" if strpos(affiliation, "Garching") > 0 & mi(city)
    replace city = "Martinsried" if strpos(affiliation, "Martinsried") > 0 & mi(city)
	replace city = "Oberpfaffenhofen" if strpos(affiliation, "Oberpfaffenhofen, Germany") > 0 
	replace city = "Munich" if strpos(affiliation, "Munchen") > 0 & country == "Germany"
    replace city = "Munich" if strpos(affiliation, "Neuherberg") > 0 & country == "Germany"
    replace city = "Munich" if strpos(affiliation, "Muenchen") > 0 & country == "Germany"
    replace city = "Walldof" if strpos(affiliation, "Walldorf") > 0 & country == "Germany"
    replace city = "Gottingen" if strpos(affiliation, "Goettingen") > 0 & country == "Germany"
    replace city = "Ludwigshafen" if strpos(affiliation, "Ludwigshafen") > 0 & country == "Germany"
    replace city = "Frankfurt" if strpos(affiliation, "Frankfurt") > 0 & country == "Germany"
    replace city = "Marburg" if strpos(affiliation, "Marburg") > 0 & country == "Germany"
    replace city = "Munster" if strpos(affiliation, "Muenster") > 0 & country == "Germany"
    replace city = "Stechlin" if strpos(affiliation, "Stechlin") > 0 & country == "Germany"
    replace city = "Giessen" if strpos(affiliation, "Giessen") > 0 & country == "Germany"
    replace city = "Tuebingen" if strpos(affiliation, "Tuebingen") > 0 & country == "Germany"
    replace city = "Julich" if strpos(affiliation, "Juelich") > 0 & country == "Germany"
    replace city = "Biberach" if strpos(affiliation, "Biberach") > 0 & country == "Germany"

	// other
	replace city = "Tel Aviv" if strpos(affiliation, "Tel-Aviv") > 0 
    replace city = "Heidelberg" if strpos(affiliation, "Heidelberg") >0 | strpos(affiliation, "Heidleberg") > 0
    replace city = "Milano" if strpos(affiliation, "Milan")  & country == "Italy"
    replace city = "Aarhus" if strpos(affiliation, "Aarhus") > 0 & country == "Denmark" & mi(city)
    replace city = "Crete" if strpos(affiliation, "Crete, Greece") > 0 
    replace city = "Montreal" if strpos(affiliation, "Montreal") > 0 & country == "Canada"
    replace city = "Geneva" if strpos(affiliation, "Geneva") > 0 & country == "Switzerland"
    save ../temp/cleaned_cities_`data'_${samp}, replace
   
    use ../temp/cleaned_cities_`data'_${samp}, replace 
    gen institution = ""
    foreach i in `institutions' {
        if !inlist("`i'", "University of Texas", "Broad Institute of MIT and Harvard", "Howard Hughes Medical Institute") {
            cap replace institution = "`i'" if strpos(affiliation, "`i'") > 0 & institution == ""
        }
    }
    gen broad_affl  = 1 if strpos(affiliation, "Broad Institute of MIT and Harvard") > 0 | strpos(affiliation, "Broad Institute") > 0
    replace institution = "Broad" if broad_affl == 1
    gen hmmi_affl  = 1 if strpos(affiliation, "Howard Hughes Medical Institute") > 0 | strpos(affiliation, "HHMI") > 0
	
	// US institutions
    replace institution = "Harvard University" if strpos(affiliation, "Harvard") > 0 & country == "United States"
    replace institution = "Dana Farber Cancer Institute" if strpos(affiliation, "Dana-Farber") > 0 | strpos(affiliation, "Dana Farber") > 0
    replace city = "Boston" if institution == "Dana Farber Cancer Institute"
    replace institution = "Indiana University" if strpos(affiliation, "Indiana University") > 0
    replace institution = "University of Minnesota" if strpos(affiliation, "University of Minnesota") > 0
    replace institution = "University of Wisonsin, Madison" if strpos(affiliation, "University of Wisconsin")>0 & city == "Madison" & mi(institution)
    replace institution = "University of Wisonsin, Oshkosh" if strpos(affiliation, "University of Wisconsin")>0 & city == "Oshkosh" & mi(institution)
    replace institution = "University of Alaska, Fairbanks" if strpos(affiliation, "University of Alaska") > 0 & strpos(affiliation, "Fairbanks") > 0
    replace institution = "University of Nevada, Reno" if strpos(affiliation, "University of Nevada") > 0 & strpos(affiliation, "Reno") > 0
    replace institution = "University of Missouri" if strpos(affiliation, "University of Missouri") > 0 
    replace institution = "University Hospitals Cleveland Medical Center" if strpos(affiliation, "Cleveland") > 0 & strpos(affiliation,"University Hospitals") > 0
    replace institution = "University of Wisconsin, Milwaukee" if strpos(affiliation, "University of Wisconsin")>0 & city == "Milwaukee" & mi(institution)
    replace institution = "Stanford University" if strpos(affiliation, "Stanford") > 0 & country == "United States"
    replace institution = "Yale University" if strpos(affiliation, "Yale") > 0 & country == "United States"
    replace institution = "Johns Hopkins University" if strpos(affiliation, "Johns") > 0 & strpos(affiliation, "Hopkins") > 0 & city == "Baltimore"
    replace institution = "Cornell University" if strpos(affiliation, "Cornell")>0 & us_state == "NY"

    replace institution = "Boston Children's Hospital" if strpos(affiliation, "Boston") > 0 & strpos(affiliation, "Children's")>0 & strpos(affiliation, "Hospital")>0
    replace institution = "Institute for Integrative Genome Biology" if strpos(affiliation ,"Institute for Integrative Genome Biology")> 0
    replace institution = "Allen Institute" if strpos(affiliation, "Allen") > 0 & strpos(affiliation, "Seattle")> 0 
    replace institution = "Manus Biosynthesis" if strpos(affiliation, "Manus Biosynthesis") >0
    replace institution = "Rutgers Univeristy" if inlist(institution, "Rutgers, The State University of New Jersey", "Rutgers, The State University of New Jersey - Camden", "Rutgers, The State University of New Jersey - Newark")
    replace institution = "Rutgers University" if strpos(affiliation, "Rutgers") > 0 & mi(institution) & us_state == "NJ"
    replace institution = "University of Hawaii, Manoa" if strpos(affiliation, "University of Hawai") > 0 & (strpos(affiliation, "noa")>0) & us_state == "HI"
    replace institution = "University of Hawaii, Hanolulu" if strpos(affiliation, "University of Hawai") > 0 & (strpos(affiliation, "Honolulu")>0) & us_state == "HI"
    replace institution = "University of North Carolina at Chapel Hill" if strpos(affiliation, "University of North Carolina") > 0 & strpos(affiliation, "Chapel Hill") > 0
    replace institution = "Memorial Sloan-Kettering Cancer Center" if strpos(affiliation, "Memorial") > 0 & strpos(affiliation, "Sloan") > 0 & strpos(affiliation, "Kettering")>0 & us_state == "NY"
    replace institution = "Washington University in St. Louis" if strpos(affiliation, "Washington University") > 0 & city == "Saint Louis" 
    replace institution = "Stony Brook University" if strpos(affiliation, "Stony Brook") > 0 & us_state == "NY"
    replace institution = "Regeneron" if strpos(affiliation, "Regeneron") > 0
	replace institution = "St. Jude Children's Research Hospital" if strpos(affiliation, "Jude Children's Research Hospital") > 0 
	replace institution = "Verve Therapeutics" if strpos(affiliation, "Verve Therapeutics") > 0 | (strpos(affiliation, "Verve")>0& city=="Cambridge") 

    replace institution = "Plexxikon Inc" if strpos(affiliation, "Plexxikon Inc") > 0
    replace institution = "FORMA Therapeutics" if strpos(affiliation, "FORMA Therapeutics") > 0
    replace institution = "Amyris" if strpos(affiliation, "Amyris")> 0 & us_state == "CA"
    replace institution = "Duke University" if strpos(affiliation, "Duke") > 0 & city == "Durham"
    replace institution = "Koch Institute" if strpos(affiliation, "Koch Institute") & city == "Cambridge"
    replace institution = "University of California, San Francisco" if strpos(affiliation, "Eli and Edythe Broad Center of Regeneration Medicine and Stem Cell Research") > 0
    replace institution = "New York Genome Center" if strpos(affiliation, "New York Genome Center") > 0 
    replace institution = "Vir Biotechnology" if strpos(affiliation, "Vir Biotechnology") > 0
    replace institution = "Genentech" if strpos(affiliation, "Genentech")>0 & us_state == "CA"
    replace institution = "Vanderbilt University" if strpos(affiliation, "Vanderbilt") > 0 & us_state == "TN"
    replace institution = "The Rockefeller University" if strpos(affiliation, "Rockefeller University")>0 & us_state =="NY"
    replace institution = "University of Massachusetts, Amherst" if strpos(affiliation, "University of Massachusetts") > 0 & strpos(affiliation, "Amherst") > 0 
    replace institution = "University of Massachusetts, Boston" if strpos(affiliation, "University of Massachusetts") > 0 & strpos(affiliation, "Boston") > 0 
    replace institution = "Boston Biomedical Research Institute" if strpos(affiliation, "Boston Biomedical Research Institute") > 0
    replace institution = "Dartmouth" if strpos(affiliation, "Dartmouth") > 0 & us_state == "NH"
    replace institution = "SUNY Albany" if strpos(affiliation, "University at Albany") > 0 & us_state == "NY"
    replace institution = "University of Massachusetts Medical School" if strpos(affiliation, "University of Massachusetts Medical") >0
    replace institution = "Oregon Health Sciences University" if strpos(affiliation, "Health")>0 & strpos(affiliation, "Science") > 0 & strpos(affiliation, "University") > 0 & us_state == "OR"
    replace institution = "University of Alabama, Birmingham" if strpos(affiliation, "University of Alabama")> 0& city == "Birmingham"
    replace institution = "New York University" if strpos(affiliation, "NYU") > 0 & city == "New York"
    replace institution = "Virginia Tech" if strpos(affiliation, "Virginia Tech")>0
    replace institution = "10X Genomics" if strpos(affiliation, "10x Genomics") >0 | strpos(affiliation, "10X Genomics") >0
    replace institution = "Johns Hopkins University" if strpos(affiliation, "Lieber") > 0 & city == "Baltimore"
    replace institution = "Frederick National Laboratory" if strpos(affiliation, "Frederick National Laboratory") >0
    replace institution = "Facebook" if strpos(affiliation, "Facebook") >0
    replace institution = "Adrienne Helis Malvin Medical Research Foundation" if strpos(affiliation, "Adrienne Helis Malvin Medical Research Foundation") > 0
    replace institution = "Adimab" if strpos(affiliation, "Adimab") > 0
    replace institution = "Aduro" if strpos(affiliation, "Aduro") > 0
    replace institution = "Agios" if strpos(affiliation, "Agios") >0
    replace institution = "Buck Institute" if strpos(affiliation, "Buck Institute for Research on Aging")>0
    replace institution = "Brotman Baty Institute" if strpos(affiliation, "Brotman Baty Institute") >0
    replace institution = "California Institute for Quantitative Biomedical Research" if strpos(affiliation, "California Institute for Quantitative Biomedical Research")>0
    replace institution = "California Institute for Biomedical Research" if strpos(affiliation, "California Institute for Biomedical Research") >0
    replace institution = "California Institute for Regenerative Medicine" if strpos(affiliation, "California Institute for Regenerative Medicine") >0
    replace institution = "Feinstein Institute for Medical Research" if strpos(affiliation, "Feinstein Institute for Medical Research") >0
    replace institution = "Van Andel Research Institute" if strpos(affiliation, "Van Andel") > 0 & us_state == "MI"
    replace institution = "Wake Forest University" if strpos(affiliation, "Wake Forest") > 0 & us_state == "NC"
    replace institution = "Seattle Children's Research Institute" if strpos(affiliation, "Seattle Children's Research Institute") >0
    replace institution = "La Jolla Institute for Immunology" if strpos(affiliation, "La Jolla Institute for Immunology")>0
    replace institution = "DeepMind" if strpos(affiliation, "DeepMind")>0	
    replace institution = "NIH" if inlist(institution, "National Cancer Institute", "National Eye Institute", "National Heart, Lung, and Blood Institute", "National Human Genome Research Institute") | ///
      inlist(institution, "National Institute on Aging", "National Institute on Alcohol Abuse and Alcoholism", "National Institute of Allergy and Infectious Diseases", "National Institute of Arthritis and Musculoskeletal and Skin Diseases") | ///
      inlist(institution, "National Institute of Biomedical Imaging and Bioengineering", "National Institute of Child Health and Human Development", "National Institue of Dental and Craniofacial Research") | ///
      inlist(institution, "National Institute of Diabetes and Digestive and Kidney Diseases", "National Institute on Drug Abuse", "National Institute of Environmental Health Sciences", "National Institute of General Medical Sciences", "National Institute of Mental Health", "National Institute on Minority Health and Health Disparities") | ///
      inlist(institution, "National Institute of Neurological Disorders and Stroke", "National Institute of Nursing Research", "National Library of Medicine", "National Heart Lung and Blood Institute", "National Institutes of Health")
    replace institution = "NIH" if city == "Bethesda" & (strpos(affiliation, "NCI") > 0 | strpos(affiliation, "NHLBI") > 0 | strpos(affiliation, "NHGRI") > 0 | strpos(affiliation, "NIAID") > 0| strpos(affiliation, "NIAMS") >0 | strpos(affiliation, "NIH") > 0 | strpos(affiliation, "National Heart, Lung, and Blood Institute") > 0)
    replace institution = "NIH" if strpos(affiliation, "Bethesda") > 0 & (strpos(affiliation, "National") > 0 & strpos(affiliation, "Institute") > 0) & strpos(affiliation, "Technology") == 0
    replace institution = "NIH" if strpos(affiliation, "MD") > 0 & (strpos(affiliation, "NIH")> 0) & country== "United States"
    replace institution = "United States Army Research Institute of Infectious Diseases" if strpos(affiliation, "United States Army Research Institute of Infectious Diseases") > 0 | (strpos(affiliation, "USAMRIID")>0 & country == "United States")
    foreach u in "Department of Energy Joint Genome Institute" "Entasis Therapeutics" "Rady Children's Institute for Genomic Medicine" {
        replace institution = "`u'" if strpos(affiliation, "`u'") > 0
    }
    replace institution = "University of Nebraska, Lincoln" if strpos(affiliation, "University of Nebraska") > 0 & strpos(affiliation, "Lincoln") > 0 
    replace institution = "Baylor College of Medicine" if strpos(affiliation, "BCM") > 0 & strpos(affiliation, "Houston") > 0
    replace institution = "Bristol-Myers Squibb" if strpos(affiliation, "Bristol") > 0 & strpos(affiliation, "Squibb") > 0
    replace institution = "J. David Gladstone Institutes" if strpos(affiliation, "Gladstone") > 0 & strpos(affiliation, "Institute") > 0 

    replace institution = "University of Colorado, Boulder" if strpos(affiliation, "University of Colorado") > 0 & strpos(affiliation, "Boulder") > 0
    replace institution = "University of Colorado, Aurora" if strpos(affiliation, "University of Colorado") > 0 & strpos(affiliation, "Aurora") > 0
    replace institution = "University of Coloardo Anschutz Medical Campus" if strpos(affiliation, "University of Colorado Anschutz Medical Campus") > 0 | strpos(affiliation, "University of Colorado Health Science") > 0 | (strpos(affiliation, "University of Colorado") > 0 & (strpos(affiliation, "Medical") > 0 | strpos(affiliation, "Medicine")>0))
    replace institution = "University of Colorado, Denver" if strpos(affiliation, "University of Colorado") > 0 & strpos(affiliation, "Denver") > 0
    replace institution = "University of Michigan, Ann Arbor" if strpos(affiliation, "University of Michigan") > 0 & city == "Ann Arbor"
    replace institution = "NorthShore University HealthSystem" if strpos(affiliation, "NorthShore University HealthSystem") > 0
    replace institution = "Louisiana State University" if strpos(affiliation, "Louisiana State University") > 0
    replace institution = "Pennsylvania State University" if strpos(affiliation, "Penn State") > 0 & us_state == "PA"
    replace institution = "Loyala University of Chicago" if strpos(affiliation, "Loyala University") > 0 & us_state == "IL"
    replace institution = "University of California, Los Angeles" if strpos(affiliation, "UCLA") > 0
    replace institution = "University of California, Santa Barbara" if strpos(affiliation, "UCSB") > 0
    replace institution = "University of California, San Diego" if strpos(affiliation, "UCSD") > 0
    replace institution = "University of California, San Diego" if strpos(affiliation, "University") > 0 & strpos(affiliation, "California") > 0 & city == "La Jolla"
    replace institution = "University of California, Santa Cruz" if strpos(affiliation, "UCSC") > 0
    replace institution = "University of California, San Francisco" if strpos(affiliation, "UCSF") > 0
    replace institution = "University of Southern California" if strpos(affiliation, "USC") > 0 & us_state == "CA"
    replace city = "Los Angeles" if institution == "University of Southern California"
    foreach cal in "Berkeley" "Los Angeles" "Santa Barbara" "San Diego" "Davis" "Irvine" "Santa Cruz" "Riverside" "Merced" "San Francisco" {
        replace institution = "University of California, `cal'" if strpos(affiliation, "University of California `cal'") > 0
        replace institution = "University of California, `cal'" if strpos(affiliation, "University of California-`cal'") > 0
        replace institution = "University of California, `cal'" if strpos(affiliation, "University of California, `cal'") > 0
        replace institution = "University of California, `cal'" if strpos(affiliation, "University of California at `cal'") > 0
        replace institution = "University of California, `cal'" if strpos(affiliation, "UC `cal'") > 0
        replace institution = "University of California, `cal'" if strpos(affiliation, "University of California") > 0 & strpos(affiliation, "`cal'")>0& mi(institution)
        replace country = "United States" if institution == "University of California, `cal'"
        replace us_state = "CA" if institution == "University of California, `cal'"
    }
    replace institution = "University of Texas, Medical Branch at Galveston" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Medical Branch")> 0 & strpos(affiliation, "Galveston")> 0
    replace institution = "University of Texas, Health Science Center at Houston" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Health")> 0 & strpos(affiliation, "Houston")> 0
    replace institution = "University of Texas, Health Science Center at San Antonio" if strpos(affiliation, "University of Texas")>0 & strpos(affiliation, "Health")> 0 & strpos(affiliation, "San Antonio")> 0
    replace institution = "University of Texas, Southwestern Medical Center" if strpos(affiliation, "University of Texas") >0 & strpos(affiliation, "Southwestern") >0
    foreach tex in "Arlington" "Southwestern Medical Center" "Austin" "Dallas" "El Paso"  "Permian Basin" "Rio Grande Valley" "San Antonio" "Tyler" {
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas `tex'") > 0
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas") > 0 & city == "`tex'"
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas at `tex'") > 0
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas, `tex'") > 0
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "University of Texas-`tex'") > 0
        replace institution = "University of Texas, `tex'" if strpos(affiliation, "UT `tex'") > 0
        replace country = "United States" if institution == "University of Texas, `tex'"
        replace us_state = "TX" if institution == "University of Texas, `tex'"
    }
    replace institution = "MD Anderson" if strpos(affiliation, "Anderson Cancer Center") > 0
    replace institution = "Brigham and Women's Hospital" if strpos(affiliation, "Brigham") > 0 & strpos(affiliation, "Women") > 0 & strpos(affiliation, "Hospital") > 0 
    replace institution = "Massachusetts Institute of Technology" if strpos(affiliation, "MIT") >0 & city == "Cambridge"
    replace institution = "Memorial Sloan-Kettering Cancer Center" if strpos(affiliation, "Sloan") > 0 & strpos(affiliation, "Kettering")>0 & mi(institution)
    replace institution = "Scripps Research Institute" if strpos(affiliation, "Scripps")>0 & strpos(affiliation, "Research")>0 & mi(institution)
    replace institution = "University of Maine" if strpos(affiliation, "University of Maine") > 0
    replace institution = "Moderna" if strpos(affiliation, "Moderna") >0 & country == "United States"
	replace city = "Cambridge" if institution == "Moderna"
	replace us_state = "MA" if institution == "Moderna"
	
    replace institution = "Children's Mercy Hospital" if strpos(affiliation, "Children's Mercy Hospital") > 0 & country == "United States" & mi(institution)
    replace institution = "Johns Hopkins University" if strpos(affiliation, "Johns Hopkins") > 0 & mi(institution)
	
	// UK institutions
	replace institution = "University College London" if strpos(affiliation, "UCL") > 0 & city == "London"
    replace institution = "University College London" if strpos(affiliation, "University College London")> 0
	replace institution = "University of St. Andrews" if strpos(affiliation, "University of St Andrew") > 0
    replace institution = "University of Cambridge" if strpos(affiliation, "Cambridge University") > 0 & mi(institution)
    replace institution = "University of Oxford" if strpos(affiliation, "Oxford University") > 0 & mi(institution)
    replace institution = "University of Galway" if strpos(affiliation, "National University") > 0 & strpos(affiliation, "Galway") > 0 
    replace institution = "University of Exeter" if strpos(affiliation, "Exeter University") > 0 & mi(institution)
    replace institution = "Paul Scherrer Institute" if strpos(affiliation, "Paul Scherrer Institut") > 0 & mi(institution)
    replace institution = "Wellcome Trust" if strpos(affiliation, "Wellcome") > 0 & country == "United Kingdom"
	replace institution = "Wellcome Genome Campus" if strpos(affiliation, "Wellcome Trust Sanger Institute")> 0 | strpos(affiliation, "Sanger Institute")>0
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
	    foreach uk in "John Innes Centre" "NIHR Cambridge Biomedical Research Centre" "NIHR Oxford Biomedical Research Centre" "Francis Crick Institute" "Natural History Museum" "Earlham Institute" "Imperial College" "University of Kent" "Babraham Institute" "Durham University" "Newcastle Hospitals NHS Foundation Trust" "Dundee University" "University of Galway" {
        replace institution = "`uk'" if strpos(affiliation, "`uk'") > 0 & country == "United Kingdom"
    }
    replace city = "Galway" if institution == "University of Galway"

    // Germany
    foreach g in "Marburg" "Munich" "Bonn" "konstanz" "Munich" "Munster" "Gottingen" "Cologne" "Frankfurt" "Giessen" "Tuebingen" "Wurzburg" "Heidelberg" "Hohenheim" "Freiburg" {
        replace institution = "University of `g'" if strpos(affiliation, "Universit") > 0 & strpos(affiliation, "`g'") > 0 & strpos(affiliation, "Germany") > 0
        replace city = "`g'" if strpos(affiliation, "`g'") > 0 & strpos(affiliation, "Germany") > 0
        replace country = "Germany" if strpos(affiliation, "Germany") > 0
    }
    replace institution = "University of Munich" if (strpos(affiliation, "Philipps") > 0 | strpos(affiliation, "Phillipps") > 0 ) & strpos(affiliation, "Marburg")>0 & strpos(affiliation, "Universit") > 0 & mi(institution)
    replace institution = "University of Giessen" if strpos(affiliation, "Justus") > 0 & strpos(affiliation, "Liebig")>0 & strpos(affiliation, "Universit") > 0 & mi(institution)
    replace institution = "University of Munich" if strpos(affiliation, "LMU Munchen")> 0 & city == "Munich" & mi(institution)
    replace institution = "Goethe University" if strpos(affiliation, "Universit")> 0 & strpos(affiliation, "Goethe") & mi(institution)
    replace institution = "Univeristy of Gottingen" if strpos(affiliation, "Universit")> 0 & city == "Gottingen" & mi(institution)
    replace institution = "University of Tuebingen" if strpos(affiliation, "Universit") > 0 & city == "Tubingen" & country == "Germany" & mi(institution)
    replace institution = "University of Wurzburg" if strpos(affiliation, "Universit") > 0 & city == "Wuerzburg" & country == "Germany" & mi(institution)
    replace institution = "University of Freiburg" if strpos(affiliation, "Albert") > 0 & strpos(affiliation, "Ludwigs")>0 & strpos(affiliation, "Freiburg")>0
    replace institution = "Freie Universitat Berlin" if strpos(affiliation, "Freie Universitat Berlin") > 0 | (strpos(affiliation, "Berlin")>0 & strpos(affiliation, "FU")>0)
    replace institution = "FAU" if strpos(affiliation, "FAU") > 0 & strpos(affiliation, "Germany") > 0 | (strpos(affiliation, "Friedrich") > 0 & strpos(affiliation, "Alexander")>0)
    replace institution = "Charite-Universitatsmedizin Berlin" if strpos(affiliation, "Charite") > 0 & strpos(affiliation, "Universitatsmedizin") > 0 & strpos(affiliation, "Berlin") > 0
    replace institution = "RWTH Aachen University" if (strpos(affiliation, "RWTH") > 0 & strpos(affiliation, "Aachen") > 0)
    replace institution = "Johannes Gutenberg University Mainz" if strpos(affiliation, "Gutenberg") > 0 & strpos(affiliation, "Universit") > 0 & strpos(affiliation, "Mainz") > 0
    replace institution = "Martin-Luther-University Halle-Wittenberg" if strpos(affiliation, "Universit") > 0 & strpos(affiliation, "Martin") > 0 & strpos(affiliation, "Luther") > 0 
    replace institution = "Leipzig University" if strpos(affiliation, "Leipzig") > 0 & strpos(affiliation, "Universit") > 0
    replace institution = "Humboldt University" if strpos(affiliation, "Humboldt") > 0 & strpos(affiliation, "Universit") > 0 & strpos(affiliation, "Berlin") > 0
    replace institution = "Technical University Dresden" if strpos(affiliation, "Techni")>0 & strpos(affiliation, "Universit")> 0 & strpos(affiliation, "Dresden") > 0
    replace institution = "Technical University Berlin" if strpos(affiliation, "Techni")>0 & strpos(affiliation, "Universit")> 0 & strpos(affiliation, "Berlin") > 0
    replace institution = "Technical University Darmstadt" if strpos(affiliation, "Techni")>0 & strpos(affiliation, "Universit")> 0 & (strpos(affiliation, "Darmstadt") > 0 )
    replace institution = "Technical University Dortmund" if strpos(affiliation, "Techni")>0 & strpos(affiliation, "Universit")> 0 & (strpos(affiliation, "Dortmund") > 0 )
    replace institution = "Technical University Braunnschweig" if strpos(affiliation, "Techni")>0 & strpos(affiliation, "Universit")> 0 & (strpos(affiliation, "Braunschweig") > 0 )
    replace institution = "Friedrich-Schiller-University Jena" if strpos(affiliation, "Friedrich") > 0 & strpos(affiliation, "Schiller")>0 & strpos(affiliation, "Universit")  > 0
    replace institution = "Friedrich-Schiller-University Jena" if strpos(affiliation, "Universit")> 0  & strpos(affiliation, "Jena")  > 0
    replace institution = "Comprehensive Pneumology Center" if strpos(affiliation, "Comprehensive Pneumology Center")> 0 & city == "Munich" & mi(institution)
    replace institution = "Research Centre Julich" if strpos(affiliation, "Research") > 0 & (strpos(affiliation, "Center") > 0 | strpos(affiliation, "Centre") > 0 ) & city == "Julich"
    replace city = "Cologne" if institution == "University of Cologne"
    replace institution = "Center for Synthetic Microbiology" if strpos(affiliation, "Center for Synthetic Microbiology") > 0 & country == "Germany" & mi(institution)
    replace institution = "German Center for Diabetes Research" if strpos(affiliation, "German Center for Diabetes Research") > 0 & country == "Germany"
    replace institution = "German Center for Neurodegenerative Disease" if strpos(affiliation, "German Center for Neurodegenerative Disease") > 0 & country == "Germany"
    replace institution = "Helmholtz Munich" if strpos(affiliation, "Helmholtz") > 0 & city == "Munich" & country == "Germany"
    replace institution = "Heinrich Heine University" if strpos(affiliation, "Heinrich") > 0 & strpos(affiliation, "Heine") > 0 & strpos(affiliation, "Universit") >  0 & country == "Germany"
    replace institution = "European Neuroscience Institute" if strpos(affiliation, "European Neuroscience Institute") > 0
    replace institution = "European Molecular Biology Laboratory" if strpos(affiliation, "European Molecular Biology Laboratory") > 0
    replace institution = "BC Cancer Research Centre" if strpos(affiliation, "BC Cancer Research Centre") > 0 
    replace city = "Vancouver" if institution == "BC Cancer Research Centre"
    replace institution = "DESY" if (strpos(affiliation, "Deutsches Elektronen-Synchrotron") > 0 | strpos(affiliation, "DESY") > 0) & country == "Germany"
    replace institution = "Monash Biomedicine Discovery Institute" if strpos(affiliation, "Monash Biomedicine Discovery Institute") > 0 
    replace institution = "DKFZ" if (strpos(affiliation, "German Cancer Research Center")> 0 | strpos(affiliation, "DKFZ") > 0) & country == "Germany"
    replace institution = "Autism CRC" if (strpos(affiliation, "Cooperative Research Centre for Living with Autism")>0 | strpos(affiliation, "Autism CRC")>0) & country == "Australia" 
    replace institution = "Senckenberg Society for Nature Research" if strpos(affiliation, "Senckenberg") > 0  & strpos(affiliation, "Naturforschung") > 0 
    replace institution = "Technical University of Munich" if strpos(affiliation, "Technical University of Munich") > 0
    replace institution = "iDiv" if strpos(affiliation, "German Centre for Integrative Biodiversity Research") > 0
    replace institution = "LIPM" if strpos(affiliation, "LIPM") > 0 & country == "France"
    replace institution = "Boehringer-Ingelheim Pharma" if strpos(affiliation, "Boehringer-Ingelheim Pharma") > 0 
    replace city = "Dusseldorf" if institution == "Heinrich Heine University"
    replace institution = "IMT" if strpos(affiliation, "Institut") > 0 & strpos(affiliation, "Molekularbiologie") > 0 & strpos(affiliation, "Tumorforschung") & city == "Marburg"
    replace institution = "IPK" if strpos(affiliation, "Leibniz Institute of Plant Genetics and Crop Plant Research") > 0
    replace institution = "ZALF" if strpos(affiliation, "Leibniz Centre for Agricultural Landscape Research") > 0
    replace institution = "Google" if strpos(affiliation, "Google") > 0
    replace institution = "Medical Research Council" if strpos(affiliation, "MRC ") > 0 & country == "United Kingdom" & mi(institution)
    replace institution = "Weizmann Institute of Science" if strpos(affiliation, "Weizmann") > 0 & country == "Israel" & mi(institution)
    replace institution = "Katholieke Universiteit Leuven" if strpos(affiliation, "KU Leuven") > 0
   
   //french uni
    foreach f in "Montpellier" "Nantes" "Strasbourg" "Toulouse" "Tours" "Bordeaux" "Lyon" "Lille" "Bourgogne"  "Lorraine" "Paris" "Toulon" "Picardie Jules Verne" "Franche-Comte" "Versailles" "Nice" "la Reunion" "Rennes" "Poitiers" {
        replace institution = "Universite de `f'" if strpos(affiliation, "Universite") > 0 & strpos(affiliation, "`f'") > 0 
        replace institution = "Universite de `f'" if strpos(affiliation, "Univ") > 0 & strpos(affiliation, "`f'") > 0 
        replace city = "`f'" if strpos(affiliation, "`f'") > 0 & mi(city)
        replace country = "France" if strpos(affiliation, "`f'") > 0 & mi(country)
    }
    foreach f in "Sorbonne Universite" "Universite Grenoble Alpes" "Universite Cote d'Azur" "Universite Paul Sabatier" "Universite d'Evry" "Universite Clermont Auvergne" "Aix Marseille Universite" "University Paris Descartes" "Turing Centre for Living Systems" "INSERM" "CNRS" "Institut Pasteur"  "Sciences Po" {
        replace institution = "`f'" if strpos(affiliation, "`f'")>0  & strpos(affiliation, "France") > 0
    }
    replace institution = "Aix Marseille Universite" if strpos(affiliation, "Aix") > 0 & strpos(affiliation, "Marseille")>0 & strpos(affiliation,"Univ")>0
    replace institution = "Universite Grenoble Alpes" if strpos(affiliation, "Grenoble") > 0 & strpos(affiliation, "Alpes")>0 & strpos(affiliation,"Univ")>0
    replace institution = "INSERM" if strpos(affiliation, "Inserm") > 0
    replace institution = "Ecole Polytechnique Federale de Lausanne" if strpos(affiliation, "Lausanne") >0 & strpos(affiliation, "polytechnique") > 0 

	// other
    replace institution = "Shaukat Khanum Memorial Cancer Hospital and Research Center" if strpos(affiliation, "Shaukat Khanum Memorial Cancer Hospital and Research Center") > 0 & mi(institution)
    replace institution = "Alexandrov Research Institute of Oncology and Medical Radiology" if strpos(affiliation, "Alexandrov Research Institute of Oncology and Medical Radiology") > 0 & country == "Belarus"
    replace institution = "Private University in the Principality of Liechtenstein" if strpos(affiliation, "Private University in the Principality of Liechtenstein") > 0 
    replace institution = "Research Institute of Molecullar Pathology" if strpos(affiliation, "Research Institute of Molecular Pathology") > 0
    replace institution = "MDC" if strpos(affiliation, "Max Delbruck Center for Molecular Medicine") > 0 | (strpos(affiliation, "MDC") & country == "Germany")
    replace institution = "University of Zurich" if strpos(affiliation, "Universit") > 0 & strpos(affiliation, "Zurich") > 0  & country == "Switzerland"
    replace institution = "Tsinghua-Peking Center for Life Sciences" if strpos(affiliation, "Tsinghua-Peking Center for Life Sciences") > 0
    replace institution = "Altius Institute for Biomedical Sciences" if strpos(affiliation, "Altius Institute for Biomedical Sciences") >0
    replace institution = "Bin Talal Bin Abdulaziz Alsaud Institute for Computational Biomedicine" if strpos(affiliation, "Bin Talal Bin Abdulaziz Alsaud Institute for Computational Biomedicine") > 0
    replace institution = "BGI-Shenzhen" if strpos(affiliation, "BGI-Shenzhen") > 0 
    replace institution = "Heptares Therapeutics" if strpos(affiliation, "Heptares Therapeutics") >0 
    replace institution = "University of Western Sydney" if strpos(affiliation, "Western Sydney University") >0
    replace institution = "CeMM Research Center for Molecular Medicine of the Austrian Academy of Sciences" if strpos(affiliation, "CeMM Research Center for Molecular Medicine of the Austrian Academy of Sciences") > 0
    replace institution = "RIKEN" if strpos(affiliation, "RIKEN") > 0 & country == "Japan"
    replace city = "Shenzhen" if institution == "BGI-Shenzhen"
    replace institution = "VIB" if strpos(affiliation, "VIB") > 0 & country == "Belgium"
    replace institution = "ETH Zurich" if strpos(affiliation, "ETH Zurich") > 0
    replace institution = "IMBA" if strpos(affiliation, "Institute of Molecular Biotechnology of the Austrian Academy of Sciences") | strpos(affiliation, "IMBA") > 0  & country == "Austria"
    replace institution = "Radboud University Nijmegen" if strpos(affiliation, "Radboud University") > 0 
    replace institution = "BBIB" if strpos(affiliation, "Berlin-Brandenburg Institute of Advanced Biodiversity Research") > 0 | (strpos(affiliation, "BBIB") & strpos(affiliation, "Germany") > 0 )
    replace institution = "Hebrew University of Jerusalem" if strpos(affiliation, "Hebrew University") > 0 & city == "Jerusalem" & mi(institution)
    replace institution = "CDC" if strpos(affiliation, "Centers for Disease Control") & country == "United States"
    replace city = "Atlanta" if institution == "CDC" & mi(city)
	// fill in random unis
	qui glevelsof city, local(found_cities)
    foreach c in `found_cities' {
        replace institution = "University of `c'" if strpos(affiliation, "University of `c'") > 0 & city == "`c'" & mi(institution)
    }
   // fill in locations of institutions 
    merge m:1 institution using ../temp/unique_institutions, assert(1 2 3) keep(1 3) nogen
    replace country = country_name if mi(country)
    drop country_name
    replace country = "United States" if institution == "NIH"
    replace city = "Cambridge" if institution == "Harvard University"
    replace us_state = "MA" if institution == "Harvard University"
    replace city = "New Haven" if institution == "Yale University"
    replace city = "Baltimore" if institution == "Johns Hopkins University"
    replace city = "Boston" if institution == "Massachusetts General Hospital"
    replace city = "Chicago" if institution == "University of Chicago"
    replace country = "China" if inlist(institution, "Chinese Academy of Sciences", "Peking University")
    replace country = "United Kingdom" if institution == "University College London"
    replace country = "Colombia" if institution == "Universidad Nacional"
    replace country = "Nepal" if institution == "Agriculture and Forestry University" 
    replace city = "Rehovot" if institution == "Weizmann Institute of Science"
    replace city = "Edinburgh" if institution == "University of Edinburgh"
    replace city = "Montreal" if institution == "McGill University"
    replace city = "Geneva" if institution == "University of Geneva"
    replace city = "Aarhus" if institution == "Aarhus University"
    replace city = "Exeter" if institution == "University of Exeter"
    replace city = "Cambridge" if institution == "University of Cambridge"
    replace city = "Oxford" if institution == "University of Oxford"
    replace city = "Ghent" if institution == "Ghent University"
    replace city = "Melbourne" if institution == "Monash University"
    replace city = "Gothenburg" if institution == "University of Gothenburg"
    replace city = "Dundee" if institution == "University of Dundee"
    replace city = "London" if institution == "Wellcome Trust"
    replace country = "United Kingdom" if institution == "Wellcome Trust"
    replace institution = "University of Queensland" if institution == "The University of Queensland"
    replace city = "Brisbane" if institution == "University of Queensland"
    replace city = "Glasgow" if institution == "University of Glasgow"
    replace city = "Bogota" if institution == "Universidad Nacional"
    replace city = "Villigen" if institution == "Paul Scherrer Institute"
    replace country = "Switzerland" if institution == "Paul Scherrer Institute"
    replace city = "Parkville" if institution == "Walter and Eliza Hall Institute of Medical Research"
    replace institution = "Max Planck" if strpos(affiliation, "Max Planck") > 0
    replace city = "St. Andrews" if institution == "University of St. Andrews"
    compress , nocoalesce
    save ../output/cleaned_all_`data'_${samp}, replace

    // extras 
    drop if pmid == 28445112
    drop if affiliation == "."

    foreach t in institution city country {

    }
    keep if inrange(date, td(01jan2015), td(31mar2022))
    save ../output/cleaned_last5yrs_`data'_${samp}, replace
end 

program output_tables
    foreach file in num_authors num_affls {
        qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
         }
 end
** 
main
