import ast
import csv
import json
import math
import yaml
from pathlib import Path
import cv2
import pandas as pd
import random
from typing import Annotated, Sequence

from pydantic import BaseModel, ConfigDict, Field, StrictInt, ValidationError, field_validator, model_validator


Coordinate = StrictInt | Annotated[float, Field(strict=True, allow_inf_nan=False)]
CropPoints = tuple[tuple[Coordinate, Coordinate], tuple[Coordinate, Coordinate]]


def _is_missing_csv_value(value: object) -> bool:
    """read_csv uses float NaN for empty cells in otherwise text columns."""
    return value is None or (isinstance(value, float) and math.isnan(value))


class VideoInfoRow(BaseModel):
    model_config = ConfigDict(extra='allow', validate_assignment=True)

    subject: str = Field(min_length=1)
    video_path: str | None = None
    pi_folder: str | None = None
    points: CropPoints | None = None
    flip_xy: bool | None = None
    id: str | None = None
    crop_success: bool | None = None

    @model_validator(mode='after')
    def path_column_present(self) -> 'VideoInfoRow':
        if not {'video_path', 'pi_folder'}.intersection(self.model_fields_set):
            raise ValueError('a video_path or pi_folder column is required')
        return self

    @field_validator('subject')
    @classmethod
    def subject_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError('subject must not be empty')
        return value

    @field_validator('video_path', 'pi_folder', 'id', 'flip_xy', 'crop_success', mode='before')
    @classmethod
    def optional_csv_value(cls, value: object) -> object:
        return None if _is_missing_csv_value(value) or value == '' else value

    @field_validator('video_path')
    @classmethod
    def resolve_video_path(cls, value: str | None) -> str | None:
        if value is None:
            return None
        path = Path(value)
        if path.is_file():
            return str(path)
        if path.is_dir():
            if (path / 'cam').is_dir():
                path = path / 'cam'
            mp4_files = sorted(
                candidate for candidate in path.iterdir()
                if candidate.suffix.lower() == '.mp4'
            )
            if mp4_files:
                return str(mp4_files[0])
        return value

    @field_validator('points', mode='before')
    @classmethod
    def parse_points(cls, value: object) -> object:
        if _is_missing_csv_value(value) or (isinstance(value, str) and not value.strip()):
            return None
        if isinstance(value, str):
            try:
                return ast.literal_eval(value)
            except (SyntaxError, ValueError) as error:
                raise ValueError('points must be a serialized list of two coordinate pairs') from error
        return value


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
    for row_number, row in enumerate(table.to_dict(orient='records'), start=2):
        try:
            VideoInfoRow.model_validate(row)
        except ValidationError as error:
            raise ValueError(f'{path}: row {row_number}: {error}') from error
    return table


def get_video_rows(job_folder: str | Path) -> list[VideoInfoRow]:
    """Read every CSV column and validate each row with Pydantic."""
    path = csv_path(job_folder)
    rows: list[VideoInfoRow] = []
    with path.open(newline='') as file:
        for row_number, record in enumerate(csv.DictReader(file), start=2):
            try:
                rows.append(VideoInfoRow.model_validate(record))
            except ValidationError as error:
                raise ValueError(f'{path}: row {row_number}: {error}') from error
    if not rows:
        raise ValueError(f'{path}: no video rows')
    return rows


def overwrite_video_rows(job_folder: str | Path, rows: Sequence[VideoInfoRow]) -> None:
    """Write typed rows to CSV, including columns outside the model schema."""
    records = [row.model_dump(exclude_unset=True) for row in rows]
    columns = list(dict.fromkeys(key for record in records for key in record))
    with csv_path(job_folder).open('w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader()
        for record in records:
            if record.get('points') is not None:
                record['points'] = json.dumps(record['points'])
            writer.writerow(record)


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
