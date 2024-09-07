set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 18
set maxvar 120000, perm

program main   
    append_indicies
end

program append_indicies
    foreach samp in fundamental thera diseases {
        import delimited using "../external/samp/`samp'_pmids.txt", clear  
        rename v1 pmid
        compress, nocoalesce
        save ../temp/`samp', replace
    }
    local filelist: dir "../temp/" files "*.dta"
    clear
    foreach file in `filelist' {
        append using ../temp/`file'
    }
    gduplicates drop pmid, force
	save "../output/all_pmids.dta", replace
end

main
