function create_csv_WIP(input_file, output_file)
% --------------------------------------------------------------------------------
% COPY & PASTE 
% create_csv_WIP('kinarm_files/UDLR_02/02_baseline_withoutFB.kinarm', '02_baseline.csv')

% Parameters: 
% input_file: string with the name of the .kinarm file you want to convert to csv. Must be in the same folder as this script, or include the full path to the file
% output_file: string with the name of the csv file you want to create (including the .csv extension)

% Outputs:
% A csv file with the name specified by output_file, containing the kinematic data and behavioral metrics extracted from the .kinarm file
% The csv will be created in the folder specified by folderPath variable at the end of the function

% This script extracts kinematic data and behavioral metrics from a .kinarm file, and creates a csv file with the extracted data
% The csv file is formatted so that each row corresponds to a trial, and each column corresponds to a different variable 
% Non-scalar data (position, velocity, etc.) for each trial is stored as a JSON string in the corresponding cell of the csv, which can be decoded in Python  (see unpack-csv.ipynb)

% This script is meant to be a starting point for data preprocessing, and will need to be modified to fit the specific variables and event labels used in your experiment. 
% If you have any errors, check to make sure all of the variable names and event labels in the script match exactly with the ones in your .kinarm file

%---------------------------------------------------------------------------------

% Load the data into matlab from .kinarm file using Kinarm-provided function
data_unfilt = exam_load(input_file);

% Add kinematics to data structure- also using Kinarm-provided function
data_kin = KINARM_add_hand_kinematics(data_unfilt);

% Filter data to smooth out noise- recommended by Kinarm, but technically optional
filter = 1;
if filter
    data = filter_double_pass(data_kin, 'standard', 'fc', 10);
else
    data = data_kin;
end


% number of decimal points data is rounded
nth = 10;

% initialize arrays for scalar data
peak_vels = [];
probes = [];
feedbacks = [];
reach_feedbacks = strings(0,1);
target_angles = [];
hand_angles_end=[];
hand_angles_pv=[];
theta_40s = [];
theta_100s = [];
mts=[];
rts=[];

% constants
M_TO_CM = 100;

