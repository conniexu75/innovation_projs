set more off 
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
global cite_affl_wt_name "Productivity"
global impact_cite_affl_wt_name "Productivity"
global body_adj_wt_name "Paper-to-Patent Citations"
global ln_y_name "Log Productivity"
global ln_pat_name "Log Paper-to-Patent Citations"
global msa_size_name "Cluster Size"
global ln_x_name "Log Cluster Size"
global time year
global year_insts "/export/scratch/cxu_sci_geo/clean_athr_inst_hist_output"


program main
    foreach s in year_firstlast {
        sample_desc, samp(`s')
        maps, samp(`s')
        raw_bs, samp(`s')
        econ_regression, samp(`s')
        regression, samp(`s')
        firm_externalities, samp(`s')
        output_tables, samp(`s')
    }
end

program sample_desc
    syntax, samp(str) 
    use ../external/econs_samp/athr_panel_full_comb_year.dta, clear
    gcollapse (mean) msa_size, by(msa_comb)
    rename msa_size econ_msa_size
    save ../temp/econs_cluster, replace
    use if !mi(msa_comb) & inrange(year, 1945,2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    count
    gunique athr_id
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_pat = ln(body_adj_wt)
    foreach var in impact_cite_affl_wt msa_size ln_y ln_x body_adj_wt ln_pat {
        qui sum `var', d
        local N = r(N)
        local mean : dis %3.2f r(mean)
        local sd : dis %3.2f r(sd)
        local p5 :  dis %3.2f r(p5)
        local p25 :  dis %3.2f r(p25)
        local p50 :  dis %3.2f r(p50)
        local p75 :  dis %3.2f r(p75)
        local p95 :  dis %3.2f r(p95)
        tw hist `var', frac ytitle("Share of author-years", size(vsmall)) xtitle("${`var'_name}", size(vsmall)) color(edkblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N = `N'" ///
                                                                "Mean = `mean'" ///
                                                                "            (`sd')" ///
                                                                "p5 = `p5'" ///
                                                                "p25 = `p25'" ///
                                                                "p50 = `p50'" ///
                                                                "p75 = `p75'" ///
                                                                "p95 = `p95'") pos(1) ring(0) size(vsmall) region(fcolor(none)))
        *graph export ../output/figures/`var'_dist`samp'.pdf, replace
    }
    preserve
    keep if inrange(year, 2015,2022)
    gcollapse (mean) msa_size cluster_shr, by(msa_comb)
    gsort -msa_size
    mkmat msa_size in 1/30, mat(top_30clus_`samp')
    li in 1/30
    mkmat msa_size in 1/10, mat(top_10clus_`samp')
    restore
    preserve
    gen has_patent_cite = pat_wt > 0
    bys athr_id msa_comb: gen athr_cnt = _n == 1
    gcollapse  (sum) athr_cnt body_adj_wt cite_affl_wt pat_wt affl_wt impact_cite_affl_wt impact_affl_wt (mean) msa_size has_patent_cite, by(msa_comb)
    merge 1:1 msa_comb using ../temp/econs_cluster, assert(1 2 3) keep(1 3) nogen

    qui reg body_adj_wt impact_cite_affl_wt 
    local coef : dis %3.2f _b[impact_cite_affl_wt]
    local N = e(N)
    binscatter2 body_adj_wt impact_cite_affl_wt , xtitle("Productivity", size(vsmall)) ytitle("Paper-to-Patent Citations", size(vsmall)) lcolor(ebblue) mcolor(gs3) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    *graph export ../output/figures/msa_pat_prod_`samp'.pdf, replace
    gen ln_pat = ln(body_adj_wt)
    gen ln_y = ln(impact_cite_affl_wt)
    qui reg ln_pat ln_y 
    local coef : dis %3.2f _b[ln_y]
    local N = e(N)
    binscatter2 ln_pat ln_y , xtitle("Log Productivity", size(vsmall)) ytitle("Log Paper-to-Patent Citations", size(vsmall)) lcolor(ebblue) mcolor(gs3)  xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    *graph export ../output/figures/msa_log_pat_prod_`samp'.pdf, replace
    
    xtile p  = msa_size, nq(20)
    gen msa_lab = "" 
   replace msa_lab =  msa_comb if msa_comb == "San Diego-Carlsbad, CA" 
   replace msa_lab =  msa_comb if msa_comb == "Bay Area, CA" 
   replace msa_lab =  msa_comb if msa_comb == "St. Louis, MO-IL" 
   replace msa_lab =  msa_comb if msa_comb == "Minneapolis-St. Paul-Bloomington, MN-WI" 
   replace msa_lab =  msa_comb if msa_comb == "Washington-Arlington-Alexandria, DC-VA-MD-WV" 
   replace msa_lab =  msa_comb if msa_comb == "Los Angeles-Long Beach-Anaheim, CA" 
   replace msa_lab =  msa_comb if msa_comb == "Boston-Cambridge-Newton, MA-NH" 
   replace msa_lab =  msa_comb if msa_comb == "New York-Newark-Jersey City, NY-NJ-PA" 
    replace msa_lab =  msa_comb  if msa_comb == "New Haven-Milford , CT" 
   egen clock = mlabvpos(msa_size econ_msa_size)
   replace clock = 9 if inlist(msa_lab , "New York-Newark-Jersey City, NY-NJ-PA","Boston-Cambridge-Newton, MA-NH", "Washington-Arlington-Alexandria, DC-VA-MD-WV")
   replace clock = 3 if inlist(msa_lab , "Minneapolis-St. Paul-Bloomington, MN-WI", "San Diego-Carlsbad, CA", "St. Louis, MO-IL", "Bay Area, CA")
    tw scatter impact_cite_affl_wt msa_size , mcolor(gs7%50) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall)) || scatter impact_cite_affl_wt msa_size if !mi(msa_lab) , mcolor(ebblue) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) xtitle("MSA Cluster Size", size(vsmall)) ytitle("MSA Productivity", size(vsmall))  jitter(5) legend(off)
   *graph export ../output/figures/cluster_prod_scatter_`samp'.pdf, replace
    corr msa_size econ_msa_size 
    local slope : dis %3.2f r(rho) 
    reg msa_size econ_msa_size
    local N = e(N)
    tw scatter msa_size econ_msa_size, mcolor(gs7%50) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall)) || ///
       scatter msa_size econ_msa_size if !mi(msa_lab) , mcolor(ebblue) mlabvp(clock) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) || ///
       (function y = _b[econ_msa_size]*x + _b[_cons], range(0 900) lpattern(dash) lcolor(lavender)), ytitle("Fundamental Science Cluster Size", size(vsmall)) xtitle("Economics Research Cluster Size", size(vsmall))  legend(on order (- "N (MSAs) = `N'" ///
                                                                                                                                                                              "Correlation = `slope'") pos(5) ring(0) region(fcolor(none)) size(vsmall) lwidth(none))
    graph export ../output/figures/econ_v_ls_`samp'.pdf, replace
    drop clock
   xtile p_prod = impact_cite_affl_wt, nq(20)
   replace msa_lab = ""
   replace msa_lab =  msa_comb if msa_comb == "San Diego-Carlsbad, CA" 
   replace msa_lab =  msa_comb if msa_comb == "Bay Area, CA" 
   replace msa_lab =  msa_comb if msa_comb == "St. Louis, MO-IL" 
   replace msa_lab =  msa_comb if msa_comb == "Minneapolis-St. Paul-Bloomington, MN-WI" 
   replace msa_lab =  msa_comb if msa_comb == "Washington-Arlington-Alexandria, DC-VA-MD-WV" 
   replace msa_lab =  msa_comb if msa_comb == "Los Angeles-Long Beach-Anaheim, CA" 
   replace msa_lab =  msa_comb if msa_comb == "Boston-Cambridge-Newton, MA-NH" 
   replace msa_lab =  msa_comb if msa_comb == "New York-Newark-Jersey City, NY-NJ-PA" 
   egen clock = mlabvpos(impact_cite_affl_wt body_adj_wt)
   replace clock = 9 if inlist(msa_lab , "New York-Newark-Jersey City, NY-NJ-PA","Boston-Cambridge-Newton, MA-NH")
   replace clock = 3 if inlist(msa_lab , "Minneapolis-St. Paul-Bloomington, MN-WI", "Washington-Arlington-Alexandria, DC-VA-MD-WV", "San Diego-Carlsbad, CA", "St. Louis, MO-IL", "Bay Area, CA")
   qui reg body_adj_wt impact_cite_affl_wt 
   local coef : dis %3.2f _b[impact_cite_affl_wt]
   local cons : dis %3.2f _b[_cons]
   local N = e(N)
   tw scatter body_adj_wt impact_cite_affl_wt  , mcolor(gs13%50) msize(vsmall) xlabel(0(5000)60000, labsize(vsmall)) ylab(0(5000)60000, labsize(vsmall)) || ///
      scatter body_adj_wt impact_cite_affl_wt if !mi(msa_lab) , mlabvp(clock) mcolor(ebblue) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) || ///
      (function y=_b[impact_cite_affl_wt]*x+_b[_cons] , range(0 60000) lpattern(dash) lcolor(lavender)), xtitle("MSA Productivity", size(vsmall)) ytitle("MSA Paper-to-Patent Citations", size(vsmall)) legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
   graph export ../output/figures/pat_prod_scatter_`samp'.pdf, replace
   /*hashsort p -cite_affl_wt 
   by p: egen mean_msa = mean(msa_size)
   by p: egen mean_cite = mean(cite_affl_wt)
   hashsort p -cite_affl_wt  
   gduplicates drop p mean_msa mean_cite, force
   drop msa_lab
   gen msa_lab = msa_comb + " " + string(${time})  + "p"+string(p)
   qui reg mean_cite mean_msa
   local coef : dis %3.2f _b[mean_msa]
   tw scatter mean_cite mean_msa, mcolor(ebblue) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall))  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) xtitle("MSA Size in Year", size(vsmall)) ytitle("Average Effective Output", size(vsmall)) legend(on order(- "Slope = `coef'") pos(5) ring(0) size(vsmall))
   *graph export ../output/figures/binscatter_`samp'.pdf, replace
   restore*/
    
