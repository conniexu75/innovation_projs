library(stringr)
library(rvest)
library(tidyverse)
library(xml2)
library(here)
library(haven)

setwd(here())
set.seed(8975)
#--------------------------------------------------------------------------------
# Pull Publication Type
# apis: 2f42bf6944745e7c722c4cbf5ac9f3d3ff09
# apis:ae06e6619c472ede6b6d4ac4b5eadecdb209 
#apis: 3c5c4af6c47a9f9e478bc7e7e8c30a794d09
#70e87a4b501324ec5eab0eca260b1fddf909
pull_pt = function(id) {
  id_equals = paste0('id=', id)
  if (id_equals != "id=NA") {
    print(id)
    # Form URL using the term
    url = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=',
                 id,
                 '&retmode=xml',
                 '&api_key=3c5c4af6c47a9f9e478bc7e7e8c30a794d09')
    # Query PubMed and save result
    xml = read_xml(url)
    pt = xml %>%
      xml_node('PublicationTypeList')
    pt = as.character(pt)
    pt = gsub("\n", "", pt)
    output = c(pt)
    Sys.sleep(runif(1,0.3,0.5))
  }
  else {
    output = c("NA")
  }
  return(output)
}

####################### PULL PUB TYPE OF ALL PMIDS FROM SELECT JRNLS ########################################################
#queries <- read_dta(file = '../external/pmid/cns_all_pmids.dta')
#pmid <- queries$pmid
#len <- length(pmid)
#n <- ceiling(len/500)
#for (i in 451:500) {
#  while(TRUE) {
#      print(i)
#      start <- (i-1)*500+1
#      end <- i*500
#      test <- try(sapply(X = pmid[start:end], FUN = pull_pt))
#      if(!is(test, 'try-error')) break
#  }
#  info = test
#  master = data.frame(pmid = pmid[start:end], pt = info[1])
#  file_name = paste("../output/","cns_",start,"_", end,".csv", sep="")
#  write_csv(master, file = file_name)
#}
#queries <- read_dta(file = '../external/pmid/med_all_pmids.dta')
#pmid <- queries$pmid
#len <- length(pmid)
#n <- ceiling(len/500)
#for (i in 480:500) {
#  while(TRUE) {
#      print(i)
#      start <- (i-1)*500+1
#      end <- i*500
#      test <- try(sapply(X = pmid[start:end], FUN = pull_pt))
#      if(!is(test, 'try-error')) break
#  }
#  info = test
#  master = data.frame(pmid = pmid[start:end], pt = info[1])
#  file_name = paste("../output/","med_",start,"_", end,".csv", sep="")
#  write_csv(master, file = file_name)
#}
#queries <- read_dta(file = '../external/pmid/scisub_all_pmids.dta')
#pmid <- queries$pmid
#len <- length(pmid)
#n <- ceiling(len/1000)
#for (i in 11:20) {
#  while(TRUE) {
#      print(i)
#      start <- (i-1)*1000+1
#      end <- i*1000
#      test <- try(sapply(X = pmid[start:end], FUN = pull_pt))
#      if(!is(test, 'try-error')) break
#  }
#  info = test
#  master = data.frame(pmid = pmid[start:end], pt = info[1])
#  file_name = paste("../output/","scisub_",start,"_", end,".csv", sep="")
#  write_csv(master, file = file_name)
#}
queries <- read_dta(file = '../external/pmid/demsci_all_pmids.dta')
pmid <- queries$pmid
len <- length(pmid)
n <- ceiling(len/1000)
for (i in 60:60){
  while(TRUE) {
      print(i)
      start <- (i-1)*1000+1
      end <- i*1000
      test <- try(sapply(X = pmid[start:end], FUN = pull_pt))
      if(!is(test, 'try-error')) break
  }
  info = test
  master = data.frame(pmid = pmid[start:end], pt = info[1])
  file_name = paste("../output/","demsci_",start,"_", end,".csv", sep="")
  write_csv(master, file = file_name)
}
