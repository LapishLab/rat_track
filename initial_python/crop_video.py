
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
import subprocess
import tempfile
import cv2
import numpy as np
from utilities import CropPoints, VideoInfoRow, get_video_rows, load_settings, overwrite_video_rows, select_points
from pathlib import Path
from typing import NamedTuple, Sequence, TypedDict
from pydantic import TypeAdapter


class CropSettings(TypedDict):
    x_margin: float
    cropped_size: Sequence[float]


class Coordinates(NamedTuple):
    width: int
    height: int
    x_start: int
    y_start: int


def main(
    job_folder: str | Path,
    skip_existing: bool = True,
    max_processes: int = 20,
) -> None:
    if max_processes < 1:
        raise ValueError('max_processes must be at least 1')

    rows = get_video_rows(job_folder)

    if any('video_path' not in row.model_fields_set for row in rows):
        raise ValueError('crop_video requires a video_path column')

    export_dir = os.path.join(job_folder, 'videos')
    os.makedirs(export_dir, exist_ok=True)

    point_names = ["light left", "light right"]

    crop_settings: CropSettings = load_settings(job_folder)['crop']

    # Choose all missing points before launching any crop processes.
    for row in rows:
        video_path = row.video_path
        row.id = f'{Path(video_path or "").stem}_subject{row.subject}'
        cropped_path = os.path.join(export_dir, f'{row.id}.mp4')
        row.crop_success = False
        if os.path.isfile(cropped_path) and skip_existing:
            print(f"Cropped video already exists at {cropped_path}. Skipping")
            row.crop_success = True
            continue
        if not video_path or not os.path.isfile(video_path):
            print(f"Video could not be found: {row.video_path}")
            continue
        if row.points is not None:
            print(f"Using saved cropping points for {video_path}")
            continue
        points = select_points(video_path, point_names)
        if points:
            row.points = TypeAdapter(CropPoints).validate_python(points)
            overwrite_video_rows(job_folder, rows)
    # Keep incomplete files on the output filesystem until each crop succeeds.
    with tempfile.TemporaryDirectory(prefix='.crop_video-', dir=export_dir) as temp_directory:
        with ThreadPoolExecutor(max_workers=max_processes) as pool:
            futures = {
                pool.submit(crop_one_video, row, crop_settings, temp_directory, export_dir): row
                for row in rows
                if row.points is not None and not row.crop_success
                and row.video_path and os.path.isfile(row.video_path)
            }
            for future in as_completed(futures):
                row = futures[future]
                try:
                    future.result()
                except (OSError, ValueError, RuntimeError) as error:
                    print(f"error cropping video for {row.id}: {error}")
                else:
                    print(f"crop success for {row.id}")
                    row.crop_success = True

    print("All crops completed.")

    overwrite_video_rows(job_folder, rows)


def crop_one_video(
    row: VideoInfoRow,
    crop_settings: CropSettings,
    temp_directory: str,
    export_dir: str,
) -> None:
    video_path = row.video_path
    points = row.points
    if video_path is None or points is None:
        raise ValueError('crop requires a video path and two points')

    video = cv2.VideoCapture(video_path)
    frame_size = (
        int(video.get(cv2.CAP_PROP_FRAME_WIDTH)),
        int(video.get(cv2.CAP_PROP_FRAME_HEIGHT)),
    )
    video.release()
    c = calc_crop_coordinates(points, crop_settings)
    p = calc_padding(c, frame_size)
    pad = f"pad={p.width}:{p.height}:{p.x_start}:{p.y_start}:black"
    crop = f"crop={c.width}:{c.height}:{c.x_start+p.x_start}:{c.y_start+p.y_start}"
    sz = crop_settings['cropped_size']
    scale = f"scale={sz[0]}:{sz[1]}"
    filter_chain = f"{pad},{crop},{scale}"
    if row.flip_xy:
        filter_chain += ",hflip,vflip"

    temp_cropped_path = os.path.join(temp_directory, f'{row.id}.mp4')
    cropped_path = os.path.join(export_dir, f'{row.id}.mp4')
    result = subprocess.run(
        ['ffmpeg', '-y', '-i', video_path, '-vf', filter_chain,
         '-c:a', 'copy', '-an', temp_cropped_path],
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg exited with {result.returncode}: {(result.stderr or '').strip()}")
    os.replace(temp_cropped_path, cropped_path)

def calc_padding(
    c: Coordinates,
    frame_size: tuple[int, int],
) -> Coordinates:
    frame_width, frame_height = frame_size
    if frame_width <= 0 or frame_height <= 0:
        raise ValueError(f"Invalid frame size: {frame_width}x{frame_height}")

    pad_left = 0
    if c.x_start < 0:
        pad_left = abs(c.x_start)

    pad_right = 0
    if c.x_start+c.width > frame_width:
        pad_right = (c.x_start+c.width) - frame_width

    pad_bottom = 0
    if c.y_start < 0:
        pad_bottom = abs(c.y_start)

    pad_top = 0
    if c.y_start+c.height > frame_height:
        pad_top = (c.y_start+c.height) - frame_height


    width = pad_left + pad_right + frame_width
    height = pad_bottom + pad_top + frame_height
    return Coordinates(width, height, pad_left, pad_bottom)

def calc_crop_coordinates(
    points: CropPoints,
    crop_settings: CropSettings,
) -> Coordinates:
    point_array = np.asarray(points, dtype=float)
    x = point_array[:,0]
    y = point_array[:,1]

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
    parser = argparse.ArgumentParser(description='Crop videos listed in a job CSV.')
    parser.add_argument('job_folder')
    parser.add_argument('--max-processes', type=int, default=4,
                        help='maximum number of simultaneous FFmpeg processes (default: 4)')
    args = parser.parse_args()
    if args.max_processes < 1:
        parser.error('--max-processes must be at least 1')
    main(args.job_folder, max_processes=args.max_processes)
