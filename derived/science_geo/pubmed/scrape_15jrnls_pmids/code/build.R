# Load package for web scraping & cleaning strings
library(tidyverse)
library(rvest)
library(stringr)
library(xml2)
library(here)

setwd(here())
set.seed(8975)

################################### FUNCTIONS ###################################
# Pull list of PMIDs to query for individually
pull_pmids = function(query){
  
  search = URLencode(query)
  
  i = 0
  # Form URL using the term
  url = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=5000&retstart=',
                i,
		            '&term=',
		            search,
                '&api_key=2f42bf6944745e7c722c4cbf5ac9f3d3ff09'
  )

  # Query PubMed and save result
  xml = read_xml(url)
  
  # Store total number of papers so you know when to stop looping
  N = xml %>%
    xml_node('Count') %>%
    xml_double()
print(N)
  # Return list of article IDs to scrape later
  pmid_list = xml %>% 
    xml_node('IdList')
  pmid_list = str_extract_all(pmid_list,"\\(?[0-9]+\\)?")[[1]]
	
  Sys.sleep(0.3)

  i = 5000
  while (i < N) {
    # Form URL using the term
    url = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=5000&retstart=',
                i,
                '&term=',
                search,
                '&tool=my_tool&email=my_email@example.com')

    # Query PubMed and save result
    xml = read_xml(url)

    new_ids = xml %>%
      xml_node('IdList')
    new_ids = str_extract_all(new_ids,"\\(?[0-9]+\\)?")[[1]]


    i = i + 5000

    pmid_list = append(pmid_list, new_ids)

    Sys.sleep(runif(1,0.6,1))
  }
  return(pmid_list)
}

################### PULL ARTICLE PMID LISTS ###################################
## FUNDAMENTAL = BASIC+ TRANSLATIONAL ARTICLES, ALL JOURNALS ===
years = as.character(1991:2000)
year_queries = paste0('(', years, '/01/01[PDAT] : ', years, '/12/31[PDAT])')

queries_sub = read_tsv(file = '../external/queries/search_terms_newfund.txt')

queries = rep(queries_sub$Query, each=length(year_queries))
query_names = rep(queries_sub$Query_Name, each=length(year_queries))

queries = paste0(year_queries, ' AND ', queries)
query_names = paste0(query_names, '_', years)

#Run through scraping function to pull out PMIDs
# 3 is the number of queries we're using in the .txt file
# 40 is the number of years between 1985 and 2024
for (counter in 1:1) {
  start <- (counter-1)*10+1
  end <- counter*10
  PMIDs =  sapply(X = queries[start:end], FUN = pull_pmids) %>%
    unname()
  for (i in 1:10) {
    j = i + (counter-1)*10
    outfile = paste0('../output/',
                     query_names[j],
                     '.csv')
    subset = data.frame(unlist(PMIDs[i]), rep(query_names[j], length(unlist(PMIDs[i])))) 
    colnames(subset)<-c('pmid','query_name')
    write_csv(subset, outfile)
  }
}

