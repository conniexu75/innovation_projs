import pyalex
from pyalex import Works, Authors, Sources, Institutions, Concepts, Publishers, Funders
import numpy as np
import pandas as pd
from itertools import chain
pyalex.config.api_key = "conniexu@g.harvard.edu"
pyalex.config.email= "conniexu@g.harvard.edu"

pmid_file = pd.read_stata('../temp/pmids.dta')
chunk_size = 50
print(len(pmid_file))

for i in range(0,len(pmid_file), chunk_size):
    print(i)
    chunk = pmid_file.iloc[i:i+chunk_size]
    query = ""
    for index, row in chunk.iterrows():
        row_str = "|".join(row.astype(str))
        query += row_str + "|"
    query = query[:-1]
    ids = []
    abstract = []
    output = Works().filter(pmid=query)
    for item in chain(*output.paginate(per_page=200)):
        ids.append(item["id"])
        abstract.append(item['abstract'])
    df = pd.DataFrame({'id': ids, 'abstract': abstract})
    file_path = "../output/abstract" + str(i) + "_" + str(i+chunk_size) + ".csv"
    df.to_csv(file_path, index=False)
