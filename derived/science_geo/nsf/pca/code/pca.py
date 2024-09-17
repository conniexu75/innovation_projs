import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.impute import SimpleImputer
import matplotlib.pyplot as plt


# load Stata files into Dataframes
herd = pd.read_stata('../external/herd/collapse_herd_2010_2022.dta')

X_continuous = herd[['applied_expend','applied_fed_expend','basic_expend','basic_fed_expend','clin_trial_expend','contracts_fund','dev_expend','expend_capital','expend_fed','expend_nonfed','expend_salaries','fed_ls_bio_fund','fed_ls_fund','fed_ls_hs_fund','grants_fund','hhs_ls_bio_fund','hhs_ls_fund','hhs_ls_hs_fund','ls_cap_expend','med_sch_expend','nonfed_ls_bio_fund','nonfed_ls_fund','nonfed_ls_hs_fund','subrecipient_fund','subrecipient_sent','tot_bus_fund','tot_fed_fund','tot_fund','tot_inst_fund','tot_nonprof_fund','tot_state_fund','ls_fund','hs_fund','bio_fund']]
X_proportion = herd[['perc_expend_basic','perc_basic_fed','perc_fed_fund_ls','perc_hhs_fund_ls','perc_sal','perc_cap','perc_ls_cap','perc_ls_biohs']]

# Impute missing values
imputer_continuous = SimpleImputer(strategy='mean')
X_continuous_imputed = imputer_continuous.fit_transform(X_continuous)

imputer_proportion = SimpleImputer(strategy='median')
X_proportion_imputed = imputer_proportion.fit_transform(X_proportion)

# Standardize the features
scaler = StandardScaler()
X_continuous_scaled = scaler.fit_transform(X_continuous_imputed)
X_proportion_scaled = scaler.fit_transform(X_proportion_imputed)

# Combine scaled data
X_combined = np.concatenate([X_continuous_scaled, X_proportion_scaled], axis=1)

# Apply PCA
pca = PCA(n_components=0.95)  # Retain 95% of the variance
X_pca = pca.fit_transform(X_combined)
explained_variance = pca.explained_variance_ratio_
weighted_components = X_pca * explained_variance
RnD_index_variance_weighted = weighted_components.sum(axis=1)

# Check the number of components and explained variance
print("Number of components:", pca.n_components_)
print("Explained variance ratio:", pca.explained_variance_ratio_.sum())

# Access the PCA components (loadings of each feature)
loadings = pca.components_

# Create a DataFrame to make it easier to inspect
loadings_df = pd.DataFrame(loadings, columns=X_continuous.columns.tolist() + X_proportion.columns.tolist())


print(loadings_df)

plt.figure(figsize=(10, 6))
plt.plot(range(1, len(pca.explained_variance_ratio_) + 1), pca.explained_variance_ratio_, marker='o', linestyle='--')
plt.title('Scree Plot')
plt.xlabel('Number of Components')
plt.ylabel('Explained Variance Ratio')
plt.xticks(range(1, len(pca.explained_variance_ratio_) + 1))  # Ensure x-axis labels are integers
plt.savefig('../output/scree_plot.pdf')
plt.close() 

cumulative_variance = np.cumsum(pca.explained_variance_ratio_)
plt.figure(figsize=(10, 6))
plt.plot(range(1, len(cumulative_variance) + 1), cumulative_variance, marker='o', linestyle='-')
plt.title('Cumulative Explained Variance')
plt.xlabel('Number of Components')
plt.ylabel('Cumulative Explained Variance Ratio')
plt.axhline(y=0.95, color='r', linestyle='--')  # Line to indicate the 95% threshold
plt.xticks(range(1, len(pca.explained_variance_ratio_) + 1))
plt.savefig('../output/cum_var.pdf')
plt.close() 

import seaborn as sns

# Assuming 'loadings_df' is a DataFrame with the PCA loadings
plt.figure(figsize=(12, 6))
sns.heatmap(loadings_df.iloc[:15, :].T, cmap='viridis', center=0)  # Transpose for better readability
plt.title('PCA Component Loadings Heatmap')
plt.xlabel('Principal Component')
plt.ylabel('Features')
plt.savefig('../output/heatmap.pdf')
plt.close() 

plt.figure(figsize=(10, 8))
plt.scatter(X_pca[:, 0], X_pca[:, 1], alpha=0.5)  # Plot the PCA-transformed data
for i, feature in enumerate(loadings_df.columns):
    plt.arrow(0, 0, loadings_df.iloc[0, i], loadings_df.iloc[1, i], color='r', alpha=0.5)
    plt.text(loadings_df.iloc[0, i] * 1.15, loadings_df.iloc[1, i] * 1.15, feature, color='g', ha='center', va='center')
plt.xlabel('PC1')
plt.ylabel('PC2')
plt.title('PCA Biplot')
plt.grid(True)
plt.savefig('../output/biplot.pdf')
plt.close()


herd['rd_index']=RnD_index_variance_weighted

plt.figure(figsize=(10, 6))
sns.histplot(herd['rd_index'], kde=True, color='skyblue')
plt.title('Distribution of R&D Index Across Institutions')
plt.xlabel('R&D Index')
plt.ylabel('Frequency')
plt.savefig('../output/rd_index.pdf')
plt.close

plt.figure(figsize=(10, 6))
sns.scatterplot(x='tot_fund', y='rd_index', data=herd)
plt.title('R&D Index vs. Total Funding')
plt.xlabel('Total Funding (in thousands)')
plt.ylabel('R&D Index')
plt.savefig('../output/rd_index_v_fund.pdf')


continuous_columns = ['applied_expend','applied_fed_expend','basic_expend','basic_fed_expend','clin_trial_expend','contracts_fund','dev_expend','expend_capital','expend_fed','expend_nonfed','expend_salaries','fed_ls_bio_fund','fed_ls_fund','fed_ls_hs_fund','grants_fund','hhs_ls_bio_fund','hhs_ls_fund','hhs_ls_hs_fund','ls_cap_expend','med_sch_expend','nonfed_ls_bio_fund','nonfed_ls_fund','nonfed_ls_hs_fund','subrecipient_fund','subrecipient_sent','tot_bus_fund','tot_fed_fund','tot_fund','tot_inst_fund','tot_nonprof_fund','tot_state_fund','ls_fund','hs_fund','bio_fund']

from scipy.stats import pearsonr

for column in continuous_columns:
    plt.figure(figsize=(10, 6))
    ax = sns.regplot(x=column, y='rd_index', data=herd)
    corr, _ = pearsonr(herd.dropna(subset=[column, 'rd_index'])[column], 
                       herd.dropna(subset=[column, 'rd_index'])['rd_index'])
    plt.text(0.05, 0.95, f'Corr: {corr:.2f}', transform=ax.transAxes, 
                 ha='left', va='top', bbox=dict(facecolor='white', alpha=0.5))
    plt.title(f'R&D Index vs. {column}')
    plt.xlabel(column)
    plt.ylabel('R&D Index')
    plt.savefig(f'../output/rd_index_v_{column}.pdf')

herd.to_csv('../output/herd_2010_2022.csv', index=False)
