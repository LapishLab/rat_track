import os
import subprocess
import sys
from utilities import get_video_info, overwrite_video_info, check_table_headers
from deeplabcut.utils.auxfun_videos import VideoReader

from pathlib import Path

def main(job_folder):
    # load videos.csv and check that it has required columns
    vi = get_video_info(job_folder)
    check_table_headers(vi, ['pi_folder', 'subject'])

    # create video folder to hold local videos
    export_dir = os.path.join(job_folder, 'videos')
    os.makedirs(export_dir, exist_ok=True)

    # pad subject number with zeros to 3 digits
    vi['subject'] = [str(s).rjust(3, '0') for s in vi.subject] 

    # pre-create new empty columns
    new_columns = ['video_path', 'id', 'local_path']
    if 'errors' not in vi.columns:
        new_columns.append('errors')
    vi[new_columns] = None

    # loop through rows to find video and copy to local job folder
    for r in vi.itertuples():
        
        # try to find the video in the pi_folder
        vid_path = get_video_path(r.pi_folder)
        if not vid_path:
            vi.at[r.Index, 'errors'] = "No video found in pi_folder"
            continue
        vi.at[r.Index, 'video_path'] = vid_path # save the path to the table, even if video might be corrupted
        
        # create unique ID from filename and subject number
        filename = Path(vid_path).stem
        id = f"{filename}_subject{r.subject}"
        vi.at[r.Index, 'id'] = id 

        # Verify that video can be loaded properly
        if is_corrupt(vid_path):
            vi.at[r.Index, 'errors'] = "corrupted video"
            continue

        # Generate File destination path from ID 
        dest = os.path.join(export_dir, id+'.mp4')
        vi.at[r.Index, 'local_path'] = dest

        # Copy file to local directory
        cmd = ['cp', '-p', r.video_path, dest]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            vi.at[r.Index, 'errors'] = f"copy failed with: {result.stderr}"
            print(f"copy failed for {cmd}")
            print("Stderr:", result.stderr)
            continue

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
    return None

def is_corrupt(video_path):
    try:
        vid = VideoReader(video_path)
        return False
    except:
        print(f"failed to load with VideoReader: {video_path}")
        return True


    return None
if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)
