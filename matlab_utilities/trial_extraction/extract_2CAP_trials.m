function [video_times, video_frames] = extract_2CAP_trials(pi_folder)
    %% get the datetime of each trial according to gpio sync signal
    sync_path = fullfile(pi_folder, "gpio", "*.csv");
    sync_path = wildcard_path(sync_path);
    sync_table = readtable(sync_path);
    
    is_trial_start = sync_table.Event==1 & sync_table.Pin==16;
    trial_time = string2datetime(sync_table.Time(is_trial_start));
    
    %% get video start time and frame times
    pts_path = fullfile(pi_folder, "cam", "*.pts");
    pts_path = wildcard_path(pts_path);
    start_time_video = date_from_filename(pts_path);
    
    %% Determine the time into the video for each trial
    video_times = seconds(trial_time - start_time_video);

    %% Find the corresonding frame for each time into the video
    frame_times = load(pts_path) / 1000; % convert from ms to s
    [~,nearest_inds] = min(abs(video_times'-frame_times));
    video_frames = frame_times(nearest_inds);
end
