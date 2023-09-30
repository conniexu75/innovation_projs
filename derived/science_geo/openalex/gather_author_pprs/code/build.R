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

get_inst_cnt_yr = function(athr_id, year){
  suppressWarnings(
    insts <- oa_fetch(
      entity = "works",
      publication_year = paste0(as.character(year)),
      group_by = "institutions.id",
      mailto = "xuconni@gmail.com",
      author.id = athr_id,
      output = "dataframe"
    ) 
  )
  if(!is.null(insts)){
    inst <- insts %>% filter(key != "unknown")
    nrows <- nrow(insts)
    if (nrows != 0) {
      athr_inst <- insts %>% 
        dplyr::rename(inst_id =  key, 
                      inst = key_display_name,
                      num_pprs = count) %>% 
        mutate(athr_id = athr_id,
               year = year) %>% 
        select(athr_id, year, inst_id, inst, num_pprs)
    } 
    return(athr_inst)
  }
  else {
    return(NULL)
  }
}

athrs <- read_dta('../output/list_of_athrs.dta') 
nr <- nrow(athrs)
split_athr <- split(athrs, rep(1:ceiling(nr/500), each = 500, length.out=nr))
num_file <- length(split_athr)

for (q in 8:100) {
  output <- data.frame(matrix(ncol = 5, nrow = 0))
  x <- c("athr_id", "year", "inst_id", "inst", "num_pprs")
  colnames(output) <- x
  
  output <- lapply(1945:2022, function(yr) {
    yr_output <- sapply(X = split_athr[[q]] %>% pull(athr_id), FUN = get_inst_cnt_yr, year = yr) 
    yr_output <- yr_output[lengths(yr_output)!=0] %>% unname %>% rbindlist
    if(nrow(yr_output)>0) {
      rbind(output, yr_output)
    }
  })
  output <- output[lengths(output)>0]
  output <- output %>% rbindlist
  write_csv(output, paste0("../output/athr_insts", as.character(q), ".csv"))
}
