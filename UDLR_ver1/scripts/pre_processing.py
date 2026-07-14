import pandas as pd
import numpy as np
import json

def json_decode(val):
    if isinstance(val, str):
        try:
            return json.loads(val)
        except (json.JSONDecodeError, TypeError):
            return val
    return val

def pre_process(file_paths, subjects):
    data = [] # Master list of all subject data

    # Loop through subjects
    for k, (s, p) in enumerate(zip(subjects, file_paths)):

        df_json = pd.read_csv(p)
        df_temp = df_json.map(json_decode)

        # concatenate is unnecessary now (only one file per subject)
        df_subj = df_temp

        # trial number per subject
        df_subj["TN"] = np.arange(1, len(df_subj) + 1)

        # subject info
        df_subj["SN"] = k + 1
        df_subj["Subject ID"] = s

        data.append(df_subj)

    # Final concatenation of all subject data
    df = pd.concat(data).reset_index(drop=True)

    # Rearrange columns to have subject and trial numbers in first two columns
    df = df[["TN"] + [c for c in df.columns if c != "TN"]] 
    df = df[["SN"] + [c for c in df.columns if c != "SN"]] 

    # Master list of all subject data
    return df


# def pre_process(file_paths, subjects):
#     data = [] # Master list of all subject data

#     # Loop through subjects
#     for k, s in enumerate(subjects):
#         dfs = []

#         # Loop through each subjects active and passive data 
#         # and concat into single df
#         for p in file_paths:
#             df_json = pd.read_csv(p)
#             df_temp = df_json.map(json_decode)
#             df_temp["TN"] = np.arange(1, len(df_temp)+1)
#             dfs.append(df_temp)
#         df_subj = pd.concat(dfs)

#         # Add subject info and append to data list
#         df_subj["SN"] = k + 1
#         df_subj["Subject ID"] = s
#         data.append(df_subj)

#     # Final concatenation of all subject data
#     df = pd.concat(data).reset_index(drop=True)

#     # Rearrange columns to have subject and trial numbers in first two columns
#     df = df[["TN"] + [c for c in df.columns if c != "TN"]] 
#     df = df[["SN"] + [c for c in df.columns if c != "SN"]] 

#     # Master list of all subject data
#     return df
