function ma = load_med(pi_folder)
    root = fileparts(fileparts(pi_folder)); % go up 2 directories to get to session root
    med_search = dir(fullfile(root,"med-pc_*"));% find the med-pc folder

    if isempty(med_search)
        error("Med folder not found in: %s", root)
    end

    med_folder = fullfile(med_search.folder, med_search.name);
    file_search = dir(fullfile(med_folder,"*.txt"));

    if isempty(file_search)
        error("Med files not found in: %s", med_folder)
    end

    [~,pi_name,~] = fileparts(pi_folder);
    pi_number = str2double(strrep(pi_name, 'box', ""));
    for i=1:height(file_search)
        file = fullfile(file_search(i).folder, file_search(i).name);
        ma = importMA(file,remove_trailing_zeros=true);
        if ma.Box == pi_number
            return
        end
    end
    error("did not find any med files in %s whos Box value matched the Pi number of %d",med_folder, pi_number)
end