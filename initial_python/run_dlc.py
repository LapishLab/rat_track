#!/usr/bin/env python3
import argparse
from pathlib import Path
from typing import Sequence
import deeplabcut as dlc
def run_dlc(
    video_folder: str | Path,
    project_root: str | Path | None = None,
    create_video: bool = False,
    overwrite: bool = False,
    network_path: str | Path = "/research/lapishla/dlc/networks/2CAPandFiber-Pi-2026-08-19/",
    shuffle: int = 2,
) -> None:

    # Parse arguments
    video_folder = Path(video_folder)
    if not video_folder.exists():
        raise FileNotFoundError(f"Video folder does not exist: {video_folder}")
    if not video_folder.is_dir():
        raise NotADirectoryError(f"Video folder is not a directory: {video_folder}")
    videos = list(video_folder.glob('*.mp4'))
    if not videos:
        raise ValueError(f"No .mp4 videos found in video folder: {video_folder}")

    network_path = Path(network_path)
    if project_root is None:
        project_root = video_folder.parent
    else:
        project_root = Path(project_root)
    shuffle = int(shuffle)

    # Prepare paths
    output_root = project_root / f'dlc-results_{network_path.name}_shuff{shuffle}'
    config =  network_path / 'config.yaml'

    failed_videos = []
    for v in videos:
        output_folder = output_root / v.stem
        output_folder.mkdir(parents=True, exist_ok=True)

        try:
            analyze_videos(config, v, output_folder, shuffle, overwrite)
        except Exception as e:
            print(f"Error processing {v.name}: {e}")
            failed_videos.append((v,e))
            continue
        if create_video:
            generate_video(config, v, output_folder, shuffle, overwrite)
    if failed_videos:
        print("DLC analysis failed for the following videos:")
        for v, e in failed_videos:
            print(f" - {v.name} : {e}")
    else:
        print("DLC analysis completed successfully for all videos.")

def generate_video(config: Path, video: Path, output_folder: Path, shuffle: int, overwrite: bool) -> None:
        if contains_files(output_folder, ['*labeled.mp4']) and not overwrite:
            print(f'Labeled video already present for {video.name}. Skipping')
            return

        print(f'Generating labeled video for {video.name}')
        dlc.create_labeled_video(
            config=config,
            videos=[str(video)],
            destfolder=str(output_folder),
            filtered=True,
            trailpoints = 1,
            pcutoff = 0,
            overwrite = True,
            dotsize=1,
            draw_skeleton=False,
            shuffle=shuffle
        )
    
def analyze_videos(config: Path, video: Path, output_folder: Path, shuffle: int, overwrite: bool) -> None:
        required_files = ['*filtered.csv', '*filtered.h5', '*meta.pickle']
        if contains_files(output_folder, required_files) and not overwrite:
            print(f'DLC output already present for {video.name}. Skipping')
            return

        print(f'Starting DLC analysis of {video.name}')
        dlc.analyze_videos(
            config=config,
            videos=[video],
            destfolder=str(output_folder),
            save_as_csv=True,
            shuffle=shuffle
        )
        dlc.filterpredictions(
            config=config,
            video=video,
            destfolder=str(output_folder),
            save_as_csv=True,
            shuffle=shuffle
        )


def contains_files(folder: str | Path, required: Sequence[str]) -> bool:
    folder = Path(folder)
    in_folder = [any(folder.glob(r)) for r in required]
    return all(in_folder)


def parse_args() -> dict[str, str | int | bool]:
    parser = argparse.ArgumentParser(description="Run DeepLabCut analysis on all .mp4 videos in a folder")
    parser.add_argument("video_folder", nargs="?", help="Path to folder containing .mp4 videos")
    parser.add_argument("--project_root", dest="project_root", default=None,
                        help="Project root directory (defaults to parent of video_folder)")
    parser.add_argument("--network_path", dest="network_path", default=None,
                        help="Path to DLC network folder containing config.yaml")
    parser.add_argument("--shuffle", dest="shuffle", type=int, default=None,
                        help="Shuffle index to use (default from run_dlc)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--create_video", dest="create_video", action="store_true",
                       help="Generate labeled videos")
    group.add_argument("--no_video", dest="create_video", action="store_false",
                       help="Do not generate labeled videos")
    parser.set_defaults(create_video=None)
    args = parser.parse_args()

    # Prompt user for video folder if not provided
    if args.video_folder is None:
        vid_folder = input("Enter the path to the video folder: ").strip()
        args.video_folder = str(Path(vid_folder).expanduser()) # replace ~ with home directory

    # Strip out all the None values, so run_dlc can use its defaults for those parameters
    kwargs = {k: v for k, v in vars(args).items() if v is not None}
    return kwargs


if __name__ == "__main__":
    kwargs = parse_args()
    run_dlc(**kwargs)
