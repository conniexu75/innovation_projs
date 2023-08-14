library(openalexR) 
library(dplyr) 
library(ggplot2) 
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
#setwd(here())
set.seed(8975)
#options(openalexR.mailto = "conniexu0@gmail.com")


################################### NEWFUND JRNLS  ###################################
#pmid_file <- read_dta('../output/list_of_pmids_newfund_jrnls.dta')
#nr <- nrow(pmid_file)
#split_pmid <- split(pmid_file, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
#num_file <- length(split_pmid)
#for (q in 54:60) {
#    ## pull open alex data from pmids
#    works_from_pmids <- oa_fetch(
#      entity = "works",
#      mailto = "conniexu0@gmail.com",
#      ids.pmid  = split_pmid[[q]] %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid),
#      verbose = TRUE,
#      output = "list"
#    )
#    ## pull open_alex author ids associated with each author for each paper
#    N_articles <- length(works_from_pmids)
#    au_ids <- lapply(1:N_articles, function(i) {
#      if (length(works_from_pmids[[i]][["authorships"]])!=0) {
#        ids <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
#        pmid <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["ids"]][["pmid"]]) %>% data.frame
#        which_athr <- ave(1:length(works_from_pmids[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
#        N_athrs <- length(works_from_pmids[[i]][["authorships"]])
#        num_affls <- list()
#        athr_id <- list()
#        athr_name <- list()
#        num_affls <-  lapply(1:N_athrs, function(j) {
#          append(num_affls, length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]]))
#        })  %>% data.frame %>% t()
#        athr_id <-  lapply(1:N_athrs, function(j) {
#          if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]])) {
#            append(athr_name, list(c("")))
#          }
#          else {
#            append(athr_id, as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]]))
#          }
#        })  %>% data.frame %>% t()
#        athr_name <-  lapply(1:N_athrs, function(j) {
#          if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]])) {
#            append(athr_name, list(c("")))
#          }
#          else {
#            append(athr_name,as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]]))
#          }
#        }) %>% data.frame %>% t()
#        cbind(ids, pmid, which_athr, athr_id, athr_name, num_affls)
#      }
#    }) %>% bind_rows()
#    colnames(au_ids) <- c("id","pmid","which_athr","athr_id", "athr_name", "num_affls")
#    au_ids <- au_ids %>%  
#      mutate(num_affls = replace(num_affls, num_affls == 0, 1)) %>% 
#      uncount(num_affls)
#    inst <- list()
#    inst_id <- list()
#    for(i in 1:N_articles) {
#      N_athrs <- length(works_from_pmids[[i]][["authorships"]])
#      if (N_athrs!=0) {
#      for(j in 1:N_athrs) {
#        if (length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])!=0){
#          for(k in 1:length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])) {
#            if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])!=0) {
#              inst<-append(inst, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])
#            }
#            else {
#              inst<-append(inst, list(c("")))
#            }
#            if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])!=0) {
#              inst_id<-append(inst_id, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])
#            }
#            else{
#              inst_id<-append(inst_id, list(c("")))
#            }
#          }
#        }
#        else {
#          inst<-append(inst, list(c("")))
#          inst_id<-append(inst_id, list(c("")))
#        }
#      }
#      }
#    }
#    inst <- inst %>% data.frame %>% t()
#    inst_id <- inst_id %>% data.frame %>% t()
#    affl_list <- cbind(au_ids,inst, inst_id) %>% 
#      group_by(id, which_athr) %>% 
#      mutate(which_affl = 1:n(),
#             id = str_replace(id, "https://openalex.org/",""),
#             pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
#             athr_id= str_replace(athr_id, "https://openalex.org/", ""),
#             inst_id = str_replace(inst_id, "https://openalex.org/",""))
#    write_dta(affl_list, paste0("../output/openalex_authors", as.character(q), ".dta"))
#    ## get mesh terms
#    mesh_terms <- lapply(1:N_articles, function(i) {
#      if (length(works_from_pmids[[i]][["mesh"]]) !=0 ) {
#        ids <- replicate(n=length(works_from_pmids[[i]][["mesh"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
#        which_mesh <- ave(1:length(works_from_pmids[[i]][["mesh"]]), ids, FUN = seq_along) %>% data.frame
#        N_mesh <- length(works_from_pmids[[i]][["mesh"]])
#        terms <- list()
#        major_topic <- list()
#        terms <-  lapply(1:N_mesh, function(j) {
#          append(terms, works_from_pmids[[i]][["mesh"]][[j]][["descriptor_name"]])
#        }) %>% data.frame %>% t()
#        major_topic <-  lapply(1:N_mesh, function(j) {
#          append(major_topic, works_from_pmids[[i]][["mesh"]][[j]][["is_major_topic"]])
#        })  %>% data.frame %>% t()
#        cbind(ids, which_mesh, terms, major_topic)
#      }
#    }) %>% bind_rows()
#    colnames(mesh_terms) <- c("id","which_mesh","term", "is_major_topic")
#    mesh_terms <- mesh_terms %>% mutate(id = str_replace(id, "https://openalex.org/",""))
#    write_dta(mesh_terms, paste0("../output/mesh_terms", as.character(q), ".dta"))
#}
#
################################### CLINICAL_MED  ###################################
#pmid_file <- read_dta('../external/pmids/list_of_pmids_clin_med.dta')
#nr <- nrow(pmid_file)
#split_pmid <- split(pmid_file, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
#num_file <- length(split_pmid)
#for (q in 4:num_file) {
#    ## pull open alex data from pmids
#    works_from_pmids <- oa_fetch(
#      entity = "works",
#      mailto = "conniexu75@gmail.com",
#      ids.pmid  = split_pmid[[q]] %>%  mutate(pmid = as.character(pmid)) %>% pull(pmid),
#      verbose = TRUE,
#      output = "list"
#    )
#    ## pull open_alex author ids associated with each author for each paper
#    N_articles <- length(works_from_pmids)
#    au_ids <- lapply(1:N_articles, function(i) {
#      if (length(works_from_pmids[[i]][["authorships"]])!=0) {
#        ids <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
#        pmid <- replicate(n=length(works_from_pmids[[i]][["authorships"]]), works_from_pmids[[i]][["ids"]][["pmid"]]) %>% data.frame
#        which_athr <- ave(1:length(works_from_pmids[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
#        N_athrs <- length(works_from_pmids[[i]][["authorships"]])
#        num_affls <- list()
#        athr_id <- list()
#        athr_name <- list()
#        num_affls <-  lapply(1:N_athrs, function(j) {
#          append(num_affls, length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]]))
#        })  %>% data.frame %>% t()
#        athr_id <-  lapply(1:N_athrs, function(j) {
#          if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]])) {
#            append(athr_name, list(c("")))
#          }
#          else {
#            append(athr_id, as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["id"]]))
#          }
#        })  %>% data.frame %>% t()
#        athr_name <-  lapply(1:N_athrs, function(j) {
#          if (is.null(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]])) {
#            append(athr_name, list(c("")))
#          }
#          else {
#            append(athr_name,as.character(works_from_pmids[[i]][["authorships"]][[j]][["author"]][["display_name"]]))
#          }
#        }) %>% data.frame %>% t()
#        cbind(ids, pmid, which_athr, athr_id, athr_name, num_affls)
#      }
#    }) %>% bind_rows()
#    colnames(au_ids) <- c("id","pmid","which_athr","athr_id", "athr_name", "num_affls")
#    au_ids <- au_ids %>%  
#      mutate(num_affls = replace(num_affls, num_affls == 0, 1)) %>% 
#      uncount(num_affls)
#    inst <- list()
#    inst_id <- list()
#    for(i in 1:N_articles) {
#      N_athrs <- length(works_from_pmids[[i]][["authorships"]])
#      if (N_athrs!=0) {
#      for(j in 1:N_athrs) {
#        if (length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])!=0){
#          for(k in 1:length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]])) {
#            if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])!=0) {
#              inst<-append(inst, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])
#            }
#            else {
#              inst<-append(inst, list(c("")))
#            }
#            if(length(works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])!=0) {
#              inst_id<-append(inst_id, works_from_pmids[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])
#            }
#            else{
#              inst_id<-append(inst_id, list(c("")))
#            }
#          }
#        }
#        else {
#          inst<-append(inst, list(c("")))
#          inst_id<-append(inst_id, list(c("")))
#        }
#      }
#      }
#    }
#    inst <- inst %>% data.frame %>% t()
#    inst_id <- inst_id %>% data.frame %>% t()
#    affl_list <- cbind(au_ids,inst, inst_id) %>% 
#      group_by(id, which_athr) %>% 
#      mutate(which_affl = 1:n(),
#             id = str_replace(id, "https://openalex.org/",""),
#             pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
#             athr_id= str_replace(athr_id, "https://openalex.org/", ""),
#             inst_id = str_replace(inst_id, "https://openalex.org/",""))
#    write_dta(affl_list, paste0("../output/openalex_authors_clin", as.character(q), ".dta"))
#    ## get mesh terms
#    mesh_terms <- lapply(1:N_articles, function(i) {
#      if (length(works_from_pmids[[i]][["mesh"]]) !=0 ) {
#        ids <- replicate(n=length(works_from_pmids[[i]][["mesh"]]), works_from_pmids[[i]][["id"]]) %>% data.frame
#        which_mesh <- ave(1:length(works_from_pmids[[i]][["mesh"]]), ids, FUN = seq_along) %>% data.frame
#        N_mesh <- length(works_from_pmids[[i]][["mesh"]])
#        terms <- list()
#        major_topic <- list()
#        terms <-  lapply(1:N_mesh, function(j) {
#          append(terms, works_from_pmids[[i]][["mesh"]][[j]][["descriptor_name"]])
#        }) %>% data.frame %>% t()
#        major_topic <-  lapply(1:N_mesh, function(j) {
#          append(major_topic, works_from_pmids[[i]][["mesh"]][[j]][["is_major_topic"]])
#        })  %>% data.frame %>% t()
#        cbind(ids, which_mesh, terms, major_topic)
#      }
#    }) %>% bind_rows()
#    colnames(mesh_terms) <- c("id","which_mesh","term", "is_major_topic")
#    mesh_terms <- mesh_terms %>% mutate(id = str_replace(id, "https://openalex.org/",""))
#    write_dta(mesh_terms, paste0("../output/mesh_terms_clin", as.character(q), ".dta"))
#}

# get total articles
#science = "S3880285" 
#nature = "S137773608" 
#cell = "S110447773" 
#onco = "S4306525036"
#jbc = "S140251998"
#neuron = "S45757444"
#nat_genet = "S137905309"
#faseb = "S25293849"
#nat_med = "S203256638"
#nat_biotech = "S106963461"
#nat_neuro = "S2298632"
#nat_cell_bio = "S151741590"
#nat_chem_bio = "S51309854"
#plos = "S202381698"
#cell_stem_cell = "S128124174"
#jrnls <- c(onco)
#for(j in jrnls) {
#  j_articles <- oa_fetch(
#      entity = "works",
#      primary_location.source.id = j,
#      type = "article",
#      type_crossref = "journal-article",
#      verbose = TRUE, 
#      output = "dataframe"
#      )
#   j_articles <- j_articles %>% select(id, display_name, publication_date, publication_year, so) 
#   write_dta(j_articles, paste0("../output/",j , "_all.dta"))
#}
