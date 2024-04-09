library(openalexR) 
library(dplyr) 
library(ggplot2) 
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
library(data.table)
set.seed(8975)
athrs <- read_dta("../output/list_of_clin_athrs.dta")
nr <- nrow(athrs)
split_athr <- split(athrs, rep(1:ceiling(nr/500), each = 500, length.out=nr))
num_file <- length(split_athr)
# 450
for (q in 324:350) {
print(q)
    works <- oa_fetch(
        entity = "works", 
        mailto = "conniexu@g.harvard.edu", 
        author.id = split_athr[[q]] %>% pull(athr_id),
        output = "list"
    )
    N_articles <- length(works)
    output <- lapply(1:N_articles, function(i) {
        ids <- works[[i]][["id"]] %>% data.frame
    })
    output <- output %>% bind_rows() %>% distinct() %>% data.frame
    write_csv(output, paste0("../output/clin_works", as.character(q), ".csv"))
}
