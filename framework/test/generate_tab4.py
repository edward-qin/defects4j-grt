################################################################################
#
# This script collects results from all the csv files in this directory to generate
# a figure similar to Table IV in the original GRT paper
#
# To run, invoke a virtual environment and run:
#   python generate_tab4.py
#
################################################################################
import os
import pandas as pd
import glob

# Define the directories containing CSV files
csv_files = glob.glob("test_d4j_*/result_db/bug_detection")

# List to store dataframes
df_list = []

# Read and aggregate CSVs
for file in csv_files:
    df = pd.read_csv(file)
    df_list.append(df)

# Combine all dataframes
full_df = pd.concat(df_list, ignore_index=True)

# Ensure relevant columns exist
required_columns = {"project_id", "test_suite_source", "timeout", "test_classification"}
if not required_columns.issubset(full_df.columns):
    raise ValueError(f"CSV files are missing required columns: {required_columns - set(full_df.columns)}")

# Filter for only "Pass" values in test_classification
filtered_df = full_df[full_df["test_classification"] == "Pass"]

# Aggregate counts of "Pass" values
agg_df = (
    filtered_df
    .groupby(["project_id", "test_suite_source", "timeout"])
    .size()
    .reset_index(name="pass_count")
)

# Pivot to format table with test_suite_source as columns and timeout as sub-columns
pivot_df = agg_df.pivot_table(
    index="project_id",
    columns=["test_suite_source", "timeout"],
    values="pass_count",
    aggfunc="sum",
    fill_value=0
)

# Add a total row summing all values
pivot_df.loc["Total"] = pivot_df.sum()

# Display table
print(pivot_df)

# Save to CSV
pivot_df.to_csv("grt_table4.csv")

print("Aggregated results saved to grt_table4.csv")
