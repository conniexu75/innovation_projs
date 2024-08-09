library(openalexR) 
library(dplyr) 
library(ggplot2) 
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
set.seed(8975)

pmid_file <- read_dta('../external/pmids/all_pmids.dta')
nr <- nrow(pmid_file)
split_pmid <- split(pmid_file, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
num_file <- length(split_pmid)
for (q in 1:50) {
   ## pull open alex data from pmids
   works_from_pmids <- oa_fetch(
     entity = "works",
     mailto = "conniexu@g.harvard.edu",
     ids.pmid  = split_pmid[[q]] %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid),
     output = "list"
   )
   ## pull open_alex author ids associated with each author for each paper
   N_articles <- length(works_from_pmids)
   au_ids <- lapply(1:N_articles, function(i) {
     if (length(works_from_pmids[[i]][["authorships"]])!=0) {
       ids <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
       abstract_len <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), length(works_from_pmids[[i]][["abstract_inverted_index"]])) %>% data.frame
       if (length(works_from_pmids[[i]][["doi"]])!=0) {
         doi <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["doi"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["doi"]])==0) {
         doi <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["primary_location"]][["source"]][["display_name"]])!=0) {
         jrnl <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["primary_location"]][["source"]][["display_name"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["primary_location"]][["source"]][["display_name"]])==0) {
         jrnl <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["title"]])!=0) {
         title <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["title"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["title"]])==0) {
         title <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["publication_date"]])!=0) {
         pub_date <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["publication_date"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["publication_date"]])==0) {
         pub_date <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["is_retracted"]])!=0) {
         retracted <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["is_retracted"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["is_retracted"]])==0) {
         retracted <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["cited_by_count"]])!=0) {
         cite_count <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["cited_by_count"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["cited_by_count"]])==0) {
         cite_count <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["type"]])!=0) {
         pub_type <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["type"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["type"]])==0) {
         pub_type <- replicate(n=length(works_from_pmids[[i]][["type"]]), "") %>% data.frame
       }
       if (length(works_from_pmids[[i]][["type_crossref"]])!=0) {
         pub_type_crossref <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["type_crossref"]]) %>% data.frame
       }
       if (length(works_from_pmids[[i]][["type_crossref"]])==0) {
         pub_type_crossref <- replicate(n=length(works_from_pmids[[i]][["type_crossref"]]), "") %>% data.frame
       }
       pmid <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["ids"]][["pmid"]]) %>% data.frame
       which_athr <- ave(1:length(works_from_pmids[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
       N_athrs <- length(works_from_pmids[[i]][["authorships"]])
       num_affls <- list()
       athr_id <- list()
       athr_pos <- list()
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
       athr_pos <-  lapply(1:N_athrs, function(j) {
         if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author_position"]][[1]])) {
           append(athr_pos, list(c("")))
         }
         else {
           append(athr_pos, as.character(works_from_pmids[[i]][["authorships"]][[j]][["author_position"]][[1]]))
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
       cbind(ids, abstract_len, doi, jrnl, title, pub_date, retracted, cite_count, pub_type,pub_type_crossref, pmid, which_athr, athr_id, athr_pos, athr_name, raw_affl, num_affls)
     }
   }) %>% bind_rows()
   colnames(au_ids) <- c("id","abstract_len", "doi", "jrnl", "title","pub_date", "retracted", "cite_count", "pub_type", "pub_type_crossref", "pmid","which_athr","athr_id","athr_pos", "athr_name", "raw_affl", "num_affls")
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
            pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
            athr_id= str_replace(athr_id, "https://openalex.org/", ""),
            inst_id = str_replace(inst_id, "https://openalex.org/",""))
   write_csv(affl_list, paste0("../output/openalex_authors", as.character(q), ".csv"))
   ## get mesh terms
   mesh_terms <- lapply(1:N_articles, function(i) {
     if (length(works_from_pmids[[i]][["mesh"]]) !=0 ) {
       ids <- replicate(n=length(works_from_pmids[[i]][["mesh"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
       which_mesh <- ave(1:length(works_from_pmids[[i]][["mesh"]]), ids, FUN = seq_along) %>% data.frame
       N_mesh <- length(works_from_pmids[[i]][["mesh"]])
       terms <- list()
       major_topic <- list()
       qualifier <- list()
       terms <-  lapply(1:N_mesh, function(j) {
         append(terms, works_from_pmids[[i]][["mesh"]][[j]][["descriptor_name"]])
       }) %>% data.frame %>% t()
       major_topic <-  lapply(1:N_mesh, function(j) {
         append(major_topic, works_from_pmids[[i]][["mesh"]][[j]][["is_major_topic"]])
       })  %>% data.frame %>% t()
       qualifier <-  lapply(1:N_mesh, function(j) {
           if (is.null(works_from_pmids[[i]][["mesh"]][[j]][["qualifier_name"]])) {
             append(qualifier, list(c("")))
           }
           else {
               append(qualifier, works_from_pmids[[i]][["mesh"]][[j]][["qualifier_name"]])
           }
       }) %>% data.frame %>% t()
      cbind(ids, which_mesh, terms, major_topic, qualifier)
     }
   }) %>% bind_rows()
   colnames(mesh_terms) <- c("id","which_mesh","term", "is_major_topic", "qualifier_name")
   if(nrow(mesh_terms)!=0) {
     mesh_terms <- mesh_terms %>% mutate(id = str_replace(as.character(id), "https://openalex.org/",""))
     write_csv(mesh_terms, paste0("../output/mesh_terms", as.character(q), ".csv"))
   }
   # get concepts
   concepts <- lapply(1:N_articles, function(i) {
     if (length(works_from_pmids[[i]][["concepts"]]) !=0 ) {
       ids <- replicate(n=length(works_from_pmids[[i]][["concepts"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
       which_concept <- ave(1:length(works_from_pmids[[i]][["concepts"]]), ids, FUN = seq_along) %>% data.frame
       N_concept <- length(works_from_pmids[[i]][["concepts"]])
       concept_id <- list()
       terms <- list()
       level <- list()
       score <- list()
       concept_id <-  lapply(1:N_concept, function(j) {
         append(terms, works_from_pmids[[i]][["concepts"]][[j]][["id"]])
       }) %>% data.frame %>% t()
       terms <-  lapply(1:N_concept, function(j) {
         append(terms, works_from_pmids[[i]][["concepts"]][[j]][["display_name"]])
       }) %>% data.frame %>% t()
       level <-  lapply(1:N_concept, function(j) {
         append(level, works_from_pmids[[i]][["concepts"]][[j]][["level"]])
       })  %>% data.frame %>% t()
       score <-  lapply(1:N_concept, function(j) {
         append(score, works_from_pmids[[i]][["concepts"]][[j]][["score"]])
       })  %>% data.frame %>% t()
       cbind(ids, which_concept, concept_id, terms, level, score)
     }
   }) %>% bind_rows()
   colnames(concepts) <- c("id","which_concept", "concept_id", "term", "level", "score")
   if(nrow(concepts)!=0) {
       concepts <- concepts %>% mutate(id = str_replace(as.character(id), "https://openalex.org/",""), 
                                      concept_id = str_replace(as.character(concept_id), "https://openalex.org/","" ))
       write_csv(concepts, paste0("../output/concepts", as.character(q), ".csv"))
   }
}

