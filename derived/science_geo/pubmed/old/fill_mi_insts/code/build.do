set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set

program main
    global country_name "countries"
    global us_state_name "US states"
    global area_name "US cities"
    global city_full_name "world cities"
    global inst_name "institutions"
    foreach samp in cns_med natsub scijrnls demsci med thera {
        local samp_type = cond(strpos("`samp'" , "cns")>0 | strpos("`samp'", "med")>0, "main", "robust")
        if "`samp'" == "med" {
            local samp_type = "clinical"
            local samp = "clin_med"
        }
        if "`samp'" == "thera" {
            local samp_type = "thera"
        }
        append_mi, samp(`samp') samp_type(`samp_type')
        append_inst, samp(`samp') samp_type(`samp_type')
    }
    clear
    foreach samp in cns_med natsub scijrnls demsci med thera {
        if "`samp'" == "med" {
            local samp_type = "clinical"
            local samp = "clin_med"
        }
         append using ../temp/all_inst_`samp'
     }
     gduplicates  drop
     save ../output/all_insts, replace
    foreach var in institution country city {
        clear
        foreach samp in cns_med natsub scijrnls demsci med thera {
            if "`samp'" == "med" {
                local samp_type = "clinical"
                local samp = "clin_med"
            }
            append using ../temp/mi_`var'_`samp'
        }
        gduplicates drop
        save ../temp/all_mi_`var', replace
    }
    clean_inst
end

program append_inst
    syntax, samp(str) samp_type(str)
    use ../external/`samp_type'_full_samp/cleaned_all_`samp', clear
    gcontract institution
    drop _freq
    drop if mi(institution)
    save ../temp/all_inst_`samp', replace
end 
program append_mi
    syntax, samp(str) samp_type(str)
    use ../external/`samp_type'_full_samp/cleaned_all_`samp', clear
    keep if (mi(institution)|mi(country)|mi(city)) & !mi(affiliation)
    keep institution affiliation country city pmid which_*
    gen samp = "`samp'"
    foreach var in institution country city {
        preserve
        keep if mi(`var')
        save ../temp/mi_`var'_`samp', replace
        restore
    }
end 

program clean_city_country 
    use ../temp/all_mi_city, clear
    append using ../temp/all_mi_country
    gduplicates drop
    gen edit = affiliation
    replace edit = strtrim(edit)

    local cities Taoyuan Hualien Urbino Dessie Naples Antwerp Bilthoven Chungcheongbuk Kent Ede Sayo Gifu Oeiras Seeland Asturias Antwerp Gothenburg Irrua Twickenham Torino Safat Legon Shitsukawa Nagakute Tigray Victoria Miaoli Ghent Padua Storrs Birmensdorf  Illkirch Klecany Shiga Texcoco Gatersleben Boston Cambridge Richmond Guri Aviano Zhunan Dolgoprudny Bashkortostan  Oaxaca Kalisizo Hualian Mekelle Kingston Pirbright Nishinomiya  Durham Nouzilly Abuja Xinxiang Dasman Nugegoda Lyngby
    foreach c in `cities' "San Sebastian" "New Lambton Heights" "Winston-Salem" "The Woodlands" "Beer-Sheva" {
        replace city = "`c'" if strpos(edit, "`c'")>0 & city ==""
    }
    replace city = "Taipei" if strpos(edit, "Tri-Service General Hospital")>0
    replace city = "Tromso" if strpos(edit, "University of TromsA")>0
    replace city = "New York" if strpos(edit, "Mount Sinai")>0
    replace city = "Matsuyama" if strpos(edit, "Ehime University")>0
    replace city = "Kyoto" if strpos(edit, "Doshisha University")>0
    replace city = "Minato" if strpos(edit, "Toroanomon Hospital")>0
    replace city = "Kofu" if strpos(edit, "University of Yamanashi")>0
    replace country = "Nigeria" if strpos(edit, "Nigeria")>0
    replace city = "Warsaw" if strpos(edit, "Polish Academy of Sciences")>0
    replace city = "Los Angeles" if strpos(edit, "UCLA")>0
    keep pmid which*  city country
    gduplicates drop pmid which*, force
    rename (city country) (test_city test_country)
    save ../output/filled_in_city_country, replace
end 
program clean_inst
    use ../temp/all_mi_institution, clear
    gen edit = affiliation
    replace edit = strtrim(edit)
    replace edit = "" if strpos(edit, "@") > 0 & strpos(edit, " ") == 0
    replace edit = subinstr(edit, ", "+city+", " + country+".", "",.) if !mi(city) & !mi(country)
    replace edit = subinstr(edit, ", UK.", "",.)
    replace edit = substr(edit, 1, strlen(edit)-1) if substr(edit, strlen(edit), 1) == "."
    replace edit = subinstr(edit, ", " + city, "",.) if substr(edit, strlen(edit) - strlen(city) + 1, strlen(edit)) == city & !mi(city)
    replace edit = subinstr(edit, ", " + country, "",.) if substr(edit, strlen(edit) - strlen(country) + 1, strlen(edit)) == country & !mi(country)
    drop if mi(edit)
    split edit, parse(",")
    gen test_inst = ""
    rename edit raw_edit 
    ds edit*
    foreach var in `r(varlist)' {
        replace test_inst = `var' if strpos(`var', "Hospital")> 0
        replace test_inst = `var' if strpos(`var', "Hospice")> 0
        replace test_inst = `var' if strpos(`var', "Hopital")> 0
        replace test_inst = `var' if strpos(`var', "Pharmaceuticals")> 0
        replace test_inst = `var' if strpos(`var', "Therapeutics")> 0
        replace test_inst = `var' if strpos(`var', "Biotech")> 0
        replace test_inst = `var' if strpos(`var', "Corp")> 0
        replace test_inst = `var' if strpos(`var', "Co.")> 0
        replace test_inst = `var' if strpos(`var', "Infirmary")> 0
        replace test_inst = `var' if strpos(`var', "Hospital")> 0
        replace test_inst = `var' if strpos(`var', "Ospedale")> 0
        replace test_inst = `var' if strpos(`var', "INRA")> 0
        replace test_inst = `var' if strpos(`var', "Veterans Affairs")> 0
        replace test_inst = `var' if strpos(strlower(`var'), "instit")>0 & mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Research Center")>0 & mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Research Centre")>0 & mi(test_inst)
        replace test_inst = `var' if strpos(`var', "National")>0 & mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Medical Center")>0  & mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Clinic")>0 &  mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Academy")> 0 &  mi(test_inst)
        replace test_inst = `var' if strpos(`var', "School of")>0 &  mi(test_inst)
        replace test_inst = `var' if strpos(`var', "Medical School")>0 &  mi(test_inst)
        replace test_inst = `var' if strpos(strlower(`var'), "universi")>0
        replace test_inst = `var' if strpos(strlower(`var'), "college")>0
    }
    replace test_inst = subinstr(test, "the ","",1) if strpos(test, "the ")==1
    replace test_inst = subinstr(test, "and ","",1) if strpos(test, "and ")==1
    frame put if !mi(test_inst) , into(cleaned_inst)
    drop if !mi(test_inst)
    
    replace test_inst = raw_edit if !(strpos(raw_edit, ",") >0 | strpos(raw_edit, ".")>0)
    replace test_inst = "" if inlist(test_inst, "and", "Kent", "New York")
    replace test_inst = "" if strpos(test_inst, "From the") == 1
    keep if !mi(test_inst)
    keep pmid which* test_inst
    save ../temp/cleaned_insts, replace
    frame change cleaned_inst
    keep pmid which* test_inst samp
    append using ../temp/cleaned_insts
    gduplicates drop pmid which*, force
    save ../output/filled_in_insts, replace

