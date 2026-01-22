function tracking = get_all_tracking(job_folder, id)
    dlc_results = [job_folder filesep 'dlc_results' filesep];

    % load filtered xy position
    file = [dlc_results 'xy_filtered' filesep  id '*_filtered.csv'];
    tracking = load_tracking_csv(file, [2,3]);
   
    % load skeleton
    file = [dlc_results 'skeleton' filesep  id '*_skeleton.csv'];
    skeleton = load_tracking_csv(file, [1,2]);
    
    % merge skeleton and xy position into a single table
    skeleton = removevars(skeleton, 'frame'); % remove duplicate "frame" column
    tracking = cat(2, tracking, skeleton);

   % % load frame to OE time syncing data
    %oe_sync = load_oe_video_sync(job_folder,id);
    %%rename column names for clarity when concatonated to tracking info
    %oe_sync.Properties.VariableNames = "time_" + oe_sync.Properties.VariableNames;
    %tracking = cat(2, oe_sync, tracking);
end

function tracking = load_tracking_csv(csv_path, header_lines)
    % allow for wildcards
    d = dir(csv_path);
    csv_path = [d.folder filesep d.name];

    % load header
    header_rows = cell(max(header_lines), 1);
    fid = fopen(csv_path, 'r');
    for i=1:max(header_lines)
        header_rows{i} = strsplit(fgetl(fid), ',');
    end
    fclose(fid); % Close the file

    header_rows = header_rows(header_lines);
    header = string(header_rows{1}) + "_" +  string(header_rows{2});
    header(1) = "frame";

    % load the data
    tracking = readtable(csv_path, Delimiter=',', NumHeaderLines=max(header_lines));
    tracking.Properties.VariableNames = header;
end