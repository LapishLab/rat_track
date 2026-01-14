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
    new_columns = ['video_path', 'id', 'local_path', 'errors']
    for c in new_columns:
        if c in vi.columns:
            new_columns.remove(c)
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

        # Scale video and put in local directory
        if(not rescale_video(vid_path, dest, "640:360")):
            vi.at[r.Index, 'errors'] = "scaling failed"
            vi.at[r.Index, 'local_path'] = None

        # Overwrite csv with updated table
        overwrite_video_info(job_folder, vi)


def get_video_path(pi_folder):
    cam_dir = pi_folder+"/cam"
    for filename in os.listdir(cam_dir):
        if filename.endswith(".mp4"):
            return cam_dir + "/" + filename
    print(f"No file found for {pi_folder}")
    return None

def is_corrupt(video_path):
    try:
        VideoReader(video_path)
        return False
    except:
        print(f"failed to load with VideoReader: {video_path}")
        return True

def rescale_video(input_path, output_path, resolution):
    """
    Uses ffmpeg to rescale a video to the given resolution.
    The output file starts with 'temp_' before the filename.
    If successful, renames the file to remove 'temp_'.
    """
    dir_name, filename = os.path.split(output_path)
    temp_output = os.path.join(dir_name, f"temp_{filename}")
    print(f'rescaling: {filename}')

    cmd = [
        "ffmpeg",
        "-y",
        "-i", input_path,
        "-vf", f"scale={resolution}",
        "-c:a", "copy",
        temp_output
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"scale failed for {cmd}")
        print("Stderr:", result.stderr)
        return False
    else:
        # Rename temp file to final output if successful
        os.rename(temp_output, output_path)
        print(f'successfully rescaled: {filename}')
        return True

if __name__ == "__main__":
    job_folder = sys.argv[1]
    main(job_folder)
