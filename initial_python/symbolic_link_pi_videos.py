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

    link_path =  [os.path.join(export_dir,id+'.mp4') for id in vi.id]

    cmds = [f"ln -sf {vi.video_path[i]} {link_path[i]}" for i in range(len(link_path))]
    cmds = [c.split() for c in cmds] # split text command into lists based on whitespace (assumed no spaces in paths)

    for c in cmds:
        subprocess.run(c, capture_output=True, text=True,check=True)

    # Overwrite csv with updated table
    overwrite_video_info(job_folder, vi)


def generate_id(vid_path, subject):
    filename = [Path(f).stem for f in vid_path]
    return [f"{filename[i]}_subject{subject[i]}" for i in range(len(filename))] # TODO: pad subject # with zeros

def get_video_path(pi_folder):
    cam_dir = pi_folder+"cam"
    for filename in os.listdir(cam_dir):
        if filename.endswith(".mp4"):
            return cam_dir + "/" + filename

if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)
