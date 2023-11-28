import pyalex
from pyalex import Works, Authors, Sources, Institutions, Concepts, Publishers, Funders
import os
import numpy as np
import pandas as pd
from itertools import chain
pyalex.config.api_key = "conniexu@g.harvard.edu"
pyalex.config.email= "conniexu@g.harvard.edu"


folder_path = "../external/abstracts"

combined_data = pd.DataFrame()

for filename in os.listdir(folder_path):
    if filename.endswith('.csv'):
        file_path = os.path.join(folder_path, filename)
        df = pd.read_csv(file_path)
        combined_data=pd.concat([combined_data,df],ignore_index=True)
combined_data.to_csv("../output/combined_abstracts.csv", index=False)

