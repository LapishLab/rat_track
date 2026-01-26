import yaml
import os
import cv2
import pandas as pd
import random

def load_settings(job_folder):
    # load default settings from inside repository
    script_dir = os.path.dirname(__file__)
    default_yaml = os.path.join(script_dir, 'settings.yaml')
    with open(default_yaml, 'r') as f:
        settings = yaml.safe_load(f)

    # overwrite with custom settings if they exist
    custom_yaml = os.path.join(job_folder, 'settings.yaml')
    if os.path.exists(custom_yaml):
        with open(custom_yaml, 'r') as f:
            custom_settings = yaml.safe_load(f)
        if custom_settings: #If any settings were found in the yaml
            settings.update(custom_settings)    
    return settings


def csv_path(job_folder):
    return os.path.join(job_folder, 'videos.csv')

def get_video_info(job_folder):
    return pd.read_csv(csv_path(job_folder))

def overwrite_video_info(job_folder, video_info):
    video_info.to_csv(csv_path(job_folder), index=False)

def select_points(video_path, point_names):
    f = read_random_frame(video_path) 
    if f is None:
        return None
    
    points = []
    def prompt_next_click():
        if len(points) < len(point_names):
            print(f"Click {point_names[len(points)]}, or type 'r' to restart selection")
            cv2.setMouseCallback('Frame', click_event)
        else:
            print("All points selected.")
            print("Click 'r' to restart selection or SPACE to confirm and exit.")
            cv2.setMouseCallback('Frame', lambda *args : None)

    def click_event(event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            points.append((x, y))
            cv2.circle(f, (x,y), 5, (0,255,0), -1)
            cv2.imshow('Frame', f)
            prompt_next_click()

    cv2.imshow('Frame', f)
    prompt_next_click()
    
    while True:
        key = cv2.waitKey(0)
        if key == ord('r'):
            cv2.destroyAllWindows()
            return select_points(video_path, point_names)
        elif key == 32:  # SPACE key to confirm and exit
            if len(points) < len(point_names):
                print("Not enough points selected. Please select all points.")
            else:
                cv2.destroyAllWindows()
                return points

def check_table_headers(df, headers):
    for h in headers:
        if h not in df:
            raise ValueError(f'table missing "{h}" column')
        
def read_random_frame(video_path):
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print(f"Error: Could not open video {video_path}")
        return None

    # Get the total number of frames (approximate, may be unreliable)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames <= 0:
        print("Error: Could not determine total frames or video is empty.")
        cap.release()
        return None

    # Select a random frame number
    random_frame_index = random.randint(0, total_frames - 1)
    cap.set(cv2.CAP_PROP_POS_FRAMES, random_frame_index)

    # Read the frame at the new position
    ret, frame = cap.read()
    cap.release()

    if ret:
        return frame
    else:
        print("Error: Could not read the selected frame.")
        return None