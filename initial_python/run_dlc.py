#!/home/lapishla/miniconda3/envs/dlc/bin/python3
from deeplabcut import analyze_videos, filterpredictions, create_labeled_video
import sys
from pathlib import Path

def run_dlc(
    video_folder,
    project_root = None,
    create_video = True,
    network_path = "/research/lapishla/dlc/networks/2CAP-Pi",
    shuffle=3,
    ):

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

    for v in video_folder.glob('*.mp4'):
        output_folder = output_root / v.stem
        output_folder.mkdir(parents=True, exist_ok=True)
        
        if contains_files(output_folder, ['*filtered.csv','*filtered.h5','*meta.pickle']):
            print(f'DLC output already present for {v} at {output_folder}. Skipping')
        else:
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


def contains_files(folder, required):
    folder = Path(folder)
    in_folder = [any(folder.glob(r)) for r in required]
    return all(in_folder)


if __name__ == "__main__":
    video_folder = sys.argv[1]
    run_dlc(video_folder)
