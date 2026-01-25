function [tracking_trans, poi_trans] = tranform2universalCoords(tracking, poi, reference_points)
    known_dist = 420; %known distance in mm
    % TODO: peform rotational transformation. Right now it assumes horizonal video
    
    % Transform by moving to center of reference and scaling by X distance
    center_ref = mean(reference_points);
    scale_ref = range(reference_points.X); %Only scaling by X. Also assumes only 2 reference points
    scale = known_dist/scale_ref;

    % Transform poi
    poi_trans = (poi - center_ref) .* scale;

    % Transform tracking points (just X and Y variables)
    variables = tracking.Properties.VariableNames;
    x_variables = variables(contains(variables,"_x"));
    y_variables = variables(contains(variables,"_y"));

    tracking_trans = tracking; % make a copy
    tracking_trans(:,x_variables) = (tracking(:,x_variables)-center_ref.X) ./ scale;
    tracking_trans(:,y_variables) = (tracking(:,y_variables)-center_ref.Y) ./ scale;
end