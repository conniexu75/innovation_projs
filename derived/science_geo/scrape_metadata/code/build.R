#------------------------------------------
# Pull Article Metadata from PubMed:      |
#   (1) publication date                  |
#   (2) MeSH Terms                        |
#   (3) Journal                           |
#   (4) Author Affiliations               |
#   (5) Publication Types                 |
#   (6) Grant Codes*                      |
#         * no longer using - WOS better  |
#------------------------------------------

# Load package for web scraping & cleaning strings
#install.packages("stringr")
#install.packages("rvest")
#install.packages("tidyverse")
#install.packages("xml2")

library(stringr)
library(rvest)
library(tidyverse)
library(xml2)
library(here)
library(haven)

setwd(here())
set.seed(8975)
#--------------------------------------------------------------------------------
# Pull Publication Date, Journal, Publication Type, Journal, MeSH Terms, and Grants
pull_affs = function(id) {
  id_equals = paste0('id=', id)
  if (id_equals != "id=NA") {
    # Form URL using the term
    url = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=',
                 id,
                 '&retmode=xml',
                 '&api_key=2f42bf6944745e7c722c4cbf5ac9f3d3ff09')
    url = curl::curl(url)
    # Query PubMed and save result
    print(id)
    xml = read_xml(url)
    gr = xml %>%
      xml_node('GrantList')
    gr = as.character(gr)
    gr = gsub("\n", "", gr)
    
    pt = xml %>%
      xml_node('PublicationTypeList')
    pt = as.character(pt)
    pt = gsub("\n", "", pt)
    
    journal = xml %>%
      xml_node('Journal')
    journal = as.character(journal)
    journal = gsub("\n", "", journal)
    
    date = xml %>%
      xml_node('DateCompleted')
    date = as.character(date)
    date = gsub("\n", "", date)
    
    mesh = xml %>%
      xml_node('MeshHeadingList')
    mesh = as.character(mesh)
    mesh = gsub("\n", "", mesh)
    
    affil = xml %>%
      xml_node('AffiliationInfo')
    affil = as.character(affil)
    affil = gsub("\n", "", affil)
    
    athrs = xml %>%
      xml_find_all(".//AuthorList[@CompleteYN='Y']")
    athrs = as.character(athrs)
    athrs <- ifelse(length(nchar(athrs)) !=0 , athrs, NA) 
    athrs = gsub("\n", "", athrs)
    output = c(date, mesh, journal, affil,athrs, pt, gr)
    Sys.sleep(runif(1,0.3,0.5))
  }
  else {
    output = c("NA", "NA", "NA", "NA", "NA", "NA","NA")
  }
  return(output)
}
# Pull Publication Type
pull_pt = function(id) {
  id_equals = paste0('id=', id)
  if (id_equals != "id=NA") {
    print(id)
    # Form URL using the term
    url = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=',
                 id,
                 '&retmode=xml',
                 '&api_key=ae06e6619c472ede6b6d4ac4b5eadecdb209')
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
################### PULL BASIC and TRANSLATIONAL SCIENCE METADATA FROM SELECT JOURNALS ###################################
#queries_sub <- read_dta(file = '../external/samp/BTC_pmids.dta')
#cats <- c("fundamental", "therapeutics", "diseases")
##cats <- c("basic", "translational")
#for(c in cats) {
#    queries <- queries_sub %>% 
#      filter(cat == c)
#    pmid <- queries$pmid
#    len <- length(pmid)
#    n <- ceiling(len/500)
#    for (i in 84:n) {
#      while(TRUE) {
#        print(i)
#        start <- (i-1)*500+1
#        end <- i*500 
#        test <- try(sapply(X = pmid[start:end], FUN = pull_affs))
#        if(!is(test, 'try-error')) break
#      }
#      info = test
#      master = data.frame(pmid = pmid[start:end], date = info[1,], mesh = info[2,],
#                          journal=info[3,], affil=info[4,], athrs = info[5,], pt = info[6,], gr = info[7,])
#      file_name = paste("../output/metadata/",c,"_select_jrnl_",start,"_", end,".csv", sep="")
#      write_csv(master, file = file_name)
#    }
#}

####################### PULL PUB TYPE OF ALL PMIDS FROM SELECT JRNLS ########################################################
queries <- read_dta(file = '../external/samp/select_jrnls_pmids.dta')
pmid <- queries$pmid
len <- length(pmid)
n <- ceiling(len/500)
for (i in 89:n) {
  while(TRUE) {
      print(i)
      start <- (i-1)*500+1
      end <- i*500
      test <- try(sapply(X = pmid[start:end], FUN = pull_affs))
      if(!is(test, 'try-error')) break
  }
  info = test
#  master = data.frame(pmid = pmid[start:end], pt = info[1])
      master = data.frame(pmid = pmid[start:end], date = info[1,], mesh = info[2,],
                          journal=info[3,], affil=info[4,], athrs = info[5,], pt = info[6,], gr = info[7,])
      file_name = paste("../output/metadata/","pt_select_jrnl_",start,"_", end,".csv", sep="")
      write_csv(master, file = file_name)
}
