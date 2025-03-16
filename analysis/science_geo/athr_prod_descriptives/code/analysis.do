set more off
clear all
capture log close
program drop _all
set scheme modern
graph set window fontface "Arial Narrow"
pause on
set seed 8975
here, set

global country_name "countries"
global us_state_name "US states"
global area_name "US cities"
global city_full_name "cities"
global inst_name "institutions"
global msatitle_name "MSAs"
global msa_comb_name "MSAs"
global msa_world_name "cities"
global msa_c_world_name "cities"

program main
    di "OUTPUT START"
    foreach athr_type in year_second {
        di "ALL: impact_cite_affl_wt"
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(1) loc(inst_id)
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(0) loc(inst_id)
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(0) loc(msa_comb)
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(1) loc(msa_c_world)
        *top_insts, athr(`athr_type') samp(all) wt_var(cite_affl_wt) 
        /*di "CNS: body_adj_wt"
        athr_loc, athr(`athr_type') samp(cns) wt_var(body_adj_wt) 
        top_insts, athr(`athr_type') samp(cns) wt_var(body_adj_wt) 
        output_tables, athr(`athr_type') samp(cns)*/
        *output_tables, athr(`athr_type') samp(all) 
        *map, athr(`athr_type') samp(all) 
    }
end

program athr_loc
    syntax, athr(str) samp(str) wt_var(str) global(int) loc(str)
    local jrnls = ""
    if "`samp'" == "cns" local jrnls "_cns"
    use ../external/samp/athr_panel_full_comb_`athr'`jrnls'_global, clear 
    replace inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    local end 20
    if "`loc'" == "inst"  {
        local end 50
    }
    if `global' == 1  {
        keep if country != "United States" 
    }
    if `global' == 0 {
        keep if country == "United States" 
    }
    preserve
    gen log_`wt_var'=log(`wt_var')
    bys `loc' inst_id : gen inst_cnt = _n == 1
    bys `loc' : egen tot_insts = total(inst_cnt) 
    bys `loc' athr_id : gen athr_cnt = _n == 1
    bys `loc' athr_id year : gen athr_yr_cnt = _n == 1
    bys `loc' year : egen athr_yrs = total(athr_yr_cnt) 
    bys `loc' year: gen athr_yr_id = _n == 1
    replace athr_yrs = . if athr_yr_id != 1
    bys `loc' : egen avg_athr_yrs = mean(athr_yrs)
    bys `loc' : egen num_athrs = total(athr_cnt)
    bys `loc': gen `loc'_cnt = _n == 1
    sum num_athrs if `loc'_cnt == 1
    bys `loc' year: gen yr_cnt = _n == 1
    bys `loc': egen num_years = total(yr_cnt)
    
/*        gen wt = num_athrs/r(sum)
    sum `wt_var'
    local total = r(sum)
    gen wt_prod   = wt * `wt_var'
    gen wt_pat   = wt * body_affl_wt 
   
    sum wt_prod 
    local sum = r(sum)
    gen scale = `total'/`sum'
    replace wt_prod = scale * wt_prod
    
    sum wt_pat
    local sum = r(sum)
    sum body_affl_wt 
    local total = r(sum)
    replace wt_pat = `total'/`sum' * wt_pat 
    collapse (mean) `wt_var' wt_prod wt_pat ,  by(`loc')*/
    drop if mi(`loc')
    drop if num_years <= 5

    if "`loc'" == "inst_id" {
        drop if avg_athr_yrs <= 5
        drop if num_athrs <= 25
    }
    if "`loc'" != "inst_id" {
        drop if tot_insts <= 5
        drop if avg_athr_yrs <= 20 
        drop if num_athrs <=100 
    }
    collapse (mean) `wt_var'  log_`wt_var' (mean) tot_insts (firstnm) country inst,  by(`loc' year)
    collapse (mean) `wt_var' log_`wt_var' (min) min_year = year (max) max_year = year (firstnm) country inst,  by(`loc')
