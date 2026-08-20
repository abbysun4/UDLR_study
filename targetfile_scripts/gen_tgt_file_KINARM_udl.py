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

    #baseline FB blocks (we want to visit each target 20 times following Tsay et al. (2022))
    baselineFB_blocks = 10

    #baseline no FB blocks (we want to visit each target 20 times following Tsay et al. (2022))
    baselinenoFB_blocks = 10

    #udl blocks (each probe is tested twice during a block, we want each probe tested 16 times total, so we set blocks to 8) 
    udl_blocks = 8

    #target angle component lists for UDL phase, these will be added together to recreate trial structure from Tsay et al. (2022)
    targAngleUDLList_part1 = rep_targ * 10
    targAngleUDLList_part2 = rep_targ * 6
    targAngleUDLList_part3 = targAngleList * 2

    #Assuming we want one probe trial happening a cycle, the number of cycles is equal to the list of probe targets for a given block
    udl_cycles = len(targAngleUDLList_part3)

    #trials per cycle for udl phase. Assuming 7 trials per cycle (6 context, 1 probe), to follow Tsay et al. (2022)
    udl_tpc = 7

    #trials per block for udl phase. (10 repeated target (serve as context) + 36 repeated target + 6 probe trials)
    udl_tpb = len(targAngleUDLList_part1) + len((targAngleUDLList_part2 * udl_cycles)) + len(targAngleUDLList_part3) 

    #trials per block minus the 10 repeated target trials at the beginning
    udl_tpb_min = len((targAngleUDLList_part2 * udl_cycles)) + len(targAngleUDLList_part3) 

    #experimental phase 1 (baseline trials with FB)
    baselineFB_trials = len(targAngleList) * baselineFB_blocks

    #experimental phase 2 (baseline trials without FB)
    baselinenoFB_trials = len(targAngleList) * baselinenoFB_blocks

    #experimental phase 3 (use-dependent learning phase)
    udl_trials = udl_tpb * udl_blocks

    #experimental phase 3 (use-dependent learning phase) minus padding context trials at the beginning
    udl_tpb_min_trials = udl_tpb_min * udl_blocks

    #target distance (in m)
    targetDistance = 0.10

    jsonData = {}
    numTrials = baselineFB_trials + baselinenoFB_trials + udl_trials  # block size
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
    baseFB = baselineFB_trials
    basenoFB = baselinenoFB_trials + baseFB
    udl_minus_padding = udl_tpb_min_trials
    udl = udl_trials + basenoFB

    if (totalNumTrials != udl):
        raise Exception('Number of reaches do not add up. Should have ' + str(totalNumTrials) + ' targets, but only has ' + str(udl) + '.')

    for i in range(totalNumTrials):
        trialNums[i] = i + 1
        aimingLandmarks[i] = 0
        tgtDistance[i] = targetDistance
        repeated_target[i] = rep_targ[0]

        if i < baseFB:
            # for now we are going to set all feedback to none (0), 
            # we will reset this to 1 for the frequent 90 deg target below
            onlineFB[i] = 1
            endpointFB[i] = 1
            rotation[i] = float(0)
            clampedFB[i] = float(0)
            targetJump[i] = float(0)
            FBdelay[i] = float(0)
            delonlineFB[i] = 0
            targwaitsignal[i] = 1

        elif i < basenoFB:
            # for now we are going to set all feedback to none (0), 
            # we will reset this to 1 for the frequent 90 deg target below
            onlineFB[i] = 0
            endpointFB[i] = 0
            rotation[i] = float(0)
            clampedFB[i] = float(0)
            targetJump[i] = float(0)
            FBdelay[i] = float(0)
            delonlineFB[i] = 0
            targwaitsignal[i] = 1

        elif i < udl:
            # for now we are going to set all feedback to none (0), 
            # we will reset this to 1 for the frequent 90 deg target below
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

    # for loop to build target list for udl phase, we use "udl_minus_padding" as our index because counterbalancing is easier 
    # when total trial count is a multiple of 7
    for i in range(0, udl_minus_padding):
        
        #if your at the beginning of the udl phase, reset angle list and probe flag list,
        #then generate shuffled list of probes
        if i == 0:
            angles_udl = []
            probe_udl = []

        #if your at the beginning of a block, reset the block list
        if i % udl_tpb_min == 0:
            block_targs = []
            block_flags = []
            # zip probe target locations with a binary flag (1 = probe), then shuffle
            probe_shuffle = list(zip(targAngleUDLList_part3.copy(), [1]*len(targAngleUDLList_part3)))
            random.shuffle(probe_shuffle) 

            #set probe counter to 0, we'll use this to index into targAngleUDLList_part3
            probe_counter = 0
    

        #if your at a multiple of 7 (cycle length), generate a new list with 6 context and 1 probe and shuffle
        # zip with binary flag (0 = not probe)
        if i % udl_tpc == 0:

            probe_targets, probe_flags = zip(*probe_shuffle)

            targs = targAngleUDLList_part2.copy()
            targs.append(probe_targets[probe_counter])

            to_shuffle_flags = [0]*len(targAngleUDLList_part2)
            to_shuffle_flags.append(probe_flags[probe_counter])

            to_shuffle = list(zip(targs, to_shuffle_flags))
            random.shuffle(to_shuffle)   

            targs_shuffled, flag_shuffled = zip(*to_shuffle)
            block_targs.append(targs_shuffled)
            block_flags.append(flag_shuffled)

            probe_counter += 1

        #if your at the end of a block (i.e., the list for a block has been constructed, shuffle outer list, flatten list, add 10 context trials at the beginning)
        if i % udl_tpb_min == udl_tpb_min - 1:

            block = list(zip(block_targs, block_flags))
            random.shuffle(block)

            block_targs_shuffled, block_flags_shuffled = zip(*block)

            block_targs_shuffled = list(chain.from_iterable(block_targs_shuffled)) 
            block_targs_shuffled = targAngleUDLList_part1 + block_targs_shuffled
            angles_udl = angles_udl + block_targs_shuffled

            block_flags_shuffled = list(chain.from_iterable(block_flags_shuffled)) 
            block_flags_shuffled = [0]*len(targAngleUDLList_part1) + block_flags_shuffled
            probe_udl = probe_udl + block_flags_shuffled

    for i in range(0, baseFB):
        if i % numTargets == 0:
            angles = targAngleList.copy()
            random.shuffle(angles)
        anglesDict[i] = float(angles[i % len(angles)])
        probeflagDict[i] = float(0)
    
    for i in range(baseFB, basenoFB):
        if i % numTargets == 0:
            angles = targAngleList.copy()
            random.shuffle(angles)
        anglesDict[i] = float(angles[i % len(angles)])
        probeflagDict[i] = float(0)
    
    for i in range(basenoFB, udl):
        anglesDict[i] = float(angles_udl[i % len(angles_udl)])
        probeflagDict[i] = float(probe_udl[i % len(angles_udl)])

        #reset feedback to 1 the trial is not a probe, to follow Tsay et al. 2022
        if not probe_udl[i % len(angles_udl)]:
            onlineFB[i] = 1

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

    filename = f"udlr_karm_tfile_udl_0{filenum}.csv"
    df_out.to_csv(filename, index=False)

for i in range(7, 11):
    #if targ_shift, then entire set of targets is shifted counterclockwise so central repeated target is 120, if not, then 60
    if i % 2 == 0:
        targ_shift = 1
    else:
        targ_shift = 0

    generateCSV(i, targ_shift)



        
