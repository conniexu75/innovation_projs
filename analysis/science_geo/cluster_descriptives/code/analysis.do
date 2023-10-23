set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975

program main
    maps
    raw_bs
    regression
    *output_tables
end

program  maps
    spshape2dta ../external/geo/cb_2018_us_state_500k.shp, replace saving(usa_state)
    use usa_state_shp, clear
    merge m:1 _ID using usa_state
    destring STATEFP, replace
    drop if inlist(STATEFP,2,15,60,66,69,72,78)
    geo2xy _Y _X, proj(web_mercator) replace
    drop _CX- _merge
    sort _ID shape_order
    save usa_state_shp_clean.dta, replace

    spshape2dta ../external/geo/cb_2018_us_cbsa_500k.shp, replace saving(usa_msa)
    use usa_msa_shp, clear
    merge m:1 _ID using usa_msa, nogen
    gen state = strtrim(substr(NAME, strpos(NAME, ",")+1, 3))
    drop if inlist(state, "AK", "HI")
    geo2xy _Y _X, proj(web_mercator) replace
    sort _ID shape_order
    save usa_msa_shp_clean.dta, replace

    use ../external/samp/athr_panel_full, clear
    merge m:1 msacode using ../external/geo/msas, assert(1 2 3) keep(1 3) nogen
    replace msa_comb = msatitle if !mi(msatitle)
    replace msa_comb = "San Francisco-Oakland-Hayward, CA" if msa_comb == "San Francisco-Oakland-Haywerd, CA"
    replace msa_comb = "Macon-Bibb County, GA" if msa_comb == "Macon, GA"
    gcollapse (sum) unq_affl_wt unq_cite_affl_wt (mean) msa_size cluster_shr avg_team_size , by(msa_comb field)
    save ../temp/map_samp, replace

    use usa_msa, clear
    rename NAME msa_comb
    forval i = 0/4 {
        preserve
        merge 1:m msa_comb using ../temp/map_samp, assert(1 3) keep(3) nogen
        keep if field == `i'
        foreach var in unq_affl_wt unq_cite_affl_wt msa_size cluster_shr avg_team_size {
            colorpalette carto BluYl, n(10) nograph 
            spmap `var' using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)') clnumber(5) ///
              ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") ///
              polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
              legend(pos(5) size(2.5))  legstyle(2)
            graph export ../output/figures/`var'_map_`i'.pdf, replace
        }
        restore
    }
end

program raw_bs
    use ../external/samp/athr_panel_full_comb, clear
    drop if mi(msa_comb) 
    gegen msa = group(msa_comb)
    gen ln_y = ln(unq_cite_affl_wt)
    gen ln_x = ln(msa_size)

    // team size vs msa size
    qui reg avg_team_size  ln_x 
    local coef = _b[ln_x]
    binscatter2 avg_team_size ln_x, xtitle("Absolute Cluster Size") ytitle("Average Team Size") legend(on order(- "Slope = `coef'") pos(5) ring(0))
    graph export ../output/figures/team_v_msa.pdf, replace

    // team size vs productivity
    qui reg ln_y avg_team_size 
    local coef = _b[avg_team_size]
    binscatter2 ln_y avg_team_size , xtitle("Average Team Size") ytitle("Citation-weighted Affiliation-Adjusted Count") legend(on order(- "Slope = `coef'") pos(5) ring(0))
    graph export ../output/figures/team_v_output.pdf, replace
end

program top_clusters



end

program regression 
    use ../external/samp/athr_panel_full_comb, clear 
    drop if mi(msa_comb) 
    gegen msa = group(msa_comb)
    gen ln_y = ln(unq_cite_affl_wt)
    gen ln_x = ln(msa_size)

    reghdfe ln_y ln_x, noabsorb
    mat coef = nullmat(coef), (_b[ln_x] \ . \ e(N))
    reghdfe ln_y ln_x avg_team_size, noabsorb
    mat coef = nullmat(coef), (_b[ln_x] \ _b[avg_team_size] \ e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year)
    mat coef = nullmat(coef), (_b[ln_x] \ _b[avg_team_size] \  e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year msa)
    mat coef = nullmat(coef), (_b[ln_x] \  _b[avg_team_size] \ e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year msa athr_id)
    mat coef = nullmat(coef), (_b[ln_x] \  _b[avg_team_size] \ e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year msa athr_id field)
    mat coef = nullmat(coef), (_b[ln_x] \  _b[avg_team_size] \ e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year msa athr_id field field#year)
    mat coef = nullmat(coef), (_b[ln_x] \  _b[avg_team_size] \ e(N))
    reghdfe ln_y ln_x avg_team_size, absorb(year msa athr_id field field#year msa#field)
    mat coef = nullmat(coef), (_b[ln_x] \  _b[avg_team_size] \ e(N))
end

program output_tables
    foreach file in coef { 
         qui matrix_to_txt, saving("../output/tables/`file'.txt") matrix(`file') ///
           title(<tab:`file'>) format(%20.4f) replace
    }

end
** 
main
