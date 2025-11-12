set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global y_name "Productivity"
global pat_adj_wt_name "Patent-to-Paper Citations"
global ln_patent_name "Log Patent-to-Paper Citations"
global ln_y_name "Log Productivity"
global x_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year 
program main
    use ../external/samp/athr_panel_full_comb_year_second, clear
    contract inst inst_id 
    drop _freq
    save ../temp/inst_xw, replace
    foreach t in year_second {
        var_decomp, samp(`t') 
        output_tables, samp(`t') 
    }
end
program var_decomp
    syntax, samp(str)
    use ../external/movers/mover_temp_`samp', clear
    merge m:1 athr_id using ../external/movers/mover_xw_`samp', keep(1 3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    bys inst_id athr_id: gen athr_tag = _n == 1 & analysis_cond == 1
    bys inst_id: egen num_athrs = total(athr_tag)
    bys inst_id year: gen yr_cnt = _n == 1
    bys inst_id: egen tot_yrs = total(yr_cnt)
    bys inst_id athr_id : gen athr_cnter = _n == 1
    bys inst_id  : egen athr_cnt= total(athr_cnter)
    bys inst_id athr_id year : gen athr_cnt_id = _n == 1
    bys inst_id year : egen athr_yrs = total(athr_cnt_id)
    bys inst_id year : gen athr_yr_id = _n ==1
    replace athr_yrs = . if athr_yr_id != 1
    bys inst_id: egen avg_athr_yrs = mean(athr_yrs)
    bys inst_id: egen tot_movers = total(athr_cnter &  mover == 1)
    forval i = 0(5)150 {
        preserve
        *drop if avg_athr_yrs < 100 
        drop if athr_cnt < `i' ///&  tot_movers < 10

        reghdfe ln_y , absorb(inst_fes = inst_id athr_fes = athr_id year_fes = year) residual
        hashsort inst_id inst_fes
        by inst_id:  replace inst_fes = inst_fes[_n-1] if mi(inst_fes)
        hashsort year year_fes
        by year:  replace year_fes = year_fes[_n-1] if mi(year_fes)
        hashsort athr_id athr_fes
        by athr_id:  replace athr_fes = athr_fes[_n-1] if mi(athr_fes)
        predict y_hat , xbd
        replace y_hat = y_hat -  year_fes
        gcollapse (mean) y_hat ln_y athr_fes (firstnm) inst_fes , by(inst_id year)
        gcollapse (mean) y_hat ln_y athr_fes (firstnm) inst_fes, by(inst_id)
        drop if mi(y_hat)
        corr inst_fes athr_fes
        local corr = r(rho)
        sum y_hat, d
        local y_var = r(Var)
        sum inst_fes, d
        local inst_var = r(Var)
        sum athr_fes, d
        local athr_var = r(Var)

        di "variance reduction if we equalize place-factors is: " 1-`athr_var'/`y_var'
        di "variance reduction if we equalize person-factors is: " 1-`inst_var'/`y_var'
        gunique inst_id
        mat var_decomp_`samp' = nullmat(var_decomp_`samp') \ (`i',  (1-`inst_var'/`y_var'), `corr', r(unique)) 
        restore
    }
    svmat var_decomp_`samp'
    drop if mi(var_decomp_`samp'1)
    keep var_decomp_`samp'*
    tw line var_decomp_`samp'2 var_decomp_`samp'1, lcolor(lavender) || ///
        scatter var_decomp_`samp'2 var_decomp_`samp'1, mcolor(lavender) || ///
        line var_decomp_`samp'3 var_decomp_`samp'1, lcolor(dkorange) || ///
        scatter var_decomp_`samp'3 var_decomp_`samp'1, mcolor(dkorange) xtitle("Number of Movers Per Institution") ytitle("") legend(on order(1 "Share of University Effect" 3 "Covariance(Author FE, Institution FE)") pos(11) ring(0) size(small)) ylabel(-0.5(0.1)0.5, labsize(small)) xlabel(0(5)150, labsize(small) angle(45)) 
    graph export ../output/figures/horse_race.pdf, replace
    rename (var_decomp_`samp'1 var_decomp_`samp'2 var_decomp_`samp'3 var_decomp_`samp'4) (num_movers share_uni cov num_insts)
    save ../output/horse_race, replace
end

program output_tables
    syntax, samp(str)
    foreach file in var_decomp { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }

end
** 
main
