#!/home/lapishla/miniconda3/envs/DEEPLABCUT/bin/python3
import sys
import multiprocessing
from deeplabcut.utils.auxiliaryfunctions import read_config
from deeplabcut import extract_frames
from functools import partial

skip_previously_extracted = True

def main(job_folder):
    config_path = "/home/lapishla/Desktop/dlc_networks/2CAP-Pi/config.yaml" 
    cfg = read_config(config_path)
    videos = [v for v in cfg["video_sets"]]

    if skip_previously_extracted:
        videos = non_extracted_videos(videos, cfg)

    extract_func = partial(extract, config_path=config_path)

    # Create a pool of worker processes (defaults to number of CPU cores)
    with multiprocessing.Pool() as pool:
        results = pool.map(extract_func, videos)
    print(results)



def extract(video_path, config_path):
    # extract_frames(
    #     config_path,
    #     mode="automatic",
    #     algo="kmeans",
    #     crop=False,
    #     userfeedback=False,
    #     videos_list=[video_path]
    # )
    print(video_path)
    print(config_path)
    return True

def non_extracted_videos(videos, cfg):
    from deeplabcut.utils.auxiliaryfunctions import get_labeled_data_folder
    from os import listdir

    need_extraction = []
    for v in videos:
        labeled_folder = get_labeled_data_folder(cfg, v)
        if len(listdir(labeled_folder)) != cfg["numframes2pick"]:
            need_extraction.append(v)
        else:
            print(f"Already extracted, skipping: \n{v}\n")
    return need_extraction

if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)