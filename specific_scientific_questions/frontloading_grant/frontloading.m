 cd ('/home/lapishla/Desktop/temp_figs')
%% load table, force all variables as string to prevent issueTimes from getting formatted weird
job_folder = "/research/lapishla/frontloading_grant/";
csv = fullfile(job_folder,"matches.csv");

opts = detectImportOptions(csv, Delimiter=",");
opts = setvartype(opts, opts.SelectedVariableNames, 'string');
t = readtable(csv, opts);
[~, t.id, ~] = fileparts(t.raw_data_dir);
%% Set up bins

% Set up bins edges for heatmap (mm)
bin_size = 5; % size in mm
max_x = 210;
max_y = 120;
x_edges = -max_x:bin_size:max_x;
y_edges = -max_y:bin_size:max_y;
smooth_mm = 5; % mm for gausian smoothing sigma 
% spike bins
spk_bin_edges = -180:60:3800;
% Distance from sipper bins
d_edges = 0:bin_size:max_x*2;

timeDrinking = nan(height(t),1);
frame_rate = 15; 
figure(3); clf; hold on;
figure(2); clf; hold on;


% %% quickly find min and max start/stop
% start = -inf;
% stop = inf;
% for i=1:height(t) % Loop through videos
%     stream = load(fullfile(t.ephys_dir(i), "stream.mat"));
%     events = struct2table(load(fullfile(t.ephys_dir(i), "events.mat")).data);
%     stream.time = stream.time-events.timestamp(1);
%     start = max([start, stream.time(1)])
%     stop = min([stop, stream.time(end)])
% end
%%
all_spikes = cell(height(t),1);
all_sip_dist_rate = cell(height(t),1);
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
    stream = load(fullfile(t.ephys_dir(i), "stream.mat"));
    events = struct2table(load(fullfile(t.ephys_dir(i), "events.mat")).data);

    %% Apply quality metrics to spikes
    goodSpikes = spikes.firing_rate>0.1 & spikes.presence_ratio>0.9 & spikes.isi_violations_ratio<1.0 & spikes.amplitude_cutoff<.1;
    spikes = spikes(goodSpikes,:);
    fprintf("%.0f Percent cluster passed quality metrics \n", 100*mean(goodSpikes))
    %% Synchronize ephys and tracking
    tracking.time = tracking.frame/frame_rate;
    
    figure(4);
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
    get_video_offset_from_ephys( ...
        fixed_t, ...
        tracking.mid_back_x, ...
        stream.time, ...
        stream.traces(:,65) *x_mult ...
        );
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
    [tracking_mm, poi_mm] = tranform2universalCoords(tracking, poi, poi(["sipper_left", "sipper_right"],:));

    %% Get position and bin
    pos = calc_head_midpoint(tracking_mm);
    pos_binned = histcounts2(pos(:,1), pos(:,2), x_edges, y_edges);
    pos_binned = pos_binned ./ 15; % divide by frame rate to get time spent in each bin
    pos_binned = imgaussfilt(pos_binned, smooth_mm/bin_size);
    tracking_mm.head_midpoint_x = pos(:,1);
    tracking_mm.head_midpoint_y = pos(:,2);

    %% Plot position heatmap
    figure(1); clf; hold on;
    img_nan(x_edges,y_edges,pos_binned);
    c = colorbar;
    c.Label.String = "Time (s)";
    colormap('jet')
    title(sprintf("Head position \n%s\nFull session", t.id(i)))
    poi_name = ["sipper_left", "sipper_right"];
    scatter(poi_mm.X(poi_name), poi_mm.Y(poi_name), 'r','*')
    xlabel('mm')
    ylabel('mm')
    xlim([-max_x max_x])
    ylim([-max_y max_y])
    axis equal




    %% Plot distance to sipper histogram 
    figure(2);
    subplot(2,2,i); hold on
     sip_dist_L = calc_dist_to_sipper(tracking_mm, poi_mm{'sipper_left',:});
     sip_dist_R = calc_dist_to_sipper(tracking_mm, poi_mm{'sipper_right',:});


     binned_sip_dist_L = histcounts(sip_dist_L, d_edges) / 15;
     binned_sip_dist_R= histcounts(sip_dist_R, d_edges) / 15;
     

     stairs(d_edges(2:end), binned_sip_dist_L)
     stairs(d_edges(2:end), binned_sip_dist_R)
     xlabel("distance to sipper")
     ylabel("Time (s)")
     legend("correct","incorrect")
     xlim([0, d_edges(end)])

    % Estimate drinking from within threshold distance to sipper
    drink_thresh = 50;
    is_drinking = sip_dist_L<drink_thresh;

    % %% TroubleShoot isDrinking effectiveness at predicting drinking %%%%%%%%%%
    % video_file = fullfile(job_folder, "videos", t.id(i)+".mp4");
    % 
    % drink_frames = find(is_drinking);
    % for ii=11000:length(drink_frames)
    %     display_frame(video_file, drink_frames(ii))
    %     pause(1/100);
    % end
    % 
    % %%
    % figure(6); clf
    % plot(is_drinking)
    % %% get drink bout lengths

    %% Get head position for each spike

    figure(12)
    sip_dist_rate = nan(height(spikes), length(binned_sip_dist_L));
    for ii=1:height(spikes)
        xy = position_at_time(spikes.spike_times{ii}, tracking_mm, 'head_midpoint');
        spike_xy_binned = histcounts2(xy(:,1), xy(:,2), x_edges, y_edges);
        spike_xy_binned = imgaussfilt(spike_xy_binned, smooth_mm/bin_size);
        t_thresh = 0.5; % time (s) required to be considered reliable
        % 
        % figure(12); clf; hold on;
        % z = spike_xy_binned ./ pos_binned;
        % z(pos_binned<t_thresh) = nan;
        % img_nan(x_edges,y_edges, z); 
        % c=colorbar; 
        % c.Label.String = 'Spike rate (Hz)';
        % colormap('jet')
        % title(sprintf("Spike rate by position \n%s\ncluster# %i", t.id(i), ii))
        % poi_name = ["sipper_left", "sipper_right"];
        % scatter(poi_mm.X(poi_name), poi_mm.Y(poi_name), 'r','*')
        % plot_circle(poi_mm{'sipper_left',:}, drink_thresh)
        % plot_corners(poi_mm)
        % xlabel('mm')
        % ylabel('mm')
        % axis equal 
        % grid on
        % clim([0 prctile(z(:), 99)])
        % xlim([-max_x max_x])
        % ylim([-max_y max_y])
        % saveas(gcf,sprintf('heatmap_rate_%i_%i.png', i,ii))


        % Get distance to sipper for each spike
        figure(13); clf; hold on;
        v = xy-poi_mm{"sipper_left",:};
        spk_sip_dist = sqrt(sum(v.^2, 2));
        sta_count = histcounts(spk_sip_dist, d_edges) ;
        % rate_spk_dist_L = imgaussfilt(sta_count, smooth_mm/bin_size) ./ imgaussfilt(binned_sip_dist_L, smooth_mm/bin_size);
        rate_spk_dist_L = sta_count ./ binned_sip_dist_L;
        rate_spk_dist_L(binned_sip_dist_L<t_thresh) = nan;
        stairs(d_edges(1:end-1), rate_spk_dist_L)
        xlabel("Distance from sipper (mm)")
        ylabel("Spike Rate")
        title(sprintf("Spike rate by sipper distance \n%s\ncluster# %i", t.id(i), ii))

        sip_dist_rate(ii,:)=rate_spk_dist_L;
    end
    all_sip_dist_rate{i} = sip_dist_rate;


    %% Bin drinking
    % binds = discretize(tracking_mm.time, spk_bin_edges);
    % binned_drinking =  accumarray(binds(~isnan(binds)), is_drinking(~isnan(binds)), [length(spk_bin_edges) - 1, 1], @mean, 0);

    bin_window = 60; % in Hz
    binned_drinking = movmean(is_drinking, bin_window/diff(tracking_mm.time(1:2)));
    %% plot heatmat from streams to troubleshoot
    % figure(111); clf; hold on;
    % s_edges = -2^15: 2^8 : 0;
    % s_pos = double([stream.traces(:,65), stream.traces(:,67)]);
    % pos_binned = histcounts2(s_pos(:,1), s_pos(:,2), s_edges, s_edges);
    % pos_binned = pos_binned ./ height(s_pos); %Convert to proportion of session time in each bin
    % img_nan(s_edges,s_edges,pos_binned); colorbar; title("anymaze " +t.id(i))
    % c = colorbar;
    % xlim([min(s_edges) max(s_edges)])
    % ylim([min(s_edges) max(s_edges)])

    %%
    % bin spikes
    bin = @(x) {histcounts(x, spk_bin_edges) / diff(spk_bin_edges(1:2))};
    spk_rate = cellfun(bin, spikes.spike_times);
    spk_rate = cell2mat(spk_rate);
    % 
    % spk_rate(:, spk_bin_edges(1:end-1)<stream.time(1)) = NaN; % Zero any bins occur before recording started
    % spk_rate(:, spk_bin_edges(2:end)>stream.time(end)) = NaN;  % Zero any bins occur after recording stoped
    all_spikes{i} = spk_rate;

    % plot spikes vs drinking
    figure(3); hold on;
    subplot(2,2,i); hold on
    x = spk_bin_edges(1:end-1);
    yyaxis left


    % plot(tracking_mm.time, binned_drinking, Color=[0 0 0], LineWidth=2)
    % ylabel("Drinking rate ")

    [f,x_cdf] = ecdf(tracking_mm.time(is_drinking));
    plot(x_cdf,f, Color=[0 0 0], LineWidth=2)
    ylabel("Cumulative drinking")

    ylim([0,1])
    yyaxis right
    shadedErrorBar(x, spk_rate, {@mean, @sem}, 'lineProps', {'Color', [0 0 1]})
    ylabel("Spike rate (Hz)")
    xlabel("Time (s)")

    xlim([min(x) max(x)]);
    xline(0, '--k')

    ax = gca();
    ax.YAxis(1).Color = [0 0 0];
    ax.YAxis(2).Color = [0 0 1];

    %% Make spectrograms
    figure(5);
    subplot(2,2,i); hold off;
    widow = 5; %Window time in Hz
    is_ch = contains({stream.channels.channel_names}, 'CH');
    avg_ch = mean(stream.traces(:,is_ch), 2);
    avg_ch = zscore(avg_ch);

    F = 0:.5:40;
    [~,~,T,P] = spectrogram(avg_ch,widow*1000,[],F, 1000, 'psd');
    dB = 10*log10(P);
    T =  T + stream.time(1);

    imagesc(T,F,dB)
    set(gca,'YDir','normal')
    ylabel("Frequency (Hz)")
    xlabel("Time (s)")

    xline(0, '--k')
    colormap('jet')

    C = colorbar();
    C.Label.String = "dB/Hz";

    %% Plot theta power vs time at sipper
    figure(7);
    subplot(2,2,i); hold off;
    min_F = 4;
    max_F = 8;
    theta = mean(dB(F>min_F & F<max_F, :));

    yyaxis right
    plot(T, theta, Color=[0 0 1], LineWidth=2)
    ylabel(sprintf("%.1f-%.1f Hz power (dB/Hz)", min_F,max_F))
    ylim([-40 -10])

    yyaxis left
    plot(tracking_mm.time, binned_drinking, Color=[0 0 0], LineWidth=2)
    ylabel("Drinking rate ")

        ax = gca();
    ax.YAxis(1).Color = [0 0 0];
    ax.YAxis(2).Color = [0 0 1];
    xline(0, '--k')
    xlim([T(1) T(end)])

    % %%  PCA analysis
    % valid_times = ~isnan(spk_rate(1,:));
    % score_times = spk_bin_edges(1:end-1);
    % score_times = score_times(valid_times);
    % vals = zscore(spk_rate(:,valid_times), [], 1);
    % 
    % [coeff, score, ~, ~, explained] = pca(vals');
    % 
    % %% 2. Scree Plot
    % figure(8);
    % subplot(2,2,i); hold off;
    % bar(explained, 'FaceColor', [0.2 0.4 0.8]);
    % xlabel('Principal Component');
    % ylabel('Variance Explained (%)');
    % title('Scree Plot');
    % grid on;
    % 
    % %% 3. Plot first X PCA scores using time vector
    % Xscores = 3;
    % 
    % figure(9);
    % subplot(2,2,i); hold off;
    % plot(score_times, score(:,1:Xscores), 'LineWidth', 1.5);
    % xlabel('Time (s)');
    % ylabel('Score (std)');
    % if i==1
    %     legend(arrayfun(@(k) ['PC ' num2str(k)], 1:Xscores, 'UniformOutput', false));
    % end
    % grid on;
    % xlim([score_times(1), score_times(end)])
    % 
    % %% 4. Histogram of coefficients for PCA component k
    % k = 1;
    % 
    % figure(10);
    % subplot(2,2,i); hold off;
    % histogram(coeff(:,k), 10);
    % xlabel('Loading Value');
    % ylabel('Count');
    % title(['Histogram of PCA Coefficients for PC ' num2str(k)]);
    % grid on;

    %% Save values
    timeDrinking(i) = mean(is_drinking(tracking_mm.time>0));
end
%%
all_spikes = cell2mat(all_spikes);
%% Run PCA on all_spikes
all_z = zscore(all_spikes, [], 2);
[coeff, score, ~, ~, explained] = pca(all_z');

%% 2. Scree Plot
figure(8); clf
bar(explained, 'FaceColor', [0.2 0.4 0.8]);
xlabel('Principal Component');
ylabel('Variance Explained (%)');
grid on;

%% 3. Plot first X PCA scores using time vector
Xscores = 3;

figure(9); clf
x = spk_bin_edges(1:end-1);
plot(x, score(:,1:Xscores), 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Score (std)');
legend(arrayfun(@(k) ['PC ' num2str(k)], 1:Xscores, 'UniformOutput', false), AutoUpdate=false);
grid on;
xlim([x(1), x(end)])

xline(0,'--k')
yline(0,'--k')

%% 4. Histogram of coefficients for PCA component k
k = 1;

figure(10); clf
% histogram(coeff(:,k), 30);
% xlabel('Loading Value');
% ylabel('Count');
% title(sprintf('PC%i coefficients (histogram) ', k));
% grid on;

mountainPlot(coeff(:,k))
title(sprintf('PC%i coefficients (mountain plot) ', k));
xline(0,'--k')
xlabel('Loading Value');
ylabel('Folded probability')


%% spike train sorted by PCX
[~, sInd] = sort(coeff(:,k));

sorted_trains = all_z(sInd, :);
figure(11); clf;
x = spk_bin_edges(1:end-1);
imagesc(x, 1:height(all_spikes), sorted_trains)
xlabel('Time (s)')
ylabel(sprintf('Clusters sorted by PC%i', k))
c = colorbar;
c.Label.String = "Zscored spike rate";
colormap('jet')

%% Plot + and - loaders avg spike train
coeff_thresh = 0.01;
pos = coeff(:,k)>coeff_thresh;
neg = coeff(:,k)< -coeff_thresh;

figure(11); clf; hold on;

y=all_z(pos,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'blue'})
y=all_z(neg,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'red'})
legend(sprintf("+ coeff (N=%i)", sum(pos)),sprintf("- coeff (N=%i)", sum(neg)), "AutoUpdate","off")
title(sprintf('PC%i loaders (threshold=%.2f)', k, coeff_thresh))
ylabel('Zscored spike rate')
xlabel('Time (s)')
xline(0, '--k')
yline(0,'--k')
grid on


%% Correlation to time drinking vs consumed
figure(6);
total_drank = double(t.initial_bottle)-double(t.final_bottle) * .079;

subplot(2,1,1)
% scatter(timeDrinking, total_drank, 'filled')
mdl = fitlm(timeDrinking, total_drank);
plot(mdl)
xlim([0 .4])
ylim([0 max(total_drank)*1.4])
xlabel("Proportion of time at sipper")
ylabel("Total fluid consumed (g)")
legend(Location="northeast")
text(0.01,0, sprintf('R^2 = %f',mdl.Rsquared.Ordinary),VerticalAlignment="bottom", HorizontalAlignment="left")

title("")

mg_per_Kg = total_drank ./ double(t.animal_weight);

subplot(2,1,2)
% scatter(timeDrinking, mg_per_Kg, 'filled')
mdl = fitlm(timeDrinking, mg_per_Kg);
plot(mdl)
xlim([0 .4])
ylim([0 max(mg_per_Kg)*1.4])
xlabel("Proportion of time at sipper")
ylabel("Ethanol consumed (mg/kg)")
text(0.01,0, sprintf('R^2 = %f',mdl.Rsquared.Ordinary),VerticalAlignment="bottom", HorizontalAlignment="left")
title("")
legend(Location="northeast")
%%
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

function out = sem(x)
    out = std(x) / sqrt(height(x));
end

function center_dist = center_dist(x,y)
    center_dist = sqrt( center_diff2(x) + center_diff2(y) );
end
function d2 = center_diff2(x)
    x = double(x);
    c = min(x) + (max(x)-min(x))/2;
    d2 = (x - c).^2;
end


function mountainPlot(dataVector)
[f,x] = ecdf(dataVector); %Compute empirical cumulative distribution function 
f(f>0.5) = 1 - f(f>0.5); %For all cdf values above 0.5 (median) fold back down to 0
plot(x,f)
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

function plot_circle(xy, r)
    pos = [xy(1)-r, xy(2)-r, 2*r, 2*r];
    rectangle('Position', pos, 'Curvature', [1 1], LineStyle="--");
end