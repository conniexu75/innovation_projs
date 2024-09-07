import pyalex
from pyalex import Works, Authors, Sources, Institutions, Concepts, Publishers, Funders
import os
import pandas as pd
import numpy as np
import re
import string
import nltk
import random
from nltk.corpus import stopwords
from nltk.stem import PorterStemmer
from nltk.stem import WordNetLemmatizer
from nltk.corpus import wordnet
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from gensim.models import Word2Vec

nltk.download("stopwords")
nltk.download("punkt")
nltk.download('wordnet')

SEED = 42
random.seed(SEED)
os.environ["PYTHONHASHSEED"] = str(SEED)
np.random.seed(SEED)

pyalex.config.api_key = "conniexu@g.harvard.edu"
pyalex.config.email= "conniexu@g.harvard.edu"

# Initialize NLTK stemmer and custom stopwords
stemmer = PorterStemmer()
nltk_stopwords = set(stopwords.words("english"))
additional_stopwords = ["patients", "risk", "clinical", "study", "associated", "levels", "significant", "significantly", "analysis", "compared", "age", "results", "study", "risk", "data", "using", "methods", "google", "febs", "scholar", "pubmed", "scopus", "text", "mm", "use", "min", "max", "mice", "activity", "effects", "abstract", "aim", "background", "conclusion", "data", "discussion", "materials", "objective", "patient", "patients", "table", "figure", "model", "models", "patient", "research", "sample", "samples", "studies", "experiment", "experiments", "hypothesis", "treated", "sugesting" , "new", "pdf", "role", "sci", "science", "shows", "shown", "showed", "test", "tested", "unique", "treatment", "underlying", "values", "value", "work", "understanding", "reported", "investigate", "investigated", "invovled", "mean", "natl", "nature", "normal", "novel", "occur", "obtained", "occurs", "overall", "particular", "possibility", "able", "according", "acade", "additional", "affect", "affected", "effect", "effected", "approach", "applied", "assess", "assessed", "based", "association", "combined", "cause", "cased", "carried", "causes", "characteristics", "characterized", "comparison", "completely", "include", "differences", "following", "followed", "forms", "furthermore", "include", "included", "including", "indicate", "indicates", "indicated","indicated", "expected", "expressing", "examine", "evidence", "end", "difference", "differences", "difference", "differentiation", "considered", "consistent", "contain", "contained", "containing", "contains", "contribute", "corresponding", "ml" , "nm", "mold", "multiple", "greater", "group", "impact", "ii", "likely", "pdf", "previously", "present", "presented", "previous", "previously", "proc", "res", "sci", "ph", "μg", "μgml", "μl", "μm", "show" , "upon", "us", "thus", "time", "times", "two", "type", "variety", "various", "used", "via", "wereas", "whether", "would", "without", "would", "yet", "set", "show", "since", "similar", "similarly", "six", "sufficient", "still", "state", "suggest", "suggests", "suggesting", "suggested", "support", "supplmeneted", "necessary", "per", "like", "often", "one", "onto", "observed", "observations", "studied", "years", "recently", "recent", "total", "together", "well", "wereas", "therefore", "low", "lower", "may", "image"]
greek_and_numbers = re.compile(r'[Α-Ωα-ω0-9]+', re.UNICODE)
additional_stopwords += list(filter(greek_and_numbers.match, nltk_stopwords))
additional_stopwords = set(additional_stopwords)
custom_stopwords = nltk_stopwords.union(additional_stopwords)


# load data
abstracts = pd.read_csv("../output/combined_abstracts.csv")
abstracts["id"]=abstracts["id"].str.replace("https://openalex.org/","")
abstracts = abstracts.dropna()
cleaned_samp = pd.read_stata("../external/samp/cleaned_all_15jrnls.dta")
athr_id = cleaned_samp[["id", "athr_id", "year"]].drop_duplicates()
titles = cleaned_samp[["id","title"]].drop_duplicates()

