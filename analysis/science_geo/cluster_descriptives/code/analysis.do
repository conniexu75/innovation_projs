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

program main
    foreach s in year_firstlast {
        sample_desc, samp(`s')
        maps, samp(`s')
        raw_bs, samp(`s')
        regression, samp(`s')
        output_tables, samp(`s')
    }
end

program sample_desc
    syntax, samp(str) 
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
        graph export ../output/figures/`var'_dist`samp'.pdf, replace
    }
    preserve
    keep if inrange(year, 2015,2022)
    gcollapse (mean) msa_size cluster_shr, by(msa_comb)
    gsort - msa_size
    mkmat msa_size in 1/30, mat(top_30clus_`samp')
    li in 1/30
    mkmat msa_size in 1/10, mat(top_10clus_`samp')
    restore
    preserve
    gen has_patent_cite = pat_wt > 0
    bys athr_id msa_comb: gen athr_cnt = _n == 1
    gcollapse  (sum) athr_cnt body_adj_wt cite_affl_wt pat_wt affl_wt impact_cite_affl_wt impact_affl_wt (mean) msa_size has_patent_cite, by(msa_comb)
    qui reg body_adj_wt impact_cite_affl_wt 
    local coef : dis %3.2f _b[impact_cite_affl_wt]
    local N = e(N)
    binscatter2 body_adj_wt impact_cite_affl_wt , xtitle("Productivity", size(vsmall)) ytitle("Paper-to-Patent Citations", size(vsmall)) lcolor(ebblue) mcolor(gs3) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    graph export ../output/figures/msa_pat_prod_`samp'.pdf, replace
    gen ln_pat = ln(body_adj_wt)
    gen ln_y = ln(impact_cite_affl_wt)
    qui reg ln_pat ln_y 
    local coef : dis %3.2f _b[ln_y]
    local N = e(N)
    binscatter2 ln_pat ln_y , xtitle("Log Productivity", size(vsmall)) ytitle("Log Paper-to-Patent Citations", size(vsmall)) lcolor(ebblue) mcolor(gs3)  xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    graph export ../output/figures/msa_log_pat_prod_`samp'.pdf, replace
    
    xtile p  = msa_size, nq(20)
    gen msa_lab = "" 
    replace msa_lab =  msa_comb  if msa_comb == "Great Falls, MT" 
    replace msa_lab =  msa_comb  if msa_comb == "San Diego-Carlsbad, CA" 
    replace msa_lab =  msa_comb  if msa_comb == "Trenton, NJ" 
    replace msa_lab =  msa_comb  if msa_comb == "New Haven-Milford , CT" 
    replace msa_lab =  msa_comb  if msa_comb == "New York-Newark-Jersey City, NY-NJ-PA" 
    replace msa_lab =  msa_comb  if msa_comb == "Bay Area, CA" 
    replace msa_lab =  msa_comb  if msa_comb == "Boston-Cambridge-Newton, MA-NH" 

/*    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Great Falls, MT" & year == 2015
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "San Diego-Carlsbad, CA" & year == 1973
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "San Diego-Carlsbad, CA" & year == 19
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Trenton, NJ" & year == 2019
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "New Haven-Milford , CT" & year == 2012
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "New York-Newark-Jersey City, NY-NJ-PA" & year == 1996
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 2015 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 2012 */
    tw scatter impact_cite_affl_wt msa_size , mcolor(gs7%50) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall)) || scatter impact_cite_affl_wt msa_size if !mi(msa_lab) , mcolor(ebblue) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) xtitle("MSA Cluster Size", size(vsmall)) ytitle("MSA Productivity", size(vsmall))  jitter(5) legend(off)
   graph export ../output/figures/cluster_prod_scatter_`samp'.pdf, replace
   
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
   /*replace msa_lab =  msa_comb + " " + string(${time})  if msa_comb == "Flint, MI" & year == 2006
   replace msa_lab =  msa_comb + " " + string(${time})  if msa_comb == "Lincoln, NE" & year == 2005 
   replace msa_lab =  msa_comb + " " + string(${time})  if msa_comb == "Worcester, MA-CT" & year == 2000
   replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "San Diego-Carlsbad, CA" & year == 1989 
   replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 1997 
   replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 2015 
   replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 2015 
   replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 2000 */
   qui reg body_adj_wt impact_cite_affl_wt 
   local coef : dis %3.2f _b[impact_cite_affl_wt]
   local cons : dis %3.2f _b[_cons]
   local N = e(N)
   tw scatter body_adj_wt impact_cite_affl_wt , mcolor(gs13%50) msize(vsmall) xlabel(0(5000)60000, labsize(vsmall)) ylab(0(5000)60000, labsize(vsmall)) || ///
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
    bys msa_comb: egen mode = mode(msacode)
    replace msacode = mode
    merge m:1 msacode using ../external/geo/msas, assert(1 2 3) keep(1 3) nogen
    replace msa_comb = msatitle if !mi(msatitle)
    replace msa_comb = "San Francisco-Oakland-Hayward, CA" if msa_comb == "San Francisco-Oakland-Haywerd, CA"
    replace msa_comb = "Macon-Bibb County, GA" if msa_comb == "Macon, GA"
    bys athr_id msa_comb ${time} : gen count = _n == 1
    keep if inrange(year , 1945,2022)
    gcollapse (sum) affl_wt impact_cite_affl_wt body_adj_wt (mean) msa_size , by(msa_comb)
    save ../temp/map_samp, replace
    
    use usa_msa, clear
    rename NAME msa_comb
    merge 1:m msa_comb using ../temp/map_samp, assert(1 2 3) keep(1 3) nogen
    foreach var in impact_cite_affl_wt msa_size body_adj_wt {
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
    graph export ../output/figures/pat_prod_`samp'.pdf, replace
    qui reg ln_pat ln_y 
    local coef : dis %3.2f _b[ln_y]
    local N = e(N)
    binscatter2 ln_pat ln_y , xtitle("Log Productivity", size(vsmall)) ytitle("Log Paper-to-Patent Citations", size(vsmall)) xlab(, labsize(vsmall)) ylab(, labsize(vsmall)) mcolor(gs5) lcolor(ebblue) legend(on order(- "N (Author-years) = `N'" ///
                                                                                                                      "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    graph export ../output/figures/log_pat_prod_`samp'.pdf, replace
end


program regression 
    syntax, samp(str) 
    use if !mi(msa_comb) & inrange(year, 1945, 2022) using ../external/samp/athr_panel_full_comb_`samp', clear 
    local reg_eq = cond("`samp'"=="year","ln_y ln_x avg_team_size","ln_y ln_x") 
    local mat_est  = cond("`samp'"=="year","_b[ln_x] \ _se[ln_x] \ _b[avg_team_size] \ _se[ln_x]", "_b[ln_x] \ _se[ln_x]") 
    bys athr_id msa_comb ${time} : gen count = _n == 1
    replace msa_size = 0.0000000000001 if msa_size == 0
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_name)
    gegen msa_field = group(msa field)
    gegen year_field = group(year field)
    gen ln_y = ln(impact_cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_x_cluster = ln(cluster_shr)
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
        mat coef_`samp' = nullmat(coef_`samp'), (`mat_est' \ e(N))
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
    reghdfe `reg_eq', absorb(${time} field field#${time} field#msa inst#year inst athr_id) vce(cluster msa)
    mat instyr_`samp' = nullmat(instyr_`samp'), (`mat_est' \ e(N))
    mat coef_`samp' = nullmat(coef_`samp') , instyr_`samp'
    reghdfe `reg_eq', absorb(year msa athr_id field inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id gen_mesh1 gen_mesh2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    mat alt_spec_`samp' = instyr_`samp' , field_`samp'
/*    reghdfe `reg_eq', absorb(year msa athr_id qualifier_name1 qualifier_name2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id term1 term2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))*/
        
end

program output_tables
    syntax, samp(str) 
    foreach file in top_10clus top_30clus coef field alt_spec { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }

end
** 
main
