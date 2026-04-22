function loader_heatmaps(t, coeff_thresh)
% Set up bins edges for heatmap (mm)
bin_size = 10; % size in mm
max_x = 210;
max_y = 120;
x_edges = -max_x:bin_size:max_x;
y_edges = -max_y:bin_size:max_y;
smooth_mm = 10; % mm for gausian smoothing sigma 
t_thresh = 0.5; % time (s) required to be considered reliable
c_lim = [-1.1 1.1];

for i=1:height(t) 
    tracking = t.tracking{i};
    poi = t.poi{i};
    spikes = t.spikes{i};

    %% Bin head position
    pos_binned = histcounts2(tracking.head_midpoint_x,tracking.head_midpoint_y, x_edges, y_edges);
    pos_binned = pos_binned ./ 15; % divide by frame rate to get time spent in each bin
    pos_binned = imgaussfilt(pos_binned, smooth_mm/bin_size);

    %% Plot position heatmap
    figure(1);hold on
    subplot(2,2,i);
    heatmat_plot(x_edges,y_edges, pos_binned, poi, "Time (s)")
    title(sprintf("Head position \n%s", t.id(i)))

    %% Bin spike triggered positions 
    for ii=1:height(spikes)
        xy = spikes.xy{ii};
        counts = histcounts2(xy(:,1), xy(:,2), x_edges, y_edges);
        counts = imgaussfilt(counts, smooth_mm/bin_size);
        rate = counts ./ pos_binned;
        rate(pos_binned<t_thresh) = nan;

        rate = (rate - mean(rate(:),'omitnan')) / std(rate(:),'omitnan');
        spikes.xy_rate{ii} = rate;

        % figure(2); clf;
        % heatmat_plot(x_edges,y_edges,rate, poi, "Rate (Hz)")
        % title(sprintf("%s\nCluster %i", t.id(i), ii))
    end

    %% plot cluster average
    % figure(2);
    % subplot(2,2,i); hold on
    % avg_img = mean(cat(3, spikes.xy_rate{:}), 3);
    % heatmat_plot(x_edges,y_edges, avg_img, poi, "Rate (Hz)")
    % title(sprintf("Avg spike rate \n%s", t.id(i)))

    % Save spikes back into table
     t.spikes{i} = spikes;
end

%% Plot avg map for high coeff clusters
all_spikes = cat(1, t.spikes{:});

figure(11); clf
subplot(3,1,1)
positive = all_spikes.coeff>coeff_thresh;
avg_img = mean(cat(3, all_spikes.xy_rate{positive}), 3);
heatmat_plot(x_edges,y_edges, avg_img, poi, "Rate (std)")
title(sprintf("+ Coeff (N=%i)", sum(positive)))
clim([c_lim(1) c_lim(2)])

subplot(3,1,2)
null = abs(all_spikes.coeff)<coeff_thresh;
avg_img = mean(cat(3, all_spikes.xy_rate{null}), 3);
heatmat_plot(x_edges,y_edges, avg_img, poi, "Rate (std)")
title(sprintf("0 Coeff (N=%i)", sum(null)))
clim([c_lim(1) c_lim(2)])

subplot(3,1,3)
negative = all_spikes.coeff<-coeff_thresh;
avg_img = mean(cat(3, all_spikes.xy_rate{negative}), 3);
heatmat_plot(x_edges,y_edges, avg_img, poi, "Rate (std)")
title(sprintf("- Coeff (N=%i)", sum(negative)))
clim([c_lim(1) c_lim(2)])

end