# Define functions for text preprocessing
def clean_text(text):
    text = text.lower()
    text = re.sub(r"\([^)]*\)", "", text)
    text = re.sub(r"[.,;:]", "", text)
    text = re.sub(r"[^\w\s]", "_", text)
    text = re.sub(r"_+", "_", text)
    text = re.sub(r"\s+", " ", text)
    text = text.strip()
    return text

def tokenize(text, stopwords):
    text = str(text).lower()
    text = re.sub(r"\[(.*?)\]", "", text)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\w+…|…", "", text)
    text = re.sub(r"(?<=\w)-(?=\w)", " ", text)
    text = re.sub(f"[{re.escape(string.punctuation)}]", "", text)
    tokens = text.split()
    tokens = [t for t in tokens if not t in stopwords]
    tokens = ["" if t.isdigit() else t for t in tokens]
    tokens = [t for t in tokens if len(t) > 1]
    return tokens

def stem_text(text):
    if pd.notna(text):
        words = nltk.word_tokenize(text)  
        stemmed_words = [stemmer.stem(word) for word in words]
        return " ".join(stemmed_words)
    else:
        return ""

def stem_text_element(element):
    if pd.notna(element):
        return stem_text(element)
    else:
        return ""

# Clean and preprocess titles and abstracts
titles["clean_title"] = titles["title"].apply(clean_text)
abstracts["cleaned_abstract"] = abstracts["abstract"].apply(clean_text)
titles["cleaned_titles"] = titles["clean_title"].map(lambda x: tokenize(x, custom_stopwords))
abstracts["cleaned_abstracts"] = abstracts["cleaned_abstract"].map(lambda x: tokenize(x, custom_stopwords))

# Load and preprocess mesh and qualifier data
mesh_terms = pd.read_stata("../external/samp/contracted_gen_mesh_15jrnls.dta")
qual_terms = mesh_terms[["id", "qualifier_name"]].drop_duplicates()
qual_terms["which_qual"]=qual_terms.groupby(["id"]).cumcount()+1
qual_terms["qualifier_name"]=qual_terms["qualifier_name"].apply(clean_text).str.replace(r'\s+_+\s+', '_', regex=True)
qual_terms = pd.pivot(qual_terms, index = "id", columns = "which_qual", values = "qualifier_name")
qual_terms["qualifier"] = qual_terms.apply(lambda row: " ".join(row.dropna()), axis=1)
concatenated_values = []
column_names = [i for i in range(1, 10)]
for index, row in qual_terms.iterrows():
    values = [str(row[col]) for col in column_names if not pd.isna(row[col])]
    concatenated_values.append(" ".join(values))
qual_terms['qualifier'] = concatenated_values
qual_terms.drop(columns=column_names, inplace=True)

mesh_terms = mesh_terms[["id", "gen_mesh"]].drop_duplicates()
mesh_terms["which_mesh"] = mesh_terms.groupby(["id"]).cumcount() + 1
mesh_terms["gen_mesh"] = mesh_terms["gen_mesh"].apply(clean_text).str.replace(r"\s+_+\s+", "_", regex=True).str.replace(" ", "_")
mesh_terms = pd.pivot(mesh_terms, index="id", columns="which_mesh", values="gen_mesh")
mesh_terms["mesh"] = mesh_terms.apply(lambda row: " ".join(row.dropna()), axis=1)
mesh_terms["mesh"] = mesh_terms["mesh"].str.lower()
concatenated_values = []
column_names = [i for i in range(1, 19)]
for index, row in mesh_terms.iterrows():
    values = [str(row[col]) for col in column_names if not pd.isna(row[col])]
    concatenated_values.append(" ".join(values))
mesh_terms['mesh'] = concatenated_values
mesh_terms['mesh'] = mesh_terms['mesh'].str.lower()
mesh_terms.drop(columns=column_names, inplace=True)


