# Load necessary libraries
library(openalexR)
library(dplyr)
library(purrr)
library(tibble)
library(readr)
library(tidyr)
library(stringr)

# Define the journal IDs and corresponding names
# S110447773 cell
#"S3880285" science

#  "S137773608", "S128124174", "S106963461",
#  "S151741590", "S137905309", "S203256638",
#  "S2298632", "S45757444", "S51309854","S25293849", 

  ##"S140251998","S128439998",
#  "nature", "cell_stem_cell", "nat_biotech",
#  "nat_cell_bio", "nat_genet", "nat_med",
#  "nat_neuro", "neuron", "nat_chem_bio","faseb", "jbc", "oncogene", 
journals <- c(
   "S202381698"
)
journal_names <- c(
  "plos"
)

# Function to process articles
process_article <- function(article) {
  if (length(article[["authorships"]]) == 0) return(NULL)
  
  n_authors <- length(article[["authorships"]])
  
  ids <- rep(as.character(article[["id"]]), n_authors)
  abstract_len <- rep(as.character(length(article[["abstract_inverted_index"]])), n_authors)
  doi <- rep(ifelse(length(article[["doi"]]) != 0, article[["doi"]], ""), n_authors)
  jrnl <- rep(ifelse(length(article[["primary_location"]][["source"]][["display_name"]]) != 0, article[["primary_location"]][["source"]][["display_name"]], ""), n_authors)
  title <- rep(ifelse(length(article[["title"]]) != 0, article[["title"]], ""), n_authors)
  pub_date <- rep(ifelse(length(article[["publication_date"]]) != 0, article[["publication_date"]], ""), n_authors)
  retracted <- rep(as.character(ifelse(length(article[["is_retracted"]]) != 0, article[["is_retracted"]], "")), n_authors)
  cite_count <- rep(as.character(ifelse(length(article[["cited_by_count"]]) != 0, article[["cited_by_count"]], "")), n_authors)
  pub_type <- rep(ifelse(length(article[["type"]]) != 0, article[["type"]], ""), n_authors)
  pub_type_crossref <- rep(ifelse(length(article[["type_crossref"]]) != 0, article[["type_crossref"]], ""), n_authors)
  
  pmid <- rep(ifelse(is.null(article[["ids"]][["pmid"]]), "", as.character(article[["ids"]][["pmid"]])), n_authors)
  
  which_athr <- seq_len(n_authors)
  
  author_data <- map_dfr(article[["authorships"]], function(authorship) {
    athr_id <- ifelse(is.null(authorship[["author"]][["id"]]), "", authorship[["author"]][["id"]])
    athr_pos <- ifelse(is.null(authorship[["author_position"]][[1]]), "", authorship[["author_position"]][[1]])
    raw_affl <- ifelse(is.null(authorship[["raw_affiliation_string"]][[1]]), "", authorship[["raw_affiliation_string"]][[1]])
    athr_name <- ifelse(is.null(authorship[["author"]][["display_name"]]), "", authorship[["author"]][["display_name"]])
    num_affls <- ifelse(is.null(length(authorship[["institutions"]])), 0, length(authorship[["institutions"]]))
    
    tibble(athr_id, athr_pos, raw_affl, athr_name, as.character(num_affls))
  })
  
  # Ensure that all the vectors are of equal length
  if (nrow(author_data) == n_authors) {
    bind_cols(
      tibble(ids, abstract_len, doi, jrnl, title, pub_date, retracted, cite_count, pub_type, pub_type_crossref, pmid, which_athr),
      author_data
    )
  } else {
    return(NULL)
  }
}

