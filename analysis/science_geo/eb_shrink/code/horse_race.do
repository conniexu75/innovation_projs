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
set maxvar 120000, perm
program main
    use ../external/samp/athr_panel_full_comb_year_second, clear
    contract inst inst_id 
    drop _freq
    save ../temp/inst_xw, replace
    foreach t in year_second {
        forval i = 0(5)150 {
            add_decomp, samp(`t')  num_movers(`i')
            var_decomp, samp(`t')  num_movers(`i')
            output_tables, samp(`t')  num_movers(`i')
        }
        clear
        forval i = 50(25)150 {
            append using ../output/values_`i'
        }
        save ../output/appended_values, replace
    }
    use ../../decomp/output/horse_race, clear
    gen cat = "no shrink"
    append using ../output/appended_values
    replace cat = "eb" if mi(cat)
    tw line cov num_movers if cat == "no shrink" , lcolor(lavender) || ///
        scatter cov num_movers if cat == "no shrink", mcolor(lavender) || ///
        line cov num_movers if cat == "eb" , lcolor(dkorange)  || ///
        scatter cov num_movers if cat == "eb", mcolor(dkorange) ///
        legend(on order(1 "Unadjusted" 3 "EB Adjusted") pos(11) ring(0) size(small)) xtitle("Min. Number of Movers at Institution") ytitle("Cov(Author FE, Institution FE)") xlab(0(25)150) ylab(-.5(.1).5)
    graph export ../output/figures/comp_cov.pdf, replace
    tw line share_uni num_movers if cat == "no shrink" , lcolor(lavender) || ///
        scatter share_uni num_movers if cat == "no shrink", mcolor(lavender) || ///
        line share_uni num_movers if cat == "eb" , lcolor(dkorange)  || ///
        scatter share_uni num_movers if cat == "eb", mcolor(dkorange) ///
        legend(on order(1 "Unadjusted" 3 "EB Adjusted") pos(11) ring(0) size(small)) xtitle("Min. Number of Movers at Institution") ytitle("share_uni") xlab(0(25)150) ylab(-.5(.1).5)
    graph export ../output/figures/comp_share_uni.pdf, replace

end
program add_decomp 
    syntax, samp(str) num_movers(int)
    cap mat drop _all
    use ../external/movers/mover_temp_`samp', clear
    merge m:1 athr_id using ../external/movers/mover_xw_`samp', keep(1 3) nogen
    gen ln_y = ln(impact_cite_affl_wt)
    bys inst_id year: gen yr_cnt = _n == 1
    bys inst_id: egen tot_yrs = total(yr_cnt)
    bys inst_id athr_id : gen athr_cnter = _n == 1
    bys inst_id  : egen athr_cnt= total(athr_cnter)
    bys inst_id: egen tot_movers = total(athr_cnter &  mover == 1)
    bys inst_id athr_id year : gen athr_cnt_id = _n == 1
    bys inst_id year : egen athr_yrs = total(athr_cnt_id)
    bys inst_id year : gen athr_yr_id = _n ==1
    replace athr_yrs = . if athr_yr_id != 1
    bys inst_id: egen avg_athr_yrs = mean(athr_yrs)
    gegen inst_grp = group(inst_id)
    gegen athr_grp = group(athr_id)
    drop if athr_cnt < `num_movers' 
    reghdfe ln_y i.inst_grp , absorb(athr_fes = athr_id year_fes = year) residual 
    predict y_hat , xbd
    replace y_hat = y_hat -  year_fes
    // eb shrink inst_fes
    glevelsof inst_grp, local(insts)
    foreach i in `insts' {
        cap mat eb_`num_movers' = nullmat(eb_`num_movers') \ ( `i', _b[`i'.inst_grp], _se[`i'.inst_grp]) 
    }
    preserve
    svmat eb_`num_movers'
    keep eb_`num_movers'1 eb_`num_movers'2 eb_`num_movers'3
    rename (eb_`num_movers'1 eb_`num_movers'2 eb_`num_movers'3) (inst_grp beta se)
    drop if mi(beta)
    drop if se == 0
    sum beta
    local mean = r(mean)
    gen eb = (beta-`mean')^2
    gen se2 = se*se
    gen sigma = eb - se2
    sum sigma
    local sigma = r(mean)
    gen beta_eb = `mean'*(se2/(se2+`sigma'))+beta*(`sigma'/(se2+`sigma'))
    keep inst_grp beta se beta_eb
    tw hist beta, freq color(lavender%70) || hist beta_eb, freq color(dkorange%70) legend(on label(1 "Unadusted") label(2 "EB Adjusted") pos(1) ring(0)) 
    graph export ../output/figures/eb_dist`num_movers'.pdf , replace
    save ../temp/eb_shrink`num_movers', replace
    restore
    merge m:1 inst_grp using ../temp/eb_shrink`num_movers', assert(1 3) keep(1 3) nogen
    corr beta_eb athr_fes
    preserve
    gcollapse (mean) y_hat , by(inst_id year)
    gcollapse (mean) y_hat , by(inst_id)
    drop if mi(y_hat)
    sum y_hat, d
    local y_var = r(Var)
    local y_p50 = r(p50)
    local y_p95 = r(p95)
    local y_p5 = r(p5)
    local y_p90 = r(p90)
    local y_p10 = r(p10)
    local y_p75 = r(p75)
    local y_p25 = r(p25)
    foreach i in 5 10 25 50 {
        local top = 100 - `i'
        gen top_`top' = y_hat > `y_p`top''
        gen bottom_`i' = y_hat < `y_p`i''
    }
    merge 1:1 inst_id using ../temp/inst_xw, keep(3) nogen
    save ../temp/inst_ranks`num_movers', replace
    restore
    merge m:1 inst_id using ../temp/inst_ranks`num_movers', keep(3) nogen
    foreach i in 5 10 25 50 {
        preserve
        local top = 100 - `i'
        keep if top_`top' == 1
        gcollapse (mean) y_hat athr_fes (firstnm) beta_eb, by(inst_id year) 
        gcollapse (mean) y_hat athr_fes (firstnm) beta_eb, by(inst_id) 
        qui sum y_hat 
        local y_top_mean = r(mean)
        qui sum beta_eb 
        local inst_top_mean = r(mean)
        qui sum athr_fes 
        local athr_top_mean = r(mean)
        restore
        preserve
        keep if bottom_`i' == 1 
        gcollapse (mean) y_hat athr_fes (firstnm) beta_eb, by(inst_id year) 
        gcollapse (mean) y_hat athr_fes (firstnm) beta_eb, by(inst_id) 
        qui sum y_hat 
        local y_bottom_mean = r(mean)
        sum beta_eb, d
        qui sum beta_eb 
        local inst_bottom_mean = r(mean)
        qui sum athr_fes 
        local athr_bottom_mean = r(mean)
        restore
        mat add_decomp_`samp'`num_movers' = nullmat(add_decomp_`samp'`num_movers') , (`y_top_mean' - `y_bottom_mean' \ `athr_top_mean' - `athr_bottom_mean' \ `inst_top_mean' - `inst_bottom_mean' \ (`athr_top_mean' - `athr_bottom_mean')/(`y_top_mean' - `y_bottom_mean') \ (`inst_top_mean' - `inst_bottom_mean')/(`y_top_mean' - `y_bottom_mean')) 
    }
    contract inst_id inst_grp
    drop _freq
    save ../temp/inst_grp_xw`num_movers', replace
end

program var_decomp
    syntax, samp(str) num_movers(int)
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
    reghdfe ln_y, absorb(inst_fes = inst_id athr_fes = athr_id year_fes = year) residual
    merge m:1 inst_id using ../temp/inst_grp_xw`num_movers',  keep(3) nogen
    merge m:1 inst_grp using ../temp/eb_shrink`num_movers',  keep(3) nogen
    hashsort inst_id beta_eb
    by inst_id:  replace beta_eb = beta_eb[_n-1] if mi(beta_eb)
    hashsort year year_fes
    by year:  replace year_fes = year_fes[_n-1] if mi(year_fes)
    hashsort athr_id athr_fes
    by athr_id:  replace athr_fes = athr_fes[_n-1] if mi(athr_fes)
    predict y_hat , xbd
    replace y_hat = y_hat -  year_fes
    gcollapse (mean) y_hat ln_y athr_fes (firstnm) beta_eb , by(inst_id year)
    gcollapse (mean) y_hat ln_y athr_fes (firstnm) beta_eb, by(inst_id)
    drop if mi(y_hat)
    corr beta_eb athr_fes
    local corr = r(rho)
    sum y_hat, d
    local y_var = r(Var)
    sum beta_eb, d
    local inst_var = r(Var)
    sum athr_fes, d
    local athr_var = r(Var)

    di "variance reduction if we equalize place-factors is: " 1-`athr_var'/`y_var'
    di "variance reduction if we equalize person-factors is: " 1-`inst_var'/`y_var'
    mat var_decomp_`samp'`num_movers'   = `y_var' \ `inst_var' \ `athr_var' \ `corr' \  (1-`inst_var'/`y_var') \ (1-`athr_var'/`y_var') 
    mat horse_race`num_movers'   = `num_movers',  (1-`athr_var'/`y_var'), `corr' 
    svmat horse_race`num_movers'                                                                         
    drop if mi(horse_race`num_movers'1)                                            
    keep horse_race*
    rename  (horse_race`num_movers'1 horse_race`num_movers'2 horse_race`num_movers'3) (num_movers share_uni cov)
    save ../output/values_`num_movers', replace
end
program output_tables
    syntax, samp(str) num_movers(int)
    foreach file in add_decomp var_decomp { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'`num_movers'.txt") matrix(`file'_`samp'`num_movers') ///
           title(<tab:`file'_`samp'`num_movers'>) format(%20.4f) replace
    }
end
** 
main
