function [lags, corrs, shuffs, all_spikes] = cluster_auto(t)
% Bin options
min_freq = .1;
bin_width = 0.005;
spk_bin_edges = -180:bin_width:3800;
n_shuff = 10;
% lag calculations
max_lag = round(1 / min_freq / bin_width);
lags = (0:max_lag) * bin_width;

%Get autocorrelation for all clusters
all_spikes = cat(1,t.spikes{:});
corrs = nan(height(all_spikes), length(lags));
shuffs = corrs;
for i=1:height(all_spikes)
    % Histcount but restrict by spikes close to the sipper
    is_close = all_spikes.sip_dist_L{i} > 50;
    all_times = all_spikes.spike_times{i};
    counts = histcounts(all_times(is_close), spk_bin_edges);

    r = xcorr(counts, max_lag, 'normalized');

    r_shuff = zeros(size(r));
    for ii=1:n_shuff
        shuff_counts = counts(randperm(numel(counts)));
        r_shuff = r_shuff + xcorr(shuff_counts, max_lag, 'normalized');
    end
    r_shuff = r_shuff / n_shuff;

    corrs(i,:) = r(max_lag+1:end);
    shuffs(i,:) = r_shuff(max_lag+1:end);

    fprintf('completed %i/%i', i, height(all_spikes))
end
end