/*        qui reg wt_pat wt_prod
    local coef : dis %3.2f _b[wt_prod]
    local N = e(N)
    tw scatter wt_pat wt_prod, xtitle("Productivitiy", size(vsmall)) ytitle("Paper-to-Patent Citations", size(vsmall)) lcolor(ebblue) mcolor(gs3) xlab(, labsize(vsmall)) ylab(, labsize(vsmall))  legend(on order(- "N (MSAs) = `N'" ///
                                                                                                                  "Slope = `coef'") pos(5) ring(0) region(fcolor(none)) size(vsmall))
    graph export ../output/figures/`loc'_pat_prod.pdf, replace*/
    tw hist log_`wt_var' , frac bin(50) color(ebblue%50) ytitle("Share of ${`loc'_name}") xtitle("Log Avg. Productivity")
    graph export ../output/figures/dist_`loc'_global`global'.pdf, replace
    /*gen log_wt_prod = log(wt_prod)
    tw hist log_wt_prod , frac bin(50) color(ebblue%50) ytitle("Share of ${`loc'_name}") xtitle("Wt. Log Avg. Productivity")
    graph export ../output/figures/wt_dist_`loc'.pdf, replace*/
    qui hashsort -`wt_var'
    qui drop if mi(`loc')
    gen rank = _n 
    save ../temp/rankings_`loc'_`athr'`jrnls'_global`global', replace
    drop rank
    qui count
    local rank_end = min(r(N),`end') 
    li `loc' `wt_var' in 1/`rank_end'
    mkmat `wt_var' in 1/`rank_end', mat(top_`loc'_`athr'`jrnls')
    qui save ../temp/`loc'_rank_`athr'`jrnls'_global`global', replace
end

program map
    syntax, athr(str) samp(str) 
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

    use if !mi(msa_comb) & inrange(year, 1945, 2023) using ../external/samp/athr_panel_full_`athr'_global, clear
    merge m:1 msacode using ../external/geo/msas, assert(1 2 3) keep(1 3) nogen
    replace msa_comb = msatitle if !mi(msatitle)
    replace msa_comb = "San Francisco-Oakland-Hayward, CA" if msa_comb == "San Francisco-Oakland-Haywerd, CA"
    replace msa_comb = "Macon-Bibb County, GA" if msa_comb == "Macon, GA"
    bys msa_comb athr_id : gen athr_cnt = _n == 1
    bys msa_comb : egen num_athrs = total(athr_cnt)
    bys msa_comb: gen msa_comb_cnt = _n == 1
    sum num_athrs if msa_comb_cnt  == 1
    gen wt = num_athrs/r(sum)
    sum impact_cite_affl_wt
    local total = r(sum)
    gen wt_prod   = wt * impact_cite_affl_wt
    sum wt_prod 
    local sum = r(sum)
    gen scale = `total'/`sum'
    replace wt_prod = scale * wt_prod
    gcollapse (mean) wt_prod , by(msa_comb)
    save ../temp/map_samp_`samp'_`athr', replace
    
    use usa_msa, clear
    rename NAME msa_comb
    merge 1:m msa_comb using ../temp/map_samp_`samp'_`athr', assert(1 2 3) keep(1 3) nogen
    foreach var in wt_prod {
    replace wt_prod = log(wt_prod)
        xtile `var'_4 = `var', nq(4)
        qui sum `var' 
        local min : dis %6.4f r(min)
        local max : dis %6.4f r(max)
        _pctile `var',percentiles(25 50 75)
        local p25: dis %6.4f r(r1)
        local p50: dis %6.4f r(r2)
        local p75: dis %6.4f r(r3)
        *local p80: dis %3.2f r(r4)
        colorpalette carto Teal, n(4) nograph 
        spmap  `var'_4 using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)'%50) clnumber(4) ///
          ocolor(white ..) osize(0.15 ..) ndfcolor(gs13) ndocolor(white ..) ndsize(0.15 ..) ndlabel("No data") ///
          polygon(data("usa_state_shp_clean") ocolor(gs2) osize(0.2) fcolor(eggshell%20)) ///
          legend(label(2 "Min-p25: `min'-`p25'") label(3 "p25-p50: `p25'-`p50'") label(4 "p50-p75: `p50'-`p75'") label(5 "p75-max: `p75'-`max'") pos(4) size(2)) legtitle("${`var'_name}")
        graph export ../output/figures/`var'_map_`samp'_`athr'.pdf, replace
    }
end

program top_insts
    syntax, athr(str) samp(str) wt_var(str) 
    local jrnls = ""
    if "`samp'" == "cns" local jrnls "_cns"
    use ../external/samp/athr_panel_full_comb_`athr'`jrnls'_global, clear 
    keep if country == "United States"
    replace inst = "Mass General Brigham" if inlist(inst, "Massachusetts General Hospital" , "Brigham and Women's Hospital")
    local end 10
    preserve
        bys msa_comb athr_id : gen athr_cnt = _n == 1
        bys msa_comb athr_id year : gen athr_yr_cnt = _n == 1
        bys msa_comb : egen num_athrs = total(athr_cnt)
        bys msa_comb: gen msa_comb_cnt = _n == 1
        sum num_athrs if msa_comb_cnt == 1
        bys msa_comb year: gen yr_cnt = _n == 1
        bys msa_comb: egen num_years = total(yr_cnt)
/*    gen wt = num_athrs/r(sum)
    sum `wt_var'
    local total = r(sum)
    gen wt_prod   = wt * `wt_var'
    sum wt_prod 
    local sum = r(sum)
    gen scale = `total'/`sum'
    replace wt_prod = scale * wt_prod*/
    bys inst_id athr_id year: gen inst_athr_yr_cnt = _n == 1
    bys inst_id year: egen num_athr_yr = total(inst_athr_yr_cnt)
    bys inst_id : egen mean_athr_yr_cnt = 
    bys msa_comb: egen avg = mean(wt_prod)
    gen neg_avg = -avg
    replace neg_avg = . if msa_comb_cnt != 1
    egen rank = rank(neg_avg)
    hashsort msa_comb rank
    by msa_comb : replace rank = rank[_n-1] if mi(rank)
    rename rank msa_rank
    drop wt* athr_cnt scale avg neg_avg num_athrs
    bys inst athr_id : gen athr_cnt = _n == 1
    bys inst : egen num_athrs = total(athr_cnt)
    bys inst: gen inst_cnt = _n == 1
    sum num_athrs if inst_cnt == 1
    gen wt = num_athrs/r(sum)
    sum `wt_var'
    local total = r(sum)
    gen wt_prod   = wt * `wt_var'
    sum wt_prod 
    local sum = r(sum)
    gen scale = `total'/`sum'
    replace wt_prod = scale * wt_prod*/
    collapse (mean)  wt_prod msa_rank,  by(inst msa_comb)
    keep if msa_rank <=10
    gen neg_avg = -wt_prod
    bys  msa_comb :egen rank= rank(neg_avg)
    keep if rank <=5
    hashsort msa_rank rank
    qui count
    li msa_comb inst wt_prod 
    mkmat wt_prod , mat(inst_msa_`athr'`jrnls')
    qui save ../temp/inst_in_msa_rank_`athr'`jrnls', replace
    restore
end


program output_tables
    syntax, samp(str) athr(str) 
    local jrnls = ""
    if "`samp'" == "cns" local jrnls "_cns"
    cap mat state_msa_`athr'`jrnls' = top_us_state_`athr'`jrnls' \ top_msa_comb_`athr'`jrnls' 
    cap mat all_`athr'`jrnls' = top_us_state_`athr'`jrnls' \ top_msa_comb_`athr'`jrnls'  \ top_inst_`athr'`jrnls'
    foreach file in top_inst inst_msa state_msa all {
        cap qui matrix_to_txt, saving("../output/tables/`file'_`athr'`jrnls'.txt") matrix(`file'_`athr'`jrnls')  ///
           title(<tab:`file'_`athr'`jrnls'>) format(%20.4f) replace
         }
 end
** 
main
