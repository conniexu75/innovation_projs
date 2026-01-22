set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
global temp "/export/scratch/cxu_sci_geo/get_cites"
set maxvar 120000

program main
    append_athr_works
end
program append_athr_works
    forval i = 1/11442 {
         di "`i'"
         import delimited ../external/pprs/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited) delimiters(",")
         gcontract ath_id id 

    }

end
