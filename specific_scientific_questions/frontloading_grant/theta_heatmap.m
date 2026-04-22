function theta_heatmap(t)
% Set up bins edges for heatmap (mm)
bin_size = 10; % size in mm
max_x = 210;
max_y = 120;
x_edges = -max_x:bin_size:max_x;
y_edges = -max_y:bin_size:max_y;
% smooth_mm = 10; % mm for gausian smoothing sigma 
% t_thresh = 0.5; % time (s) required to be considered reliable
c_lim = [-1.1 1.1];


for i=1:height(t) 
    tracking = t.tracking{i};
    poi = t.poi{i};
    tracking = tracking(tracking.time>0 & tracking.time<60*60, :); %limit to 1 hr post sipper

    %% Bin head position
    [~,~,~,binX,binY] = histcounts2(tracking.head_midpoint_x,tracking.head_midpoint_y, x_edges, y_edges);
    map = cell(length(y_edges)-1, length(x_edges)-1);

    for ii=1:height(tracking)
        if binY(ii)~=0 & binX(ii)~=0
            map{binY(ii),binX(ii)} = cat(1, map{binY(ii),binX(ii)}, tracking.theta(ii));
        end
    end

    map = cellfun(@mean, map);

    %% Plot position heatmap
    figure(1);hold on
    subplot(2,2,i);
    heatmat_plot(x_edges,y_edges, map, poi, "Theta power (dB)")
    title(sprintf("%s", t.id(i)))
end
end