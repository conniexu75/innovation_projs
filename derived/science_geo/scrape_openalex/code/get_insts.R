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


################################### MAIN ###################################
insts <- read_dta('../output/list_of_insts.dta')
nr <- nrow(insts)
split_insts <- split(insts, rep(1:ceiling(nr/5000), each = 5000, length.out=nr))
num_file <- length(split_insts)
for (q in 1:num_file) {
  insts <- oa_fetch(
    entity = "institutions",
    mailto = "xuconni@gmail.com",
    id  = split_insts[[q]] %>%  mutate(inst_id = as.character(inst_id)) %>% pull(inst_id),
    verbose = TRUE,
    output = "list"
  )
  N_insts <- length(insts)
  
  inst_geo <- lapply(1:N_insts, function(i) {
    if (length(insts[[i]][["id"]])!=0) {
      inst_id <- insts[[i]][["id"]] %>% data.frame
    }
    else {
      inst_id <- c("")%>% data.frame
    }
    if (length(insts[[i]][["display_name"]])!=0) {
      inst <-  insts[[i]][["display_name"]] %>% data.frame
    }
    else {
      inst <- c("")%>% data.frame
    }
    if (length(insts[[i]][["country_code"]])!=0) {
      country_code <- insts[[i]][["country_code"]] %>% data.frame
    }
    else {
      country_code <- c("")%>% data.frame
    }
    if (length(insts[[i]][["type"]])!=0) {
      type <- insts[[i]][["type"]] %>% data.frame
    }
    else {
      type <- c("")%>% data.frame
    }
    if (length(insts[[i]][["geo"]][["city"]])!=0) {
      city <- insts[[i]][["geo"]][["city"]]%>% data.frame
    }
    else {
      city <- c("")%>% data.frame
    }
    if (length(insts[[i]][["geo"]][["country"]])!=0) {
      country <- insts[[i]][["geo"]][["country"]]%>% data.frame
    }
    else {
      country <- c("")%>% data.frame
    }
    if (length(insts[[i]][["geo"]][["region"]])!=0) {
      region <- insts[[i]][["geo"]][["region"]]%>% data.frame
    }
    else {
      region <- c("")%>% data.frame
    }
    cbind(inst_id, inst, country_code, country, city, region, type)
  }) %>% bind_rows() 
  
  colnames(inst_geo) <- c("inst_id","inst", "country_code", "country", "city", "region", "type")
  write_dta(inst_geo, paste0("../output/inst_geo_chars", as.character(q), ".dta"))
}
