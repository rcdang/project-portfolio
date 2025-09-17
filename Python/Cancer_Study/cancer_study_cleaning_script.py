# %% [markdown]
# ### Cancer Study Cleaning Steps

# %%
import numpy as np
import pandas as pd

# %%

dataset = pd.read_csv('cancer_incidents_extract.csv')

# %%
# Drop columns: 'Source.Name', 'Domain' and 12 other columns
dataset = dataset.drop(columns=['Source.Name', 'Domain', 'Indicator', 'Year', 'GeogID', 'Race_Ethnicity', 'Gender', 'Age_Group', 'Month', 'Measure', 'ts', 'measureName', 'contentAreaName', 'Race_Ethnicitylabel'])

# %%
 # Filter rows based on column: 'Name'
dataset = dataset[dataset['Name'] != "ARIZONA"]

# %%
# Create Gender Column to account for breast and testicular cancer 
conditions = [
     dataset['indicatorName'].str.contains('Females Only', case=False, na=False),
     dataset['indicatorName'].str.contains('Males Only', case=False, na=False),
     dataset['Genderlabel'] == 'Female',
     dataset['Genderlabel'] == 'Male'
            ]
choices = ['Female', 'Male', 'Female', 'Male']
dataset['gender'] = np.select(conditions, choices, default=np.nan)

# %%
# drop 'Genderlabel'
dataset = dataset.drop(columns=['Genderlabel'])

# %%
# Rename columns
dataset = dataset.rename(columns={'Name': 'county', 'Value': 'cancer_rate', 'indicatorName': 'cancer_type'})

# %%

# create primary key

# extract cancer name and gender code
dataset['cancer_name'] = dataset['cancer_type'].str.split(' ').str[2]
dataset['gender_code'] = dataset['gender'].str[0]
# create unique composite key of county, cancer_name, and gender_code
dataset['ID'] = (dataset['county'] + '-' + dataset['cancer_name'] + '-' + dataset['gender_code']).str.upper()
# remove intermediate columns
dataset = dataset.drop(columns=['cancer_name', 'gender_code'])

# %%
# move ['ID'] to front
cols_to_move = ['ID']
remaining_cols = [col for col in dataset.columns if col not in cols_to_move]
new_order = cols_to_move + remaining_cols
dataset = dataset[new_order]

# %%
# extract cancer type text between delimiters 
dataset['cancer_type'] = dataset['cancer_type'].str.split(' ')
dataset['cancer_type'] = dataset['cancer_type'].str[2:].str.join(' ')

# %%
# Change column types to string
dataset = dataset.astype({'ID': 'string','county': 'string', 'cancer_type': 'string','gender': 'string'})

# %%
dataset.head()


