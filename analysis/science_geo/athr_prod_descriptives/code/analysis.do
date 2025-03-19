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
        identify_movers, athr(`athr_type')
        *athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(1) loc(inst_id)
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(0) loc(inst_id)
        athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(0) loc(msa_comb)
        *athr_loc, athr(`athr_type') samp(all) wt_var(impact_cite_affl_wt) global(1) loc(msa_c_world)
        top_insts, athr(`athr_type') samp(all) wt_var(cite_affl_wt) 
        output_tables, athr(`athr_type') samp(all) 
    }
end

program identify_movers 
    syntax, athr(str) 
    use ../external/samp/athr_panel_full_comb_`athr'_global, clear 
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    bys athr_id inst_id: gen id_cnt =_n == 1
    bys athr_id : egen mover = sum(id_cnt)
    replace mover = mover > 1
    bys inst_id: egen tot_athrs = total(id_cnt)
    bys inst_id: egen tot_movers = total(mover * id_cnt)
    gcontract inst_id tot_athrs tot_movers 
    drop _freq
    save ../temp/inst_stats, replace
end
program athr_loc
    syntax, athr(str) samp(str) wt_var(str) global(int) loc(str)
    local jrnls = ""
    if "`samp'" == "cns" local jrnls "_cns"
    use ../external/samp/athr_panel_full_comb_`athr'`jrnls'_global, clear 
    keep if inrange(year, 2015, 2023)
    merge m:1 inst_id using ../temp/inst_stats, assert(3) keep(3) nogen
    local end 20
    if "`loc'" == "inst_id"  {
        local end 50
    }
    if `global' == 1  {
        keep if country != "United States" 
    }
    if `global' == 0 {
        keep if country == "United States" 
    }
    preserve
    drop if mi(`loc')
    gen log_`wt_var'=log(`wt_var')
    bys inst_id athr_id year : gen inst_athr_yr_cnt = _n == 1
    bys inst_id year : egen inst_athr_yrs = total(inst_athr_yr_cnt) 
    bys inst_id year: gen inst_yr_cnt = _n == 1
    replace  inst_athr_yrs = . if inst_yr_cnt != 1
    bys inst_id : egen inst_avg_athr_yrs = mean(inst_athr_yrs)
    bys inst_id athr_id : gen inst_athr_cnt = _n == 1
    bys inst_id : egen inst_num_athrs = total(inst_athr_cnt)
    bys inst_id: egen num_inst_yrs = total(inst_yr_cnt)
