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
    append_jrnls
end

program append_cns
    local filelist: dir "../external/samp/CNS/" files "CNS_*.csv"
    foreach file in `filelist' {
        import delimited using "../external/samp/CNS/`file'", clear
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
    save ../temp/CNS_pmids, replace

    split query_name, p("_")
    ren query_name1 cat 
    ren query_name2 year
    destring year, replace
    drop query_name 
    replace pmid = pmid*10000 if inlist(cat, "fundamental", "diseases", "therapeutics")
    duplicates tag pmid cat, gen(dup)
	bys pmid cat: egen minyr = min(year)
    drop if year > minyr & dup > 0
    drop dup minyr
	duplicates tag pmid, gen(dup)
    gen fund = cat == "fundamental"
    bys pmid: egen tot_fund = max(fund)
    drop if dup > 0 & tot_fund == 1 & fund != 1
	gisid pmid
	replace pmid = pmid/10000 if inlist(cat, "fundamental", "diseases", "therapeutics")
	save "../output/CNS_pmids.dta", replace
end

program append_jrnls 
    local jrnls  nejm jama lancet bmj annals science nature cell
    foreach jrnl in `jrnls' {
        forval yr = 1988/2022 {
            import delimited ../external/samp/`jrnl'`yr'.csv, clear
            save ../temp/`jrnl'`yr', replace
        }
        clear
        forval yr = 1988/2022 {
            append using ../temp/`jrnl'`yr'
        }
        gen journal_abbr = "`jrnl'"
        save ../temp/`jrnl', replace
    }
    clear
    foreach jrnl in `jrnls' {
        append using ../temp/`jrnl'
    }
    bys pmid: egen minyr = min(year)
    drop if year > minyr
    drop minyr
    gisid pmid
    save ../output/cns_med_all_pmids, replace

    preserve 
    keep if inlist(journal_abbr, "cell","nature","science")
    save ../output/cns_all_pmids, replace
    restore

    preserve 
    keep if !inlist(journal_abbr, "cell","nature","science")
    save ../output/med_all_pmids, replace
    restore
end
main
