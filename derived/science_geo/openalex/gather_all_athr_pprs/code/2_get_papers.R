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
athrs <- read_dta("../output/list_of_athrs.dta")
nr <- nrow(athrs)
split_athr <- split(athrs, rep(1:ceiling(nr/500), each = 500, length.out=nr))
num_file <- length(split_athr)
for (q in 6403:6403) {
print(q)
    works <- oa_fetch(
        entity = "works", 
        mailto = "conniexu@g.harvard.edu", 
        author.id = split_athr[[q]] %>% filter(athr_id != "A9999999999") %>% pull(athr_id),
        output = "list"
    )
    N_articles <- length(works)
    output <- lapply(1:N_articles, function(i) {
        ids <- works[[i]][["id"]] %>% data.frame
    })
    output <- output %>% bind_rows() %>% distinct() %>% data.frame
    write_csv(output, paste0("/export/scratch/cxu_sci_geo/gather_all_athr_pprs/works", as.character(q), ".csv"))
}
