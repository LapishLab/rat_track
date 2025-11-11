#!/home/lapishla/miniconda3/envs/DEEPLABCUT/bin/python3
import deeplabcut
import os
import glob
import sys

def main(job_folder):
    config = "/home/lapishla/Desktop/dlc_networks/2CAP-Pi/config.yaml" # TODO make not hard coded. Put model in repository?
    videos = job_folder
    destfolder = os.path.join(job_folder, "dlc_results")
    os.makedirs(destfolder, exist_ok=True)

    shuffle = 1

    deeplabcut.analyze_videos(
        config=config,
        videos=videos,
        destfolder=destfolder,
        save_as_csv=True,
        shuffle=shuffle
    )

    deeplabcut.filterpredictions(
        config=config,
        video=videos,
        destfolder=destfolder,
        save_as_csv=True,
        shuffle=shuffle
    )

    deeplabcut.plot_trajectories(
        config=config,
        videos=videos,
        destfolder=destfolder,
        filtered=True,
        pcutoff = None,
        shuffle=shuffle
    )


    deeplabcut.create_labeled_video(
        config=config,
        videos=videos,
        destfolder=destfolder,
        filtered=True,
        trailpoints = 1,
        pcutoff = 0,
        overwrite = True,
        dotsize=1,
        draw_skeleton=True,
        shuffle=shuffle
    )

    deeplabcut.analyzeskeleton(
        config=config,
        videos=videos,
        destfolder=destfolder,
        save_as_csv=True,
        filtered=True,
        shuffle=shuffle
    )

    organize_results(destfolder)

def organize_results(destfolder):
    move_files_to_subdirectory(destfolder, "labeled_video",".mp4")
    move_files_to_subdirectory(destfolder, "xy_filtered","_filtered.csv")
    move_files_to_subdirectory(destfolder, "skeleton","_skeleton.csv")
    move_files_to_subdirectory(destfolder, "xy_raw",".csv")
    move_files_to_subdirectory(destfolder, "h5",".h5")
    move_files_to_subdirectory(destfolder, "pickle",".pickle")

def move_files_to_subdirectory(current_dir, sub_name, file_end):
    sub_dir = os.path.join(current_dir, sub_name)
    os.makedirs(sub_dir, exist_ok=True)
    for f in glob.glob(os.path.join(current_dir, f"*{file_end}")):
        os.rename(f, os.path.join(sub_dir, os.path.basename(f)))


if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)