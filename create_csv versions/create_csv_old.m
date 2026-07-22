function create_csv_old(input_file, output_file)

% create_csv_old('kinarm_files/UDLR_02/02_baseline_withoutFB.kinarm', '02_baseline_withoutFB.csv')

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


% temporary placement of code to create table of events*
 % n_col = length(data.c3d(1).EVENTS.LABELS);
 % event_labels = strings(1, n_col);
 % 
 % for i=1:n_col
 %     event_labels(i)=string(data.c3d(1).EVENTS.LABELS{i});
 % end
 % T_events = array2table(NaN(length(data.c3d),n_col), 'VariableNames', event_labels);

% you can also print this in the Command Window 
 % data = exam_load(filepath) 


% number of decimal points data is rounded
nth = 5;

% initialize cell arrays for non-scalar data
x = {};
y = {};
vel_x = {};
vel_y = {};
vel = {};
force_X = {};
distances = {};

% initialize arrays for scalar data
peak_vels = [];
time_pvs = [];
feedbacks = [];

%% ABBY: uncommented these out 
target_xs = [];
target_ys=[];

target_x_globals = [];
target_y_globals = [];

target_angles = [];

% start_xs = [];
% start_ys = [];
start_x_globals = [];
start_y_globals = [];

hand_angles=[];
hand_angles_pv=[];

mts=[];
rts=[];

% constants
M_TO_CM = 100;


%% ABBY: change back to w/o -1 
for n=1:length(data.c3d)
    
    %T_events(n,:)= num2cell(round(data.c3d(n).EVENTS.TIMES, nth));
    
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

    %%%% CHECK %%%%

    %% this used to be commented out
    % end_target_index = data.c3d(n).TP_TABLE.Probe_Target(tp);
    start_target_index = data.c3d(n).TP_TABLE.Start_Target(tp);

    start_x = round(data.c3d(n).TARGET_TABLE.X(start_target_index), 10);
    start_y = round(data.c3d(n).TARGET_TABLE.Y(start_target_index), 10);

    start_x_global = round(data.c3d(n).TARGET_TABLE.X_GLOBAL(start_target_index), 10);
    start_y_global = round(data.c3d(n).TARGET_TABLE.Y_GLOBAL(start_target_index), 10);

    target_x_global = M_TO_CM * round(data.c3d(n).VCODE_3(index_end), 10);
    target_y_global = M_TO_CM * round(data.c3d(n).VCODE_4(index_end), 10);
    target_x = round((target_x_global - start_x_global), 10);
    target_y = round((target_y_global - start_y_global), 10);

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

    force_x_temp = data.c3d(n).Right_FS_ForceX;
    force_x_temp = force_x_temp(index_start:index_end);
 

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
    peak_vel = round(peak_vel, 10);
  
    time_pv = peak_idx / sample_freq;
    
    x_pv = x_temp(peak_idx);
    y_pv = y_temp(peak_idx);
    
    % same process as finding end point error angle
    % ABBY COMMENTED: only returns pos values 
    % reach_pv_vec = [x_pv y_pv] - [start_x_global start_y_global];
    % angle_pv = acos(dot(reach_pv_vec,target_vec) / (norm(reach_pv_vec) * norm(target_vec)));
    % angle_pv = rad2deg(angle_pv);
    
    target_angle = atan2d(target_y_global - start_y_global, target_x_global - start_x_global);
    target_angle = mod(target_angle, 360);
    target_angle = round(target_angle, 1);
    
    hand_pv_angle = atan2d(y_pv - start_y_global, x_pv - start_x_global);
    angle_pv = hand_pv_angle - target_angle;
    angle_pv = atan2d(sind(hand_pv_angle - target_angle),cosd(hand_pv_angle - target_angle));     

    % round after calculations
    x_temp = round(x_temp, nth);
    y_temp = round(y_temp, nth);
    
    vel_x_temp = round(vel_x_temp, nth);
    vel_y_temp = round(vel_y_temp, nth);
    vel_temp = round(vel_temp, nth);
    
    angle_end = round(angle_end, 10);
    angle_pv = round(angle_pv, 10);
    
    distances_temp = round(distances_temp, nth);
    
    %force_x_temp = round(force_x_temp, nth);
    
    % convert to json
    x{n} = string(jsonencode(x_temp));
    y{n} = string(jsonencode(y_temp));
    
    vel_x{n} = string(jsonencode(vel_x_temp));
    vel_y{n} = string(jsonencode(vel_y_temp));
    vel{n} = string(jsonencode(vel_temp));
    
    distances{n} = string(jsonencode(distances_temp));
    
    %force_X{n} = string(jsonencode(force_x_temp));
    
    % concat to list  
    rts = [rts; {rt}];
    mts = [mts;{mt}];
    feedbacks = [feedbacks; {feedback}];
    
    % target_xs = [target_xs; {target_x}];
    % target_ys = [target_ys; {target_y}];
    % % 
    % start_xs = [start_xs; {start_x}];
    % start_ys = [start_ys; {start_y}];

    target_angles = [target_angles; {target_angle}];
    
    hand_angles = [hand_angles; {angle_end}];
    hand_angles_pv = [hand_angles_pv;{angle_pv}];

    target_x_globals = [target_x_globals; {target_x_global}];
    target_y_globals = [target_y_globals; {target_y_global}];
     
    start_x_globals = [start_x_globals; {start_x_global}];
    start_y_globals = [start_y_globals; {start_y_global}];
    
    peak_vels = [peak_vels; {peak_vel}];
    time_pvs = [time_pvs; {time_pv}];
    
end

x = x';
y=y';
vel_x=vel_x';
vel_y=vel_y';
vel=vel';
distances=distances';
force_X = force_X';

% Now safe to horizontally concatenate
t1 = [x, y, vel_x, vel_y, vel, peak_vels, time_pvs, hand_angles_pv, distances, rts, mts, hand_angles, ...
   feedbacks, target_x_globals, target_y_globals, target_angles, start_x_globals, start_y_globals];


T = array2table(t1, 'VariableNames', {'x', 'y', 'vel_x', 'vel_y', 'vel', 'peak_vel', 'time_pv', ...
 'theta_pv', 'dist_to_start', 'rt', 'mt', 'theta_end', 'feedback', 'target_x_global', 'target_y_global', ...
 'target_angle', 'start_x_global', 'start_y_global'});

% folderPath = '/Users/abbysun/Documents/github_abby/UDL_abby/csv_files';
folderPath = '/Users/abbysun/Desktop';

fileName = fullfile(folderPath, output_file);

writetable(T, fileName, 'Delimiter', ',');
