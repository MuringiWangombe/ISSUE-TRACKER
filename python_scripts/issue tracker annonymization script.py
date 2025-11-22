import pandas as pd
import os
import numpy as np

#  CONFIGURATION 

FILE_PATH = r"C:\Users\murin\PROJECTA\python_projects\ISSUE TRACKER.csv" 

#   OUTPUT DIRECTORY AND FILENAME 

OUTPUT_DIR = r"C:\Users\murin\PROJECTA\python_projects\Portfolio_Output" 
OUTPUT_FILENAME = 'anonymized_portfolio_data.xlsx'

# DATE PARSING CONFIGURATION TO ENSURE THEY ARE SAVED AS DATE/TIME & NOT TEXT
DATE_COLUMNS = [
    'DateOnly', 'event_timestamp', 'first_response_timestamp', 
    'resolution_timestamp', 'Ticket Creation Date'
]

# Column names for anonymization 
SCHOOL_COLUMN = 'School Name'
RM_COLUMN = 'Regional Manager Name'
REL_MGR_COLUMN = 'Relationship Manager Name'

# Creating a consistent anonymous token for each unique value
def create_mapping(unique_values, prefix):
    
    mapping = {}
    for i, val in enumerate(unique_values):
        if pd.isna(val) or val is None:
            mapping[val] = val # Keep Nulls as nuls
        else:
            mapping[val] = f"{prefix} {i+1}"
    return mapping

 #  parsing the timestamp using multiple expected formats
def parse_multi_format(date_str):
   
    
    formats = [
        '%d/%m/%Y %H:%M:%S',
        '%d/%m/%Y %H:%M',
        '%Y-%m-%d %H:%M:%S' 
    ]
    if pd.isna(date_str) or not date_str:
        return pd.NaT # Return Not a Time for empty/missing values
        
    for fmt in formats:
        try:
            return pd.to_datetime(date_str, format=fmt)
        except ValueError:
            continue 
    return pd.NaT 

try:
    
    df = pd.read_csv(
        FILE_PATH, 
        encoding='latin-1', 
        parse_dates=DATE_COLUMNS, #  Tells pandas which columns are dates
        date_parser=parse_multi_format 
    )
    print(f"Successfully loaded {len(df)} rows from {FILE_PATH}.")


    #  ANONYMIZATION LOGIC 
    df[SCHOOL_COLUMN] = df[SCHOOL_COLUMN].map(create_mapping(df[SCHOOL_COLUMN].unique(), "School"))
    df[RM_COLUMN] = df[RM_COLUMN].map(create_mapping(df[RM_COLUMN].unique(), "Regional Manager"))
    df[REL_MGR_COLUMN] = df[REL_MGR_COLUMN].map(create_mapping(df[REL_MGR_COLUMN].unique(), "Relationship Manager"))
    df['Resolved By Name'] = df['Resolved By Name'].map(create_mapping(df['Resolved By Name'].unique(), "Agent"))

    df['Region'] = df['Region'].map(create_mapping(df['Region'].unique(), "Region"))
    df['Country'] = df['Country'].map(create_mapping(df['Country'].unique(), "Country"))
    df['County'] = df['County'].map(create_mapping(df['County'].unique(), "Location"))

    df['Issue Title'] = "Generic Issue Description" 
    df['Sub Module'] = "Generic Module"


    #  SAVE DATA 
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    OUTPUT_PATH = os.path.join(OUTPUT_DIR, OUTPUT_FILENAME)
    
    # Save to Excel
    df.to_excel(OUTPUT_PATH, index=False)
    
    print(f"\nSuccess! Anonymized data saved to: {OUTPUT_PATH}")

except FileNotFoundError:
    print(f"ERROR: File not found. Check FILE_PATH: '{FILE_PATH}'")
except KeyError as e:
    print(f"ERROR: Column name issue. Check column spelling: {e}")
except ImportError:
    print("\nERROR: openpyxl library is missing. Please run: pip install openpyxl")
except Exception as e:
    print(f"An unexpected error occurred: {e}")