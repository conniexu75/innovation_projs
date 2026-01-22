library(openalexR) 
library(dplyr) 
library(ggplot2) 
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
set.seed(8975)

#################################### NEWFUND JRNLS  ###################################
# primary_location.source.id  = c("S203860005", "S23254222", "S95323914", "S95464858", "S88935262"),
# qje aer jpe econometrica restud
# S42893225 S158011328" "S170166683" S96919139" S4210174288
# aej applied econ, aej economic plicy, aej macroecon , agej micro, aer insights
#S45992627 S179979277  S165087003 S156003414, S180061323
# economic journla, int econ review, jouranl of eruopean economica sso, quant econ, restat
works <- oa_fetch(
 entity = "works",
 mailto = "conniexu@g.harvard.edu",
 primary_location.source.id  = c("S180061323"),
 output = "list"
)

N_articles <- length(works)
au_ids <- lapply(1:N_articles, function(i) {
 if (length(works[[i]][["authorships"]])!=0) {
   ids <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["id"]]) %>% data.frame
   abstract_len <- replicate(n=length(works[[i]][["authorships"]]), length(works[[i]][["abstract_inverted_index"]])) %>% data.frame
   if (length(works[[i]][["title"]])!=0) {
     title <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["title"]]) %>% data.frame
   }
   if (length(works[[i]][["title"]])==0) {
     title <- replicate(n=length(works[[i]][["authorships"]]), "") %>% data.frame
   }
   if (length(works[[i]][["publication_date"]])!=0) {
     pub_date <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["publication_date"]]) %>% data.frame
   }
   if (length(works[[i]][["publication_date"]])==0) {
     pub_date <- replicate(n=length(works[[i]][["authorships"]]), "") %>% data.frame
   }
   if (length(works[[i]][["is_retracted"]])!=0) {
     retracted <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["is_retracted"]]) %>% data.frame
   }
   if (length(works[[i]][["is_retracted"]])==0) {
     retracted <- replicate(n=length(works[[i]][["authorships"]]), "") %>% data.frame
   }
   if (length(works[[i]][["cited_by_count"]])!=0) {
     cite_count <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["cited_by_count"]]) %>% data.frame
   }
   if (length(works[[i]][["cited_by_count"]])==0) {
     cite_count <- replicate(n=length(works[[i]][["authorships"]]), "") %>% data.frame
   }
   if(length(works[[i]][["type_crossref"]])!=0) {
     pub_type <- replicate(n=length(works[[i]][["authorships"]]), works[[i]][["type_crossref"]]) %>% data.frame
   }
   if(length(works[[i]][["type_crossref"]])==0) {
     pub_type <- replicate(n=length(works[[i]][["authorships"]]), " ") %>% data.frame
   }
   which_athr <- ave(1:length(works[[i]][["authorships"]]), ids, FUN = seq_along) %>% data.frame
   N_athrs <- length(works[[i]][["authorships"]])
   num_affls <- list()
   athr_id <- list()
   raw_affl <- list()
   athr_name <- list()
   num_affls <-  lapply(1:N_athrs, function(j) {
     append(num_affls, length(works[[i]][["authorships"]][[j]][["institutions"]]))
   })  %>% data.frame %>% t()
   athr_id <-  lapply(1:N_athrs, function(j) {
     if (is.null(works[[i]][["authorships"]][[j]][["author"]][["id"]])) {
       append(athr_id, list(c("")))
     }
     else {
       append(athr_id, as.character(works[[i]][["authorships"]][[j]][["author"]][["id"]]))
     }
   })  %>% data.frame %>% t()
   raw_affl <-  lapply(1:N_athrs, function(j) {
     if (is.null(works[[i]][["authorships"]][[j]][["raw_affiliation_string"]][[1]])) {
       append(raw_affl, list(c("")))
     }
     else {
       append(raw_affl, as.character(works[[i]][["authorships"]][[j]][["raw_affiliation_string"]][[1]]))
     }
   })  %>% data.frame %>% t()
   athr_name <-  lapply(1:N_athrs, function(j) {
     if (is.null(works[[i]][["authorships"]][[j]][["author"]][["display_name"]])) {
       append(athr_name, list(c("")))
     }
     else {
       append(athr_name,as.character(works[[i]][["authorships"]][[j]][["author"]][["display_name"]]))
     }
   }) %>% data.frame %>% t()
   cbind(ids, abstract_len, title, pub_date, retracted, cite_count, pub_type, which_athr, athr_id, athr_name, raw_affl, num_affls)
 }
}) %>% bind_rows()
colnames(au_ids) <- c("id","abstract_len", "title","pub_date", "retracted", "cite_count", "pub_type","which_athr","athr_id", "athr_name", "raw_affl", "num_affls")
au_ids <- au_ids %>%
 mutate(num_affls = replace(num_affls, num_affls == 0, 1)) %>%
 uncount(num_affls)
inst <- list()
inst_id <- list()
for(i in 1:N_articles) {
 N_athrs <- length(works[[i]][["authorships"]])
 if (N_athrs!=0) {
 for(j in 1:N_athrs) {
   if (length(works[[i]][["authorships"]][[j]][["institutions"]])!=0){
     for(k in 1:length(works[[i]][["authorships"]][[j]][["institutions"]])) {
       if(length(works[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])!=0) {
         inst<-append(inst, works[[i]][["authorships"]][[j]][["institutions"]][[k]][["display_name"]])
       }
       else {
         inst<-append(inst, list(c("")))
       }
       if(length(works[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])!=0) {
         inst_id<-append(inst_id, works[[i]][["authorships"]][[j]][["institutions"]][[k]][["id"]])
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
write_csv(affl_list, paste0("../output/restat.csv"))
