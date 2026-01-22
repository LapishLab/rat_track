function tracking = get_all_tracking(job_folder, id)
    dlc_results = fullfile(job_folder,'dlc_results', id);

    if ~exist(dlc_results, "dir")
        error("DLC result folder not found at %s", dlc_results)
    end

    % load filtered xy position
    file = dir(fullfile(dlc_results, '*_filtered.csv'));
    if isempty(file)
        error("No matching filtered tracking csv found for %s", id)
    elseif length(file)>1
        error("More than 1 filtered tracking csv found for %s", id)
    end
    tracking = load_tracking_csv(fullfile(file.folder,file.name), [2,3]);
    
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