import os
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

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
    subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

    # Rename temp file to final output if successful
    os.rename(temp_output, output_path)
    print(f'successfully rescaled: {filename}')

def batch_rescale_videos(input_dir, output_dir, resolution, max_workers=4):
    """
    Loops through all video files in input_dir, rescales them to the given resolution,
    and saves them to output_dir. Processes up to max_workers videos simultaneously.
    Only processes videos that are not already present in output_dir.
    Output files are first written with 'temp' in the name, then renamed if successful.
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    video_extensions = ('.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv')
    video_files = [
        f for f in os.listdir(input_dir)
        if f.lower().endswith(video_extensions)
    ]

    print(f'{len(video_files)} videos in {input_dir}')
    # Only process videos not already present in output_dir
    videos_to_process = []
    for video in video_files:
        output_path = os.path.join(output_dir, video)
        if not os.path.exists(output_path):
            videos_to_process.append(video)
        else:
            print(f'Skipping {video}: already present in {output_dir}')
            
    
    print(f'{len(videos_to_process)} videos will be rescaled')

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for video in videos_to_process:
            input_path = os.path.join(input_dir, video)
            output_path = os.path.join(output_dir, video)
            futures.append(
                executor.submit(rescale_video, input_path, output_path, resolution)
            )
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"Error processing video: {e}")

original = "/media/4TB_sandisk/dlc_PV2CAP_pi/videos/"
destination = '/home/lapishla/Desktop/dlc/jobs/PV2CAP_pi/halfRes/'
new_scale = "640:360"
batch_rescale_videos(original, destination, new_scale)