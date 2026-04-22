
function t = load_data_table(csv)

opts = detectImportOptions(csv, Delimiter=",");
opts = setvartype(opts, opts.SelectedVariableNames, 'string');
t = readtable(csv, opts);
[~, t.id, ~] = fileparts(t.raw_data_dir);

job_folder = fileparts(csv);

for i=1:height(t) % Loop through videos
    % load POI
    poi_file = fullfile(job_folder,"poi", t.id(i)+"_poi.csv");
    poi = readtable(poi_file,  'Delimiter', ',', 'ReadRowNames', true);

    % load tracking
    tracking_file = fullfile(job_folder, "dlc-results_dlc-ephys_shuff1", t.id(i), "*_filtered.csv");
    tracking_file = struct2table(dir(tracking_file));
    tracking_file = fullfile(tracking_file.folder,tracking_file.name);
    tracking = load_tracking_csv(tracking_file, [2,3]);

    %% Load ephys
    spikes = load(fullfile(t.ephys_dir(i), "spikes.mat"));
    spikes = struct2table(spikes.clusters);
    spikes = sortrows(spikes,"amplitude_median","ascend");
    stream = load(fullfile(t.ephys_dir(i), "stream.mat"));
    events = struct2table(load(fullfile(t.ephys_dir(i), "events.mat")).data);

    %% Apply quality metrics to spikes
    goodSpikes = spikes.firing_rate>0.1 & spikes.presence_ratio>0.9 & spikes.isi_violations_ratio<1.0 & spikes.amplitude_cutoff<.1;
    spikes = spikes(goodSpikes,:);
    fprintf("%.0f Percent cluster passed quality metrics \n", 100*mean(goodSpikes))

    %% Get video info
    video_file = fullfile(job_folder, "videos", t.id(i)+".mp4");
    vid_reader = VideoReader(video_file);
    %% Synchronize ephys and tracking
    tracking.time = tracking.frame/vid_reader.FrameRate;
    
    figure(1);
    ax = subplot(2,2,i);
    cla(ax); hold on
    title(t.id(i))
    % Only Use X
    if t.flip_xy(i)=="1"
        x_mult = -1;
    else
        x_mult = 1;
    end

    offset = get_video_offset_from_ephys( ...
        tracking.time , ...
        tracking.mid_back_x, ...
        stream.time, ...
        stream.traces(:,65) *x_mult ...
        );
    fixed_t = tracking.time - offset;

    % sanity check syncing
    % get_video_offset_from_ephys( ...
    %     fixed_t, ...
    %     tracking.mid_back_x, ...
    %     stream.time, ...
    %     stream.traces(:,65) *x_mult ...
    %     );
    m_spike = max(cellfun(@max, spikes.spike_times));
    if abs(m_spike - fixed_t(end)) > abs(m_spike - tracking.time(end))
        warning("last spike is farther from last tracking than before syncing")
    end

    %% Fix all times (shift all time by sipper out)
    tracking.time = fixed_t - events.timestamp(1);
    for ii=1:height(spikes)
        spikes.spike_times{ii} = spikes.spike_times{ii}-events.timestamp(1);
    end

    stream.time = stream.time-events.timestamp(1);
    events.timestamp = events.timestamp - events.timestamp(1);

    %% Transform coordinates
    [tracking_mm, poi_mm, tform] = tranform2universalCoords(tracking, poi, poi(["sipper_left", "sipper_right"],:));

    %% Various tracking calculations
    % Calculate head midpoint
    pos = calc_head_midpoint(tracking_mm);
    tracking_mm.head_midpoint_x = pos(:,1);
    tracking_mm.head_midpoint_y = pos(:,2);

    % Sipper Distance
    tracking_mm.sip_dist_L = calc_dist_to_sipper(tracking_mm, poi_mm{'sipper_left',:});
    tracking_mm.sip_dist_R = calc_dist_to_sipper(tracking_mm, poi_mm{'sipper_right',:});

    %% Spike triggered position calculations
    for ii=1:height(spikes)
        % xy position
        spikes.xy{ii} = position_at_time(spikes.spike_times{ii}, tracking_mm, 'head_midpoint');

        % distance from sippers
        v = spikes.xy{ii} -poi_mm{"sipper_left",:};
        spikes.sip_dist_L{ii} = sqrt(sum(v.^2, 2));

        v = spikes.xy{ii} -poi_mm{"sipper_right",:};
        spikes.sip_dist_R{ii} = sqrt(sum(v.^2, 2));
    end
    %% save to table
    t.tracking{i} = tracking_mm;
    t.poi{i} = poi_mm;
    t.events{i} = events;
    t.stream{i} = stream;
    t.spikes{i} = spikes;
    t.vid_reader{i} = vid_reader;
    t.img_transform{i} = tform;


end



end

function offset = get_video_offset_from_ephys(v_time, v_pos, e_time, e_pos)
    % sr_vid = round(1/diff(v_time(1:2)));
    % sr_ephys = round(1/diff(e_time(1:2)));

    e_pos = double(e_pos);
    % Downsample ephys position to match sample rate of video
    e_time_down = min(e_time): diff(v_time(1:2)) : max(e_time);
    % e_pos_lowpass = lowpass(e_pos, sr_vid, sr_ephys);
    e_pos_down = interp1(e_time, e_pos, e_time_down, "nearest", 'extrap');

    %% run cross correlation to find offset of peak
    [r, lags] = xcorr(zscore(v_pos), zscore(e_pos_down));
    % peak at positive lag value = ephys occurs after video
    lags = lags * diff(v_time(1:2)); % convert lags to seconds
    lags = lags + v_time(1) - e_time_down(1); %shift lags to account for video or ephys not starting at 0
    [~, max_ind] = max(r);
    offset = lags(max_ind);

    %% plot
    plot(lags,r)
    % xline(0,'--k')
    % yline(0,'--k')
    % xlim([offset-5, offset+5])
    xlabel('Lags (s)')
    ylabel({'Xcorr', 'DLC vs ephys'})
end
function xy = position_at_time(times, tracking, bodypart)
    bodypart = string(bodypart);
    times(times < min(tracking.time) | times > max(tracking.time) ) = []; % drop any times outside of our video tracking times

    track_x = tracking{:, bodypart+"_x"};
    x = interp1(tracking.time, track_x, times, 'linear');
    
    track_y = tracking{:, bodypart+"_y"};
    y = interp1(tracking.time, track_y, times, 'linear');

    xy = cat(2,x(:),y(:));
end