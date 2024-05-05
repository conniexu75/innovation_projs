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
    append_jrnls
end

program append_indicies
    foreach samp in fundamental therapeutics diseases {
        forval y = 1945/2022 {
            import delimited using "../external/samp/`samp'_`y'", clear varn(1)
            tostring pmid, replace
            tostring query_name, replace
            drop if pmid == "NA"
            destring pmid, replace
            save ../temp/`samp'_`y', replace
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
    replace pmid = pmid*10000 
    duplicates tag pmid cat, gen(dup)
	bys pmid cat: egen minyr = min(year)
    drop if year > minyr & dup > 0
    drop dup minyr
	duplicates tag pmid, gen(dup)
    gen fund = cat == "fundamental"
    bys pmid: egen tot_fund = max(fund)
    drop if dup > 0 & tot_fund == 1 & fund != 1
    
    drop dup fund tot_fund
    gduplicates drop 
    duplicates tag pmid, gen(dup)
    gen dis = cat == "diseases"
    bys pmid: egen tot_dis = max(dis)
    drop if dup > 0 & tot_dis == 1 &  dis != 1
	gisid pmid
	replace pmid = pmid/10000 if inlist(cat, "fundamental", "diseases", "therapeutics")
    drop dup dis tot_dis 
	save "../output/all_newfund_pmids.dta", replace
end

main
