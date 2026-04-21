#!/home/lapishla/miniconda3/envs/openCV/bin/python
import sys
import pandas as pd
from os.path import join, basename, splitext, isfile
from os import listdir, makedirs
import sys
from utilities import load_settings, select_points

def main(job_folder, overwrite=False):
    video_folder = join(job_folder, 'videos')
    point_names = load_settings(job_folder)['points_of_interest']
    video_files = [join(video_folder, f) for f in listdir(video_folder) if f.endswith('.mp4')]
    poi_folder = join(job_folder,"poi")
    makedirs(poi_folder, exist_ok=True)
    for index, video_path in enumerate(video_files):
        video_name = splitext(basename(video_path))[0]
        poi_file = join(poi_folder, f"{video_name}_poi.csv")

        if isfile(poi_file) and not overwrite:
            print(f"Already completed {video_path}, skipping")
            continue

        print(f"Processing {index}/{len(video_files)}: {video_path} ")
        points = select_points(video_path, point_names)
        if not points: # User closed the window
            return None
        print(f"Selected points for {video_path}: {points}")

        df = pd.DataFrame(points, index=point_names, columns=['X', 'Y'])
        df.to_csv(poi_file)
        print(f"saved {poi_file}")


if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)