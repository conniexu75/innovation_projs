library(openalexR) 
library(dplyr) 
library(ggplot2) 
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
set.seed(8975)

pmid_file <- read_dta('../external/ids/list_of_works.dta')
nr <- nrow(pmid_file)
split_pmid <- split(pmid_file, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
num_file <- length(split_pmid)
for (q in 700:700) {
    print(q)
   ## pull open alex data from pmids
   works_from_pmids <- oa_fetch(
     entity = "works",
     mailto = "conniexu@g.harvard.edu",
     id  = split_pmid[[q]] %>% pull(id),
     output = "list"
   )
   ## pull open_alex author ids associated with each author for each paper
   N_articles <- length(works_from_pmids)
   au_ids <- lapply(1:N_articles, function(i) {
     if (length(works_from_pmids[[i]][["authorships"]])!=0) {
       ids <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
       if (length(works_from_pmids[[i]][["publication_date"]])!=0) {
         pub_date <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["publication_date"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["publication_date"]])==0) {
         pub_date <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if(length(works_from_pmids[[i]][["type_crossref"]])!=0) {
            pub_type <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["type_crossref"]]) %>% data.frame
       }
       if(length(works_from_pmids[[i]][["type_crossref"]])==0) {
            pub_type <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), " ") %>% data.frame
       }
       which_athr <- ave(1:length(works_from_pmids[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
       N_athrs <- length(works_from_pmids[[i]][["authorships"]])
       num_affls <- list()
       athr_id <- list()
       raw_affl <- list()
       athr_name <- list()
       num_affls <-  lapply(1:N_athrs, function(j) {
         append(num_affls, length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]]))
       })  %>% data.frame %>% t()
       athr_id <-  lapply(1:N_athrs, function(j) {
         if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]])) {
           append(athr_id, list(c("")))
         }
         else {
           append(athr_id, as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]]))
         }
       })  %>% data.frame %>% t()
       raw_affl <-  lapply(1:N_athrs, function(j) {
         if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["raw_affiliation_string"]][[1]])) {
           append(raw_affl, list(c("")))
         }
         else {
           append(raw_affl, as.character(works_from_pmids[[i]][["authorships"]][[j]][["raw_affiliation_string"]][[1]]))
         }
       })  %>% data.frame %>% t()
       athr_name <-  lapply(1:N_athrs, function(j) {
         if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]])) {
           append(athr_name, list(c("")))
         }
         else {
           append(athr_name,as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]]))
         }
       }) %>% data.frame %>% t()
       cbind(ids, pub_date, pub_type, which_athr, athr_id, athr_name, raw_affl, num_affls)
     }
   }) %>% bind_rows()
   colnames(au_ids) <- c("id", "pub_date", "pub_type", "which_athr","athr_id", "athr_name", "raw_affl", "num_affls")
   au_ids <- au_ids %>%
     mutate(num_affls = replace(num_affls, num_affls == 0, 1)) %>%
     uncount(num_affls)
   inst <- list()
   inst_id <- list()
   for(i in 1:N_articles) {
     N_athrs <- length(works_from_pmids[[i]][["authorships"]])
     if (N_athrs!=0) {
     for(j in 1:N_athrs) {
       if (length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])!=0){
         for(k in 1:length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])) {
           if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])!=0) {
             inst<-append(inst, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])
           }
           else {
             inst<-append(inst, list(c("")))
           }
           if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])!=0) {
             inst_id<-append(inst_id, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])
           }
           else{
             inst_id<-append(inst_id, list(c("")))
           }
         }
       }
       else {
         inst<-append(inst, list(c("")))
         inst_id<-append(inst_id, list(c("")))
       }
     }
     }
   }
   inst <- inst %>% data.frame %>% t()
   inst_id <- inst_id %>% data.frame %>% t()
   affl_list <- cbind(au_ids,inst, inst_id) %>%
     group_by(id, which_athr) %>%
     mutate(which_affl = 1:n(),
            id = str_replace(as.character(id), "https://openalex.org/",""),
            athr_id= str_replace(athr_id, "https://openalex.org/", ""),
            inst_id = str_replace(inst_id, "https://openalex.org/",""))
   write_csv(affl_list, paste0("/export/scratch/cxu_sci_geo/scrape_econ_inst/openalex_authors", as.character(q), ".csv"))
}
