function create_csv_v2(input_file, output_file)

% COPY & PASTE 
% create_csv('kinarm_files/UDLR_02/02_baseline_withoutFB.kinarm', '02_baseline_withoutFB.csv')

% unpacking data directly from .kinarm file
data_unfilt = exam_load(input_file);

% add kinematics to data structure
data_kin = KINARM_add_hand_kinematics(data_unfilt);

% optionally filter data
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

% when event code: E_FILE_READ then we want to use this index to get the value 

for n=1:length(data.c3d)
    % definitions
    tp = data.c3d(n).TRIAL.TP;
    sample_freq = data.c3d(n).HAND.RATE;
    
    % find index of end event in list of event labels
    end_event_index = find(string(data.c3d(n).EVENTS.LABELS)=='DONE_MOVEMENT');
  
    % find the time of the event
    end_reach = data.c3d(n).EVENTS.TIMES(end_event_index);

    % find the index of the end of the reach
    % since data is taken at 1000hz, index should just be the time * 1000
    % to get the index of the sample
    index_end = round(end_reach*sample_freq);

    % same process to determine the index of the start of the reach
    start_event_index = find(string(data.c3d(n).EVENTS.LABELS)=='SHOW_PROBE_WAIT_TARGET');
    start_reach = data.c3d(n).EVENTS.TIMES(start_event_index);
    index_start = round(start_reach*data.c3d(n).HAND.RATE);


    %% for the reach feedback: 
    event_labels = string(data.c3d(n).EVENTS.LABELS);
    if any(event_labels == "TOO_SLOW")
        reach_feedback = "too slow";
    elseif any(event_labels == "TOO_FAST")
        reach_feedback = "too fast";
    elseif any(event_labels == "PROBE_SUCCESS")
        reach_feedback = "good reach";
    else
        reach_feedback = missing;   % or "unknown"
    end


    %% for the probe: 
    probe = round(data.c3d(n).PROBE(index_end),0);

    % get the feedback 
    feedback = round(min(data.c3d(n).FEEDBACK),0);


    start_target_index = data.c3d(n).TP_TABLE.Start_Target(tp);

    start_x_global = round(data.c3d(n).TARGET_TABLE.X_GLOBAL(start_target_index), 10);
    start_y_global = round(data.c3d(n).TARGET_TABLE.Y_GLOBAL(start_target_index), 10);

    target_x_global = M_TO_CM * round(data.c3d(n).VCODE_3(index_end), 10);
    target_y_global = M_TO_CM * round(data.c3d(n).VCODE_4(index_end), 10);

    % convert x,y trajectory and velocities to cm
    % trim the reaches based on the start and end index
    x_temp_all = M_TO_CM*data.c3d(n).Right_HandX;
    y_temp_all = M_TO_CM*data.c3d(n).Right_HandY;
    x_temp = x_temp_all(index_start:index_end);
    y_temp = y_temp_all(index_start:index_end);
    
    vel_x_temp = M_TO_CM*data.c3d(n).Right_HandXVel;
    vel_y_temp = M_TO_CM*data.c3d(n).Right_HandYVel;
    vel_x_temp = vel_x_temp(index_start:index_end);
    vel_y_temp = vel_y_temp(index_start:index_end);

    % CALCULATIONS

    % calculate distance from x,y coordinate to start position using
    % distance formula
    distances_temp = sqrt((x_temp - start_x_global).^2 + (y_temp - start_y_global).^2);
        
    % movement onset defined as first time distance to start goes above 1 cm
    movement_onset = find(distances_temp > 1, 1);

    %% in SECONDS 
    rt = movement_onset/sample_freq;

    % movement time = reach end index - reach start index / 1000 = mt in seconds
    mt = (length(x_temp) - movement_onset) / sample_freq;

    %x,y end points of reach
    x_ep = x_temp(end);
    y_ep = y_temp(end);
    

    %calculate combined velocity (with both x+y components)
    vel_temp = sqrt(vel_x_temp.^2+ vel_y_temp.^2);
 
    % calculate pv and timestamp
    [peak_vel, peak_idx] = max(vel_temp);
    peak_vel = round(peak_vel, nth);
    
    x_pv = x_temp(peak_idx);
    y_pv = y_temp(peak_idx);
    
    % same process as finding end point error angle    
    target_angle = atan2d(target_y_global - start_y_global, target_x_global - start_x_global);
    target_angle = mod(target_angle, 360);
    target_angle = round(target_angle, 1);
    
    hand_pv_angle = atan2d(y_pv - start_y_global, x_pv - start_x_global);
    angle_pv = hand_pv_angle - target_angle;
    angle_pv = atan2d(sind(hand_pv_angle - target_angle),cosd(hand_pv_angle - target_angle));     

    % calculate endpoint direction angle
    hand_end_angle = atan2d(y_ep - start_y_global,x_ep - start_x_global);
    angle_end = hand_end_angle - target_angle;
    angle_end = atan2d(sind(angle_end), cosd(angle_end));

    % for theta_40 and theta_100 
    index_40 = movement_onset + round(0.040 * sample_freq);
    index_100 = movement_onset + round(0.100 * sample_freq);

    x_40 = x_temp(index_40);
    y_40 = y_temp(index_40);
    x_100 = x_temp(index_100);
    y_100 = y_temp(index_100);

    % angle error at 40 ms
    hand_40_angle = atan2d(y_40 - start_y_global, x_40 - start_x_global);
    theta_40 = hand_40_angle - target_angle;
    theta_40 = atan2d(sind(theta_40), cosd(theta_40));

    % angle error at 100 ms
    hand_100_angle = atan2d(y_100 - start_y_global, x_100 - start_x_global);
    theta_100 = hand_100_angle - target_angle;
    theta_100 = atan2d(sind(theta_100), cosd(theta_100));

    % round after calculations
    angle_end = round(angle_end, nth);
    angle_pv = round(angle_pv, nth);
    theta_40 = round(theta_40, nth);
    theta_100 = round(theta_100, nth);
    

    % concat to list  
    rts = [rts; {rt}];
    mts = [mts;{mt}];
    reach_feedbacks = [reach_feedbacks; reach_feedback]; target_angles = [target_angles; {target_angle}];
    hand_angles_end = [hand_angles_end; {angle_end}];
    hand_angles_pv = [hand_angles_pv;{angle_pv}];
    peak_vels = [peak_vels; {peak_vel}];

    probes = [probes; probe];
    feedbacks = [feedbacks; {feedback}];
    theta_40s = [theta_40s; {theta_40}];
    theta_100s = [theta_100s; {theta_100}];
    
end


T = table(target_angles, probes,feedbacks, reach_feedbacks, rts, mts, theta_40s, theta_100s, hand_angles_pv, hand_angles_end, ...
    'VariableNames', {'target_angle', 'probe', 'feedback', 'reach_feedback','rt', 'mt','theta_40', 'theta_100', 'theta_pv', 'theta_end'});

% folderPath = '/Users/abbysun/Documents/github_abby/UDLR_study/UDLR_ver1/data/csv_files';
folderPath = '/Users/abbysun/Desktop';

fileName = fullfile(folderPath, output_file);

writetable(T, fileName, 'Delimiter', ',');
