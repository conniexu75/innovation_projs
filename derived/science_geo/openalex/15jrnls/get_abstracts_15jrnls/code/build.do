set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000

program main
    *append_athrs
    *merge_mesh
    merge_concepts
end
program append_athrs
    use if year >= 1945 using ../external/samp/cleaned_all_15jrnls.dta, clear
    gcontract id athr_id
    drop _freq
    gen num = subinstr(athr_id, "A", "",.)
    destring num, replace
    drop if num < 5000000000
    drop num
    save ../output/list_of_athrs, replace
end

program merge_mesh
    // further contract 
    use  ../external/samp/contracted_gen_mesh_15jrnls, clear
    replace gen_mesh = "Proteins" if strpos(gen_mesh, "Proteins")>0

    use ../output/list_of_athrs, clear
    joinby id using ../external/samp/contracted_gen_mesh_15jrnls
    gcontract athr_id gen_mesh
    gsort athr_id -_freq
    bys gen_mesh: egen mesh_tot = total(_freq)
    drop if mi(gen_mesh)
    gsort athr_id -_freq - mesh_tot
    by athr_id: gen rank = _n 
    keep if inlist(rank, 1,2)
    keep athr_id gen_mesh rank
    save ../output/athr_mesh_terms, replace
end

program merge_concepts
    use ../output/list_of_athrs, clear
    joinby id using ../external/samp/concepts_15jrnls
    gen count = 1
    destring score, replace
    collapse (sum) count (mean) score , by(athr_id term)
    replace score = count *score
    bys term: egen term_tot = total(count)
    drop if mi(term)
    gsort athr_id -term_tot -score
    by athr_id: gen rank = _n 
    keep if inlist(rank, 1,2)
    keep athr_id term rank score
    save ../output/athr_concepts, replace
end


main
