import random
import numpy as np
import pandas as pd
from itertools import chain
from itertools import groupby
from custom_functions import trial_count_checker

def generateCSV(filenum, targ_shift):

    #target angles locations
    if targ_shift:
        targAngleList = [30, 60, 90, 120, 150, 180, 210]
        rep_targ = [120]
    else: 
        targAngleList = [330, 0, 30, 60, 90, 120, 150]
        rep_targ = [60]

    #based on these lists, set the number of trials per cycle (tpc)
    numTargets = len(targAngleList)
    repulse_tpc = len(targAngleList)

    #repulsive bias blocks (shorter, 7 trials per block, so 7 trials total)
    repulse_blocks = 100

    #target distance (in m)
    targetDistance = 0.10

    #experimental phase 1 (repulsive bias)
    repulse_trials = repulse_blocks * repulse_tpc

    jsonData = {}
    numTrials = repulse_trials # block size
    totalNumTrials = numTrials
    jsonData["numtrials"] = totalNumTrials
    trialNums = {}
    aimingLandmarks = {}
    onlineFB = {}
    delonlineFB = {}
    targwaitsignal = {}
    endpointFB = {}
    FBdelay = {}
    rotation = {}
    clampedFB = {}
    tgtDistance = {}
    repeated_target = {}
    anglesDict = {}
    probeflagDict = {}
    betweenBlocks = {}
    targetJump = {}

    # Breakpoints between phases
    repulse = repulse_trials

    if (totalNumTrials != repulse):
        raise Exception('Number of reaches do not add up. Should have ' + str(totalNumTrials) + ' targets, but only has ' + str(udl) + '.')

    for i in range(totalNumTrials):
        trialNums[i] = i + 1
        aimingLandmarks[i] = 0
        tgtDistance[i] = targetDistance
        repeated_target[i] = rep_targ[0]
        if i < repulse:
            onlineFB[i] = 0
            endpointFB[i] = 0
            rotation[i] = float(0)
            clampedFB[i] = float(0)
            targetJump[i] = float(0)
            FBdelay[i] = float(0)
            delonlineFB[i] = 0
            targwaitsignal[i] = 1

    # Set values in betweenBlocks to 0.0
    for i in range(totalNumTrials):
        betweenBlocks[str(i)] = 0.0

    # Set up all targets. 
    for i in range(0, repulse):
        if i == 0:
            angles = targAngleList * repulse_blocks
            random.shuffle(angles)
        anglesDict[i] = float(angles[i])
        probeflagDict[i] = float(0)

    targetarray = np.array(list(anglesDict.values()))
    probearray = np.array(list(probeflagDict.values()))

    df_out = pd.DataFrame({
        "tgt_angle": targetarray,
        "target_x": targetDistance*np.cos(np.deg2rad(targetarray)),
        "target_y": targetDistance*np.sin(np.deg2rad(targetarray)),
        "FB": list(onlineFB.values()),
        "probe": probearray,
        "repeated_target": list(repeated_target.values())
    })


    filename = f"udlr_karm_tfile_repulse_0{filenum}.csv"
    df_out.to_csv(filename, index=False)

for i in range(7, 11):
    #if targ_shift, then entire set of targets is shifted counterclockwise so central repeated target is 120, if not, then 60
    if i % 2 == 0:
        targ_shift = 1
    else:
        targ_shift = 0

    #while loop to regenerate file until you have <=3 consecutive target repeats and adequate trials per condition for the random phase
    good_file = 1

    while good_file:

        generateCSV(i, targ_shift)

        df = pd.read_csv(f"udlr_karm_tfile_repulse_0{i}.csv") 

        # recreate trial numbers
        df['trialnum'] = np.arange(1, len(df) + 1)

        mask_rand = (df['trialnum'] >= 1) & (df['trialnum'] <= 700)

        #check for maximum number of consecutive target repeats in random phase
        max_rep = max(len(list(group)) for key, group in groupby(df.loc[mask_rand]['tgt_angle'].to_numpy()))

        #check for number of trials for analyzed conditions 
        trials_rand = trial_count_checker(df, mask_rand)


        #check for number of each target location N+1, where N is trial with repeated target   
        #if conditions are satisfied, move onto next subject file
        if max_rep <= 3 and all(trials_rand[i][1] > 12 for i in range(7)):
            good_file = 0
        

        
