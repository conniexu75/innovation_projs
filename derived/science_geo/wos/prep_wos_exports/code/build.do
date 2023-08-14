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
    foreach samp in cns_med scijrnls natsub demsci {
        local fol = cond("`samp'"=="cns_med","main","robust")
        create_wos_queries, samp(`samp') fol(`fol')
    }
end

program create_wos_queries
    syntax, samp(str) fol(str)
    use ../external/`fol'/contracted_pmids_`samp'.dta, clear
    gen group = int((_n-1)/450)
    tostring pmid, replace
    bys group: gen top = _n == 1
    forval ii = 1/449 {
        replace pmid = pmid + " OR " + pmid[_n+`ii'] if top & group == group[_n+`ii']
    }
    gen peak = substr(pmid, -15, .) // to look at last pmid on the list and verify
                                    // it's the same as the 500th pmid in the group
    drop if !top
    replace pmid = "PMID=(" + pmid
    replace pmid = pmid + ")"
    ren pmid query
    drop top peak
    export excel using "../output/wos_`samp'_queries.xlsx", replace
end
main
