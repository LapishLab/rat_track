clear
sip_lines = [4,3]; % OE event lines corresponding to L and R sippers

%% set time of interest
pre_time = 6; %time before sipper (light should start 5s prior)
post_time = 9; %time after sipper (sipper stays out for 8s)
t_of_interest = -2.88;

% plot individual blinks?
% light_start = [-5;-4;-3;-2];
% light_stop = light_start+0.25;
light_start = -5;
light_stop = light_start+4;

%% set colors
c_light = [252,186,3]/255; % orange
c_wait = ones(1,3) * 1; % white
c_sip = [130,255,100]/255; % light green

c_gaze = [127,0,255]/255;% purple
c_dist = [0,102,204]/255; % cyan

%%
job_folder = pwd;
video_table = load_video_csv(job_folder);

% For getting average gaze and distance
common_time = -5:1/15:5;
all_gaze = zeros(height(video_table), 48, length(common_time));
all_dist = all_gaze;

for ind=1:height(video_table) % Loop through videos
    id = video_table.id{ind};
    video_path=[job_folder filesep 'videos' filesep id '.mp4'];

    % load OE events
    oe_events = load_oe_events(video_table.oe_export_folder{ind});
    poi = load_poi(job_folder, id);

    % load tracking (also loads oe time sync)
    tracking = get_all_tracking(job_folder, id);
    [time, is_left] = get_trial_times(oe_events, sip_lines);

    for ind_t = 1:length(time) % Loop through trials
        
        t=time(ind_t);
        is_trial = tracking.time_oe>t-pre_time & tracking.time_oe<t+post_time;
        trial = tracking(is_trial,:);
        t_time = trial.time_oe - t;
        
        if is_left(ind_t)
            light = poi{{'light_left'},:};
            sipper = poi{{'sipper_left'}, :};
        else
            light = poi{{'light_right'},:};
            sipper = poi{{'sipper_right'}, :};
        end

        [~, interest_ind] = min(abs(t_time - t_of_interest));
        color = repmat(c_wait, height(trial),1);
        for i=1:length(light_start)
            is_blinking = t_time>=light_start(i) & t_time<light_stop(i);
            color(is_blinking,:) = repmat(c_light, sum(is_blinking), 1);
        end

        sip_dist_pix = calc_dist_to_sipper(trial, sipper);
        sip_dist_mm = sip_dist_pix*scale_factor(poi);

        
        all_dist(ind, ind_t, :) = interp1(t_time, sip_dist_mm, common_time, 'linear','extrap');
    end
end


