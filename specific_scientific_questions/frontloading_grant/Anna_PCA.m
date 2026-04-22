%% Plot spiking throughout session
bin_width = 60;
spk_bin_edges = -180:bin_width:3800;
bin = @(x) {histcounts(x, spk_bin_edges) / bin_width};
spk_rate = cellfun(bin, all_spikes.spike_times);
spk_rate = cell2mat(spk_rate);
spk_rate = movmean(spk_rate, 3, 2);
spk_rate = zscore(spk_rate,[],2);

% figure(2); clf; hold on
% x = spk_bin_edges(2:end)-bin_width/2;
% shadedErrorBar(x,spk_rate(positive,:), {@mean,@sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
% shadedErrorBar(x,spk_rate(negative,:), {@mean,@sem}, 'lineProps', {'Color', 'red', 'DisplayName',  sprintf('Negative loaders (N=%i)', sum(negative))})
% shadedErrorBar(x,spk_rate(null,:), {@mean,@sem}, 'lineProps', {'Color', 'black', 'DisplayName',  sprintf('Null loaders (N=%i)', sum(null))})
% legend(AutoUpdate="off")
% xlim([min(x), max(x)])
% xlabel('Time (s)')
% ylabel('Spike rate (std)')
% 
% xline(0,'--k')
% yline(0,'--k')



%% Run PCA on all_spikes
[coeff, score, ~, ~, explained] = pca(spk_rate');

%% 2. Scree Plot
figure(1); clf
bar(explained, 'FaceColor', [0.2 0.4 0.8]);
xlabel('Principal Component');
ylabel('Variance Explained (%)');
grid on;

%% 3. Plot first X PCA scores using time vector
Xscores = 3;

figure(2); clf
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
coeff_thresh = 0.03;

figure(3); clf
% histogram(coeff(:,k), 30);
% xlabel('Loading Value');
% ylabel('Count');
% title(sprintf('PC%i coefficients (histogram) ', k));
% grid on;

mountainPlot(coeff(:,k))
title(sprintf('PC%i coefficients', k));
xline(0,'-k')
xlabel('Loading Value');
ylabel('Folded probability')
xline(coeff_thresh, '--k')
xline(-coeff_thresh, '--k')
% spike train sorted by PCX
[~, sInd] = sort(coeff(:,k));

xlim([-.15 .15])

%% Plot + and - loaders avg spike train

positive = coeff(:,k)>coeff_thresh;
negative = coeff(:,k)< -coeff_thresh;
null =  coeff(:,k)<coeff_thresh & coeff(:,k)> -coeff_thresh;



figure(4); clf; hold on;

x = spk_bin_edges(2:end) / 60;
y=spk_rate(positive,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
y=spk_rate(negative,:);
shadedErrorBar(x, y, {@mean, @sem}, 'lineProps', {'Color', 'red','DisplayName', sprintf('Negative loaders (N=%i)', sum(negative))})

shadedErrorBar(x, spk_rate(null,:), {@mean, @sem}, 'lineProps', {'Color', 'black', 'DisplayName', sprintf('Null loaders (N=%i)', sum(null))})
legend(AutoUpdate="off")
% legend(sprintf("+ coeff (N=%i)", sum(pos)),sprintf("- coeff (N=%i)", sum(neg)), "AutoUpdate","off")
title(sprintf('PC%i loaders (threshold=%.3f)', k, coeff_thresh))
ylabel('Firing rate (z-scored)')
xlabel('Time (minutes)')
xline(0, '--k')
yline(0,'--k')
grid on

%% PC1 coeff vs sip_dist

figure(5); clf;
% scatter(coeff(:,k) , all_spikes.amplitude_median, '.')
scatter(coeff(:,k) , all_spikes.coeff, '.')
xlabel('Coefficients related to drinking early in session')
ylabel('Coefficient related to firing when close to sipper')


%% waveform

w = cellfun(@get_wave, all_spikes.waveform, UniformOutput=false);
w = cell2mat(w')';



%

figure(5);
subplot(1,3,1)
imagesc(w(positive,:))
title('positive')
subplot(1,3,2)
imagesc(w(null,:))
title('null')
subplot(1,3,3)
imagesc(w(negative,:))
title('negative')
%%
figure(6); clf; hold on
% plot(w(:,ind))

x = 1:width(w);

shadedErrorBar(x, w(positive,:), {@mean, @sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
shadedErrorBar(x, w(negative,:), {@mean, @sem}, 'lineProps', {'Color', 'red','DisplayName', sprintf('Negative loaders (N=%i)', sum(negative))})
shadedErrorBar(x, w(null,:), {@mean, @sem}, 'lineProps', {'Color', 'black', 'DisplayName', sprintf('Null loaders (N=%i)', sum(null))})
legend()

%%

%%
[~, ind_min] = min(w');
good_w = ind_min > 25 & ind_min < 37;
good_w = good_w';
%
figure(5);
subplot(1,3,1)
imagesc(w(positive & good_w,:))
title('positive')
subplot(1,3,2)
imagesc(w(null & good_w,:))
title('null')
subplot(1,3,3)
imagesc(w(negative & good_w,:))
title('negative')
%%
figure(6); clf; hold on
% plot(w(:,ind))

x = (1:width(w)) ./ 10;

shadedErrorBar(x, w(positive&good_w,:), {@mean, @sem}, 'lineProps', {'Color', 'blue', 'DisplayName', sprintf('Positive loaders (N=%i)', sum(positive))})
shadedErrorBar(x, w(negative&good_w,:), {@mean, @sem}, 'lineProps', {'Color', 'red','DisplayName', sprintf('Negative loaders (N=%i)', sum(negative))})
shadedErrorBar(x, w(null&good_w,:), {@mean, @sem}, 'lineProps', {'Color', 'black', 'DisplayName', sprintf('Null loaders (N=%i)', sum(null))})
legend()

ylabel('Zscored voltage')
xlabel('Time (ms)')
%%

function w = get_wave(w)
    [~, ind] = max(std(w));
    w = w(:,ind);
    w = zscore(w);
    % if max(w) > abs(min(w))
    %     w = w *-1;
    % end
end

