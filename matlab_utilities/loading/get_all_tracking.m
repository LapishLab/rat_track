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