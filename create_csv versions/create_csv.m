function create_csv(input_file, output_file)

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
feedbacks = [];
target_angles = [];
hand_angles=[];
theta_40s = [];
theta_100s = [];
hand_angles_pv=[];
mts=[];
rts=[];

% constants
M_TO_CM = 100;


for n=1:length(data.c3d)
    % definitions
    tp = data.c3d(n).TRIAL.TP;
    sample_freq = data.c3d(n).HAND.RATE;
    
    % find index of end event in list of event labels
    %end_event_index = find(string(data.c3d(n).EVENTS.LABELS)=='DONE_MOVEMENT');
    event_labels = string(data.c3d(n).EVENTS.LABELS);

    % Use PROBE_SUCCESS as the end event if it exists;
    % otherwise fall back to DONE_MOVEMENT.
    success_idx = find(event_labels == "PROBE_SUCCESS", 1);

    if ~isempty(success_idx)
        end_event_index = success_idx;
    else
        end_event_index = find(event_labels == "DONE_MOVEMENT", 1);
    end

    % find the time of the selected end event
    end_reach = data.c3d(n).EVENTS.TIMES(end_event_index);

  
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


    %% this used to be commented out
    start_target_index = data.c3d(n).TP_TABLE.Start_Target(tp);

    start_x_global = round(data.c3d(n).TARGET_TABLE.X_GLOBAL(start_target_index), 10);
    start_y_global = round(data.c3d(n).TARGET_TABLE.Y_GLOBAL(start_target_index), 10);

    target_x_global = M_TO_CM * round(data.c3d(n).VCODE_3(index_end), 10);
    target_y_global = M_TO_CM * round(data.c3d(n).VCODE_4(index_end), 10);

    % get the feedback -- does min work?? 
    feedback = round(min(data.c3d(n).FEEDBACK),0);


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

    % calculations
    % calculate distance from x,y coordinate to start position using
    % distance formula
    distances_temp = sqrt((x_temp - start_x_global).^2 + (y_temp - start_y_global).^2);
        
    % movement onset defined as first time distance to start goes above 1 cm
    movement_onset = find(distances_temp > 1, 1);
    rt = movement_onset/sample_freq;

    % movement time = reach end index - reach start index / 1000 = mt in seconds

    success_idx = find(string(data.c3d(n).EVENTS.LABELS) == "PROBE_SUCCESS", 1);

    if ~isempty(success_idx)
        success_time = data.c3d(n).EVENTS.TIMES(success_idx);
        index_end_mt = round(success_time * sample_freq);
    else
        index_end_mt = NaN;
    end


    if isnan(index_end_mt)
        mt = NaN; 
    else
        x_temp_mt = x_temp_all(index_start:index_end_mt);
        mt = (length(x_temp_mt) - movement_onset)/sample_freq;
    end 


    %x,y end points of reach
    x_ep = x_temp(end);

    y_ep = y_temp(end);
    
 
    % calculate vector from reach end point to start coordinates
    reach_end_vec = [x_ep y_ep]-[start_x_global start_y_global];
    
    % calculate vector from target position to start coordinates
    target_vec = [target_x_global target_y_global]-[start_x_global start_y_global];
    
    % % end point error angle in radians
    angle_end = atan2d(det([target_vec; reach_end_vec]), dot(target_vec, reach_end_vec));

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

    % angle error at 40 ms and 100 ms after movement onset
    index_40 = movement_onset + round(0.040 * sample_freq);
    index_100 = movement_onset + round(0.100 * sample_freq);

    % Make sure indices do not exceed the reach length
    if index_40 <= length(x_temp)
        x_40 = x_temp(index_40);
        y_40 = y_temp(index_40);

        hand_40_angle = atan2d(y_40 - start_y_global, x_40 - start_x_global);
        theta_40 = hand_40_angle - target_angle;
        theta_40 = atan2d(sind(theta_40), cosd(theta_40));
    else
        theta_40 = NaN;
    end

    if index_100 <= length(x_temp)
        x_100 = x_temp(index_100);
        y_100 = y_temp(index_100);

        hand_100_angle = atan2d(y_100 - start_y_global, x_100 - start_x_global);
        theta_100 = hand_100_angle - target_angle;
        theta_100 = atan2d(sind(theta_100), cosd(theta_100));
    else
        theta_100 = NaN;
    end


    % round after calculations
    angle_end = round(angle_end, nth);
    angle_pv = round(angle_pv, nth);
    theta_40 = round(theta_40, nth);
    theta_100 = round(theta_100, nth);
    
    % concat to list  
    rts = [rts; {rt}];
    mts = [mts;{mt}];
    feedbacks = [feedbacks; {feedback}];
    target_angles = [target_angles; {target_angle}];
    hand_angles = [hand_angles; {angle_end}];
    hand_angles_pv = [hand_angles_pv;{angle_pv}];
    theta_40s = [theta_40s; {theta_40}];
    theta_100s = [theta_100s; {theta_100}];

    peak_vels = [peak_vels; {peak_vel}];
    
end

% Now safe to horizontally concatenate

t1 = [peak_vels, theta_40s, theta_100s, hand_angles_pv, rts, mts, hand_angles, feedbacks, target_angles];

T = array2table(t1, ...
    'VariableNames', {'peak_vel', 'theta_40', 'theta_100', ...
                      'theta_pv', 'rt', 'mt', ...
                      'theta_end', 'feedback', 'target_angle'});


folderPath = '/Users/abbysun/Documents/github_abby/UDLR_study/UDLR_ver1/data/csv_files';


fileName = fullfile(folderPath, output_file);

writetable(T, fileName, 'Delimiter', ',');
