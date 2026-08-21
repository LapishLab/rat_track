
import os
import subprocess
import cv2
import numpy as np
import sys
from utilities import load_settings, get_video_info, overwrite_video_info, resolve_video_path, select_points, check_table_headers
from pathlib import Path
from typing import NamedTuple, Sequence, TypedDict


class CropSettings(TypedDict):
    x_margin: float
    cropped_size: Sequence[float]


class Coordinates(NamedTuple):
    width: int
    height: int
    x_start: int
    y_start: int


def main(job_folder: str | Path) -> None:
    # Load CSV file of video info
    video_info = get_video_info(job_folder)
    check_table_headers(video_info, ['video_path', 'subject'])
    vi_temp = video_info.copy() # create a copy of the csv table where we can save temporary variables

    # Validate video paths
    vid_path = vi_temp['video_path'].apply(resolve_video_path)
    is_missing = vid_path.isin([''])
    if is_missing.any():
        print('Videos could not be found for the following paths:')
        [print(p) for p in vi_temp['video_path'][is_missing]]
    vi_temp['video_path'] = vid_path

    # generate IDs for videos
    vi_temp['id'] = [f'{Path(r.video_path).stem}_subject{r.subject}' for r in vi_temp.itertuples()]
    export_dir = os.path.join(job_folder, 'videos')
    os.makedirs(export_dir, exist_ok=True)
    vi_temp['cropped_path'] =  [os.path.join(export_dir,id+'.mp4') for id in vi_temp.id]

    crop_settings: CropSettings = load_settings(job_folder)['crop']
    
    # interactively choose cropping points for each video
    point_names = ["light left", "light right"]
    vi_temp['points'] = None 
    for r in vi_temp.itertuples():
        if not r.video_path:
            continue
        p = select_points(r.video_path, point_names)
        if p:
            vi_temp.at[r.Index, 'points'] = p
        else:
            print(f"error choosing points for {r.video_path}")

    # Create cropping process for each video
    vi_temp['process'] = None  
    for r in vi_temp.itertuples():
        if not r.points:
            continue
        # cropping string
        video = cv2.VideoCapture(r.video_path)
        frame_size = (
            int(video.get(cv2.CAP_PROP_FRAME_WIDTH)),
            int(video.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        )
        video.release()
        c = calc_crop_coordinates(r.points, crop_settings, frame_size)
        crop = f"crop={c.width}:{c.height}:{c.x_start}:{c.y_start}"

        # scaling string
        sz = crop_settings['cropped_size']
        scale = f"scale={sz[0]}:{sz[1]}"

        # filter chain string
        filter_chain = f"{crop},{scale}"

        if hasattr(r, 'flip_xy') and r.flip_xy:
            filter_chain = filter_chain + ",hflip,vflip"
        
        # Full FFmpeg command
        ffmpeg_cmd = [
            "ffmpeg",
            "-y", #automatically overwrite
            "-i", r.video_path,
            "-vf", filter_chain,
            "-c:a", "copy",
            "-an",
            r.cropped_path
        ]

        p = subprocess.Popen(ffmpeg_cmd, stderr=subprocess.PIPE, text=True)
        vi_temp.at[r.Index, 'process'] = p



    print("All subprocesses launched.")

    # Wait for all processes to complete and collect their output
    vi_temp['crop_success'] = False 
    for r in vi_temp.itertuples():
        if r.process:
            stderr_output: str
            _, stderr_output = r.process.communicate() # wait for process
            if r.process.returncode == 0:
                print(f"crop success for {r.id}")
                vi_temp.at[r.Index, 'crop_success'] = True       
            else:
                print(f"ffmpeg Error for {r.id}:\n{stderr_output.strip()}")

    print("All subprocesses completed.")

    # Overwrite csv with ID and success flag
    video_info['id'] = vi_temp['id'] 
    video_info['crop_success'] = vi_temp['crop_success']
    overwrite_video_info(job_folder, video_info)

def calc_crop_coordinates(points, crop_settings):
    points = np.array(points)
    x = points[:,0]
    y = points[:,1]

    # calculate x points from reference and margin
    width = x.max() - x.min()
    margin = crop_settings['x_margin'] * width
    x_start = int(round(x.min() - margin))
    x_stop = int(round(x.max() + margin))
    width = x_stop - x_start

    # calculate y from reference and aspect ratio
    sz = crop_settings['cropped_size']
    height = int(round(width* sz[1] / sz[0]))
    y_start = int(round(y.mean() - height/2))

    # return relevant values in namedtuple
    return Coordinates(width, height, x_start, y_start)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python crop_video.py <job_folder>")
        sys.exit(1)
    job_folder = sys.argv[1]
    main(job_folder)
