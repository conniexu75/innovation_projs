library(openalexR)
library(dplyr)
library(ggplot2)
library(stringr)
library(here)
library(haven)
library(foreign)
#setwd(here())
set.seed(8975)
options(openalexR.mailto = "xuconni@gmail.com")


################################### MAIN ###################################
doi_file <- read_dta('../output/list_of_doi_newfund_jrnls.dta')
pmid_file <- read_dta('../output/list_of_pmids_newfund_jrnls.dta')
pmids <- pmid_file %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid)
pmids_sub <- pmid_file %>% sample_n(100) %>% mutate(pmid = as.character(pmid)) %>% pull(pmid)

## pull open alex data from pmids
works_from_pmids <- oa_fetch(
  entity = "works",
  ids.pmid  = pmids_sub,
  verbose = TRUE
)

## get open alex id and pmid xwalk
pmid_list = works_from_pmids %>% select(ids)
id_xwalk <- lapply(1:nrow(pmid_list) , function(i) {
    alex_id <- subset(pmid_list[["ids"]][[i]], name == "openalex")[2] %>% data.frame()
    pmid <- subset(pmid_list[["ids"]][[i]], name == "pmid")[2] %>% data.frame()
    cbind(alex_id, pmid)
}) %>% bind_rows() %>%
rename("id" = "value...1", 
        "pmid" = "value...2") %>%
        mutate(id = str_replace(id, "https://openalex.org/",""),
                pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/","")) %>% as.data.frame()
write.dta(id_xwalk, "../output/openalex_pmid_xwalk.dta")
## pull open_alex author ids associated with each author for each paper
all_authors = works_from_pmids %>% select(id, author)
au_ids<- lapply(1:nrow(all_authors), function(i) {
    ids <- replicate(n=length(all_authors[["author"]][[i]][["au_id"]]), all_authors[["id"]][[i]]) %>% data.frame
    authors <- all_authors[["author"]][[i]][["au_id"]] %>% data.frame()
    name <- all_authors[["author"]][[i]][["au_display_name"]] %>% data.frame()
    inst_name <- all_authors[["author"]][[i]][["institution_display_name"]] %>% data.frame()
    inst_id <- all_authors[["author"]][[i]][["institution_id"]] %>% data.frame()
    cbind(ids, authors, name, inst_name, inst_id)
      }) %>% 
        bind_rows() %>%
        rename("id" = "....1", 
        "author_id" = "....2", 
        "author_name" = "....3",
        "inst_name" = "....4", 
        "inst_id" = "....5") %>%
        mutate(id = str_replace(id, "https://openalex.org/",""),
                author_id= str_replace(author_name, "https://openalex.org/", ""),
                inst_id = str_replace(inst_id, "https://openalex.org/","")) %>% as.data.frame()

write.dta(au_ids, "../output/openalex_authors_xwalk.dta")
unique_authors <- unique(au_ids$authors) 

