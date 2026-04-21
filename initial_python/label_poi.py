#!/home/lapishla/miniconda3/envs/openCV/bin/python
from pathlib import Path
import sys
import pandas as pd
from utilities import load_settings, select_points

def main(job_folder, overwrite=False):
    job_folder = Path(job_folder)

    video_folder = job_folder / 'videos'
    point_names = load_settings(job_folder)['points_of_interest']
    video_files = [f for f in video_folder.iterdir() if f.suffix == '.mp4']
    poi_folder = job_folder / "poi"
    poi_folder.mkdir(parents=True, exist_ok=True)
    for index, video_path in enumerate(video_files):
        video_name = video_path.stem
        poi_file = poi_folder / f"{video_name}_poi.csv"

        if poi_file.is_file() and not overwrite:
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