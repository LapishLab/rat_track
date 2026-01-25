function full_colormap = cardinal_circular_colormap()

key_directions = [
    "Left";
    "Up";
    "Right";
    "Down";
    "Left";
    ];

key_angles = [
    -180; %left
    -90; %down
    0; %right
    90; %up
    180 %left
    ];

key_colors = [
    0 0 1; %left - blue
    0 1 1; %down - green/blue
    1 0 0; %right - red
    1 1 0; %up - red/green
    0 0 1; %left - blue
    ];

full_angles = -180:180;
full_colormap = nan(length(full_angles), 3);
for i=1:3
    full_colormap(:,i) = interp1(key_angles,key_colors(:,i), full_angles, 'linear');
end

% Add custom labels to colorbar
c = colorbar;
c.Ticks = key_angles;
c.TickLabels = key_directions;
c.Label.String = 'Gaze direction';
clim([-180,180])

end