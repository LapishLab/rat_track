#!/home/lapishla/miniconda3/envs/dlc/bin/python3
from deeplabcut import analyze_videos, filterpredictions, create_labeled_video
import argparse
from pathlib import Path
from typing import Sequence

def run_dlc(
    video_folder: str | Path,
    project_root: str | Path | None = None,
    create_video: bool = True,
    network_path: str | Path = "/research/lapishla/dlc/networks/2CAP-Pi",
    shuffle: int = 3,
) -> None:

    # Parse arguments
    video_folder = Path(video_folder)
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
    for v in video_folder.glob('*.mp4'):
        output_folder = output_root / v.stem
        output_folder.mkdir(parents=True, exist_ok=True)
        
        if contains_files(output_folder, ['*filtered.csv','*filtered.h5','*meta.pickle']):
            print(f'DLC output already present for {v} at {output_folder}. Skipping')
        else:
            try:
                print(f'Starting DLC analysis of {v}')
                analyze_videos(
                    config=config,
                    videos=[str(v)],
                    destfolder=str(output_folder),
                    save_as_csv=True,
                    shuffle=shuffle
                )
                filterpredictions(
                    config=config,
                    video=[str(v)],
                    destfolder=str(output_folder),
                    save_as_csv=True,
                    shuffle=shuffle
                )
            except Exception as e:
                print(f"Error processing {v}: {e}")
                failed_videos.append(v)
                continue

        if create_video:
            if contains_files(output_folder, ['*labeled.mp4']):
                print(f'Labeled video already present for {v} at {output_folder}. Skipping')
            else:
                print(f'Generating labeled video for {v}')
                create_labeled_video(
                    config=config,
                    videos=[str(v)],
                    destfolder=str(output_folder),
                    filtered=True,
                    trailpoints = 1,
                    pcutoff = 0,
                    overwrite = True,
                    dotsize=1,
                    draw_skeleton=False,
                    shuffle=shuffle
                )
    if failed_videos:
        print("DLC analysis failed for the following videos:")
        for v in failed_videos:
            print(f" - {v}")
    else:
        print("DLC analysis completed successfully for all videos.")


def contains_files(folder: str | Path, required: Sequence[str]) -> bool:
    folder = Path(folder)
    in_folder = [any(folder.glob(r)) for r in required]
    return all(in_folder)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run DeepLabCut analysis on all .mp4 videos in a folder")
    parser.add_argument("video_folder", help="Path to folder containing .mp4 videos")
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
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    kwargs = {k: v for k, v in vars(args).items() if k != 'video_folder' and v is not None}
    run_dlc(args.video_folder, **kwargs)


if __name__ == "__main__":
    main()
