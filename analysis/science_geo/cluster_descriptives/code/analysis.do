set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    regression
    output_tables
end

program regression 
    use ../external/pubmed/athr_panel_full, clear
    drop if mi(msa_comb)
    gegen msa = group(msa_comb)
    gen ln_basic = ln(affl_wt)
    gen ln_cluster = ln(cluster_shr)
    qui reghdfe ln_basic ln_cluster, absorb(year msa) 
    local slope: di %3.2f _b[ln_cluster]
    binscatter2 ln_basic ln_cluster, absorb(year msa) xtitle("ln(Cluster Share)") ytitle("ln(Basic Research)") legend(on order(- "Slope = `slope'") size(small) pos(5) ring(0) region(lwidth(none))) 
    graph export ../output/figures/bs.pdf, replace
    
    reghdfe ln_basic ln_cluster, noabsorb
    mat coef = nullmat(coef), (_b[ln_cluster] \ e(N))
    reghdfe ln_basic ln_cluster, absorb(year)
    mat coef = nullmat(coef), (_b[ln_cluster] \ e(N))
    reghdfe ln_basic ln_cluster, absorb(year msa)
    mat coef = nullmat(coef), (_b[ln_cluster] \ e(N))
    reghdfe ln_basic ln_cluster, absorb(year msa athr_id)
    mat coef = nullmat(coef), (_b[ln_cluster] \ e(N))
end

program output_tables
    foreach file in coef { 
         qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
    }

end
** 
main
