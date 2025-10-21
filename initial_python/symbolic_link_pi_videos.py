import os
import subprocess
import numpy as np
import sys
from utilities import load_settings, get_video_info, overwrite_video_info, select_points
from collections import namedtuple

from pathlib import Path

def main(job_folder):
    # generate IDs for videos
    vi = get_video_info(job_folder)

    vi['subject'] = [str(s).rjust(3, '0') for s in vi.subject] # pad subject number with zeros
    vi['video_path'] = [get_video_path(f) for f in vi.pi_folder] #TODO: verify video exists
    vi['id'] = generate_id(vi.video_path, vi.subject)

    export_dir = os.path.join(job_folder, 'videos')
    os.makedirs(export_dir, exist_ok=True)

    for r in vi.itertuples():
        if not r.id:
            continue
        dest = os.path.join(export_dir,r.id+'.mp4')
        cmd = f"cp -p {r.video_path} {dest}"
        cmd = cmd.split() # split text command into lists based on whitespace (assumed no spaces in paths)
        subprocess.run(cmd, capture_output=True, text=True,check=True)

    # Overwrite csv with updated table
    overwrite_video_info(job_folder, vi)


def generate_id(vid_path, subject):
    id = []
    for i in range(len(vid_path)):
        if not vid_path[i]:
            id.append(None)
            continue

        p = Path(vid_path[i])
        if not p.is_file():
            id.append(None)
            continue

        filename = p.stem
        id.append(f"{filename}_subject{subject[i]}")
    return id

def get_video_path(pi_folder):
    cam_dir = pi_folder+"/cam"
    for filename in os.listdir(cam_dir):
        if filename.endswith(".mp4"):
            return cam_dir + "/" + filename
    print(f"No file found for {pi_folder}")

if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)
