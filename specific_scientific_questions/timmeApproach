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
    fig_dir = "fig_attention/"+id;
    mkdir(fig_dir)

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

        figure(1); clf; hold on;
        % f= trial.frame(diff(t_time<-1)<0)+2; %last frame of CS+

        [~, interest_ind] = min(abs(t_time - t_of_interest));
        f= trial.frame(interest_ind); 
        display_frame(video_path, f)
        hold on;

        % scatter(light(:,1), light(:,2), 'filled','red')
        plot_corners(poi)
        text(light(:,1), light(:,2),'L',color="white",FontWeight='bold', HorizontalAlignment='center', VerticalAlignment='middle')
        text(sipper(:,1), sipper(:,2),'S',color="white",FontWeight='bold', HorizontalAlignment='center', VerticalAlignment='middle')
        % plot_gaze(pre_light, "magenta");
        % plot_gaze(mid_light, c_light);
        % plot_gaze(sip_wait, c_wait);
        % plot_gaze(sip_post, c_sip);
        color = repmat(c_wait, height(trial),1);
        for i=1:length(light_start)
            is_blinking = t_time>=light_start(i) & t_time<light_stop(i);
            color(is_blinking,:) = repmat(c_light, sum(is_blinking), 1);
        end

        is_S = t_time>=0 & t_time<8;
        color(is_S,:) = repmat(c_sip, sum(is_S), 1);
        plot_gaze(trial, color);
        xlim([1,640])
        ylim([1,480])
        daspect([1 1 1])
        %scale bar
        bar_length = 75;
        x=270;
        x = [x, x+bar_length/scale_factor(poi)];
        y=[375,375];
        plot(x,y, 'k', LineWidth=3, Color=[1,1,1])
        text(mean(x),y(1),'75 mm',FontWeight='bold',HorizontalAlignment='center',VerticalAlignment='bottom', Color=[1,1,1])
        title(sprintf("Video: %d \nTrial: %d", ind, ind_t))
        axis off

        gaze_angle = calc_gaze_angle(trial);
        light_angle = calc_angle_to_light(trial, light);
        gaze_diff =  gaze_angle - light_angle;
        % gaze_diff =  gaze_angle - calc_angle_to_light(trial, sipper);

        gaze_diff = abs(mod(gaze_diff+180,360)-180);

        sip_dist_pix = calc_dist_to_sipper(trial, sipper);
        sip_dist_mm = sip_dist_pix*scale_factor(poi);

        f2 = figure(2); clf; hold on;
        % light rectangle and text
        for i=1:length(light_start)
            width = light_stop(i) - light_start(i);
            rectangle(Position=[light_start(i),0,width,180], FaceColor=c_light, EdgeColor=c_light)
            % text(light_start(i)+width/2, 178, 'CS+', HorizontalAlignment='center', VerticalAlignment='top')
        end
         % wait rectangle
        rectangle(Position=[-1,0,1,180], FaceColor=c_wait, EdgeColor=c_wait)
        % sipper rectangle and text
        rectangle(Position=[0,0,8,180], FaceColor=c_sip, EdgeColor=c_sip)
        % text(post_time/2 , 178, 'sipper', HorizontalAlignment='center', VerticalAlignment='top')
        % plot gaze_diff
        plot(t_time, gaze_diff, LineWidth=3, Color=c_gaze)
        ylabel("Gaze offset from CS+ (°)", 'FontWeight', 'bold')
        ylim([0,180])
        % plot distance from sipper
        yyaxis right
        plot(t_time, sip_dist_mm, LineWidth=3, Color=c_dist)
        ylabel("Distance to sipper (mm)", 'FontWeight', 'bold')
        ylim([0 420])
        xlim([-pre_time,post_time])
        xlabel("time before sipper (s)", 'FontWeight', 'bold')
        ax = gca;
        ax.YAxis(1).Color = c_gaze;
        ax.YAxis(2).Color = c_dist;
        ax.YAxis(1).FontWeight= 'bold';
        ax.YAxis(2).FontWeight= 'bold';
        ax.XAxis.FontWeight= 'bold';
        title(sprintf("Video: %d \nTrial: %d", ind, ind_t))
        % xline(t_time(interest_ind), '--')
        set(gca, 'Layer','top')
        %pause(1);
        saveas(f2, sprintf('%s/trial_%02d.png',fig_dir, ind_t))

        % play video
        % figure(3); clf; hold on;
        % play_video(video_path, trial.time_video(1), trial.time_video(end))

        % Save interpolated gaze and distance
        all_gaze(ind, ind_t, :) = interp1(t_time, gaze_diff, common_time, 'linear','extrap');
        all_dist(ind, ind_t, :) = interp1(t_time, sip_dist_mm, common_time, 'linear','extrap');
    end
end




%% plot all gaze

all_gaze_unrap = squeeze(reshape(all_gaze, [],1,size(all_gaze,3)));
all_dist_unrap = squeeze(reshape(all_dist, [],1,size(all_dist,3)));

figure(4); clf; hold on

shadedErrorBar(common_time,all_gaze_unrap,{@mean,@sem},'lineProps',{'Color', c_gaze});
ylim([0 180])
yline(90, '--', Color=c_gaze)
ylabel("Gaze offset from CS+ (°)")

yyaxis right
shadedErrorBar(common_time,all_dist_unrap,{@mean,@sem},'lineProps',{'Color', c_dist});
ylim([0 420])
yline(210, '--', Color=c_dist)
ylabel("Distance to sipper (mm)")

xline(-1, Color=c_light)
xline(0, Color=c_sip)
xlabel("time before sipper (s)")

ax = gca;
ax.YAxis(1).Color = c_gaze;
ax.YAxis(2).Color = c_dist;

%% zoom in on y differences

yyaxis left; ylim([90-20, 90+20])
yyaxis right; ylim([210-40, 210+40])


function err = sem(x)
    err = std(x) / sqrt(size(x,1));
end



