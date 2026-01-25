%%
job_folder = pwd;
video_table = load_video_csv(job_folder);

% Only run analysis on TACpilot videos
video_table = video_table(contains(video_table.pi_folder, "_TACpilot_"), :);

% skip rows without a local video path
missing_video = cellfun(@isempty, video_table.local_path);
video_table = video_table(~missing_video,:); 

% Set up bins edges for heatmap (mm)
bin_size = 2; % size in mm
max_x = 250;
max_y = 100;
x_edges = -max_x:bin_size:max_x;
y_edges = -max_y:bin_size:max_y;

% preallocate arrays to save data over sessions
all_pos = nan(length(x_edges)-1,length(y_edges)-1, height(video_table));
all_angle = all_pos;
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
    [pos_binned,~,~,binX,binY] = histcounts2(pos(:,1), pos(:,2), x_edges, y_edges);
    pos_binned = pos_binned ./ height(pos); %Convert to proportion of session time in each bin
    outside = binX==0 | binY==0; % A value of 0 indicates an element that does not belong to any of the bins
    
    % Get gaze angle and average in bins
    angle = calc_gaze_angle(tracking_mm);
    bin_inds = [binX,binY];
    bin_inds = bin_inds(~outside,:); %remove those outside the bins
    angle = angle(~outside);%remove those outside the bins
    angle_binned = accumarray(bin_inds, angle, size(pos_binned), @mean_degrees, nan);
    
    % plot
    subplot(2,1,1); img_nan(x_edges,y_edges,pos_binned); colorbar; title("position")
    subplot(2,1,2); img_nan(x_edges,y_edges,angle_binned); colorbar; title("angle")

    % save this session in preallocated array
    all_pos(:,:,ind) = pos_binned; 
    all_angle(:,:,ind) = angle_binned; 

    
    % % %%%%% In progress!! Getting trials and syncing to Med data %%%
    % video = load_video(job_folder,id);
    % [video_times, video_frames] = extract_2CAP_trials(video_table.pi_folder{ind}); % These times seem wrong when playing the videos in the loop below.
    % med = load_med(video_table.pi_folder{ind}); % None of the med arrays seem to match the length of the sync events in the pi gpio csv file
    % 
    % for ind_t = 1:length(video_times) % Loop through trials and play video clips
    %     start = video_times(ind_t)-10;
    %     stop = video_times(ind_t)+10;
    %     figure(1); clf;
    %     play_video(video, start, stop)
    % end
    % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
%%
pos_avg = mean(all_pos(:, :, [8 9 11]), 3);
angle_avg = mean_degrees(all_angle(:, :,[8 9 11]), 3, Weights=all_pos(:,:,[8 9 11]));
figure;
% plot
t = tiledlayout(2,1); % Create a 1x2 tiled layout
ax1 = nexttile;
img_nan(x_edges,y_edges,pos_avg);
title("position")
xlabel('mm from center'); ylabel('mm from center')
clim([0 1e-3])

ax2 = nexttile;
img_nan(x_edges,y_edges,angle_avg);
title("angle")
xlabel('mm from center'); ylabel('mm from center')

%use circular colormap for angles
% jet_wrap = vertcat(jet,flipud(jet));
% colormap(ax2, jet_wrap);
colormap(ax2, cardinal_circular_colormap());

%% export to .mat
pos_avg10mm = mean(all_pos(:, :, [8 9 11]), 3);
angle_avg10mm = mean_degrees(all_angle(:, :,[8 9 11]), 3, Weights=all_pos(:,:,[8 9 11]));
pos_avg125mm = mean(all_pos(:, :, [31 33 35]), 3);
angle_avg125mm = mean_degrees(all_angle(:, :,[31 33 35]), 3, Weights=all_pos(:,:,[31 33 35]));
save ('tacCPPHeatmapsK99.mat', "pos_avg10mm","angle_avg10mm","pos_avg125mm","angle_avg125mm")


%% Sanity check angle calculation
% Correction!!
% +90 == Down
% -90 == Up

figure(101); clf;
video = load_video(job_folder,id);
index = 1000:2000;
for i=index
    frame = rgb2gray(read(video, i));
    imagesc(frame)
    title(angle(i))
end
%%

% 
% 
%     for ind_t = 1:length(video_times) % Loop through trials
% 
%         t=time(ind_t);
%         is_trial = tracking.time_oe>t-pre_time & tracking.time_oe<t+post_time;
%         trial = tracking(is_trial,:);
%         t_time = trial.time_oe - t;
% 
%         if is_left(ind_t)
%             light = poi{{'light_left'},:};
%             sipper = poi{{'sipper_left'}, :};
%         else
%             light = poi{{'light_right'},:};
%             sipper = poi{{'sipper_right'}, :};
%         end
% 
%         [~, interest_ind] = min(abs(t_time - t_of_interest));
%         color = repmat(c_wait, height(trial),1);
%         for i=1:length(light_start)
%             is_blinking = t_time>=light_start(i) & t_time<light_stop(i);
%             color(is_blinking,:) = repmat(c_light, sum(is_blinking), 1);
%         end
% 
%         sip_dist_pix = calc_dist_to_sipper(trial, sipper);
%         sip_dist_mm = sip_dist_pix*scale_factor(poi);
% 
%         approachInd = find(sip_dist_mm < 55);
%         if ~isempty(approachInd)
%             approachTime = trial.time_oe(approachInd(1,1));
%         else
%             approachTime = NaN;
%         end
% 
%         all_dist(ind, ind_t, :) = interp1(t_time, sip_dist_mm, common_time, 'linear','extrap');
%         allApproach(ind, ind_t) = approachTime;
%     end
% 
% end
% 