*    drop if num_inst_yrs < 5
*    drop if inst_avg_athr_yrs < 5
    drop if tot_athrs <100 
    drop if tot_movers < 25 

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
    if "`loc'" != "inst_id" {
*        drop if num_years < 5
*        drop if tot_insts ==  1
*        drop if avg_athr_yrs <= 15 
*        drop if num_athrs <=75 
    }
    collapse (mean) `wt_var'  log_`wt_var' tot* (firstnm) country inst,  by(`loc' year)
    collapse (mean) `wt_var' log_`wt_var' tot* (firstnm) country inst,  by(`loc')
    tw hist log_`wt_var' , frac bin(50) color(ebblue%50) ytitle("Share of ${`loc'_name}") xtitle("Log Avg. Productivity")
    graph export ../output/figures/dist_`loc'_global`global'.pdf, replace
    qui hashsort -`wt_var'
    qui drop if mi(`loc')
    gen rank = _n 
    save ../temp/rankings_`loc'_`athr'`jrnls'_global`global', replace
    drop rank
    qui count
    local rank_end = min(r(N),`end') 
    if "`loc'" == "inst_id"  & `global' == 0 {
        li inst `wt_var' log_`wt_var' in 1/`rank_end'
    }
    if "`loc'" == "inst_id"  & `global' == 1 {
        li inst country `wt_var' in 1/`rank_end'
    }
    else {
        li `loc' `wt_var' in 1/`rank_end'
    }
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
    bys msa_comb inst_id : gen inst_cnt = _n == 1
    bys msa_comb : egen tot_insts = total(inst_cnt) 
    bys msa_comb athr_id year : gen athr_yr_cnt = _n == 1
    bys msa_comb year : egen athr_yrs = total(athr_yr_cnt) 
    bys msa_comb year: gen athr_yr_id = _n == 1
    replace athr_yrs = . if athr_yr_id != 1
    bys msa_comb : egen avg_athr_yrs = mean(athr_yrs)
    drop if tot_insts == 1
    gcollapse (mean) impact_cite_affl_wt, by(msa_comb year)
    gcollapse (mean) impact_cite_affl_wt, by(msa_comb)
    save ../temp/map_samp_`samp'_`athr', replace
    
    use usa_msa, clear
    rename NAME msa_comb
    merge 1:m msa_comb using ../temp/map_samp_`samp'_`athr', assert(1 2 3) keep(1 3) nogen
    replace impact_cite_affl_wt= log(impact_cite_affl_wt)
    xtile impact_cite_affl_wt_4 = impact_cite_affl_wt, nq(4)
    qui sum impact_cite_affl_wt 
    local min : dis %6.4f r(min)
    local max : dis %6.4f r(max)
    _pctile impact_cite_affl_wt,percentiles(25 50 75)
    local p25: dis %6.4f r(r1)
    local p50: dis %6.4f r(r2)
    local p75: dis %6.4f r(r3)
    *local p80: dis %3.2f r(r4)
    colorpalette carto Teal, n(4) nograph 
    spmap  impact_cite_affl_wt_4 using usa_msa_shp_clean,  id(_ID)  fcolor(`r(p)'%50) clnumber(4) ///
      ocolor(white ..) osize(0.15 ..) ndfcolor(gs13) ndocolor(white ..) ndsize(0.15 ..) ndlabel("No data") ///
      polygon(data("usa_state_shp_clean") ocolor(gs2) osize(0.2) fcolor(eggshell%20)) ///
      legend(label(2 "Min-p25: `min'-`p25'") label(3 "p25-p50: `p25'-`p50'") label(4 "p50-p75: `p50'-`p75'") label(5 "p75-max: `p75'-`max'") pos(4) size(2)) legtitle("${impact_cite_affl_wt_name}")
    graph export ../output/figures/impact_cite_affl_wt_map_`samp'_`athr'.pdf, replace
end

program top_insts
    syntax, athr(str) samp(str) wt_var(str) 
    local jrnls = ""
    if "`samp'" == "cns" local jrnls "_cns"
    use ../external/samp/athr_panel_full_comb_`athr'`jrnls'_global, clear 
    if inst == "City of Hope" {
        replace inst_id = "I1301076528"
        replace region = "California"
        replace msa_c_world = "Los Angeles-Long Beach-Anaheim, US"
        replace city = "Duarte" 
        replace us_state = "CA"
        replace msa_comb = "Los Angeles-Long Beach-Anaheim, CA"
        replace msatitle = "Los Angeles-Long Beach-Anaheim, CA"
    }
    keep if inrange(year, 2015, 2023)
    merge m:1 inst_id using ../temp/inst_stats, assert(3) keep(3) nogen
    keep if country == "United States"
    local end 10
    preserve
    bys inst_id athr_id : gen inst_athr_cnt = _n == 1
    bys inst_id : egen inst_athrs=total(inst_athr_cnt)

    bys inst_id athr_id year: gen inst_athr_yr_cnt = _n == 1
    bys inst_id year: egen num_athr_yr = total(inst_athr_yr_cnt)
    bys inst_id year: gen inst_yr_id = _n == 1
    replace num_athr_yr = . if inst_yr_id != 1
    bys inst_id : egen avg_inst_athr_yrs = mean(num_athr_yr)
    
    bys inst_id year: gen inst_yr_cnt = _n == 1
    bys inst_id: egen num_inst_yrs = total(inst_yr_cnt)
    drop if tot_athrs <100 
    drop if tot_movers < 25 
    /*drop if num_inst_yrs < 5
    drop if avg_inst_athr_yrs < 5
    drop if inst_athrs < 25*/

    bys msa_comb inst_id : gen msa_inst_cnt = _n == 1
    bys msa_comb : egen tot_insts = total(msa_inst_cnt) 
    bys msa_comb athr_id : gen athr_cnt = _n == 1
    bys msa_comb athr_id year : gen athr_yr_cnt = _n == 1
    bys msa_comb : egen num_athrs = total(athr_cnt)
    bys msa_comb: gen msa_comb_cnt = _n == 1
    bys msa_comb year: gen yr_cnt = _n == 1
    bys msa_comb: egen num_years = total(yr_cnt)
    bys msa_comb year : egen athr_yrs = total(athr_yr_cnt) 
    bys msa_comb year: gen athr_yr_id = _n == 1
    replace athr_yrs = . if athr_yr_id != 1
    bys msa_comb : egen avg_athr_yrs = mean(athr_yrs)
*    drop if num_years < 5
*    drop if tot_insts == 1

    bys msa_comb year: egen avg_yr = mean(impact_cite_affl_wt)
    bys msa_comb year: gen id = _n == 1 
    replace avg_yr = . if id != 1
    bys msa_comb : egen avg = mean(avg_yr)
    gen neg_avg = -avg
    replace neg_avg = . if msa_comb_cnt != 1
    egen rank = rank(neg_avg)
    hashsort msa_comb rank
    by msa_comb : replace rank = rank[_n-1] if mi(rank)
    rename rank msa_rank
    drop  athr_cnt  avg neg_avg num_athrs
    bys inst athr_id : gen athr_cnt = _n == 1
    bys inst : egen num_athrs = total(athr_cnt)
    bys inst: gen inst_cnt = _n == 1
    sum num_athrs if inst_cnt == 1
    collapse (mean)  impact_cite_affl_wt  msa_rank,  by(inst msa_comb year)
    collapse (mean)  impact_cite_affl_wt  msa_rank,  by(inst msa_comb)
    keep if msa_rank <=10
    gen neg_avg = -impact_cite_affl_wt
    bys  msa_comb :egen rank= rank(neg_avg)
    keep if rank <=5
    hashsort msa_rank rank
    qui count
    li msa_comb inst  impact_cite_affl_wt
    mkmat impact_cite_affl_wt, mat(inst_msa_`athr'`jrnls')
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
