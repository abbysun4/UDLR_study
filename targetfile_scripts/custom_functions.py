import pandas as pd
import numpy as np
from itertools import groupby


def trial_count_checker(df_inp, mask):
    #This function grabs the subset of trials where target location is 90 (N) and each subsequent trial (N+1)
    #Then counts the number of trials where location changes -60, 0 and 60 for N to N+1

    df = df_inp.loc[mask].reset_index(drop=True)
    repeated_target = df['repeated_target'].iloc[0]
    
    if  repeated_target == [120]:
        targAngle = np.array([30, 60, 90, 120, 150, 180, 210])
    else: 
        targAngle = np.array([330, 0, 30, 60, 90, 120, 150])

    #calculate xdiff for 90 deg target angle
    # indices where tgt_angle == 90
    if  repeated_target == [120]:
        ph = df.index[df['tgt_angle'] == 120]
    else: 
        ph = df.index[df['tgt_angle'] == 60]

    # interleave 90 deg loc trials and each subsequent trial to check for the number of trials that will be in each condition for main figure
    ph_all = []
    for i, idx in enumerate(ph):

        if idx < len(df)-1:
            #ph_all.append(idx)                            
            ph_all.append(idx + 1)
    x_90 = df.iloc[ph_all]['tgt_angle']
    

    xdiff_90 = np.deg2rad(x_90.diff())
    xdiffang_90 = np.rad2deg(np.arctan2(np.sin(xdiff_90),np.cos(xdiff_90))).round()

    angles = targAngle

    angles_desired = np.column_stack([
        angles,
        np.zeros(len(angles))
    ])

    for i in range(len(angles)):
        angle = angles_desired[i, 0]
        angles_desired[i, 1] = np.sum(x_90 == angle)

    return angles_desired