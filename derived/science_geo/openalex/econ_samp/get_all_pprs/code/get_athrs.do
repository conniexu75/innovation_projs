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
    append_athrs
end
program append_athrs
    foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
        import delimited using ../external/openalex/`j', clear varn(1) bindquotes(strict)
        save ../temp/`j', replace
    }
    clear 
    foreach j in qje aer jpe econometrica restud aejae aejep aejmac aejmicro aerinsights ej ier jeea qe restat {
        append using ../temp/`j'
    }
    
    gcontract athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_athrs, replace
end

main
