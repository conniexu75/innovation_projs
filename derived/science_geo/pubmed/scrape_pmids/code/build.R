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
## FUNDAMENTAL = BASIC+ TRANSLATIONAL ARTICLES, ALL JOURNALS ===
years = as.character(1988:2022)
year_queries = paste0('(', years, '/01/01[PDAT] : ', years, '/12/31[PDAT])')

queries_sub = read_tsv(file = '../external/queries/search_terms_newfund_all_jrnls.txt')

queries = rep(queries_sub$Query, each=length(year_queries))
query_names = rep(queries_sub$Query_Name, each=length(year_queries))

queries = paste0(year_queries, ' AND ', queries)
query_names = paste0(query_names, '_', years)

#Run through scraping function to pull out PMIDs
# 5 is the number of queries we're using in the .txt file
# 35 is the number of years between 1988 and 2022
#for (counter in 1:5) {
#  start <- (counter-1)*35+1
#  end <- counter*35
#  PMIDs =  sapply(X = queries[start:end], FUN = pull_pmids) %>%
#    unname()
#  for (i in 1:35) {
#    j = i + (counter-1)*35
#    outfile = paste0('../output/',
#                     query_names[j],
#                     '.csv')
#    subset = data.frame(unlist(PMIDs[i]), rep(query_names[j], length(unlist(PMIDs[i])))) 
#    colnames(subset)<-c('pmid','query_name')
#    write_csv(subset, outfile)
#  }
#}

### Select Med Journals and Basic Science Journals (all articles) ========================================
#jrnls = c("nejm", "jama", "lancet", "bmj", "annals", "science", "nature", "cell", "onco", "neuron", "nat_neuro", "nat_med", "nat_genet", "nat_chem_bio", "nat_cell_bio", "nat_biotech", "cell_stem_cell", "faseb", "jbc")
jrnls = c("onco", "neuron", "nat_neuro", "nat_med", "nat_genet", "nat_chem_bio", "nat_cell_bio", "nat_biotech", "cell_stem_cell", "faseb", "jbc")
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

 pull plos separately because it's weird
jrnls = c("plos")
years = as.character(1988:2022)
year_queries = paste0('(', years, '/01/01[edat] : ', years, '/03/31[edat])')
year_queries2 = paste0('(', years, '/04/01[edat] : ', years, '/07/31[edat])')
year_queries3 = paste0('(', years, '/08/01[edat] : ', years, '/12/31[edat])')
for (j in jrnls) {
  j3 = substr(j,1,4)
  queries_sub = read_tsv(file = paste0('../external/queries/search_terms_newfund_',j,'.txt'))
  queries = rep(queries_sub$Query, each=length(year_queries))
  query_names = rep(queries_sub$Query_Name, each=length(year_queries))
  queries1 = paste0(year_queries, ' AND ', queries)
  queries2 = paste0(year_queries2, ' AND ', queries)
  queries3 = paste0(year_queries3, ' AND ', queries)
  query_names = paste0(query_names, '_', years)
  #Run through scraping function to pull out PMIDs
  # 5 is the number of queries we're using in the .txt file
  # 35 is the number of years between 1988 and 2022
  for (counter in 1:5) {
    start <- (counter-1)*35+1
    end <- counter*35
    PMIDs =  sapply(X = queries1[start:end], FUN = pull_pmids) %>%
      unname()
    PMIDs2 =  sapply(X = queries2[start:end], FUN = pull_pmids) %>%
      unname()
    PMIDs3 = sapply(X = queries3[start:end], FUN = pull_pmids) %>%
      unname()
    for (i in 1:35) {
      j = i + (counter-1)*35
      outfile = paste0('../output/',j3,'_',
                       query_names[j],
                       '.csv')
      subset = data.frame(unlist(PMIDs[i]), rep(query_names[j], length(unlist(PMIDs[i])))) 
      colnames(subset)<-c('pmid','query_name')
      subset2 = data.frame(unlist(PMIDs2[i]), rep(query_names[j], length(unlist(PMIDs2[i])))) 
      colnames(subset2)<-c('pmid','query_name')
      subset3 = data.frame(unlist(PMIDs3[i]), rep(query_names[j], length(unlist(PMIDs3[i])))) 
      colnames(subset3)<-c('pmid','query_name')
      combined = rbind(subset,subset2,subset3)
      colnames(combined)<-c('pmid','query_name')
      write_csv(combined, outfile)
    }
  }
}

## pull plos separately
jrnls = c("plos")
years = as.character(1998:2022)
year_queries = paste0('(', years, '/01/01[edat] : ', years, '/03/31[edat])')
year_queries2 = paste0('(', years, '/04/01[edat] : ', years, '/06/30[edat])')
year_queries3 = paste0('(', years, '/07/01[edat] : ', years, '/09/30[edat])')
year_queries4 = paste0('(', years, '/10/01[edat] : ', years, '/12/31[edat])')
for (j in jrnls) {
  queries_sub = read_tsv(file = paste0('../external/queries/',j,'.txt'))
  queries = rep(queries_sub$Query, each=length(year_queries))
  queries1 = paste0(year_queries, ' AND ', queries)
  queries2 = paste0(year_queries2, ' AND ', queries)
  queries3 = paste0(year_queries3, ' AND ', queries)
  queries4 = paste0(year_queries4, ' AND ', queries)
  query_names = paste0(years)
  for (counter in 1:35) {
    PMIDs =  sapply(X = queries1[counter], FUN = pull_pmids) %>%
      unname()
    PMIDs = as.numeric(PMIDs)
    PMIDdf = data.frame(pmid=PMIDs) %>% 
      mutate(year = years[counter])
    
    PMIDs2 = sapply(X = queries2[counter], FUN = pull_pmids) %>%
      unname()
    PMIDs2 = as.numeric(PMIDs2)
    PMIDdf2 = data.frame(pmid=PMIDs2) %>%
      mutate(year = years[counter])
    
    PMIDs3 = sapply(X = queries3[counter], FUN = pull_pmids) %>%
      unname()
    PMIDs3 = as.numeric(PMIDs3)
    PMIDdf3 = data.frame(pmid=PMIDs3) %>%
      mutate(year = years[counter])
    PMIDs4 = sapply(X = queries4[counter], FUN = pull_pmids) %>%
      unname()
    PMIDs4 = as.numeric(PMIDs4)
    PMIDdf4 = data.frame(pmid=PMIDs4) %>%
      mutate(year = years[counter])
    PMIDdf <- rbind(PMIDdf, PMIDdf2, PMIDdf3, PMIDdf4)
    write_csv(PMIDdf,paste0('../output/',j,
                            years[counter],
                            '.csv'))
  }
}