# Loop through each journal ID and name
for (i in seq_along(journals)) {
  journal <- journals[i]
  journal_name <- journal_names[i]
  
  # Fetch articles for the current journal
  response <- oa_fetch(
    entity = "works",
    mailto = "conniexu@g.havard.edu",
    from_publication_date = "1945-01-01",
    to_publication_date = "2023-12-31",
    type = "article",
    type_crossref = "journal-article",
    primary_location.source.id = journal,
    output = "list"
  )
  
  # Process articles to get author and affiliation data
  au_ids <- map_dfr(response, process_article)
  colnames(au_ids) <- c("id", "abstract_len", "doi", "jrnl", "title", "pub_date", "retracted", "cite_count", "pub_type", "pub_type_crossref", "pmid", "which_athr", "athr_id", "athr_pos", "raw_affl", "athr_name", "num_affls")
  
  au_ids <- au_ids %>%
    mutate(num_affls = as.numeric(num_affls),
           num_affls = replace(num_affls, num_affls == 0, 1)) %>%
    uncount(num_affls)
  
  inst <- list()
  inst_id <- list()
  
  for (article in response) {
    if (length(article[["authorships"]]) == 0) next
    
    for (authorship in article[["authorships"]]) {
      if (length(authorship[["institutions"]]) == 0) {
        inst <- append(inst, "")
        inst_id <- append(inst_id, "")
      } else {
        for (institution in authorship[["institutions"]]) {
          inst <- append(inst, ifelse(length(institution[["display_name"]]) != 0, institution[["display_name"]], ""))
          inst_id <- append(inst_id, ifelse(length(institution[["id"]]) != 0, institution[["id"]], ""))
        }
      }
    }
  }
  
  affl_data <- tibble(inst = unlist(inst), inst_id = unlist(inst_id))
  
  if (nrow(au_ids) == nrow(affl_data)) {
    affl_list <- au_ids %>%
      mutate(inst = affl_data$inst, inst_id = affl_data$inst_id) %>%
      group_by(id, which_athr) %>%
      mutate(
        which_affl = 1:n(),
        id = str_replace(as.character(id), "https://openalex.org/", ""),
        pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
        athr_id = str_replace(athr_id, "https://openalex.org/", ""),
        inst_id = str_replace(inst_id, "https://openalex.org/", "")
      ) %>%
      ungroup()  # Ungroup to flatten the data structure if necessary
    
    # Write the processed author data to CSV with journal-specific suffix
    write_csv(affl_list, paste0("../output/openalex_authors_", journal_name, ".csv"))
    cat(paste("Affiliation data for", journal_name, "has been successfully exported.\n"))
  } else {
    stop("Mismatch in the number of rows between au_ids and affiliation data. Please check the alignment of inst and inst_id.")
  }
  
  # Extract MeSH terms
  mesh_terms <- map_dfr(response, function(article) {
    if (length(article[["mesh"]]) == 0) return(NULL)
    
    ids <- rep(article[["id"]], length(article[["mesh"]]))
    which_mesh <- seq_along(article[["mesh"]])
    terms <- map_chr(article[["mesh"]], "descriptor_name")
    major_topic <- map_lgl(article[["mesh"]], "is_major_topic")
    qualifier <- map_chr(article[["mesh"]], ~ ifelse(is.null(.x[["qualifier_name"]]), "", .x[["qualifier_name"]]))
    
    tibble(ids, which_mesh, terms, major_topic, qualifier)
  })
  
  colnames(mesh_terms) <- c("id", "which_mesh", "term", "is_major_topic", "qualifier_name")
  
  if (nrow(mesh_terms) != 0) {
    mesh_terms <- mesh_terms %>% mutate(id = str_replace(as.character(id), "https://openalex.org/", ""))
    
    # Write the MeSH terms to CSV with journal-specific suffix
    write_csv(mesh_terms, paste0("../output/mesh_terms_", journal_name, ".csv"))
    cat(paste("MeSH terms for", journal_name, "have been successfully exported.\n"))
  } else {
    cat(paste("No MeSH terms found for", journal_name, ".\n"))
  }
  # Extract concepts
  concepts <- map_dfr(response, function(article) {
    if (length(article[["concepts"]]) == 0) return(NULL)
    
    ids <- rep(article[["id"]], length(article[["concepts"]]))
    which_concept <- seq_along(article[["concepts"]])
    concept_id <- map_chr(article[["concepts"]], "id")
    terms <- map_chr(article[["concepts"]], "display_name")
    level <- map_int(article[["concepts"]], "level")
    score <- map_dbl(article[["concepts"]], "score")
    
    tibble(ids, which_concept, concept_id, terms, level, score)
  })
  
  colnames(concepts) <- c("id", "which_concept", "concept_id", "term", "level", "score")
  
  if (nrow(concepts) != 0) {
    concepts <- concepts %>%
      mutate(
        id = str_replace(as.character(id), "https://openalex.org/", ""),
        concept_id = str_replace(as.character(concept_id), "https://openalex.org/", "")
      )
    
    # Write the concept data to CSV with journal-specific suffix
    write_csv(concepts, paste0("../output/concepts_", journal_name, ".csv"))
    cat(paste("Concept data for", journal_name, "has been successfully exported.\n"))
  } else {
    cat(paste("No concept data found for", journal_name, ".\n"))
  }
}
