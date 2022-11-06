set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    append_btc
    append_jrnls
end

program append_btc
    local filelist: dir "../external/samp/BTC/" files "BTC_*.csv"
    foreach file in `filelist' {
        import delimited using "../external/samp/BTC/`file'", clear
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
    save ../temp/BTC_appended, replace

    split query_name, p("_")
    ren query_name1 btc
    ren query_name2 year
    destring year, replace
    drop query_name 
    replace pmid = pmid*10000 if inlist(btc, "total", "totalCTs")
    duplicates tag pmid, gen(dup)
    gen nothc = btc != "healthcare"
		bys pmid: egen tot_nothc = total(nothc)
		drop if dup & btc == "healthcare" & tot_nothc > 0
		drop dup
	duplicates tag pmid, gen(dup)
	gen clin = btc == "clinical" if dup > 0
		bys pmid: egen tot_clin = total(clin)
		drop if btc == "translational" & tot_clin > 0 & dup
		drop dup tot_clin clin tot_nothc nothc
	bys pmid btc: egen minyr = min(year)
		drop if year > minyr
	isid pmid
	replace pmid = pmid/10000 if inlist(btc, "total", "totalCTs")
	duplicates tag pmid, gen(dup)
	drop if dup & inlist(btc, "total", "totalCTs")
	replace btc = "other" if btc == "total"
	isid pmid
	drop dup minyr
	save "../output/BTC_pmids.dta", replace
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
    save ../output/select_jrnls_pmids, replace
end
main
