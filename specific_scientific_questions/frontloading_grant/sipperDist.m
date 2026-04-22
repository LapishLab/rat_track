
function t = sipperDist(t)
%% Set up bins

bin_size = 5; % size in mm
smooth_mm = 5; % mm for gausian smoothing sigma
drink_thresh_dist = 50; % mm
max_x = 210; % mm
min_x = 20;

dist_bins = min_x:bin_size:max_x; % Distance from sipper bins
smth_sigma = smooth_mm/bin_size;

figure(1); clf;
figure(2); clf;


for i=1:height(t) % Loop through videos
    tracking = t.tracking{i};
    poi = t.poi{i};
    spikes = t.spikes{i};

    %% Pick distance from sipper threshold using histogram
    figure(1); hold on;
    subplot(2,2,i); hold on
    binned_sip_dist_L = histcounts(tracking.sip_dist_L, dist_bins) / 15;
    binned_sip_dist_R = histcounts(tracking.sip_dist_R, dist_bins) / 15;

    binned_sip_dist_L = imgaussfilt(binned_sip_dist_L, smth_sigma);
    binned_sip_dist_R = imgaussfilt(binned_sip_dist_R, smth_sigma);
     
    stairs(dist_bins(2:end), binned_sip_dist_L)
    stairs(dist_bins(2:end), binned_sip_dist_R)

    legend("correct","incorrect", AutoUpdate=false)
    xlabel("distance to sipper")
    ylabel("Time (s)")
    
    xlim([dist_bins(1), dist_bins(end)])
    xline(drink_thresh_dist, '--k')

    % Estimate drinking from within threshold distance to sipper
    is_drinking = tracking.sip_dist_L<drink_thresh_dist;

    %% Spike triggered sipper distance    
    bin_dist = @(x) imgaussfilt(histcounts(x, dist_bins), smth_sigma) ./  binned_sip_dist_L;
    spk_dist_rate_L = cellfun(bin_dist, spikes.sip_dist_L, UniformOutput=false);
    % bin_dist = @(x) imgaussfilt(histcounts(x, dist_bins), smth_sigma) ./  binned_sip_dist_R;
    % spk_dist_rate_R = cellfun(bin_dist, spikes.sip_dist_R, UniformOutput=false);

    spikes.dist_rate = cell2mat(spk_dist_rate_L);

    figure(2); hold on; subplot(2,2,i); 
    imagesc(spikes.dist_rate)
    colorbar

   %% save back into table
   spikes.session_id = repmat(t.id(i), height(spikes),1);
   t.spikes{i} = spikes;
end


%% Concatonate all spikes and distance traces and zscore
all_spikes = cat(1, t.spikes{:});
dist_rate = zscore(all_spikes.dist_rate, [], 2);

figure(2); clf
imagesc(dist_bins, 1:height(dist_rate), dist_rate)
colorbar

%% Perform PCA
[coeff, score, ~, ~, explained] = pca(dist_rate');



%% Scree Plot
figure(3); clf
bar(explained);
xlabel('Principal Component');
ylabel('Variance Explained (%)');

%% Plot first X PCA scores
num_PCs = 3;

figure(4); clf
x = dist_bins(2:end) - diff(dist_bins)/2;
plot(x, score(:,1:num_PCs), 'LineWidth', 1.5);

legend(arrayfun(@(k) ['PC ' num2str(k)], 1:num_PCs, 'UniformOutput', false), AutoUpdate=false);
xlim([x(1), x(end)])
grid on;
xline(0,'--k')
yline(0,'--k')
xlabel('Distance from sipper (mm)');
ylabel('Score (std)');

%% Histogram of coefficients for PCA component k
k = 1;

figure(5); clf
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


%% Save coeff values back into spikes
all_spikes.coeff = coeff(:,k);
for i=1:height(t)
     is_session = strcmp(all_spikes.session_id, t.id(i));
     t.spikes{i} = all_spikes(is_session,:);
end

%% spike train sorted by PCX
[~, sInd] = sort(coeff(:,k));

sorted_trains = dist_rate(sInd, :);
figure(6); clf;
% x = spk_bin_edges(1:end-1);
imagesc(dist_bins, 1:height(all_spikes), sorted_trains)
xlabel('distance from sipper (mm)')
ylabel(sprintf('Clusters sorted by PC%i', k))
c = colorbar;
c.Label.String = "Zscored spike rate";
colormap('jet')

%% Plot + and - loaders avg spike train
coeff_thresh = 0.01;
pos = coeff(:,k)>coeff_thresh;
neg = coeff(:,k)< -coeff_thresh;

figure(7); clf; hold on;
% x = 
y=dist_rate(pos,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'blue'})
y=dist_rate(neg,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'red'})
legend(sprintf("+ coeff (N=%i)", sum(pos)),sprintf("- coeff (N=%i)", sum(neg)), "AutoUpdate","off")
title(sprintf('PC%i loaders (threshold=%.2f)', k, coeff_thresh))
ylabel('Zscored spike rate')
xlabel('Time (s)')
xline(0, '--k')
yline(0,'--k')
grid on


end