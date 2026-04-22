function heatmat_plot(x,y, z, poi, c_label)
    hold on;
    img_nan(x,y,z);
    
    xlabel('mm')
    ylabel('mm')
    xlim([min(x) max(x)])
    ylim([min(y) max(y)])

    poi_name = ["sipper_left", "sipper_right"];
    scatter(poi.X(poi_name), poi.Y(poi_name), 'r','*')

    colormap('jet')
    c = colorbar;
    c.Label.String = c_label;
    axis equal  
end
