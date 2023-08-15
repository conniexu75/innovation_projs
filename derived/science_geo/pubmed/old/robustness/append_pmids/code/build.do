set more off
clear all
capture log close
program drop _all
set scheme modern
preliminaries
version 17
set maxvar 120000, perm

program main   
    append_subsamples
    append_jrnls
end

program append_subsamples
    foreach samp in sci nat dem plo {
        local upper = strupper("`samp'")
        local filelist: dir "../external/samp/`upper'/" files "`samp'_*.csv"
        foreach file in `filelist' {
            import delimited using "../external/samp/`upper'/`file'", varnames(1) clear
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
        save ../temp/`upper'_appended, replace
        
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
        drop tot_fund fund dup
        save "../output/`upper'_indicies_pmids.dta", replace
}
        use ../output/DEM_indicies_pmids, clear
        append using ../output/PLO_indicies_pmids
        save ../output/DEM_indicies_pmids, replace
end

program append_jrnls 
    local jrnls cell_stem_cell faseb jbc nat_biotech nat_cell_bio nat_chem_bio nat_genet nat_med nat_neuro neuron onco plos 
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
        bys pmid: egen minyr = min(year)
        drop if year > minyr
        drop minyr
        gisid pmid
        save ../output/`jrnl'_all_pmids, replace
    }
    clear
    foreach j in nat_genet nat_med nat_biotech nat_cell_bio nat_chem_bio {
        append using ../output/`j'_all_pmids
    }
    save ../output/natsub_all_pmids, replace

    clear
    foreach j in plos jbc onco faseb {
        append using ../output/`j'_all_pmids
    }
    save ../output/demsci_all_pmids, replace

    clear
    foreach j in neuron nat_neuro cell_stem_cell {
        append using ../output/`j'_all_pmids
    }
    save ../output/scijrnls_all_pmids, replace
end
main
