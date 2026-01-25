function h = img_nan(x,y,data)
    data = data';
    mask = ~isnan(data);
    h = imagesc(x,y, data, 'AlphaData', mask);

    colorbar
    axis equal
end