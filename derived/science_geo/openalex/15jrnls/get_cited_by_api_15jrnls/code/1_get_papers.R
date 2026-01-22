library(purrr)
library(openalexR)
library(haven)
library(tidyverse)
library(data.table)

set.seed(8975)

# Read the Stata file
pprs <- read_dta("../external/pprs/list_of_works_15jrnls.dta")
nr <- nrow(pprs)

# Split the data into chunks of 5000 rows each
split_ppr <- split(pprs, rep(1:ceiling(nr / 5000), each = 5000, length.out = nr))
num_file <- length(split_ppr)

# Process each chunk
for (q in 7001:8000) {
  print(q)
  
  # Fetch works using OpenAlex API for the current chunk
  works <- oa_fetch(
    entity = "works",
    mailto = "conniexu@g.harvard.edu",
    paging = "cursor",
    id = split_ppr[[q]] %>% filter(id != "id") %>% pull(id),
    output = "list"
  )
  
  # Number of articles fetched
  N_articles <- length(works)
  
  # Extract IDs and cited_by_api_urls
  output <- lapply(1:N_articles, function(i) {
    ids <- works[[i]][["id"]] 
    url <- works[[i]][["cited_by_api_url"]] 
    
    # Remove 'https://openalex.org/' from the IDs
    clean_ids <- str_remove(ids, "https://openalex.org/")
    
    # Return a data frame with id and urls columns
    data.frame(id = clean_ids, urls = url, stringsAsFactors = FALSE)
  })
  
  # Combine the results into a single data frame and remove duplicates
  output <- output %>% bind_rows() %>% distinct()
  
  # Save the results to a CSV file with headers
  write_csv(output, paste0("../output/urls", as.character(q), ".csv"))
  
  print(sprintf("Chunk %d processed and saved to %s", q, paste0("../output/urls", as.character(q), ".csv")))
}
