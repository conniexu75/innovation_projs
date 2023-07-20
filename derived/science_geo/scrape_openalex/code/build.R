library(openalexR)
library(dplyr)
library(ggplot2)
library(stringr)
library(here)
library(haven)
library(foreign)
#setwd(here())
set.seed(8975)
options(openalexR.mailto = "conniexu0@gmail.com")


################################### MAIN ###################################
doi_file <- read_dta('../output/list_of_doi_newfund_jrnls.dta')
pmid_file <- read_dta('../output/list_of_pmids_newfund_jrnls.dta')
nr <- nrow(pmid_file)
split_pmid <- split(pmid_file, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
num_file <- length(split_pmid)
for (j in 53:55) {
    ## pull open alex data from pmids
    works_from_pmids <- oa_fetch(
      entity = "works",
      ids.pmid  = split_pmid[[j]] %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid),
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
    write.dta(id_xwalk, paste0("../output/openalex_pmid_xwalk",as.character(j),".dta"))

    ## pull open_alex author ids associated with each author for each paper
    all_authors = works_from_pmids %>% select(id, author) 
    au_ids<- lapply(1:nrow(all_authors), function(i) {
        if (is.na(all_authors[["author"]][[i]]) == FALSE) {
            print(i)
            ids <- replicate(n=length(all_authors[["author"]][[i]][["au_id"]]), all_authors[["id"]][[i]]) %>% data.frame
            which_athr <- ave(1:length(all_authors[["author"]][[i]][["au_id"]]), ids, FUN = seq_along)
            authors <- all_authors[["author"]][[i]][["au_id"]] %>% data.frame()
            name <- all_authors[["author"]][[i]][["au_display_name"]] %>% data.frame()
            inst_name <- all_authors[["author"]][[i]][["institution_display_name"]] %>% data.frame()
            inst_id <- all_authors[["author"]][[i]][["institution_id"]] %>% data.frame()
            which_athr <- ave(1:length(all_authors[["author"]][[i]][["au_id"]]), ids, FUN = seq_along)
            cbind(ids, authors, name, inst_name, inst_id, which_athr)
              }}) %>% 
                bind_rows() %>%
                rename("id" = "....1", 
                "author_id" = "....2", 
                "author_name" = "....3",
                "inst_name" = "....4", 
                "inst_id" = "....5") %>%
                mutate(id = str_replace(id, "https://openalex.org/",""),
                        author_id= str_replace(author_id, "https://openalex.org/", ""),
                        inst_id = str_replace(inst_id, "https://openalex.org/","")) %>% as.data.frame()
        write.dta(au_ids, paste0("../output/openalex_authors_xwalk", as.character(j), ".dta"))
}

unique_authors <- unique(au_ids$authors) 

