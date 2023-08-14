set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    append_cns
end

program append_cns
    local filelist: dir "../external/samp/" files "therapeutics_*.csv"
    foreach file in `filelist' {
        import delimited using "../external/samp/`file'", clear
        tostring pmid, replace
        tostring query_name, replace
        drop if pmid == "NA"
        destring pmid, replace
        save ../temp/`file', replace
    }
    clear
    foreach file in `filelist' {
        append using ../temp/`file'
    }
    save ../temp/thera_pmids, replace
    split query_name, p("_")
    ren query_name1 cat 
    ren query_name2 year
    destring year, replace
    drop query_name 
    duplicates tag pmid cat, gen(dup)
	bys pmid cat: egen minyr = min(year)
    drop if year > minyr & dup > 0
    drop dup minyr
	gisid pmid
	save "../output/thera_pmids.dta", replace
end

main
