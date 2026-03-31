function tracking = load_tracking_csv(csv_path, header_lines)
    % allow for wildcards
    d = dir(csv_path);
    csv_path = [d.folder filesep d.name];

    % load header
    header_rows = cell(max(header_lines), 1);
    fid = fopen(csv_path, 'r');
    for i=1:max(header_lines)
        header_rows{i} = strsplit(fgets(fid), ',');
    end
    fclose(fid); % Close the file

    header_rows = header_rows(header_lines);
    header = string(header_rows{1}) + "_" +  string(header_rows{2});
    header(1) = "frame";

    % load the data
    tracking = readtable(csv_path, Delimiter=',', NumHeaderLines=max(header_lines));
    tracking.Properties.VariableNames = header;
end