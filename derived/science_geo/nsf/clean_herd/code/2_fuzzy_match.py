import os
import pandas as pd
import numpy as np
from fuzzywuzzy import process, fuzz
import us
# load Stata files into Dataframes
openalex_inst = pd.read_stata('../temp/openalex_inst.dta')
inst_names = pd.read_stata('../temp/inst_names.dta')


def convert_state_to_abbr(full_name):
    if full_name == "District of Columbia":
        return "DC"
    elif full_name == "Virgin Islands, U.S.":
        return "VI"
    state = us.states.lookup(full_name)
    return state.abbr if state else full_name

def preprocess_text(df, column_name):
    df[column_name] = df[column_name].str.lower()
    df[column_name] = df[column_name].str.replace(', the', '', case=False, regex=True)
    df[column_name] = df[column_name].str.replace(' university system ', '', case=False, regex=True)
    df[column_name] = df[column_name].str.replace('state university of new york', 'SUNY', case=False, regex=True)
    df[column_name] = df[column_name].str.replace('univ.', 'university', regex=False)
    df[column_name] = df[column_name].str.replace('coll.', 'college', regex=False)
    df[column_name] = df[column_name].str.replace(' main campus', '', regex=False)
    df[column_name] = df[column_name].str.replace(' campus', '', regex=False)
    df[column_name] = df[column_name].str.replace(' system office', '', regex=False)
    df[column_name] = df[column_name].str.replace('college', 'university', case=False, regex=True)
    df[column_name] = df[column_name].str.strip()
    return df

# Apply preprocessing to institution names, cities, and states
openalex_inst['state'] = openalex_inst['state'].apply(convert_state_to_abbr)
openalex_inst = preprocess_text(openalex_inst, 'inst')
openalex_inst = preprocess_text(openalex_inst, 'city')
openalex_inst = preprocess_text(openalex_inst, 'state')
inst_names = preprocess_text(inst_names, 'inst_name_long')
inst_names = preprocess_text(inst_names, 'inst_city')
inst_names = preprocess_text(inst_names, 'inst_state_code')

def combined_fuzzy_matching_name_state(inst_names_df, openalex_inst_df):
    potential_matches = []  # Store potential matches with scores
    # Iterate over inst_names to find matches in openalex_inst
    for idx, row in inst_names_df.iterrows():
        for oa_idx, oa_row in openalex_inst_df.iterrows():
            # Ensure state match before proceeding
            if row['inst_state_code'] == oa_row['state']:
                name_score = fuzz.WRatio(row['inst_name_long'], oa_row['inst'])
                # Directly use name score since city component is removed
                if name_score >= 90:
                    potential_matches.append({
                        'inst_name_idx': idx,
                        'oa_inst_idx': oa_idx,
                        'name_score': name_score,  # Using only name score
                        'oa_inst_name': oa_row['inst']  # Store the openalex_inst name for the match
                    })
    # Sort potential matches by name score to prioritize higher scores
    potential_matches.sort(key=lambda x: x['name_score'], reverse=True)
    matched_oa_inst_ids = set()
    matched_inst_names_idxs = set()
    # Assign matches ensuring no openalex_inst is matched more than once
    for match in potential_matches:
        oa_inst_idx = match['oa_inst_idx']
        inst_name_idx = match['inst_name_idx']
        if oa_inst_idx not in matched_oa_inst_ids:
            inst_names_df.at[inst_name_idx, 'matched_oa_inst_id'] = openalex_inst_df.iloc[oa_inst_idx]['oa_inst_id']
            inst_names_df.at[inst_name_idx, 'matched_oa_inst_name'] = match['oa_inst_name']
            inst_names_df.at[inst_name_idx, 'match_score'] = match['name_score']
            matched_oa_inst_ids.add(oa_inst_idx)
            matched_inst_names_idxs.add(inst_name_idx)  # Ensure this line gets matched only once
    # Mark unmatched entries
    inst_names_df['matched_oa_inst_id'].fillna(value='No Match', inplace=True)
    inst_names_df['matched_oa_inst_name'].fillna(value='No Match', inplace=True)
    inst_names_df['match_score'].fillna(value=0, inplace=True)
    return inst_names_df

# Apply the updated matching function
inst_names_matched_name_state = combined_fuzzy_matching_name_state(inst_names, openalex_inst)

# Export the matched DataFrame to a CSV file
inst_names_matched_name_state.to_csv('inst_names_matched_name_state.csv', encoding='utf-8', index=False)
