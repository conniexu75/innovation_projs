import pyalex
pyalex.config.api_key = "<conniexu@g.harvard.edu>"
from pyalex import Works
from itertools import chain
import pandas as pd

# Define your chunk size
chunk_size = 500  # Replace with your actual chunk size
id_file = pd.read_stata('../external/pprs/list_of_works_15jrnls.dta')  # Replace with your actual file path

# Loop through the file in chunks
for i in range(0, len(id_file), chunk_size):
    print(f"Processing chunk: {i} to {i + chunk_size}")
    chunk = id_file.iloc[i:i + chunk_size]

    # Prepare the query string for the chunk
    query = ""
    for index, row in chunk.iterrows():
        row_str = "|".join(row.astype(str))
        query += row_str + "|"
    query = query[:-1]  # Remove the trailing '|'

    # Initialize lists to hold IDs and cited_by_api_url
    ids = []
    cited_by_urls = []

    # Fetch data from OpenAlex API
    output = Works().filter(openalex_id=query)
    for item in chain(*output.paginate(per_page=200)):
        ids.append(item["id"])
        cited_by_urls.append(item.get('cited_by_api_url', 'URL not available'))  # Extract cited_by_api_url

    # Create a DataFrame with the results
    df = pd.DataFrame({'id': ids, 'cited_by_api_url': cited_by_urls})

    # Save the DataFrame to a CSV file
    file_path = f"../output/cited_by_url_{i}_{i + chunk_size}.csv"
    df.to_csv(file_path, index=False)
    print(f"Chunk {i} to {i + chunk_size} processed and saved to {file_path}")
