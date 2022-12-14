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
    global demsci_num 10 
    global cns_med_num 6
    global scijrnls_num 1
    global natsub_num 1
    foreach samp in scijrnls natsub cns_med demsci {
        append_wos, samp(`samp')  num_fols(${`samp'_num})
    }
    clear
    foreach j in scijrnls natsub {
        append using  ../output/`j'_appended
    }
    save ../output/scisub_appended, replace
    clear 
    foreach j in cns med {
        use ../output/cns_med_appended, clear
        merge 1:1 pmid using ../external/jrnls/`j'_all_pmids, assert(1 2 3) keep (3) nogen
        save ../output/`j'_appended, replace
    }
end

program append_wos
    syntax, samp(str) num_fols(int)
    forval i = 1/`num_fols' {
        local filelist`i': dir "../external/wos/`samp'`i'" files "*.txt"
        local counter = 1
        foreach file of local filelist`i' {
            import delimited "../external/wos/`samp'`i'/`file'",  clear delim("\t") varn(1) 
            keep pm tc fu fx pd py
            rename (pm tc fu fx pd py) (pmid cite_count funding_agency funding_txt pub_mnth pub_year)
            tostring pmid, replace
            drop if inlist(pmid, "NA","")
            drop if substr(pmid,1,3) == "WOS"
            destring pmid, replace force
            destring cite_count pub_year, replace force
            drop if pmid == .
            tostring funding* pub_mnth, replace
            save ../temp/`samp'`i'_`counter', replace
            local counter = `counter' + 1
        }
        clear
        local filelist : dir "../temp/" files "`samp'`i'*.dta"
        foreach file in `filelist' {
            append using ../temp/`file'
        }
        save ../temp/`samp'`i'_appended, replace
    }
    clear
    forval i = 1/`num_fols' {
        append using ../temp/`samp'`i'_appended
    }
    gduplicates drop pmid, force
    save ../output/`samp'_appended, replace
end
main
