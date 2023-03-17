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
    global samp cns_med 
    global basic_name basic
    global translational_name trans
    global diseases_name dis
    global fundamental_name fund
    global therapeutics_name thera
    create_cat_samps
    foreach samp in cns {
/*        clear
        append using ../output/cleaned_dis_all_`samp'
        append using ../output/cleaned_thera_all_`samp'
        save ../output/cleaned_nofund_all_`samp', replace
        append using ../output/cleaned_fund_all_`samp'
        save ../output/cleaned_newfund_all_`samp', replace 

        clear
        append using ../output/cleaned_dis_last5yrs_`samp'
        append using ../output/cleaned_thera_last5yrs_`samp'
        save ../output/cleaned_nofund_last5yrs_`samp', replace
        append using ../output/cleaned_fund_all_`samp'
        save ../output/cleaned_newfund_last5yrs_`samp', replace */
        use ../external/thera/major_mesh_terms_thera, clear
        merge m:1 pmid using ../external/thera_xwalk/thera_pmids, assert(2 3) keep(3) nogen
        merge m:1 pmid using ../external/wos/thera_appended, assert(1 2 3) keep(3) nogen
        merge m:1 pmid using ../external/jrnls/`samp'_all_pmids, assert(1 2 3) keep(3)  nogen
        save ../output/mesh_thera_cns, replace

        clear
        append using ../output/mesh_dis_`samp'
        append using ../output/mesh_thera_`samp'
        *save ../output/mesh_nofund_`samp', replace
        append using ../output/mesh_fund_`samp'
        save ../output/mesh_newfund_`samp', replace
    }
end

