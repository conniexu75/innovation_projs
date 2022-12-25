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
    local samp cns_med
    append_metadata, data(`samp')
    clean_pubtype, data(`samp')
    extract_pmids_to_clean, data(`samp')
end

program append_metadata
    syntax, data(str)
	local filelist: dir "../external/samp" files "`data'_*"
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
	save "../output/master_`data'_appended.dta", replace
end

program clean_pubtype
    syntax, data(str)
    use ../output/master_`data'_appended, clear
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
    gen trial = 0 
    gen study = 0
    forval i = 1/`num_pts' {
        replace to_drop = 1 if inlist(pt`i', "Autobiography", "Biography", "Case Reports", "Classical Article", "Comment", "Congress", "Dataset", "Editorial")
        replace to_drop = 1 if inlist(pt`i', "Historical Article", "Introductory Journal Article", "Letter" , "News", "Clinical Conference", "Practice Guideline", "Guideline")
        replace to_drop = 1 if inlist(pt`i', "Meta-Analysis", "Personal Narrative", "Portrait", "Published Erratum", "Retracted Publication", "Review", "Video-Audio Media", "Webcast", "Legal Case")
        replace to_drop = 1 if inlist(pt`i', "Retraction of Publication", "Systematic Review", "Address" , "Bibliography", "Consensus Development Conference" , "Consensus Development Conference, NIH")
        replace to_drop = 1 if inlist(pt`i', "Corrected and Republished Article", "Duplicate Publication","Interactive Tutorial", "Expression of Concern", "Lecture","Patient Education Handout" )
        replace trial = 1 if strpos(pt`i', "Clinical Trial") > 0 | strpos(pt`i', "Randomized Controlled Trial")>0
        replace study = 1 if strpos(pt`i', "Study") > 0 
        replace pub_type = "Clinical Study" if strpos(pt`i', "Clinical Study") > 0  | strpos(pt`i', "Study") > 0
        replace pub_type = "Clinical Trial" if strpos(pt`i', "Clinical Trial") > 0  | strpos(pt`i', "Randomized Controlled Trial")>0
        replace pub_type = "Journal Article" if pt`i' == "Journal Article" 
        replace pub_type = pt`i' if mi(pub_type)
        tab pub_type
    }
	drop if (to_drop == 1 | study == 1 ) & trial == 0
    preserve
    keep if trial ==1
    gcontract pmid
    drop _freq
    save ../output/pmids_trial_`data', replace
    restore
    gcontract pmid
    drop _freq
    save ../output/all_jrnl_articles_`data', replace
end

program extract_pmids_to_clean
    syntax, data(str)
    use ../output/all_jrnl_articles_`data', clear
    merge 1:m pmid using ../external/cats/CNS_pmids, assert(1 2 3) keep(3) nogen
    save ../output/pmids_category_xwalk, replace
    preserve
    merge m:1 pmid using ../output/pmids_trial_`data', assert(1 2 3) keep(3) nogen
    assert cat == "therapeutics"
    restore
    gcontract pmid 
    drop _freq
    save ../output/contracted_pmids_`data', replace
    merge 1:1 pmid using ../output/master_`data'_appended, assert(2 3) keep(3) nogen
	save "../output/`data'_to_clean.dta", replace
end
** 
main
