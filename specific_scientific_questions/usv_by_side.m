usv = load('/home/lapishla/Desktop/dlc/jobs/TAC/usv.mat');


job_folder = pwd;
video_table = load_video_csv(job_folder);

% Only run analysis on TACpilot videos
video_table = video_table(contains(video_table.pi_folder, "_TACpilot_"), :);

% skip rows without a local video path
missing_video = cellfun(@isempty, video_table.local_path);
video_table = video_table(~missing_video,:);

tac_freq = cell(height(video_table),1);
bar_freq = cell(height(video_table),1);
used = table();
for ind=1:height(video_table) % Loop through videos
    id = video_table.id{ind};
    poi = load_poi(job_folder, id);
    tracking = get_all_tracking(job_folder, id);
    [tracking_mm, poi_mm] = tranform2universalCoords(tracking, poi, poi(["sipper_left", "sipper_right"],:));
    
    % Mirror X so TAC is always on right
    if strcmp(video_table.tac_side{ind}, 'l')
        % multiply tracking x values by -1
        variables = tracking_mm.Properties.VariableNames;
        x_variables = variables(contains(variables,"_x"));
        tracking_mm{:,x_variables} = tracking_mm{:,x_variables} * -1;
        % multiply poi x values by -1 
        poi_mm.X = poi_mm.X * -1;
        % also swap POI labels around. I don't love this. But I can't think of something better.
        poi_mm({'light_left','light_right'},:) = poi_mm({'light_right','light_left'},:);
        poi_mm({'sipper_left','sipper_right'},:) = poi_mm({'sipper_right','sipper_left'},:);
        poi_mm({'corner_UL','corner_UR'},:) = poi_mm({'corner_UR','corner_UL'},:);
        poi_mm({'corner_LL','corner_LR'},:) = poi_mm({'corner_LR','corner_LL'},:);
    end

    % Get position and bin
    pos = calc_head_midpoint(tracking_mm);


    % Find matching USV session
    match = strcmp(video_table.pi_folder{ind}, usv.session_table.pi_folder);

    % Add USV times to tracking table
    id_parts = split(id, '_');
    time_str = join(id_parts(1:3), '_');
    video_start = datetime(time_str, 'InputFormat', 'yyyyMMdd_HHmmss_SSSSSS');

    
    vid2audio_t_offset = usv.session_table.time(match) - video_start;
    if seconds(vid2audio_t_offset) > 20
        warning("There seems to be a large difference in video and audio start time: %d", seconds(vid2audio_t_offset))
    end

    video = load_video(job_folder,id);

    v_time = video_start + seconds(tracking.frame ./ video.FrameRate);
    a_time = seconds(v_time - usv.session_table.time(match));

    calls = usv.session_table.calls{match};
    freq = calls.Box(:,2) + calls.Box(:,4)/2; 
    
    t_dif = a_time - calls.Box(:,1)';
    [~, frame_ind] = min(abs(t_dif));

    x_pos = tracking_mm.mid_back_x(frame_ind);

    tac_freq{ind} = freq(x_pos>0);
    bar_freq{ind} = freq(x_pos<0);

    used = cat(1,used,usv.session_table(match,:));
end
%%
which_sess = used.point==10

tac_cat = cat(1, tac_freq{which_sess});
bar_cat = cat(1, bar_freq{which_sess});

% Mountain plot
figure(1); clf; hold on
mountainPlot(tac_cat)
mountainPlot(bar_cat)
ylabel("Probability of more extreme")

xlabel("USV Frequency (kHz)")

legend("tac side","bar side")
xlim([20 80])

% PDF plot of same data, because easier for people to understand
figure(2); clf; hold on;
edges = 20:2:80;
[tacX, tacF] = pdf(tac_cat, edges);
[barX, barF] = pdf(bar_cat, edges);
legend("tac side","bar side")
xlabel("USV frequency (kHz)")


%%

[h, p] = kstest2(tac_cat, bar_cat);
%%

function mountainPlot(dataVector)
[f,x] = ecdf(dataVector); %Compute empirical cumulative distribution function 
f(f>0.5) = 1 - f(f>0.5); %For all cdf values above 0.5 (median) fold back down to 0
plot(x,f)
end

function [x, f] = pdf(d, edges)
    f = histcounts(d,edges, Normalization='pdf');
    x=edges(1:end-1) + diff(edges)/2;
    plot(x,f)

    ylabel("Probability density")
end