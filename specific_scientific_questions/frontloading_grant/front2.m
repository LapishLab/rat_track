%% load all data at once
clear
job_folder = "/research/lapishla/frontloading_grant/";
csv = fullfile(job_folder,"matches.csv");
t = load_data_table(csv);

%% Get table back but spike cluster now have coefficients for PCA1 (sipper distance)
t = sipperDist(t);

%% position heatmaps for positive loaders
coeff_thresh = .05;
loader_heatmaps(t, coeff_thresh)

%% heatmap of theta power by position
t = theta_position(t); % Get theta power for each tracking point
theta_heatmap(t)
%% Autocorrelation for all neurons
[lags, corrs, shuffs, all_spikes] = cluster_auto(t);
freq = 1./lags;

%% Get coeff groups

positive = all_spikes.coeff>coeff_thresh;
negative = all_spikes.coeff<-coeff_thresh;
null = abs(all_spikes.coeff)<coeff_thresh;

%% correlation - shuffled
clf; hold on
ex_ind = randi(height(corrs));

plot(lags, corrs(ex_ind, :))
plot(lags, shuffs(ex_ind, :))
legend('real', 'shuffled')
% yscale('log')
xlim([0 .5])
ylim([1e-3, .5])
%%
[~, fr_ind] = sort(all_spikes.firing_rate);
% [~, fr_ind] = sort(all_spikes.coeff);
% [~, fr_ind] = sort(theta);
x_max = .5;
clf
subplot(1,3,1)
imagesc(lags, 1:height(corrs), corrs(fr_ind, :))
title('real')
ylabel('Clusters (sorted by firing rate)')
xlim([0 x_max])
clim([0 .4])
colorbar

subplot(1,3,2)
imagesc(lags, 1:height(corrs), shuffs(fr_ind, :))
title('shuffled')
xlim([0 x_max])
clim([0 .4])
xlabel('Lag time (s)')
colorbar

subplot(1,3,3)
subtraced = corrs-shuffs;
imagesc(lags, 1:height(corrs), subtraced(fr_ind, :))
title('real - shuffled')
xlim([0 x_max])
clim([0 .1])
colorbar

%% Get theta power
isTheta = freq>6 & freq<11;
theta = mean(corrs(:,isTheta), 2) - mean(shuffs(:,isTheta), 2);
% theta = mean(corrs(:,isTheta), 2);

% Bar plot of theta correlation
clf
raw_data_error_bar(["Positive", "Null", "Negative"], {theta(positive), theta(null), theta(negative)}, bar_funcs={@mean, @sem})  

ylabel('6-11Hz Correlation-Shuffled')
%% scatter  theta vs coeff
clf 
scatter(all_spikes.coeff, theta, 'filled', MarkerFaceAlpha=0.8 )
xlabel('PC1 coefficients (close to sipper PC)')
ylabel('Theta metric (corr-shuffled for 6-11 Hz)')

xline(0,'--k')
yline(0,'--k')
%% Lag vs Correlation (split by loaders)
figure(1);clf; hold on;
y = corrs();

% y = zscore(corrs(:,2:end), [], 2); %Don't include 0 shift
y = corrs(:,2:end) - shuffs(:,2:end) ;
x = lags(2:end);  
shadedErrorBar(x,y(positive,:), {@mean,@sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
shadedErrorBar(x,y(negative,:), {@mean,@sem}, 'lineProps', {'Color', 'red', 'DisplayName',  sprintf('Negative loaders (N=%i)', sum(negative))})
shadedErrorBar(x,y(null,:), {@mean,@sem}, 'lineProps', {'Color', 'black', 'DisplayName',  sprintf('Null loaders (N=%i)', sum(null))})
legend(Location="northoutside", AutoUpdate="off")

x = -1 * lags(2:end);  %Also plot left side
shadedErrorBar(x,y(positive,:), {@mean,@sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
shadedErrorBar(x,y(negative,:), {@mean,@sem}, 'lineProps', {'Color', 'red', 'DisplayName',  sprintf('Negative loaders (N=%i)', sum(negative))})
shadedErrorBar(x,y(null,:), {@mean,@sem}, 'lineProps', {'Color', 'black', 'DisplayName',  sprintf('Null loaders (N=%i)', sum(null))})
%
% ylim([0 .2])
% xlim([0,40])
xlim([-.5 .5])
xlabel('Lag time (s)')
ylabel('Correlation - Shuffled')


%% Plot spiking throughout session
bin_width = 60;
spk_bin_edges = -180:bin_width:3800;
bin = @(x) {histcounts(x, spk_bin_edges) / bin_width};
spk_rate = cellfun(bin, all_spikes.spike_times);
spk_rate = cell2mat(spk_rate);
spk_rate = zscore(spk_rate,[],2);

figure(2); clf; hold on
x = spk_bin_edges(2:end)-bin_width/2;
shadedErrorBar(x,spk_rate(positive,:), {@mean,@sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
shadedErrorBar(x,spk_rate(negative,:), {@mean,@sem}, 'lineProps', {'Color', 'red', 'DisplayName',  sprintf('Negative loaders (N=%i)', sum(negative))})
shadedErrorBar(x,spk_rate(null,:), {@mean,@sem}, 'lineProps', {'Color', 'black', 'DisplayName',  sprintf('Null loaders (N=%i)', sum(null))})
legend(AutoUpdate="off")
xlim([min(x), max(x)])
xlabel('Time (s)')
ylabel('Spike rate (std)')

xline(0,'--k')
yline(0,'--k')

% %% Direct power spectrum of clusters
% st = all_spikes.spike_times;
% min_t = min(cellfun(@min, st));
% st = cellfun(@(x) 100*(x'-min_t), st, UniformOutput=false);
% st = st(1:3);
% st = cell2struct(st, 'times', 2);
% %%
% params = struct();
% params.Fs = 100;       % Sampling frequency
% params.tapers = [3 5];  % [Time-bandwidth product, Number of tapers]
% params.fpass = [0 40 ./params.Fs]; % Frequency range of interest
% params.trialave = 1;    % Average over trials (0 for single trial)
% prams.err = [1 .05];
% 
% % Compute spectrum directly from timestamps
% % t_spikes should be a column vector or structure
% [S, f] = mtspectrumpt(st, params);
% %%
% plot(f*params.Fs, S);
% xlabel('Frequency (Hz)'); ylabel('Power');
% title('Chronux Multitaper Spectrum (Point Process)');