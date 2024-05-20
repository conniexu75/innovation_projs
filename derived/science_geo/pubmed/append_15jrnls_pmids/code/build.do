set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    append_indicies
end

program append_indicies
    foreach j in science plosone oncogene neuron nature natneurosci natmed natgenet natchembiol natcellbiol natbiotechnol jbilchem fasebj cellstemcell cell {
        foreach samp in fundamental thera disease {
            import delimited using "../external/samp/`j'_`samp'_search_terms", clear varn(1) 
            tostring pmid, replace
            tostring query_name, replace
            drop if pmid == "NA"
            destring pmid, replace
            gen jrnl = "`j'"
            save ../temp/`j'_`samp', replace
        }
    }
    local filelist: dir "../temp/" files "*.dta"
    clear
    foreach file in `filelist' {
        append using ../temp/`file'
    }
    save ../temp/all_newfund_pmids, replace

    split query_name, p("_")
    ren query_name1 cat 
    ren query_name2 year
    destring year, replace
    drop query_name 
    gduplicates drop pmid, force
	save "../output/all_newfund_pmids.dta", replace
end

main
