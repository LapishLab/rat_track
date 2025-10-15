function t = date_from_filename(f)
    [~,names,~] = fileparts(f);
    t = string2datetime(names);
end