/*    preserve
    keep if inrange(year , 2015,2022)
    gcollapse (mean) msa_size cluster_shr, by(msa_comb)
    gsort - msa_size
    mkmat msa_size in 1/30, mat(top_30clus_`samp')
    li in 1/30
    mkmat msa_size in 1/10, mat(top_10clus_`samp')
    restore*/
/*    gcollapse (mean) msa_size_field field_cluster_shr, by(msa_comb field)
    forval i = 0/4 {
        preserve
        keep if field ==`i'
        gsort -msa_size_field
        li in 1/10
        restore
    }*/

end

program  maps
    syntax, samp(str) 
    spshape2dta ../external/geo/cb_2018_us_state_500k.shp, replace saving(usa_state)
    use usa_state_shp, clear
    merge m:1 _ID using usa_state
    destring STATEFP, replace
    drop if STATEFP > 56
    // alaska
    drop if _X > 0 & !mi(_X) & STATEFP == 2  
    geo2xy _Y _X if STATEFP ==2, proj(mercator) replace
    replace _Y = _Y / 5 +1200000 if STATEFP == 2 
    replace _X = _X / 5 - 2000000  if STATEFP == 2 
    drop if _X < -160 & !mi(_X) & _ID == 43  // small islands to the west
    geo2xy _Y _X if _ID == 43, proj(mercator) replace
    replace _Y = _Y  + 800000 if _ID == 43
    replace _X = _X  - 1200000 if _ID == 43
    geo2xy _Y _X if !inlist(_ID, 28,43), replace proj(mercator)
    replace _X = _X + 53500 if !inlist(_ID, 28,43)
    replace _Y = _Y - 3100 if !inlist(_ID, 28,43)
    drop _CX- _merge
    sort _ID shape_order
    save usa_state_shp_clean.dta, replace
    
    spshape2dta ../external/geo/cb_2018_us_cbsa_500k.shp, replace saving(usa_msa)
    use usa_msa_shp, clear
    merge m:1 _ID using usa_msa, nogen
    destring CBSAFP, replace
    gen state = strtrim(substr(NAME, strpos(NAME, ",")+1, 3))
    drop if inlist(state, "PR")
    // alaska
    drop if _X > 0 & !mi(_X) & state == "AK" 
    geo2xy _Y _X if state == "AK" , proj(mercator) replace
   replace _Y = _Y / 5 + 1200000 if state == "AK"
    replace _X = _X / 5 - 1705000 if state == "AK" 
    drop if _X < -160 & !mi(_X) & state == "HI"  // small islands to the west
    geo2xy _Y _X if state == "HI", proj(mercator) replace
    replace _Y = _Y + 800000 if state == "HI" 
    replace _X = _X  - 1200000 if state == "HI" 
    geo2xy _Y _X if !inlist(state, "AK", "HI"), replace proj(mercator)
    sort _ID shape_order
    save usa_msa_shp_clean.dta, replace

    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_`samp', clear
*    bys msa_comb: egen mode = mode(msacode)
*    replace msacode = mode
    merge m:1 msacode using ../external/geo/msas, assert(1 2 3) keep(1 3) nogen
    replace msa_comb = msatitle if !mi(msatitle)
    replace msa_comb = "San Francisco-Oakland-Hayward, CA" if msa_comb == "San Francisco-Oakland-Haywerd, CA"
    replace msa_comb = "Macon-Bibb County, GA" if msa_comb == "Macon, GA"
    bys athr_id msa_comb ${time} : gen count = _n == 1
    gcollapse (sum) affl_wt impact_cite_affl_wt body_adj_wt (mean) msa_size , by(msa_comb)
    save ../temp/map_samp, replace
    
    use usa_msa, clear
    rename NAME msa_comb
    merge 1:m msa_comb using ../temp/map_samp, assert(1 2 3) keep(1 3) nogen
    foreach var in impact_cite_affl_wt {
        xtile `var'_5 = `var', nq(5)
        qui sum `var' 
        local min : dis %3.2f r(min)
        local max : dis %3.2f r(max)
        _pctile `var',percentiles(20 40 60 80)
        local p20: dis %3.2f r(r1)
        local p40: dis %3.2f r(r2)
        local p60: dis %3.2f r(r3)
        local p80: dis %3.2f r(r4)
        colorpalette carto Teal, n(5) nograph 
        spmap  `var'_5 using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)'%50) clnumber(5) ///
          ocolor(white ..) osize(0.15 ..) ndfcolor(gs13) ndocolor(white ..) ndsize(0.15 ..) ndlabel("No data") ///
          polygon(data("usa_state_shp_clean") ocolor(gs2) osize(0.2) fcolor(eggshell%20)) ///
          legend(label(2 "Min-p20: `min'-`p20'") label(3 "p20-p40: `p20'-`p40'") label(4 "p40-p60: `p40'-`p60'") label(5 "p60-p80: `p60'-`p80'") label(6 "p80-Max: `p80'-`max'") pos(4) size(2)) legtitle("${`var'_name}")
        graph export ../output/figures/`var'_map_`samp'.pdf, replace
    }
