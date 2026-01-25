function avg_angle = mean_degrees(angle, dim, opts)
    arguments
        angle
        dim = 1; % dimension to average accross
        opts.Weights = ones(size(angle));
    end
    avg_x = mean(sind(angle), dim, 'omitmissing', Weights=opts.Weights);
    avg_y = mean(cosd(angle), dim, 'omitmissing', Weights=opts.Weights);
    
    avg_angle = rad2deg(atan2(avg_x,avg_y)) ;
end
