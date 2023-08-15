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
    global temp "/export/scratch/cxu_sci_geo/get_pt"
    append_metadata
    clean_pubtype
end
program append_metadata
    local filelist1: dir "../external/cns_med/" files "*.csv"
    local filelist2: dir "../external/other/" files "*.csv"
    foreach file in `filelist1' {
        import delimited "../external/cns_med/`file'", clear varn(1)
        keep pmid pt
        tostring pmid, replace
        drop if inlist(pmid, "pmid", "v1", "NA")
        destring pmid, replace
        local name = subinstr("`file'",".csv","",.)
        local namelist `namelist' `name'
        compress, nocoalesce 
        save ${temp}/`name', replace
    }
    foreach file in `filelist2' {
        import delimited "../external/other/`file'", clear varn(1)
        keep pmid pt
        tostring pmid, replace
        drop if inlist(pmid, "pmid", "v1", "NA")
        destring pmid, replace
        local name = subinstr("`file'",".csv","",.)
        local namelist `namelist' `name'
        compress, nocoalesce 
        save ${temp}/`name', replace
    }
    
    clear 
    foreach file of local namelist {
        append using ${temp}/`file'
    }
    gduplicates drop pmid, force
    save ${temp}/master_pt_appended, replace

    merge 1:1 pmid using ../external/pmid/med_all_pmids, assert(1 2 3) keep(3) nogen
    save ${temp}/clin_med_pt_appended, replace

    use ${temp}/master_pt_appended, clear
    merge 1:1 pmid using ../external/pmid/all_jrnls_all_pmids, assert(1 2 3) keep(3) nogen
    save ${temp}/all_jrnls_pt_appended, replace
end
program clean_pubtype
    // first drop non journal articles for our full sample (include clinical trials)
    use ${temp}/all_jrnls_pt_appended,clear 
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
    gcontract pmid 
    drop _freq
    save ../output/cleaned_all_jrnl_base, replace
    
    use ${temp}/clin_med_pt_appended, clear
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
       replace to_drop = 1 if inlist(pt`i', "Retraction of Publication", "Twin Study", "Systematic Review", "Address" , "Bibliography", "Consensus Development Conference" , "Consensus Development Conference, NIH")
       replace to_drop = 1 if inlist(pt`i', "Corrected and Republished Article", "Duplicate Publication","Interactive Tutorial", "Expression of Concern", "Lecture","Multicenter Study", "Patient Education Handout" , "Validation Study") 
       replace pub_type = "Journal Article" if pt`i' == "Journal Article"
       replace pub_type = "Clinical Study" if strpos(pt`i', "Clinical Study")
       replace pub_type = "Clinical Trial" if strpos(pt`i', "Clinical Trial")
       replace pub_type = pt`i' if mi(pub_type)
    }
	drop if to_drop == 1
    save ../output/cleaned_clin_med_base, replace
end
** 
main