end

program raw_bs
    syntax, samp(str) 
    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear
    drop if mi(msa_comb) 
    gegen msa = group(msa_comb)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_pat = ln(body_adj_wt)

    // patented vs productivity
    qui reg body_adj_wt impact_cite_affl_wt 
    local coef : dis %3.2f _b[impact_cite_affl_wt]
    local N = e(N)
    binscatter2 body_adj_wt impact_cite_affl_wt, xtitle("Productivity", size(vsmall)) ytitle("Paper-to-Patent Citations", size(vsmall)) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) mcolor(gs5) lcolor(ebblue) legend(on order(- "N (Author-years) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    *graph export ../output/figures/pat_prod_`samp'.pdf, replace
    qui reg ln_pat ln_y 
    local coef : dis %3.2f _b[ln_y]
    local N = e(N)
    binscatter2 ln_pat ln_y , xtitle("Log Productivity", size(vsmall)) ytitle("Log Paper-to-Patent Citations", size(vsmall)) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) mcolor(gs5) lcolor(ebblue) legend(on order(- "N (Author-years) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    *graph export ../output/figures/log_pat_prod_`samp'.pdf, replace
end

program econ_regression 
    syntax, samp(str) 
    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    gcollapse (mean) msa_size, by(msa_comb year)
    rename msa_size ls_msa_size
    save ../temp/ls_yr_cluster, replace
    
    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/econs_samp/athr_panel_full_comb_year.dta, clear
    merge m:1 msa_comb year using  ../temp/ls_yr_cluster, assert(1 2 3) keep(1 3) nogen
    local reg_eq "ln_y ln_x"
    local mat_est "_b[ln_x] \ _se[ln_x]"
    bys athr_id msa_comb ${time} : gen count = _n == 1
    replace msa_size = 0.0000000000001 if msa_size == 0
    replace ls_msa_size = 0.0000000000001 if ls_msa_size == 0
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gen ln_y = ln(cite_affl_wt)
    gen ln_x = ln(ls_msa_size)
    gen ln_x_econ = ln(msa_size)
    reghdfe `reg_eq', noabsorb
    local slope = _b[ln_x]
    foreach fe in "${time} msa" "${time} msa inst" "${time} msa inst athr_id" {
        reghdfe `reg_eq', absorb(`fe') vce(cluster msa)
        mat econ_coef_`samp' = nullmat(econ_coef_`samp'), (`mat_est' \ . \ . \e(N))
        local slope : dis %3.2f _b[ln_x]
    }
    reghdfe ln_y ln_x_econ, absorb(${time} msa inst athr_id) vce(cluster msa)
    mat econ_`samp' = nullmat(econ_`samp'), (. \ . \ _b[ln_x_econ] \ _se[ln_x_econ] \ e(N))
    mat econ_coef_`samp' = nullmat(econ_coef_`samp') , econ_`samp'
    mat drop econ_`samp'
end

program regression 
    syntax, samp(str) 
    use ../external/econs_samp/athr_panel_full_comb_year.dta, clear
    gcollapse (mean) msa_size, by(msa_comb year)
    rename msa_size econ_msa_size
    save ../temp/econ_yr_cluster, replace

    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    gcollapse (mean) msa_size, by(msa_comb year)
    merge 1:1 msa_comb year using ../temp/econ_yr_cluster, keep(3) nogen
    corr msa_size econ_msa_size 
    local slope : dis %3.2f r(rho) 
    reg msa_size econ_msa_size
    local N = e(N)
    gen msa_lab = "" 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "San Diego-Carlsbad, CA" & year == 1973
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "San Diego-Carlsbad, CA" & year == 19
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Trenton, NJ" & year == 2019
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "New Haven-Milford , CT" & year == 2012
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "New York-Newark-Jersey City, NY-NJ-PA" & year == 1996
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 2015 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 2012 
    tw scatter msa_size econ_msa_size, mcolor(gs7%50) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall)) || ///
       scatter msa_size econ_msa_size if !mi(msa_lab) , mcolor(ebblue) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) || ///
       (function y = _b[econ_msa_size]*x + _b[_cons], range(0 1250) lpattern(dash) lcolor(lavender)), ytitle("Fundamental Science Cluster Size", size(vsmall)) xtitle("Economics Research Cluster Size", size(vsmall))  legend(on order (- "N (MSAs) = `N'" ///
                                                                                                                                                                              "Correlation = `slope'") pos(5) ring(0) region(fcolor(none)) size(vsmall) lwidth(none))
    
    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    merge m:1 msa_comb year using  ../temp/econ_yr_cluster, assert(1 2 3) keep(1 3) nogen
