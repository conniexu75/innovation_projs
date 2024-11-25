set more off
clear all
capture log close
program drop _all
set scheme modern
pause on
set seed 8975
here, set
set maxvar 120000
global temp "/export/scratch/cxu_sci_geo/get_jrnl_totals"

program main
    foreach samp in 15jrnls {
        *clean_titles, samp(`samp')
    }
end

program clean_titles
    syntax, samp(str) 
    use pmid title id pub_type jrnl using ../external/openalex/openalex_`samp'_merged, clear
    keep if pub_type == "article"
    replace title = stritrim(title)
    drop if mi(title)
    gen lower_title = stritrim(subinstr(subinstr(subinstr(subinstr(strlower(title), `"""', "", .), ".", "",.)), " :", ":",.), "'", "", .)
    drop if strpos(lower_title , "nuts")>0 & strpos(lower_title, "bolts")>0
    foreach s in "economic" "economy" "public health" "hallmarks" "government" "reform" "equity" "payment" "politics" "policy" "policies" "comment" "guideline" "profession's" "interview" "debate" "professor" "themes:"  "professionals" "physician" "workforce" "medical-education"  "medical education" "funding" "conference" "insurance" "fellowship" "ethics" "legislation" "the editor" "response : " "letters" "this week" "notes" "news " "a note" "obituary"  "review" "perspectives" "scientists" "book" "institution" "meeting" "university" "universities" "journals" "publication" "recent " "costs" "challenges" "researchers" "perspective" "reply" " war" " news" "a correction" "academia" "society" "academy of" "nomenclature" "teaching" "education" "college" "academics"  "political" "association for" "association of" "response by" "societies" "health care" "health-care"  "abstracts" "journal club" "curriculum" "women in science" "report:" "letter:" "editorial:" "lesson" "awards" "doctor" "nurse" "health workers" " story"  "case report" "a brief history" "lecture " "career" "finance" "criticism" "critique" "discussion" "world health" "workload" "compensation" "educators" "war" "announces" "training programmes" "nhs" "nih" "national institutes of health" "address" "public sector" "private sector" "government" "price" "reflections" "health care" "healthcare" "health-care" " law" "report" "note on" "insurer" "health service research" "error" "quality of life" {
        drop if strpos(lower_title, "`s'")>0
    }
    gen strp = substr(lower_title, 1, strpos(lower_title, ": ")) if strpos(lower_title, ": ") > 0
    bys strp jrnl : gen tot_strp = _N
    foreach s in "letter:" "covid-19:" "snapshot:" "editorial:" "david oliver:" "offline:" "helen salisbury:" "margaret mccartney:" "book:" "response:" "letter from chicago:" "a memorable patient:" "<i>response</i> :" "reading for pleasure:" "partha kar" "venus:" "matt morgan:" "bad medicine:" "nota bene:" "cohort profile:" "size matters:" "usa:" "cell of the month:" "living on the edge:" "enhanced snapshot:" "world view:" "science careers:" "clare gerada:" "rammya mathew:" "endpiece:" "role model:" "quick uptakes:" "webiste of the week:" "tv:" "press:" "brief communication:" "essay:" "clinical update:" "assisted dying:" "controversies in management:" "health agencies update:" "the bmj awards 2020:" "lesson of the week:" "ebola:" "media:" "management for doctors:" "monkeypox:" "profile:" "the bmj awards 2017:" "the world in medicine:" "the bmj awards 2021:" "when i use a word . . .:" "personal paper:"  "clinical decision making:" "how to do it:" "10-minute consultation:" "frontline:" "when i use a word:" "medicine as a science:" "personal papers:" "miscellanea:" "the lancet technology:" {
        drop if strpos(lower_title, "`s'") == 1 & tot_strp > 1
    }
    drop if inlist(lower_title, "random samples", "sciencescope", "through the glass lightly", "equipment", "women in science",  "correction", "the metric system")
    drop if inlist(lower_title, "convocation week","the new format", "second-quarter biotech job picture", "gmo roundup")
    drop if strpos(lower_title, "annals ")==1
    drop if strpos(lower_title, "a fatal case of")==1
    drop if strpos(lower_title, "a case of ")==1
    drop if strpos(lower_title, "case ")==1
    drop if strpos(lower_title, "a day ")==1
    drop if strpos(lower_title,"?")>0
    save ${temp}/openalex_`samp'_clean_titles, replace
end

main
