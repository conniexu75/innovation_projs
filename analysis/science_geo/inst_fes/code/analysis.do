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
program main
    use ../external/samp/athr_panel_full_comb_year_second, clear
    contract inst inst_id 
    drop _freq
    save ../temp/inst_xw, replace
    get_inst_fes
end

program get_inst_fes
    foreach y in impact_cite_affl_wt impact_affl_wt {
        di "`y'"
        use ../external/movers/mover_temp_year_second, clear
        merge m:1 athr_id using ../external/movers/mover_xw_year_second, keep(1 3) nogen
        cap mat drop _all
        gen ln_y = ln(`y')
        bys inst_id athr_id: gen athr_tag = _n == 1 & analysis_cond == 1
        bys inst_id: egen num_athrs = total(athr_tag)
        bys inst_id athr_id : gen athr_cnter = _n == 1
        bys inst_id  : egen athr_cnt= total(athr_cnter)
        bys inst_id: egen tot_movers = total(athr_cnter &  mover == 1)
        *keep if num_athrs >= 25
        drop if athr_cnt <100 & tot_movers < 10 
        bys inst_id:  gen first_inst = _n ==1
        hashsort num_athrs inst_id
        gegen inst_rank = group(inst_id)
        replace inst_rank = inst_rank + 1 
        replace inst_rank = 1 if inst_id == "I100538780" 
        // weslyn university
        preserve
        gcontract inst_rank inst_id
        drop _freq
        save ../temp/rank_xw_`y', replace
        restore
        glevelsof inst_rank, local(insts)
        di "running reg"
        reghdfe ln_y i.inst_rank, absorb(athr_fes = athr_id year_fes = year) residual vce(cluster inst_rank)
        foreach i in `insts' {
            mat inst_fes = nullmat(inst_fes) \ (`i',_b[`i'.inst_rank] , _se[`i'.inst_rank])
        }
        svmat inst_fes
        keep inst_fes*
        drop if mi(inst_fes1)
        rename (inst_fes1 inst_fes2 inst_fes3) (inst_rank b se)
        gen lb = b -1.96*se
        gen ub = b +1.96*se
        drop if se == 0
        merge 1:1 inst_rank using ../temp/rank_xw_`y', keep(3) assert(2 3) nogen
        merge 1:1 inst_id using ../temp/inst_xw, keep(3) assert(2 3) nogen
        hashsort -b
        gen new_rank = _n
        gen inst_lab = ""
        replace inst_lab = inst if new_rank ==1 | inlist(inst, "Stanford University", "Harvard University", "Scripps Research Institute")
        save ../output/reg_fes_`y', replace
    *    keep if b >=0 
        gen zero = 0
        keep if new_rank <=50
        tw bar b new_rank if mi(inst_lab) , color(gs10%60) || bar b new_rank if new_rank == 1, color(ebblue%70) || bar b new_rank if inst == "Stanford University", color(dkorange%70) || bar b new_rank if inst == "Scripps Research Institute", color(dkgreen%50) || bar b new_rank if inst == "Harvard University" , color(lavender) || rcap lb ub new_rank, msize(vsmall) lcolor(gs8%70) lwidth(thin) legend(order(2 "Gladstone Institutes" 3 "Stanford University" 4  "Scripps Research Institute" 5 "Harvard University") pos(1) ring(0) size(vsmall)) xsca(noline)  xlabel(, nolabels) xtitle("") ytitle("Institution Fixed Effects", size(small)) ylab(, labsize(small)) note("Median institution based on number of movers is omitted (Merck). Plot only shows top 50 insitutions.", size(vsmall))
        graph export ../output/figures/inst_fes_`y'.pdf, replace
    }
    clear
    use ../output/reg_fes_impact_cite_affl_wt , clear
    gen cat = "og"
    append using ../output/reg_fes_impact_affl_wt
    replace cat = "new" if mi(cat)
    keep new_rank inst_id b  cat
    greshape wide new_rank b, i(inst_id) j(cat) string
    merge 1:1 inst_id using ../temp/inst_xw, keep(3) assert(2 3) nogen
    corr new_rankog new_ranknew
    local corr : di %4.3f r(rho)
    reg new_rankog new_ranknew
    local slope : di %4.3f _b[new_ranknew] 
    tw scatter  new_rankog new_ranknew || (function y = _b[new_ranknew]*x + _b[_cons], range(0 503)), xtitle("Institution FE Rank - Non-citation Weighted Output") ytitle("Institution FE Rank - Citation-weighted Output", size(small)) xlabel(0(50)503, labsize(small)) ylabel(0(50)503, labsize(small)) legend(on order(- "Correlation: `corr'") ring(0) pos(11) region(fcolor(none)) size(small))
    graph export ../output/figures/corr_rank.pdf, replace
    corr bog bnew 
    local corr : di %4.3f r(rho)
    reg bog bnew 
    local slope : di %4.3f _b[bnew] 
    tw scatter bog bnew || (function y = _b[bnew]*x+_b[_cons], range(-1 3.5)) ,xtitle("Institution FE - Non-citation Weighted Output", size(small)) ytitle("Institution FE - Citation-weighted Output", size(small)) xlab(-1(.5)3.5, labsize(small)) ylab(-1(.5)4.5, labsize(small)) legend(on order(- "Correlation: `corr'") ring(0) pos(11) region(fcolor(none)) size(small))


    graph export ../output/figures/corr_fes.pdf, replace
end
** 
main
