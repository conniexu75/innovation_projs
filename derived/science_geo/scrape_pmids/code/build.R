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
                '&tool=my_tool&email=my_email@example.com'
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
### BASIC, TRANSLATIONAL, AND CLINICAL SCIENCE JOURNAL ARTICLES, ALL JOURNALS ===
years = as.character(1988:2022)
year_queries = paste0('(', years, '/01/01[PDAT] : ', years, '/12/31[PDAT])')

queries_sub = read_tsv(file = '../external/queries/search_terms_basic_indices_select_jrnl.txt')

queries = rep(queries_sub$Query, each=length(year_queries))
query_names = rep(queries_sub$Query_Name, each=length(year_queries))

queries = paste0(year_queries, ' AND ', queries)
query_names = paste0(query_names, '_', years)

#Run through scraping function to pull out PMIDs
# 5 is the number of queries we're using in the .txt file
# 35 is the number of years between 1988 and 2022
for (counter in 1:5) {
  start <- (counter-1)*35+1
  end <- counter*35
  PMIDs =  sapply(X = queries[start:end], FUN = pull_pmids) %>%
    unname()
  for (i in 1:35) {
    j = i + (counter-1)*35
    outfile = paste0('../output/BTC/BTC_',
                     query_names[j],
                     '.csv')
    subset = data.frame(unlist(PMIDs[i]), rep(query_names[j], length(unlist(PMIDs[i])))) 
    colnames(subset)<-c('pmid','query_name')
    write_csv(subset, outfile)
  }
}

### Select Med Journals and Basic Science Journals (basic science articles + translational) ========================================
#type <- c("basic", "trans")
#for (t in type) {
#  queries_sub = read_tsv(file = paste0('../external/queries/search_terms_',t,'_select_jrnls.txt'))
#  queries = paste0(queries_sub$Query, ' AND (1988/01/01[PDAT] : 2022/12/31[PDAT])')
#  query_names = queries_sub$Query_Name
#  #Run through scraping function to pull out PMIDs
#  PMIDs = sapply(X = queries, FUN = pull_pmids) %>%
#    unname()
#  PMIDs = as.numeric(PMIDs)
#  PMIDdf = data.frame(pmid=PMIDs)
#  write_csv(PMIDdf, paste0('../output/',t,'_select_jrnls_pmids.csv'))
#}

### Select Med Journals and Basic Science Journals (all articles) ========================================
jrnls = c("nejm", "jama", "lancet", "bmj", "annals", "science", "nature", "cell")
years = as.character(1988:2022)
year_queries = paste0('(', years, '/01/01[PDAT] : ', years, '/12/31[PDAT])')
for (j in jrnls) {
  queries_sub = read_tsv(file = paste0('../external/queries/',j,'.txt'))
  queries = rep(queries_sub$Query, each=length(year_queries))
  queries = paste0(year_queries, ' AND ', queries)
  query_names = paste0(years)
  for (counter in 1:35) {
    PMIDs =  sapply(X = queries[counter], FUN = pull_pmids) %>%
      unname()
    PMIDs = as.numeric(PMIDs)
    PMIDdf = data.frame(pmid=PMIDs) %>% 
      mutate(year = years[counter])
    write_csv(PMIDdf,paste0('../output/',j,
                            years[counter],
                            '.csv'))
  }
}
