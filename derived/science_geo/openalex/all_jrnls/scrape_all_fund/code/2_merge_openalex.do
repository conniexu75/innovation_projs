set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global output "/export/scratch/cxu_sci_geo/scrape_all_fund"

program main
    *append_files
    append_mesh
    append_concepts
end
program append_files
        forval i = 1/5003 {
        di "`i'"
        qui {
                import delimited using ../output/openalex_authors`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
                drop if jrnl == "PubMed"
                keep if pub_type == "article" & pub_type_crossref == "journal-article"
                gen n = `i'
                compress, nocoalesce
                save ${output}/openalex_authors`i', replace
            }
        }
        clear
        forval i = 1/5003 {
            di "`i'"
            qui append using ${output}/openalex_authors`i'
        }
    destring pmid, replace
    destring which_athr, replace
    destring which_affl, replace
    destring cite_count, replace
    gduplicates drop  pmid which_athr which_affl inst_id , force
    gduplicates drop  pmid which_athr inst_id , force
    gduplicates tag pmid which_athr which_affl, gen(dup)
    drop if dup == 1 & mi(inst)
    drop dup 
    gsort pmid athr_id which_athr
    gduplicates drop pmid athr_id inst_id, force
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    gen mi_inst = mi(inst)
    bys pmid athr_id: egen has_nonmi_inst = min(mi_inst)  
    replace has_nonmi_inst = has_nonmi_inst == 0
    drop if mi(inst) & num_which_athr > 1 & has_nonmi_inst
    drop which_athr_counter num_which_athr
    bys pmid athr_id which_athr : gen which_athr_counter = _n == 1
    bys pmid athr_id: egen num_which_athr = sum(which_athr_counter)
    cap destring which_athr, replace
    bys pmid athr_id: egen min_which_athr = min(which_athr)
    replace which_athr = min_which_athr if num_which_athr > 1
    gduplicates drop pmid which_athr inst_id, force
    bys pmid which_athr: gen author_id = _n == 1
    bys pmid: gen which_athr2 = sum(author_id)
    replace which_athr = which_athr2
    drop which_athr2
    bys pmid which_athr (which_affl) : replace which_affl = _n 
    gisid pmid which_athr which_affl
    save ../output/openalex_all_jrnls_merged, replace
    
    gcontract inst_id, nomiss
    drop _freq
    save ../output/list_of_insts, replace
end
program append_mesh
        forval i = 2166/5003 {
        di "`i'"
        qui {
                cap import delimited using ../output/mesh_terms`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
                cap drop n
                gen n = `i'
                keep if is_major_topic == "TRUE"
                if _N > 0 {
                    gduplicates drop id term qualifier_name, force
                    compress, nocoalesce
                    save ${output}/mesh_terms`i', replace
                }
            }
        }
        clear
        forval i = 1/5003 {
            di "`i'"
            cap qui append using ${output}/mesh_terms`i'
        }
        gen gen_mesh = term if strpos(term, ",") == 0 & strpos(term, ";") == 0
        replace gen_mesh = term if strpos(term, "Models")>0
        replace gen_mesh = subinstr(gen_mesh, "&; ", "&",.)
        gen rev_mesh = reverse(term)
        replace rev_mesh = substr(rev_mesh, strpos(rev_mesh, ",")+1, strlen(rev_mesh)-strpos(rev_mesh, ","))
        replace rev_mesh = reverse(rev_mesh)
        replace gen_mesh = rev_mesh if mi(gen_mesh)
        drop rev_mesh
        contract id gen_mesh qualifier_name, nomiss
        save ../output/contracted_gen_mesh_all_jrnls, replace
end
program append_concepts
        forval i = 1/5003 {
        di "`i'"
        qui {
                cap import delimited using ../output/concepts`i', stringcols(_all) clear varn(1) bindquotes(strict) maxquotedrows(unlimited)
                gen n = `i'
                gduplicates drop id term, force
                compress, nocoalesce
                save ${output}/concepts`i', replace
            }
        }
        clear
        forval i = 1/5003 {
            di "`i'"
            cap qui append using ${output}/concepts`i'
        }
        destring level , replace
        drop if level > 2
        save ../output/concepts_all_jrnls_merged,replace
end
main
