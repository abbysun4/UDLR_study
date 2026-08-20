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

    #target distance (in m)
    targetDistance = 0.10

    #number of trials for various blocks
    base_fb_trials = 16 

    jsonData = {}
    numTrials = base_fb_trials 
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
    base_fb = base_fb_trials

    if (totalNumTrials != base_fb):
        raise Exception('Number of reaches do not add up. Should have ' + str(totalNumTrials) + ' targets, but only has ' + str(udl) + '.')

    for i in range(totalNumTrials):
        trialNums[i] = i + 1
        aimingLandmarks[i] = 0
        tgtDistance[i] = targetDistance
        repeated_target[i] = rep_targ[0]
        if i < base_fb :
            onlineFB[i] = 1
            endpointFB[i] = 1
            rotation[i] = float(0)
            clampedFB[i] = float(0)
            targetJump[i] = float(0)
            FBdelay[i] = float(0)
            delonlineFB[i] = 0
            targwaitsignal[i] = 0

    # Set values in betweenBlocks to 0.0
    for i in range(totalNumTrials):
        betweenBlocks[str(i)] = 0.0

    # Set up all targets. 
    for i in range(0, base_fb):
        if i % numTargets == 0:
            angles = targAngleList.copy()
            random.shuffle(angles)
        anglesDict[i] = float(angles[i % len(angles)])
        probeflagDict[i] = float(0)

    
    betweenBlocks[str(base_fb - 1)] = 1

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

    filename = f"udlr_karm_tfile_baseline_0{filenum}.csv"
    df_out.to_csv(filename, index=False)

for i in range(7, 11):
    #if targ_shift, then entire set of targets is shifted counterclockwise so central repeated target is 120, if not, then 60
    if i % 2 == 0:
        targ_shift = 1
    else:
        targ_shift = 0

    generateCSV(i, targ_shift)

        