program create_cat_samps
foreach cat in diseases fundamental {
        use ../external/xwalk/pmids_category_xwalk, clear
        keep if cat == "`cat'"
        gisid pmid
        save ../temp/${`cat'_name}_pmids, replace

        foreach samp in all {
            use ../external/samp/cleaned_`samp'_${samp}, clear
            merge m:1 pmid using ../temp/${`cat'_name}_pmids, assert(1 2 3) keep(3) nogen

            // add some additional clean_metadata code
            drop if inlist(pmid, 33471991, 28445112, 28121514, 30345907, 27192541, 25029335, 23862974, 30332564, 31995857, 34161704)
            drop if inlist(pmid, 29669224, 35196427,26943629,28657829,34161705,31166681,29539279, 33264556, 33631065, 33306283, 33356051)
            drop if inlist(pmid, 34587383, 34260849, 34937145, 34914868, 33332779, 36286256, 28657871, 35353979, 33631066, 27959715)
            drop if inlist(pmid, 29045205, 27376580, 29800062)

            foreach i in "Public Health Agency of Barcelona" "Westat" "The George Institute for Global Health" "University Hospital Knappschaftskrankenhaus Bochum" "American Medical Association" "Sharp End Advisory" "Clover Health" "D'Or Institute for Research and Education" "Western Slope Endocrinology" "BRICNet" "Beneficencia Portuguesa" "Sanquin Research" "HCor Research Institute" "GAMUT" "Kaiser Permanente Washington Health Research Institute" "Agency for Healthcare Research and Quality" "National Clinical Guideline Centre" "Brazilian Clinical Research Institute" "Hospital Alemao Oswaldo Cruz" "Louvain Drug Research Institute" "ClAnica Imbanaco" "Clinical Practice Assessment Unit" "Zealand University Hospital" "Murdoch Childrens Research Institute" "Centers for Medicare & Medicaid Services" "Society for Applied Studies" "China Academy of Chinese Medical Sciences" "Universidad del Valle" "Seattle Genetics" "Hellenic Institute for the Study of Sepsis" "KAIST" "IRCM" "CCRM" "Leap Therapeutics" "Tzaneio General Hospital of Piraeus" "Sotiria General Hospital of Chest Diseases" "IRCSS Sacro Cuore Hospital" "Elpis General Hospital" "Spallanzani Institute" "Wyeth-Ayerst Research" "APV Homogenizer Group" "BioCentury" "FDA" "Mesoblast" "Dark Horse Consultion" "BEFORE Brands" "Color Genomics" "Epinomics" "Roche " "Hospital of Jesolo" "Royal Botanic Gardens" "UNSW Sydney" "University of Nevada" "GEOMAR" "Monsanto" "National Institute of Health" "GSK" "Qingdao National Laboratory for Marine Science and Technology" "CONICET" "Monell Chemical Senses Center" "Burnham Institute" "Austrian Cluster for Tissue Regeneration" "Bio Architecture Lab" "National Orchid Conservation Center of China" "IFOM" "Joint Center for Structural Genomics" "Third Military Medical University" "National Institute of Agrobiological Sciences" "TIGEM" "Yunnan Key Laboratory of Primate Biomedical Research" "DuPont Pioneer" "Friedrich Miescher Institute" "Loyola University Chicago" "International Network for Quality Rice" "Rigel Pharmaceuticals" "Elan Pharmaceuticals" "Lexicon Pharmaceuticals" "Constellation Pharmaceuticals" "Immunocore" "XOMA" "National Institute of Infectious Diseases" "Yukiguni Maitake" "Trius Therapeutics" "BioElectron" "Seattle Structural Genomics Center for Infectious Diseases" "CNIO" "Naval Medical Research Center" "SAIT" "Hannover Medical School" "Center for Disease Control and Prevention" "Ulm University" "Point Loma Nazarene University" "Debre Tabor University" "Sackler School of Graduate Biomedical Sciences" "Vita-Salute San Raffaele University" "Turku University" "Hebrew University" "Pai-Chai University" "National Chung-Hsing University" "RAND" "Imperial Cancer Research Fund" "CIRAD" "U.S. Geological Survey" "USDA-ARS" { 
                replace institution = "`i'" if strpos(affiliation, "`i'") > 0 & mi(institution)
            }
            replace institution = "Seoul National University" if strpos(affiliation, "Seoul National University") > 0
            replace institution = "University of Washington" if institution == "Fred Hutchinson Cancer Research Center"
            replace institution = "Loyola University Chicago" if institution == "Loyola University of Chicago"
            replace institution = "CDC" if institution == "Center for Disease Control and Prevention" & strpos(affiliation, "Atlanta")>0
            replace institution = "Friedrich Miescher Institute for Biomedical Research" if institution == "Friedrich Miescher Institute"
            replace institution = "University of Bochum" if inlist(institution, "University Hospital Knappschaftskrankenhaus Bochum", "Ruhr-Universitat Bochum")
            replace institution = "KAIST" if strpos(affiliation, "KAIST")>0 & country == "South Korea"
            replace city = "Bochum" if institution == "University of Bochum"
            replace country = "Germany" if institution == "University of Bochum"
            replace institution = "AHRQ" if institution == "Agency for Healthcare Research and Quality" | (strpos(affiliation, "AHRQ")>0 & mi(institution))
            replace institution = "Leiden University" if institution == "University of Leiden"
            replace institution = "McGill University" if institution == "Clinical Practice Assessment Unit"
            replace institution = "FDA" if strpos(institution, "Food and Drug Administration")>0 | strpos(affiliation, "Food and Drug Administration")>0
            replace institution = "GlaxoSmithKline" if institution == "GSK"
            replace institution = "University of New South Wales" if institution == "UNSW Sydney"
            replace institution = "University of Wisconsin, Madison" if strpos(affiliation, "University of Wisconsin")>0 & city == "Madison" & mi(institution)
            replace institution = "University of Wisconsin, Oshkosh" if strpos(affiliation, "University of Wisconsin")>0 & city == "Oshkosh" & mi(institution)
            replace institution = "CONICET" if strpos(affiliation, "Consejo Nacional de Investigaciones")>0
            replace institution = "University of Nevada, Las Vegas" if institution == "University of Nevada" & strpos(affiliation, "Las Vegas") > 0
            replace institution = "University of Nevada, Reno" if institution == "University of Nevada" & strpos(affiliation, "Reno") > 0
            replace institution = "Radboud University" if strpos(affiliation, "Radboud")>0 & strpos(strlower(affiliation), "university")>0
            foreach cal in "Berkeley" "Los Angeles" "Santa Barbara" "San Diego" "Davis" "Irvine" "Santa Cruz" "Riverside" "Merced" "San Francisco" {
                replace institution = "University of California, `cal'" if strpos(affiliation, "University of California `cal'") > 0
                replace institution = "University of California, `cal'" if strpos(affiliation, "University of California-`cal'") > 0
                replace institution = "University of California, `cal'" if strpos(affiliation, "University of California, `cal'") > 0
                replace institution = "University of California, `cal'" if strpos(affiliation, "University of California at `cal'") > 0
                replace institution = "University of California, `cal'" if strpos(affiliation, "UC `cal'") > 0
                replace institution = "University of California, `cal'" if strpos(affiliation, "University of California") > 0 & strpos(affiliation, "`cal'")>0& mi(institution)
                replace country = "United States" if institution == "University of California, `cal'"
            }

            merge m:1 pmid which_athr which_affiliation using ../external/inst_xwalk/filled_in_insts, assert(1 2 3) keep (1 3) nogen
            replace institution  =  test_inst if !mi(test_inst) & mi(institution)
            save ../output/cleaned_${`cat'_name}_`samp'_${samp}, replace
            preserve
            keep if inlist(journal_abbr, "Cell","Science","Nature") 
            save ../output/cleaned_${`cat'_name}_`samp'_cns, replace
            restore
            preserve
            keep if !inlist(journal_abbr, "Cell","Science","Nature") 
            save ../output/cleaned_${`cat'_name}_`samp'_med, replace
            restore
        }
        use ../external/samp/major_mesh_terms_${samp}, clear
        merge m:1 pmid using ../temp/${`cat'_name}_pmids, assert(1 2 3) keep(3) nogen
        save ../output/mesh_${`cat'_name}_${samp}, replace
        preserve
        merge m:1 pmid using ../external/jrnls/cns_all_pmids, assert(1 2 3) keep(3)  nogen
        save ../output/mesh_${`cat'_name}_cns, replace
        restore
        preserve
        merge m:1 pmid using ../external/jrnls/med_all_pmids, assert(1 2 3) keep(3) nogen
        save ../output/mesh_${`cat'_name}_med, replace
        restore
    }
end
** 
main
