function video = load_video(job_folder, id)
    filename = fullfile(job_folder,"videos",id+".mp4");
    if ~exist(filename,"file")
        error("could not find video: %s", filename)
    end
    video = VideoReader(filename);
end