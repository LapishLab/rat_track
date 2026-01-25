function [tracking_trans, poi_trans] = tranform2universalCoords(tracking, poi, reference_points)
    known_dist = 420; %known distance in mm
    known_points  = [-known_dist/2, 0; known_dist/2, 0];

    reference_points = table2array(reference_points);

    % Estimate the geometric transformation
    tform = fitgeotform2d(reference_points, known_points, "similarity");

    % Transform poi
    poi_trans = poi;
    poi_trans{:,:} = transformPointsForward(tform, table2array(poi));

    % Transform tracking points (just X and Y variables)
    variables = tracking.Properties.VariableNames;
    x_variables = variables(contains(variables,"_x"));
    y_variables = variables(contains(variables,"_y"));

    tracking_trans = tracking; % make a copy
    for i=1:length(x_variables)
        x_nm = x_variables{i};
        y_nm = y_variables{i};

        % Check that we correctly extracted the X&Y coordinates for the
        % same body part
        part_x = strrep(x_nm, "_x","");
        part_y = strrep(y_nm, "_y","");
        if part_x ~= part_y
            error("X and Y body parts not matching (%s & %s) \n", part_x, part_y)
        end

        % predict new XY
        xy = [tracking{:,x_nm}, tracking{:,y_nm}];
        xy = transformPointsForward(tform, xy);
        tracking_trans{:,x_nm} = xy(:,1);
        tracking_trans{:,y_nm} = xy(:,2);
    end
end