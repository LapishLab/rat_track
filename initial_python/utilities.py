import ast
import math
import yaml
from pathlib import Path
import cv2
import pandas as pd
import random
from typing import Annotated

from pydantic import BaseModel, Field, StrictInt, ValidationError, field_validator


Coordinate = StrictInt | Annotated[float, Field(strict=True, allow_inf_nan=False)]


def _is_missing_csv_value(value: object) -> bool:
    """read_csv uses float NaN for empty cells in otherwise text columns."""
    return value is None or (isinstance(value, float) and math.isnan(value))


class VideoInfoRow(BaseModel):
    subject: str = Field(min_length=1)
    video_path: str | None = None
    pi_folder: str | None = None
    points: tuple[tuple[Coordinate, Coordinate], tuple[Coordinate, Coordinate]] | None = None

    @field_validator('subject')
    @classmethod
    def subject_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError('subject must not be empty')
        return value

    @field_validator('video_path', 'pi_folder', mode='before')
    @classmethod
    def optional_path(cls, value: object) -> object:
        return None if _is_missing_csv_value(value) else value

    @field_validator('points', mode='before')
    @classmethod
    def parse_points(cls, value: object) -> object:
        if _is_missing_csv_value(value) or (isinstance(value, str) and not value.strip()):
            return None
        if not isinstance(value, str):
            raise ValueError('points must be a serialized list of two coordinate pairs')
        try:
            return ast.literal_eval(value)
        except (SyntaxError, ValueError) as error:
            raise ValueError('points must be a serialized list of two coordinate pairs') from error


def load_settings(job_folder):
    # load default settings from inside repository
    script_dir = Path(__file__).parent
    default_yaml = script_dir / 'settings.yaml'
    with open(default_yaml, 'r') as f:
        settings = yaml.safe_load(f)

    # overwrite with custom settings if they exist
    custom_yaml = Path(job_folder) / 'settings.yaml'
    if custom_yaml.exists():
        with open(custom_yaml, 'r') as f:
            custom_settings = yaml.safe_load(f)
        if custom_settings: #If any settings were found in the yaml
            settings.update(custom_settings)    
    return settings


def csv_path(job_folder: str | Path) -> Path:
    return Path(job_folder) / 'videos.csv'

def get_video_info(job_folder: str | Path) -> pd.DataFrame:
    """Load and validate a video table, preserving subject IDs as text.

    A table may start with pi_folder or contain resolved video_path values.
    Empty video paths and points are allowed so they can be filled in later.
    Other columns are retained for the different processing stages.
    """
    path = csv_path(job_folder)
    table = pd.read_csv(path, dtype={
        'subject': str, 'video_path': str, 'pi_folder': str, 'points': str,
    })
    if 'subject' not in table:
        raise ValueError(f'{path}: missing required column "subject"')
    if not {'video_path', 'pi_folder'}.intersection(table.columns):
        raise ValueError(f'{path}: expected a "video_path" or "pi_folder" column')

    for row_number, row in enumerate(table.to_dict(orient='records'), start=2):
        try:
            VideoInfoRow.model_validate(row)
        except ValidationError as error:
            raise ValueError(f'{path}: row {row_number}: {error}') from error
    return table


def resolve_video_path(video_path):
    """Resolve a missing or directory-valued video path to an MP4 file."""
    if pd.isna(video_path) or not str(video_path).strip():
        return video_path

    video_path = Path(video_path)
    if video_path.is_file():
        return str(video_path)

    if video_path.is_dir():
        if (video_path / 'cam').is_dir():
            video_path = video_path / 'cam'
        mp4_files = sorted(
            path for path in video_path.iterdir()
            if path.suffix.lower() == '.mp4'
        )
        if mp4_files:
            return str(mp4_files[0])
    return ""  # Return an empty string if no valid video file is found

def overwrite_video_info(job_folder, video_info):
    video_info.to_csv(csv_path(job_folder), index=False)

def select_points(video_path, point_names):
    f = read_random_frame(video_path) 
    if f is None:
        raise ValueError("Could not read frame from video.")
    
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
        key = cv2.waitKey(1000) # Poll every second to check for window close
        if cv2.getWindowProperty('Frame', cv2.WND_PROP_VISIBLE) <= 0:
            print("Window closed. Exiting point selection.")
            cv2.destroyAllWindows()
            return None
        if key != -1: # If a key was pressed then...
            if key == ord('r'): # if the key was 'r' then start over (reset)
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
