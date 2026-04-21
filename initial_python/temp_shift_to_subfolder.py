from pathlib import Path
import shutil

def organize_by_prefix(dir_path):
    """
    For each file in dir_path:
      - Extract the text before 'DLC_Resnet'
      - Create a subfolder named after that extracted text
      - Move the file into that subfolder
    """
    dir_path = Path(dir_path)

    for file in dir_path.iterdir():
        if file.is_file():
            name = file.name

            # Only process files containing the pattern
            if "DLC_Resnet" in name:
                prefix = name.split("DLC_Resnet")[0]

                # Strip trailing underscores/spaces just in case
                prefix = prefix.rstrip("_ ").strip()

                # Create the destination folder
                dest_folder = dir_path / prefix
                dest_folder.mkdir(exist_ok=True)

                # Move the file
                shutil.move(str(file), dest_folder / file.name)

                print(f"Moved {file.name} → {dest_folder}")


organize_by_prefix("/research/lapishla/dlc/jobs/PV2CAP_pi/halfRes/dlc_results_shuffle3")
