import os
import math
import pandas as pd
import pyreadstat

# Path to the Stata file
stata_file_path = '../external/pmids/all_pmids.dta'

# Path to the output directory
output_dir = '../temp/'

# Read the Stata file and count the number of observations
df, meta = pyreadstat.read_dta(stata_file_path)
num_observations = len(df)

# Calculate the total number of files needed, rounding up
num_files = math.ceil(num_observations / 5000)

# Generate the expected file numbers
expected_file_numbers = list(range(1, num_files + 1))

# Check for existing files in the output directory
existing_files = os.listdir('../output/')

# Extract the numbers from existing filenames
existing_file_numbers = [int(f.replace('concepts', '').replace('.csv', '')) for f in existing_files if f.startswith('concepts') and f.endswith('.csv')]

# Identify missing file numbers
missing_file_numbers = [num for num in expected_file_numbers if num not in existing_file_numbers]

# Create a DataFrame for the missing file numbers
missing_files_df = pd.DataFrame(missing_file_numbers, columns=['missing_files'])

# Save the missing files to a CSV
missing_files_csv_path = os.path.join(output_dir, 'missing_openalex_authors_files.csv')
missing_files_df.to_csv(missing_files_csv_path, index=False)

print(f"Missing file numbers have been saved to {missing_files_csv_path}")