/*
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Faculty of")==1
    *replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Laboratory of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "School of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Division of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Centre for")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Center of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "College of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Department of")==1

    replace test_inst = substr(edit, 1 , strpos(edit, ",")-1) if !(strpos(edit, "of")>0 | strpos(edit, "de ")>0  | strpos(edit, "di ")>0)
    replace test_inst = "" if test_inst == city & !mi(city)
    replace test_inst = test_inst +  " " + city if inlist(test_inst, "University Hospital", "Academic Medical Center", "Academic Medical Centre")




    frame put if !mi(test_inst), into(cleaned_inst2)
    drop if !mi(test_inst)
    replace edit = subinstr(edit, ".","",.) if strpos(edit, ".") == strlen(edit)
    replace edit = subinstr(edit, ", "+country,"",.) if !mi(country)
    replace edit = subinstr(edit, ", "+city,"",.) if !mi(city)
    replace edit = strtrim(edit)
    replace test_inst = edit if !(strpos(edit, ",") >0 | strpos(edit, ".")>0)
    replace test_inst = subinstr(test, "the ","",1) if strpos(test, "the ")==1
    replace test_inst = substr(test, 1, strlen(test)-4) if substr(test, strlen(test)-3, strlen(test)) == " and"
    replace test_inst = "" if inlist(test_inst ,"and" , "an")
    replace test_inst = "" if test_inst == city
    replace test_inst = "" if strpos(test_inst , "Department of") == 1 | strpos(test_inst , "Departments of") == 1 | strpos(test_inst, "Faculty of") == 1
    frame put if !mi(test_inst), into(cleaned_inst3)
     drop if !mi(test_inst)




    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Faculty of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "School of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Division of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "College of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(edit, "Department of")==1
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(substr(edit,1,strpos(edit, ",")), "Unit")>0
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(substr(edit,1,strpos(edit, ",")), "Faculty")>0
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(substr(edit,1,strpos(edit, ",")), "Division")>0
    replace edit = substr(edit, strpos(edit,",")+2, strlen(edit) - (strpos(edit,",")+2)) if strpos(substr(edit,1,strpos(edit, ",")), "Department")>0
*    replace edit = substr(edit, strpos(strlower(edit), "universit"), strlen(edit) - strpos(strlower(edit), "universit")) if strpos(strlower(edit), "universit")>0 & strpos(strlower(substr(edit, 1 , strpos(edit, ",")-1)), "universit")==0
    replace test_inst = substr(edit, 1 , strpos(edit, ",")-1)
    replace test_inst = test_inst +  " " + city if inlist(test_inst, "University Hospital", "Academic Medical Center")
    replace edit = subinstr(edit, city + ", " + country, "",.)
    replace edit = "" if strpos(edit, city+",") == 1 & !mi(city)
    replace edit = strtrim(edit)
    replace edit = "" if strpos(edit, "@") > 0 & strpos(edit, " ") == 0
    replace edit = "" if inlist(edit, "and", "an", "Londo", "London", "UK")
    replace test_inst = substr(edit, 1 , strpos(edit, ",")-1)*/

end 
** 
main