for n=1:length(data.c3d)
    
    % ===== EVENTS =====
    labels = string(data.c3d(n).EVENTS.LABELS);
    times  = data.c3d(n).EVENTS.TIMES;
    sample_freq = data.c3d(n).HAND.RATE;

    start_event_index = find(labels == 'SHOW_PROBE_WAIT_TARGET', 1);
    end_event_index = find(labels == 'REACH_TARGET', 1);

    % Find the index of the end of the reach
    % Since data is taken at 1000hz, index should just be the time * 1000 to get the index of the sample
    % Log as NaN if event is not found, or there are indexing issues
    if isempty(end_event_index)
        disp("Issue within EVENTS on trial " + n)
        index_end = NaN;
    else
        index_end = round(times(end_event_index) * sample_freq);
    end

    % Same process to determine the index of the start of the reach
    if isempty(start_event_index)
        disp("Issue within EVENTS on trial " + n)
        index_start = NaN;
    else
        index_start = round(times(start_event_index) * sample_freq);
    end

    %% for the reach feedback: 
    if any(labels == "TOO_SLOW")
        reach_feedback = "too slow";
    elseif any(labels == "TOO_FAST")
        reach_feedback = "too fast";
    elseif any(labels == "GOOD_REACH")
        reach_feedback = "good reach";
    elseif any(labels == "TOO_EARLY")
        reach_feedback = "too early";
    else
        reach_feedback = missing;   
    end

    % ===== Extracting Data from TP Table =====
    tp = data.c3d(n).TRIAL.TP;

    start_target_index = data.c3d(n).TP_TABLE.Start_Target(tp);

    start_x_global = round(data.c3d(n).TARGET_TABLE.X_GLOBAL(start_target_index), 10);
    start_y_global = round(data.c3d(n).TARGET_TABLE.Y_GLOBAL(start_target_index), 10);

    % VCODE3 = x, VCODE4 = y 
    % Need to extract the coordinates in this manner because we read in
    % .dat files 

    target_x_global = M_TO_CM * round(data.c3d(n).VCODE_3(index_end), 10);
    target_y_global = M_TO_CM * round(data.c3d(n).VCODE_4(index_end), 10);

    % ===== POSITION / VELOCITY TO CM =====
    % Trim the reaches based on the start and end index if indexes are valid, otherwise log as NaN
    if ~isnan(index_start) && ~isnan(index_end) && index_start < index_end
        try
            x_temp = M_TO_CM * data.c3d(n).Right_HandX(index_start:index_end);
            y_temp = M_TO_CM * data.c3d(n).Right_HandY(index_start:index_end);

            vel_x_temp = M_TO_CM * data.c3d(n).Right_HandXVel(index_start:index_end);
            vel_y_temp = M_TO_CM * data.c3d(n).Right_HandYVel(index_start:index_end);
        catch
            disp("Issue within POSITION / VELOCITY TO CM on trial " + n)
            x_temp = NaN; y_temp = NaN;
            vel_x_temp = NaN; vel_y_temp = NaN;
        end

    else
        disp("Issue within POSITION / VELOCITY TO CM on trial " + n)
        x_temp = NaN; y_temp = NaN;
        vel_x_temp = NaN; vel_y_temp = NaN;
    end


    % ============================================================
    % RT AND MT CALCULATION -- COMBINED DISTANCE + VELOCITY
    % ============================================================

    MOVEMENT_ONSET_CM = 1;       % cm
    MOVEMENT_ONSET_VEL = 3;      % cm/s
    TARGET_DISTANCE_CM = 10;     % cm

    rt = NaN;
    mt = NaN;
    movement_onset = [];

    if ~isnan(index_start) && ~isnan(index_end) && index_start < index_end

        % Extract hand position from cue to reach end
        x_rtmt = M_TO_CM * data.c3d(n).Right_HandX(index_start:index_end);
        y_rtmt = M_TO_CM * data.c3d(n).Right_HandY(index_start:index_end);

        % Extract x and y velocity (cm/s)
        vx_rtmt = M_TO_CM * data.c3d(n).Right_HandXVel(index_start:index_end);
        vy_rtmt = M_TO_CM * data.c3d(n).Right_HandYVel(index_start:index_end);

        % Calculate resultant hand speed
        speed_rtmt = sqrt(vx_rtmt.^2 + vy_rtmt.^2);

        % Calculate distance from starting position
        distances_rtmt = sqrt((x_rtmt - start_x_global).^2 + (y_rtmt - start_y_global).^2);

        % MOVEMENT ONSET THRESHOLD: Distance-based movement onset (> 1 cm) and Velocity-based movement onset (> 3 cm/s)

        onset_indices = find((distances_rtmt > MOVEMENT_ONSET_CM) & (speed_rtmt > MOVEMENT_ONSET_VEL));

        if ~isempty(onset_indices)

            movement_onset = onset_indices(1);

            % Reaction time (seconds)
            rt = (movement_onset - 1) / sample_freq;

            % Movement time: combined onset to reaching 10 cm
            target_reach_relative = find(distances_rtmt(movement_onset:end) >= TARGET_DISTANCE_CM, 1);

            if ~isempty(target_reach_relative)
                target_reach_idx = movement_onset + target_reach_relative - 1;
                mt = (target_reach_idx - movement_onset) / sample_freq;
            end
        end
    end



   % ===== PEAK VELOCITY =====
    if ~isnan(vel_x_temp)   
        % Calculate total velocity (with both x and y components)
        vel_temp = sqrt(vel_x_temp.^2 + vel_y_temp.^2);
        % Calculate PV by taking the max of the velocity vector 
        [peak_vel, peak_idx] = max(vel_temp);
    else
        disp("Issue within PEAK VELOCITY on trial " + n)
        vel_temp = NaN;
        peak_vel = NaN;
        peak_idx = NaN;
    end

    % ===== ANGLE @ PV =====

    %% target angle: 
    target_angle = atan2d(target_y_global - start_y_global, target_x_global - start_x_global);
    target_angle = mod(target_angle, 360);
    target_angle = round(target_angle, 1);

    if ~isnan(peak_idx)
        try
            % x,y points at PV
            x_pv = x_temp(peak_idx);
            y_pv = y_temp(peak_idx);

            % Calculate the angle between the vectors using dot product formula, and convert to degrees 
            hand_pv_angle = atan2d(y_pv - start_y_global, x_pv - start_x_global);
            angle_pv = atan2d(sind(hand_pv_angle - target_angle), cosd(hand_pv_angle - target_angle));

        catch
            disp("Issue within ANGLE @ PV on trial " + n)
            angle_pv = NaN;
        end
    else
        disp("Issue within ANGLE @ PV on trial " + n)
        angle_pv = NaN;
    end

    % ===== ANGLE @ END =====
    if ~isnan(x_temp)
        try
            % x,y end points of reach (safe access) 
            x_ep = x_temp(end);
            y_ep = y_temp(end);

            % Calculate the angle between the vectors using dot product formula, and convert to degrees
            hand_end_angle = atan2d(y_ep - start_y_global, x_ep - start_x_global);
            angle_end = atan2d(sind(hand_end_angle - target_angle), cosd(hand_end_angle - target_angle));

        catch
            disp("Issue within ANGLE @ END on trial " + n)
            angle_end = NaN;
        end
    else
        disp("Issue within ANGLE @ END on trial " + n)
        angle_end = NaN;
    end

    % ===== THETA @ 40 ms and 100 ms AFTER MOVEMENT ONSET =====

    theta_40 = NaN;
    theta_100 = NaN;

    if ~isempty(movement_onset)

        index_40 = movement_onset + round(0.040 * sample_freq);
        index_100 = movement_onset + round(0.100 * sample_freq);

        % Theta at 40 ms
        if index_40 <= length(x_rtmt)
            x_40 = x_rtmt(index_40);
            y_40 = y_rtmt(index_40);

            hand_40_angle = atan2d(y_40 - start_y_global, x_40 - start_x_global);
            theta_40 = atan2d(sind(hand_40_angle - target_angle), cosd(hand_40_angle - target_angle));
        end

        % Theta at 100 ms
        if index_100 <= length(x_rtmt)
            x_100 = x_rtmt(index_100);
            y_100 = y_rtmt(index_100);

            hand_100_angle = atan2d(y_100 - start_y_global, x_100 - start_x_global);
            theta_100 = atan2d(sind(hand_100_angle - target_angle), cosd(hand_100_angle - target_angle));
        end
    end
 

    %% for the probe: 
    probe = round(data.c3d(n).PROBE(index_end),0);
    % get the feedback 
    feedback = round(min(data.c3d(n).FEEDBACK),0);

    % round after calculations (if numeric)
    if isnumeric(angle_end), angle_end = round(angle_end, nth); end
    if isnumeric(angle_pv), angle_pv = round(angle_pv, nth); end
    if isnumeric(theta_40), theta_40 = round(theta_40, nth); end
    if isnumeric(theta_100), theta_100 = round(theta_100, nth); end

    % concat to list  
    rts = [rts; {rt}];
    mts = [mts;{mt}];
    reach_feedbacks = [reach_feedbacks; reach_feedback]; 
    target_angles = [target_angles; {target_angle}];
    hand_angles_end = [hand_angles_end; {angle_end}];
    hand_angles_pv = [hand_angles_pv;{angle_pv}];
    peak_vels = [peak_vels; {peak_vel}];

    probes = [probes; probe];
    feedbacks = [feedbacks; {feedback}];
    theta_40s = [theta_40s; {theta_40}];
    theta_100s = [theta_100s; {theta_100}];
    
end


T = table(target_angles, probes, feedbacks, reach_feedbacks,rts, mts, peak_vels, theta_40s, theta_100s,hand_angles_pv, hand_angles_end, ...
    'VariableNames', {'target_angle', 'probe', 'feedback', 'reach_feedback','rt', 'mt', 'peak_vel', 'theta_40', 'theta_100', 'theta_pv', 'theta_end'});

folderPath = '/Users/abbysun/Documents/github_abby/UDLR_study/UDLR_exp1/data/csv_files';

fileName = fullfile(folderPath, output_file);

writetable(T, fileName, 'Delimiter', ',');