/*    corr msa_size econ_msa_size 
    local slope : dis %3.2f r(rho) 
    binscatter2 msa_size econ_msa_size, mcolor(gs5) lcolor(ebblue) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) ytitle("Fundamental Science Research Cluster Size", size(vsmall)) xtitle("Economics Research Cluster Size", size(vsmall)) legend(on order(- "Correlation = `slope'") pos(5) ring(0) lwidth(none) size(vsmall) region(fcolor(none)))
    graph export ../output/figures/econ_v_ls.pdf, replace*/
    local reg_eq "ln_y ln_x"
    local mat_est "_b[ln_x] \ _se[ln_x]"
*    local reg_eq = cond("`samp'"=="year","ln_y ln_x avg_team_size","ln_y ln_x") 
*    local mat_est  = cond("`samp'"=="year","_b[ln_x] \ _se[ln_x] \ _b[avg_team_size] \ _se[ln_x]", "_b[ln_x] \ _se[ln_x]") 
    bys athr_id msa_comb ${time} : gen count = _n == 1
    replace msa_size = 0.0000000000001 if msa_size == 0
    replace econ_msa_size = 0.0000000000001 if econ_msa_size == 0
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gegen msa_field = group(msa field)
    gegen year_field = group(year field)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_x_econ = ln(econ_msa_size)
    preserve
    keep if inrange(year, 2015, 2022)
    keep if inlist(msa_comb, "Ann Arbor, MI", "San Diego-Carlsbad, CA", "Boston-Cambridge-Newton, MA-NH", "Bay Area, CA", "Gainesville, FL")
    foreach m in "Gainesville, FL" "Ann Arbor, MI" "San Diego-Carlsbad, CA" "Bay Area, CA" "Boston-Cambridge-Newton, MA-NH" {
        sum impact_cite_affl_wt if msa_comb == "`m'", d
        mat row = (r(min) , r(p5) , r(p10), r(p25), r(p50) , r(p75), r(p90) , r(p95), r(max), r(mean) , r(sd))
        sum msa_size if msa_comb == "`m'" 
        mat row = row , r(mean)
        mat city_stats_`samp' = nullmat(city_stats_`samp') \ (row)
    }
    restore
    reghdfe `reg_eq', noabsorb
    local slope = _b[ln_x]
    if "`samp'" == "year" {
        binscatter2  ln_y ln_x ,controls(avg_team_size) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
        *graph export ../output/figures/bs_`samp'.pdf, replace
    }
    if "`samp'" == "year_firstlast" {
        binscatter2  ln_y ln_x , ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
        *graph export ../output/figures/bs_`samp'.pdf, replace
    }
    foreach fe in "${time} msa field" "${time} msa field field#${time}" "${time} msa field field#${time} msa#field" "${time} msa field field#${time} msa#field inst" "${time} msa field field#${time} msa#field inst athr_id" {
        reghdfe `reg_eq', absorb(`fe') vce(cluster msa)
        mat coef_`samp' = nullmat(coef_`samp'), (`mat_est' \ . \ . \e(N))
        if "`fe'" == "${time} msa field field#${time} msa#field inst athr_id" {
            global final_elasticity = _b[ln_x]
        }
        local slope : dis %3.2f _b[ln_x]
        if "`samp'" == "year" {
            binscatter2  ln_y ln_x ,controls(avg_team_size) absorb(year msa field year_field msa_field athr_id) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
            *graph export ../output/figures/final_bs_`samp'.pdf, replace
        }
        if "`samp'" == "year_firstlast" {
            binscatter2  ln_y ln_x , absorb(year msa field year_field msa_field athr_id) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
            *graph export ../output/figures/final_bs_`samp'.pdf, replace
        }
    }
    reghdfe ln_y ln_x_econ, absorb(${time} msa field field#${time} field#msa inst athr_id) vce(cluster msa)
    mat econ_`samp' = nullmat(econ_`samp'), (. \ . \ _b[ln_x_econ] \ _se[ln_x_econ] \ e(N))
    mat coef_`samp' = nullmat(coef_`samp') , econ_`samp'
    reghdfe `reg_eq', absorb(year msa athr_id field inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id gen_mesh1 gen_mesh2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
*    mat alt_spec_`samp' = instyr_`samp' , field_`samp'
/*    reghdfe `reg_eq', absorb(year msa athr_id qualifier_name1 qualifier_name2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id term1 term2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))*/
end