cleaned_abstract =  abstracts[["id","cleaned_abstracts"]]
cleaned_titles = titles[["id", "cleaned_titles"]]

merged = pd.merge(qual_terms, mesh_terms, on='id', how='inner')
merged = pd.merge(merged, cleaned_titles, on='id', how='left')
merged = pd.merge(cleaned_abstract, merged, on = 'id', how='outer')
athr_data = pd.merge(merged, athr_id, on ='id', how = 'left')
athr_data.dropna(how='all', inplace=True)

# Combine text data into a new 'text' column, excluding NaN values
def concatenate_tokens(tokens):
    if isinstance(tokens, list):  # Check if 'tokens' is not NaN
        return ' '.join(tokens)
    else:
        return tokens

athr_data['cleaned_abstracts']=athr_data['cleaned_abstracts'].apply(concatenate_tokens)
athr_data['cleaned_titles']=athr_data['cleaned_titles'].apply(concatenate_tokens)
# Fill NaN values with empty strings for the specified columns
columns_to_fillna = ['mesh', 'qualifier', 'cleaned_titles', 'cleaned_abstracts']
athr_data[columns_to_fillna] = athr_data[columns_to_fillna].fillna('')
athr_data['text1'] = athr_data[['mesh']].apply(lambda x: ' '.join(x.dropna()), axis=1)
athr_data['text2'] = athr_data[[ 'qualifier', 'mesh']].apply(lambda x: ' '.join(x.dropna()), axis=1)
athr_data['text3'] = athr_data[[ 'qualifier', 'mesh', 'cleaned_titles']].apply(lambda x: ' '.join(x.dropna()), axis=1)
athr_data['text4'] = athr_data[[ 'cleaned_abstracts', 'qualifier', 'mesh', 'cleaned_titles']].apply(lambda x: ' '.join(x.dropna()), axis=1)

# stem version
columns_to_stem = ['mesh', 'qualifier', 'cleaned_titles', 'cleaned_abstracts']
for column in columns_to_stem:
    athr_data[column] = athr_data[column].apply(stem_text_element)

for text_column in ['text1', 'text2', 'text3', 'text4']:
    result_df = pd.DataFrame(columns=['athr_id', 'year', 'cluster_name'])
    selected_data = athr_data[['athr_id', 'year', text_column]]
    collapsed_data = selected_data.groupby(['athr_id', 'year'])[text_column].apply(lambda x: ' '.join(x)).reset_index()
    max_df = 1.0 if text_column in ['text1', 'text2'] else 0.90
    min_df = 0.01 if text_column in ['text1', 'text2'] else 0.02
    tfidf_vectorizer = TfidfVectorizer(stop_words=custom_stopwords, max_df=max_df, min_df=min_df, token_pattern = r"(?u)\S\S+")
    tfidf_matrix = tfidf_vectorizer.fit_transform(collapsed_data[text_column])
    kmeans = KMeans(n_clusters=5, random_state=42,init='k-means++')
    kmeans.fit(tfidf_matrix)
    collapsed_data['cluster_label'] = kmeans.labels_
    result_df = pd.concat([result_df, collapsed_data[['athr_id', 'year', 'cluster_label']]], ignore_index=True)
    file  = "../output/" + str(text_column) + ".csv"
    result_df.to_csv(file, index = False)
    cluster_centers = kmeans.cluster_centers_
    terms = tfidf_vectorizer.get_feature_names_out()
    top_15_terms_list = []
    for i, center in enumerate(cluster_centers):
       top_15_terms_idx = center.argsort()[-15:][::-1]
       top_15_terms = [terms[idx] for idx in top_15_terms_idx]
       top_15_terms_list.append(f"Cluster {i + 1} - Top 15 Terms: {', '.join(top_15_terms)}")
    with open(f'{text_column}.txt', 'w') as txt_file:
       txt_file.write('\n'.join(top_15_terms_list))
