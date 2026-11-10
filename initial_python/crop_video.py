
import os
import subprocess
import tempfile
import cv2
import numpy as np
import sys
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


def main(job_folder: str | Path, skip_existing: bool = True) -> None:
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
    # Create each crop in a temporary directory on the same filesystem as the
    # final output. This keeps incomplete files out of their final locations and
    # allows a successful crop to be installed atomically with os.replace().
    with tempfile.TemporaryDirectory(prefix='.crop_video-', dir=export_dir) as temp_directory:
        pending: list[tuple[VideoInfoRow, subprocess.Popen[str], str, str]] = []
        for row in rows:
            if row.points is None or row.crop_success:
                continue
            video_path = row.video_path
            if not video_path or not os.path.isfile(video_path):
                continue

            # cropping and padding strings
            video = cv2.VideoCapture(video_path)
            frame_size = (
                int(video.get(cv2.CAP_PROP_FRAME_WIDTH)),
                int(video.get(cv2.CAP_PROP_FRAME_HEIGHT)),
            )
            video.release()
            c = calc_crop_coordinates(row.points, crop_settings)
            p = calc_padding(c, frame_size)
            pad = f"pad={p.width}:{p.height}:{p.x_start}:{p.y_start}:black"
            crop = f"crop={c.width}:{c.height}:{c.x_start+p.x_start}:{c.y_start+p.y_start}"

            # scaling string
            sz = crop_settings['cropped_size']
            scale = f"scale={sz[0]}:{sz[1]}"

            # filter chain string
            filter_chain = f"{pad},{crop},{scale}"

            if row.flip_xy:
                filter_chain = filter_chain + ",hflip,vflip"

            temp_cropped_path = os.path.join(temp_directory, f'{row.id}.mp4')
            cropped_path = os.path.join(export_dir, f'{row.id}.mp4')

            # Full FFmpeg command
            ffmpeg_cmd = [
                "ffmpeg",
                "-y", #automatically overwrite
                "-i", video_path,
                "-vf", filter_chain,
                "-c:a", "copy",
                "-an",
                temp_cropped_path,
            ]

            process = subprocess.Popen(ffmpeg_cmd, stderr=subprocess.PIPE, text=True)
            pending.append((row, process, temp_cropped_path, cropped_path))

        print("All subprocesses launched.")

        # Wait for all processes to complete and collect their output
        for row, process, temp_cropped_path, cropped_path in pending:
            _, stderr_output = process.communicate() # wait for process
            if process.returncode == 0:
                try:
                    os.replace(temp_cropped_path, cropped_path)
                except OSError as error:
                    print(f"error saving cropped video for {row.id}: {error}")
                else:
                    print(f"crop success for {row.id}")
                    row.crop_success = True
            else:
                print(f"ffmpeg Error for {row.id}:\n{(stderr_output or '').strip()}")

    print("All subprocesses completed.")

    overwrite_video_rows(job_folder, rows)

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
    if len(sys.argv) < 2:
        print("Usage: python crop_video.py <job_folder>")
        sys.exit(1)
    job_folder = sys.argv[1]
    main(job_folder)