program firm_externalities
    syntax, samp(str)
    // create clusters 
    use if !mi(msa_comb) & !mi(inst_id) using ${year_insts}/filled_in_panel_year, clear
    bys inst_id msa_comb year athr_id: gen count = _n == 1
    bys inst_id msa_comb year : egen inst_athrs = total(count) 
    drop count 
    bys msa_comb year athr_id: gen count = _n == 1
    bys msa_comb year : egen msa_size = total(count) 
    drop count
    bys inst_id msa_comb year: gen count = _n == 1
    bys msa_comb year: gegen num_insts = total(count)
    contract msa_comb inst_id inst year inst_athrs msa_size
    bys msa_comb year: egen sum_insts = total(inst_athrs)
    assert sum_insts == msa_size
    drop sum_insts _freq
    save ../temp/inst_cluster_size, replace

    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    drop msa_size
    merge m:1 inst_id msa_comb year  using ../temp/inst_cluster_size , assert(2 3) keep(3) nogen
    contract inst_id inst msa_comb year msa_size inst_athrs 
    gisid inst_id msa_comb year
    drop _freq
    gen wo_inst_cluster = msa_size - inst_athrs
    gen ln_wo_inst = ln(wo_inst_cluster)
    gen ln_cluster_diff = ln(msa_size) - ln_wo_inst 
    gen firm_elasticity = ln_cluster_diff * ${final_elasticity}
    drop if mi(firm_elasticity)
    bys msa_comb year: gen num_insts = _N
    drop if num_insts == 1 
    // pick a year and report some top ones . t = 2018
    preserve
    keep if year == 2018
    gsort -inst_athrs
    li msa_comb inst inst_athrs msa_size firm_elasticity in 1/10
    mkmat firm_elasticity in 1/10, mat(inst_elasticities_`samp')
    sum firm_elasticity
    restore
    bys msa_comb year: egen tot_firm_elasticity = total(firm_elasticity)
    gen perc = firm_elasticity/tot_firm_elasticity*100
    bys msa_comb year: egen tot = sum(perc)
    assert round(tot) == 100
    drop tot
    keep if inlist(msa_comb, "Boston-Cambridge-Newton, MA-NH", "Bay Area, CA", "Washington-Arlington-Alexandria, DC-VA-MD-WV", "Baltimore-Columbia-Towson, MD")
    glevelsof msa_comb, local(city)
    hashsort msa_comb year -perc
    gen group = 1 if msa_comb == "Baltimore-Columbia-Towson, MD" & inst == "Johns Hopkins University"
    replace group = 2 if msa_comb == "Baltimore-Columbia-Towson, MD" & inst == "University of Maryland, Baltimore"
    replace group = 3 if msa_comb == "Baltimore-Columbia-Towson, MD" & mi(group)
    replace group = 1 if msa_comb == "Boston-Cambridge-Newton, MA-NH" & inst == "Harvard University"
    replace group = 2 if msa_comb == "Boston-Cambridge-Newton, MA-NH" & inst == "Mass General Brigham"
    replace group = 3 if msa_comb == "Boston-Cambridge-Newton, MA-NH" & inst == "Massachusetts Institute of Technology"
    replace group = 4 if msa_comb == "Boston-Cambridge-Newton, MA-NH" & mi(group)
    replace group = 1 if msa_comb == "Bay Area, CA" & inst == "Stanford University"
    replace group = 2 if msa_comb == "Bay Area, CA" & inst == "University of California, San Francisco"
    replace group = 3 if msa_comb == "Bay Area, CA" & inst == "University of California, Berkeley"
    replace group = 4 if msa_comb == "Bay Area, CA" & mi(group)
    replace group = 1 if msa_comb == "Washington-Arlington-Alexandria, DC-VA-MD-WV" & inst == "National Institutes of Health"
    replace group = 2 if msa_comb == "Washington-Arlington-Alexandria, DC-VA-MD-WV" & inst == "National Aeronautics and Space Administration"
    replace group = 3 if msa_comb == "Washington-Arlington-Alexandria, DC-VA-MD-WV" & mi(group)
    replace inst = "UCSF" if inst == "University of California, San Francisco"
    replace inst = "UC Berkeley" if inst == "University of California, Berkeley"
    replace inst = "MIT" if inst == "Massachusetts Institute of Technology"
    foreach c in `city' {
        if "`c'" == "Boston-Cambridge-Newton, MA-NH" local suf "bos"
        if "`c'" == "Bay Area, CA" local suf "bay"
        if "`c'" == "Washington-Arlington-Alexandria, DC-VA-MD-WV" local suf "dc"
        if "`c'" == "Baltimore-Columbia-Towson, MD" local suf "balt"
        preserve
        keep if msa_comb == "`c'"
        collapse (sum) perc (firstnm) inst inst_id, by(msa_comb year group)
        hashsort msa_comb year -group
        bys year: gen stack_perc = sum(perc)
        local stacklines
        qui xtset group year
        sum group
        local max_grp = r(max)
        qui levelsof group, local(rank_grps)
        local items = `r(r)'
        foreach x of local rank_grps {
            colorpalette carto Teal, intensify(0.85)  n(`items') nograph
            local stacklines `stacklines' area stack_perc year if group == `x', fcolor("`r(p`x')'") lcolor(white) lwidth(*0.3) ||
        }
        gen labely = . 
        gen rev_group = -group
        if `max_grp' == 4 {
             qui bys year (rev_group): replace labely = perc/2 if group == 4
             qui bys year (rev_group): replace labely = perc/2 + perc[_n-1] if group == 3
             qui bys year (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 2
             qui bys year (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] + perc[_n-3] if group == 1
        }
        if `max_grp' == 3 {
             qui bys year (rev_group): replace labely = perc/2 if group == 3
             qui bys year (rev_group): replace labely = perc/2 + perc[_n-1] if group == 2
             qui bys year (rev_group): replace labely = perc/2 + perc[_n-1] + perc[_n-2] if group == 1
        }
        gen labely_lab = "Everywhere else" if group == `max_grp'
        replace labely_lab = inst if mi(labely_lab)
        local w = 27
        graph tw `stacklines' (scatter labely year if year == 2022, ms(smcircle) ///
          msize(0.2) mcolor(black%40) mlabsize(vsmall) mlabcolor(black) mlabel(labely_lab)), ///
          ytitle("Relative Productivity Spillover Effect in Cluster", size(vsmall)) xtitle("Year", size(vsmall)) xlabel(1945(2)2022, angle(45) labsize(vsmall)) ylabel(0(10)100, labsize(vsmall)) ///
          graphregion(margin(r+27)) plotregion(margin(zero)) ///
          legend(off)
        qui graph export ../output/figures/elasticity_trend_`suf'.pdf , replace
        restore
    }
    hashsort inst_id year
    tw line firm_elasticity year if inst == "Harvard University", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.04(0.02)0.16, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("Harvard University Productivity Externality", size(vsmall))
    graph export ../output/figures/harvard_elasticity_trend.pdf, replace 
    tw line firm_elasticity year if inst == "Massachusetts Institute of Technology", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.01(0.01)0.05, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("MIT Productivity Externality", size(vsmall))
    graph export ../output/figures/mit_elasticity_trend.pdf, replace 
    tw line firm_elasticity year if inst == "Mass General Brigham", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.01(0.01)0.05, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("MGH Productivity Externality", size(vsmall))
    graph export ../output/figures/mgh_elasticity_trend.pdf, replace 
    
    hashsort inst_id year
    tw line firm_elasticity year if inst == "Stanford University", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.04(0.01)0.08, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("Stanford University Productivity Externality", size(vsmall))
    graph export ../output/figures/stanford_elasticity_trend.pdf, replace 

    hashsort inst_id year
    tw line firm_elasticity year if inst == "National Institutes of Health", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.02(0.02)0.12, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("NIH Productivity Externality", size(vsmall))
    graph export ../output/figures/nih_elasticity_trend.pdf, replace 

    hashsort inst_id year
    tw line firm_elasticity year if inst == "Johns Hopkins University", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.20(0.02)0.30, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("Johns Hopkins University Productivity Externality", size(vsmall))
    graph export ../output/figures/jhu_elasticity_trend.pdf, replace 

    hashsort inst_id year
    tw line firm_elasticity year if inst == "University of Michigan–Ann Arbor", xlab(1945(5)2022, angle(45) labsize(vsmall)) ylab(0.50(0.05)0.80, labsize(vsmall)) xtitle("Year", size(vsmall)) ytitle("University of Michigan-Ann Arbor Productivity Externality", size(vsmall))
    graph export ../output/figures/umich_elasticity_trend.pdf, replace 
end

program output_tables
    syntax, samp(str) 
    foreach file in top_10clus top_30clus coef field city_stats inst_elasticities econ_coef { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }
end
** 
main
