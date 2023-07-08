set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global pubmed_name "PubMed"
    global acs_name "ACS Life Science"
    global bio_name "ACS Bio/Medicine"
    output_tables
end

program cluster_desc
    use ../external/pubmed/athr_panel, clear
    rename (cluster_shr cite_affl_wt msa_comb) (pubmed_cluster article_cnt msatitle)
/*    merge m:1 msatitle year using ../external/acs/acs_clusters, assert(1 2 3) keep(1 3) nogen 
    rename cluster_shr acs_cluster
    gegen msa = group(msatitle)

    preserve
    gcollapse (mean) pubmed_cluster acs_cluster bio_cluster, by(msatitle)
    gsort -pubmed_cluster
    gen msa_label = msatitle if inlist(msatitle, "Boston-Cambridge-Newton, MA-NH", "New York-Newark-Jersey City, NY-NJ-PA", "Washington-Arlington-Alexandria, DC-VA-MD-WV", "Bay Area, CA")
    gen clock =  .
    replace clock = 9 if inlist(msa_label, "New York-Newark-Jersey City, NY-NJ-PA", "Bay Area, CA")
    replace clock = 6 if inlist(msa_label, "Washington-Arlington-Alexandria, DC-VA-MD-WV")
    corr pubmed_cluster acs_cluster
    local corr: di %3.2f r(rho)
    tw scatter pubmed_cluster acs_cluster, mlabel(msa_label) xtitle("ACS Life Sciences Cluster Size") ytitle("Pubmed Cluster Size") mlabsize(small) mlabcolor(black) mlabvp(clock) ///
     legend(on order(- "Correlation = `corr'") size(small) pos(5) ring(0) region(lwidth(none))) 
    graph export ../output/figures/pubmed_acs_corr.pdf, replace
    corr pubmed_cluster bio_cluster
    local corr: di %3.2f r(rho)
    tw scatter pubmed_cluster bio_cluster, mlabel(msa_label) xtitle("ACS Biologist/Medical Scientists Cluster Size") ytitle("Pubmed Cluster Size") mlabsize(small) mlabcolor(black) mlabvp(clock) ///
     legend(on order(- "Correlation = `corr'") size(small) pos(5) ring(0) region(lwidth(none))) 
    graph export ../output/figures/pubmed_acs_bio_corr.pdf, replace
    restore*/
end
program regression 
    gen ln_basic = ln(expanded_wt)
    gen ln_pubmed_cluster = ln(pubmed_cluster)
    gen ln_acs_cluster = ln(acs_cluster)
    gen ln_bio_cluster = ln(bio_cluster)
    foreach c in pubmed {
        qui reghdfe ln_basic ln_`c'_cluster, absorb(year msa) 
        local slope: di %3.2f _b[ln_`c'_cluster]
        binscatter2 ln_basic ln_`c'_cluster, absorb(year msa) xtitle("ln(${`c'_name})") ytitle("ln(Basic Research)") legend(on order(- "Slope = `slope'") size(small) pos(5) ring(0) region(lwidth(none))) 
        graph export ../output/figures/bs_`c'.pdf, replace
    }
    foreach c in pubmed {
        reghdfe ln_basic ln_`c'_cluster, noabsorb
        mat `c'_coef = nullmat(`c'_coef), (_b[ln_`c'_cluster] \ e(N))
        reghdfe ln_basic ln_`c'_cluster, absorb(year)
        mat `c'_coef = nullmat(`c'_coef), (_b[ln_`c'_cluster] \ e(N))
        reghdfe ln_basic ln_`c'_cluster, absorb(year msa)
        mat `c'_coef = nullmat(`c'_coef), (_b[ln_`c'_cluster] \ e(N))
        reghdfe ln_basic ln_`c'_cluster, absorb(year msa name_grp)
        mat `c'_coef = nullmat(`c'_coef), (_b[ln_`c'_cluster] \ e(N))
    }
end
program output_tables
    *mat coef = pubmed_coef \ acs_coef

    foreach file in pubmed_coef { //acs_coef bio_coef  {
         qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
    }

end
** 
main
