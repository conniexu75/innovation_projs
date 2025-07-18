set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975

program main
    use ../external/inst/make_delta_figs_inst_year_second, clear
    bys athr_id (which_place year): gen inst_ln_y_diff = inst_ln_y[_n+1] - inst_ln_y
    bys athr_id (which_place year): gen star_inst_ln_y_diff = star_inst_ln_y[_n+1] - star_inst_ln_y
    bys athr_id (which_place year): gen inst_ln_cns_y_diff = inst_ln_cns_y[_n+1] - inst_ln_cns_y
    keep inst_ln_y_diff star_inst_ln_y_diff inst_ln_cns_y_diff
    gen group = 1
    save ../temp/df1, replace
    use ../external/city/delta_dist_msa, clear
    bys athr_id (which_place year): gen msa_wo_inst_diff = msa_wo_inst[_n+1] - msa_wo_inst 
    gen group = 2
    keep group *_diff
    append using ../temp/df1
    foreach v in inst_ln_y_diff star_inst_ln_y_diff {
        sum `v', d
        local m_`v' : dis %6.3f r(mean)
        local n_`v' = r(N) 
        local sd_`v' : dis %5.3f  r(sd)
    }
    tw kdensity inst_ln_y_diff if group == 1 & inrange(inst_ln_y_diff, -4,4), lcolor(lavender) || kdensity star_inst_ln_y_diff if group == 1 & inrange(inst_ln_y_diff,-4,4), lcolor(orange)  ytitle("Share of Movers", size(vsmall)) xtitle("Destination-Origin Difference in Log Output", size(vsmall)) legend(on order(1 "Institution: N = `n_inst_ln_y_diff'; mean = `m_inst_ln_y_diff'" 2 "Institution Stars: N = `n_star_inst_ln_y_diff'; mean = `m_star_inst_ln_y_diff'") size(vsmall) ring(0) pos(1) region(fcolor(none))) xlab(-4(1)4, labsize(vsmall)) ylab(, labsize(vsmall))
    graph export ../output/delta_dist.pdf, replace

end
** 
main
