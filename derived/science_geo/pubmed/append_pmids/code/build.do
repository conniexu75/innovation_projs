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
        forval y = 1998/2022 {
            import delimited using "../external/samp/`samp'_`y'", clear varn(1)
            tostring pmid, replace
            tostring query_name, replace
            drop if pmid == "NA"
            destring pmid, replace
            save ../temp/`samp'_`y', replace

            import delimited using "../external/samp/plos_`samp'_`y'", clear varn(1)
            tostring pmid, replace
            tostring query_name, replace
            drop if pmid == "NA"
            destring pmid, replace
            save ../temp/plos_`samp'_`y', replace
        }
    }
    local filelist: dir "../temp/" files "*.dta"
    clear
    foreach file in `filelist' {
        append using ../temp/`file'
    }
    save ../temp/newfund_pmids, replace

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
    
    drop dup 
    duplicates tag pmid cat, gen(dup)
    gen dis = cat == "diseases"
    bys pmid: egen tot_dis = max(dis)
    drop if dup > 0 & tot_dis == 1 &  dis != 1
    gduplicates drop 
	gisid pmid
	replace pmid = pmid/10000 if inlist(cat, "fundamental", "diseases", "therapeutics")
    drop dup fund tot_fund
	save "../output/newfund_pmids.dta", replace
end

program append_jrnls 
    local jrnls  nejm jama lancet bmj annals science nature cell onco neuron nat_neuro nat_med nat_genet nat_chem_bio nat_cell_bio nat_biotech cell_stem_cell faseb jbc plos
    foreach jrnl in `jrnls' {
        forval yr = 1988/2022 {
            import delimited ../external/samp/`jrnl'`yr'.csv, clear
            tostring pmid, replace
            drop if pmid == "NA"
            destring pmid, replace
            save ../temp/`jrnl'`yr', replace
        }
        clear
        forval yr = 1988/2022 {
            append using ../temp/`jrnl'`yr'
        }
        gen journal_abbr = "`jrnl'"
        save ../temp/`jrnl', replace
    }
    local cns cell nature science
    local med nejm jama lancet bmj annals lancet
    local scisub neuron nat_neuro nat_med nat_genet nat_chem_bio nat_cell_bio nat_biotech cell_stem_cell
    local demsci onco faseb jbc plos
    local all_jrnls `cns' `scisub' `demsci'

    foreach samp in cns med scisub demsci all_jrnls {
        clear
        foreach jrnl in ``samp'' {
            append using ../temp/`jrnl'
        }
        gduplicates drop 
        bys pmid: egen minyr = min(year)
        drop if year > minyr
        drop minyr
        gisid pmid
        save ../output/`samp'_all_pmids, replace
    }
end
main
