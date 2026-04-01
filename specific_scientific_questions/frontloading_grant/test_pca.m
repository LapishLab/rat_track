all_sip_dist_rate = cell2mat(all_sip_dist_rate);
good_times = ~any(isnan(all_sip_dist_rate));

all_sip_dist_rate = all_sip_dist_rate(:, good_times);
x = d_edges(2:end);
x = x(good_times);
%% Plot clusters
good_times2  = x<200;

%% Run PCA on all_spikes

all_z = zscore(all_sip_dist_rate(:,good_times2), [], 2);
x_dist = x(good_times2);
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
plot(x_dist, score(:,1:Xscores), 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Score (std)');
legend(arrayfun(@(k) ['PC ' num2str(k)], 1:Xscores, 'UniformOutput', false), AutoUpdate=false);
grid on;
xlim([0, x_dist(end)])

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


% spike train sorted by PCX
[~, sInd] = sort(coeff(:,k));

sorted_trains = all_z(sInd, :);
figure(11); clf;
x = spk_bin_edges(1:end-1);
imagesc(x_dist, 1:height(all_spikes), sorted_trains)
xlabel('distance from sipper (mm)')
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
function mountainPlot(dataVector)
[f,x] = ecdf(dataVector); %Compute empirical cumulative distribution function 
f(f>0.5) = 1 - f(f>0.5); %For all cdf values above 0.5 (median) fold back down to 0
plot(x,f)
end
