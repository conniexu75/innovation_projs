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
for (j in 1:num_file) {
    ## pull open alex data from pmids
    works_from_pmids <- oa_fetch(
      entity = "works",
      ids.pmid  = split_pmid[[j]] %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid),
      verbose = TRUE,
      output = "list"
    )
    ## pull open_alex author ids associated with each author for each paper
    N_articles <- length(works_from_pmids)
    au_ids <- lapply(1:N_articles, function(i) {
      ids <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
      pmid <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["ids"]][["pmid"]]) %>% data.frame
      which_athr <- ave(1:length(works_from_pmids[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
      N_athrs <- length(works_from_pmids[[i]][["authorships"]])
      num_affls <- list()
      athr_id <- list()
      athr_name <- list()
      num_affls <-  lapply(1:N_athrs, function(j) {
        append(num_affls, length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]]))
      })  %>% data.frame %>% t()
      athr_id <-  lapply(1:N_athrs, function(j) {
        append(athr_id, works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]])
      })  %>% data.frame %>% t()
      athr_name <-  lapply(1:N_athrs, function(j) {
        append(athr_name, works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]])
      })  %>% data.frame %>% t()
      cbind(ids, pmid, which_athr, athr_id, athr_name, num_affls)
    }) %>% bind_rows()
    colnames(au_ids) <- c("id","pmid","which_athr","athr_id", "athr_name", "num_affls")
    au_ids <- au_ids %>% uncount(num_affls)
    inst <- list()
    inst_id <- list()
    for(i in 1:N_articles) {
      N_athrs <- length(works_from_pmids[[i]][["authorships"]])
      for(j in 1:N_athrs) {
        for(k in 1:length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])) {
          inst<-append(inst, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])
          inst_id<-append(inst_id, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])
        }
      }
    }
    
    inst <- inst %>% data.frame %>% t()
    inst_id <- inst_id %>% data.frame %>% t()
    affl_list <- cbind(au_ids,inst, inst_id) %>% 
      group_by(id, which_athr) %>% 
      mutate(which_affl = 1:n(),
             id = str_replace(id, "https://openalex.org/",""),
             pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
             athr_id= str_replace(athr_id, "https://openalex.org/", ""),
             inst_id = str_replace(inst_id, "https://openalex.org/",""))
    write.dta(affl_list, paste0("../output/openalex_authors", as.character(j), ".dta"))
    ## get mesh terms
    mesh_terms <- lapply(1:N_articles, function(i) {
      ids <- replicate(n=length(works_from_pmids[[i]][["mesh"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
      which_mesh <- ave(1:length(works_from_pmids[[i]][["mesh"]]), ids, FUN = seq_along) %>% data.frame
      N_mesh <- length(works_from_pmids[[i]][["mesh"]])
      terms <- list()
      major_topic <- list()
      terms <-  lapply(1:N_mesh, function(j) {
        append(terms, works_from_pmids[[i]][["mesh"]][[j]][["descriptor_name"]])
      }) %>% data.frame %>% t()
      major_topic <-  lapply(1:N_mesh, function(j) {
        append(major_topic, works_from_pmids[[i]][["mesh"]][[j]][["is_major_topic"]])
      })  %>% data.frame %>% t()
      cbind(ids, which_mesh, mesh_terms, major_topic)
    }) %>% bind_rows()
    colnames(mesh_terms) <- c("id","which_mesh","term", "is_major_topic")
    mesh_terms <- mesh_terms %>% mutate(id = str_replace(id, "https://openalex.org/",""))
    write.dta(mesh_terms, paste0("../output/mesh_terms", as.character(j), ".dta"))
}

