set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
global cite_affl_wt_name "Effective Paper Publications"
global ln_y_name "ln(Effective Paper Publications)"
global msa_size_name "Cluster Size"
global ln_x_name "ln(Cluster Size)"
global time year

program main
    foreach s in year year_firstlast {
        sample_desc, samp(`s')
        maps, samp(`s')
        raw_bs, samp(`s')
        regression, samp(`s')
        output_tables, samp(`s')
    }
end

program sample_desc
    syntax, samp(str) 
    use if !mi(msa_comb) using ../external/samp/athr_panel_full_comb_`samp', clear 
    count
    gunique athr_id
    gen ln_y = ln(cite_affl_wt)
    gen ln_x = ln(msa_size)
    foreach var in cite_affl_wt msa_size ln_y ln_x {
        qui sum `var', d
        local N = r(N)
        local mean : dis %3.2f r(mean)
        local sd : dis %3.2f r(sd)
        local p5 :  dis %3.2f r(p5)
        local p25 :  dis %3.2f r(p25)
        local p50 :  dis %3.2f r(p50)
        local p75 :  dis %3.2f r(p75)
        local p95 :  dis %3.2f r(p95)
        tw hist `var', frac ytitle("Share of author-years", size(small)) xtitle("${`var'_name}", size(small)) color(teal) legend(on order(- "N = `N'" ///
                                                                "Mean = `mean'" ///
                                                                "            (`sd')" ///
                                                                "p5 = `p5'" ///
                                                                "p25 = `p25'" ///
                                                                "p50 = `p50'" ///
                                                                "p75 = `p75'" ///
                                                                "p95 = `p95'") pos(1) ring(0) size(vsmall))
        graph export ../output/figures/`var-'_dist`samp'.pdf, replace
    }
    preserve
    gcollapse (mean) msa_size cite_affl_wt, by(msa_comb ${time})
    xtile p  = msa_size, nq(20)
    gen msa_lab = "" 
    replace msa_lab =  msa_comb + " " + string(${time})  + "p1" if msa_comb == "Prescott, AZ" & year == 2022
    replace msa_lab =  msa_comb + " " + string(${time})  + "p5" if msa_comb == "Harrisonburg, VA" & year == 2016
    replace msa_lab =  msa_comb + " " + string(${time})  + "p10" if msa_comb == "Chico, CA" & year == 2020
    replace msa_lab =  msa_comb + " " + string(${time})  + "p25" if msa_comb == "Reno, NV" & year == 1986 
    replace msa_lab =  msa_comb + " " + string(${time})  + "p50" if msa_comb == "Fort Wayne, IN" & year == 2020
    replace msa_lab =  msa_comb + " " + string(${time})  + "p75" if msa_comb == "Toledo, OH" & year == 2013
    replace msa_lab =  msa_comb + " " + string(${time})  + "p90" if msa_comb == "Cincinnati, OH-KY-IN" & year == 2023
    replace msa_lab =  msa_comb + " " + string(${time})  + "p95" if msa_comb == "Dallas-Fort Worth-Arlington, TX" & year == 2016
    replace msa_lab =  msa_comb + " " + string(${time})  + "p99" if msa_comb == "Los Angeles-Long Beach-Anaheim, CA" & year == 2016
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Bay Area, CA" & year == 2022 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 1997 
    replace msa_lab =  msa_comb + " " + string(${time})   if msa_comb == "Boston-Cambridge-Newton, MA-NH" & year == 2022 

    tw scatter cite_affl_wt msa_size if cite_affl_wt < 1,  mcolor(gs13) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall)) || scatter cite_affl_wt msa_size if !mi(msa_lab) , mcolor(teal) msize(vsmall)  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) xtitle("MSA Size in Year", size(small)) ytitle("Average Effective Output", size(small))  jitter(5) legend(off)
   graph export ../output/figures/dist_scatter_`samp'.pdf, replace
   hashsort p -cite_affl_wt 
   by p: egen mean_msa = mean(msa_size)
   by p: egen mean_cite = mean(cite_affl_wt)
   hashsort p -cite_affl_wt  
   gduplicates drop p mean_msa mean_cite, force
   drop msa_lab
   gen msa_lab = msa_comb + " " + string(${time})  + "p"+string(p)
   qui reg mean_cite mean_msa
   local coef = _b[mean_msa]
    tw scatter mean_cite mean_msa, mcolor(teal) msize(vsmall) xlabel(#10, labsize(vsmall)) ylab(#10, labsize(vsmall))  mlabel(msa_lab) mlabcolor(black) mlabsize(tiny) xtitle("MSA Size in Year", size(small)) ytitle("Average Effective Output", size(small)) legend(on order(- "Slope = `coef'") pos(5) ring(0) size(tiny))
    graph export ../output/figures/binscatter_`samp'.pdf, replace

   restore
    preserve
    gcollapse (mean) msa_size cluster_shr, by(msa_comb)
    gsort - msa_size
    mkmat msa_size cluster_shr in 1/10, mat(top_clus_`samp')
    li in 1/10
    restore
    preserve
    keep if year >= 2015
    gcollapse (mean) msa_size cluster_shr, by(msa_comb)
    gsort - msa_size
    mkmat msa_size cluster_shr in 1/10, mat(top_clus_rec_`samp')
    li in 1/10
    restore
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

    use ../external/samp/athr_panel_full_`samp', clear
    bys msa_comb: egen mode = mode(msacode)
    replace msacode = mode
    merge m:1 msacode using ../external/geo/msas, assert(1 2 3) keep(1 3) nogen
    replace msa_comb = msatitle if !mi(msatitle)
    replace msa_comb = "San Francisco-Oakland-Hayward, CA" if msa_comb == "San Francisco-Oakland-Haywerd, CA"
    replace msa_comb = "Macon-Bibb County, GA" if msa_comb == "Macon, GA"
    bys athr_id msa_comb ${time} : gen count = _n == 1
    drop unbal_msa_size 
    bys msa_comb ${time}: egen unbal_msa_size = total(count)
    bys ${time}: egen tot_unbal_msa_size = total(unbal_msa_size)
    gcollapse (sum) affl_wt cite_affl_wt (mean) msa_size unbal_msa_size, by(msa_comb year)
    keep if year == 2020
    save ../temp/map_samp, replace
    
    use usa_msa, clear
    rename NAME msa_comb
    merge 1:m msa_comb using ../temp/map_samp, assert(1 2 3) keep(3) nogen
    foreach var in cite_affl_wt msa_size  unbal_msa_size {
        colorpalette carto Sunset, n(10) nograph 
        spmap  `var' using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)') clnumber(10) ///
          ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") ///
          polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
          legend(pos(5) size(2.5))  legstyle(2)
        graph export ../output/figures/`var'_map_`samp'.pdf, replace
    }
/*    use usa_msa, clear
    rename NAME msa_comb
    forval i = 0/4 {
        preserve
        merge 1:m msa_comb using ../temp/map_samp_field, assert(1 2 3) keep(3) nogen
        keep if field == `i'
        foreach var in cite_affl_wt msa_size_field  {
            colorpalette carto BluYl, n(10) nograph 
            spmap `var' using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)') clnumber(5) ///
              ocolor(white ..) osize(0.02 ..) ndfcolor(gs4) ndocolor(gs6 ..) ndsize(0.03 ..) ndlabel("No data") ///
              polygon(data("usa_state_shp_clean") ocolor(gs5) osize(0.15)) ///
              legend(pos(5) size(2.5))  legstyle(2)
            graph export ../output/figures/`var'_map_`i'_`samp'.pdf, replace
        }
        restore
    }*/
end

program raw_bs
    syntax, samp(str) 
    use ../external/samp/athr_panel_full_comb_`samp', clear
    drop if mi(msa_comb) 
    gegen msa = group(msa_comb)
    gen ln_y = ln(cite_affl_wt)
    gen ln_x = ln(msa_size)
    // team size vs msa size
    qui reg avg_team_size  ln_x 
    local coef = _b[ln_x]
    binscatter2 avg_team_size ln_x, xtitle("Absolute Cluster Size") ytitle("Average Team Size") legend(on order(- "Slope = `coef'") pos(5) ring(0))
    graph export ../output/figures/team_v_msa_`samp'.pdf, replace

    // team size vs productivity
    qui reg ln_y avg_team_size 
    local coef = _b[avg_team_size]
    binscatter2 ln_y avg_team_size , xtitle("Average Team Size") ytitle("Citation-weighted Affiliation-Adjusted Count") legend(on order(- "Slope = `coef'") pos(5) ring(0))
    graph export ../output/figures/team_v_output_`samp'.pdf, replace
end


program regression 
    syntax, samp(str) 
    use if !mi(msa_comb) using ../external/samp/athr_panel_full_comb_`samp', clear 
    local reg_eq = cond("`samp'"=="year","ln_y ln_x avg_team_size","ln_y ln_x") 
    local mat_est  = cond("`samp'"=="year","_b[ln_x] \ _b[avg_team_size]", "_b[ln_x]") 
    bys athr_id msa_comb ${time} : gen count = _n == 1
    drop unbal_msa_size 
    bys msa_comb ${time}: egen unbal_msa_size = total(count)
    bys ${time}: egen tot_unbal_msa_size = total(unbal_msa_size)
    gen unbal_cluster_shr = unbal_msa_size/tot_unbal_msa_size
    replace msa_size = 0.0000000000001 if msa_size == 0
    gegen msa = group(msa_comb)
    rename inst inst_name
    gegen inst = group(inst_id)
    gegen msa_field = group(msa field)
    gegen year_field = group(year field)
    gen ln_y = ln(cite_affl_wt)
    gen ln_x = ln(msa_size)
    gen ln_x_cluster = ln(cluster_shr)
    reghdfe `reg_eq', noabsorb
    local slope = _b[ln_x]
    if "`samp'" == "year" {
        binscatter2  ln_y ln_x ,controls(avg_team_size) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
        graph export ../output/figures/bs_`samp'.pdf, replace
    }
    if "`samp'" == "year_firstlast" {
        binscatter2  ln_y ln_x , ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
        graph export ../output/figures/bs_`samp'.pdf, replace
    }
    foreach fe in "${time} msa field" "${time} msa field field#${time}" "${time} msa field field#${time} msa#field" "${time} msa field field#${time} msa#field inst" "${time} msa field field#${time} msa#field inst athr_id" {
        reghdfe `reg_eq', absorb(`fe') vce(cluster msa)
        mat coef_`samp' = nullmat(coef_`samp'), (`mat_est' \ e(N))
        local slope : dis %3.2f _b[ln_x]
        if "`samp'" == "year" {
            binscatter2  ln_y ln_x ,controls(avg_team_size) absorb(year msa field year_field msa_field athr_id) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
            graph export ../output/figures/final_bs_`samp'.pdf, replace
        }
        if "`samp'" == "year_firstlast" {
            binscatter2  ln_y ln_x , absorb(year msa field year_field msa_field athr_id) ytitle("Log Output") xtitle("Log Cluster Size") legend(on order(- "Slope = `slope'") pos(5) ring(0) lwidth(none))
            graph export ../output/figures/final_bs_`samp'.pdf, replace
        }
    }

    reghdfe `reg_eq', absorb(year msa athr_id field inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id gen_mesh1 gen_mesh2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id qualifier_name1 qualifier_name2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
    reghdfe `reg_eq', absorb(year msa athr_id term1 term2 inst) vce(cluster msa)
    mat field_`samp' = nullmat(field_`samp'), (`mat_est' \ e(N))
        
    replace ln_x = ln(unbal_msa_size)
    replace ln_x_cluster = ln(unbal_cluster_shr)
    foreach fe in "${time} msa field" "${time} msa field field#${time}" "${time} msa field field#${time} msa#field" "${time} msa field field#${time} msa#field inst" "${time} msa field field#${time} msa#field inst athr_id" {
        reghdfe `reg_eq', absorb(`fe') vce(cluster msa)
        mat unbal_`samp' = nullmat(unbal_`samp'), (`mat_est' \ e(N))
    }
end

program output_tables
    syntax, samp(str) 
    foreach file in top_clus top_clus_rec coef field unbal { 
         qui matrix_to_txt, saving("../output/tables/`file'_`samp'.txt") matrix(`file'_`samp') ///
           title(<tab:`file'_`samp'>) format(%20.4f) replace
    }

end
** 
main
