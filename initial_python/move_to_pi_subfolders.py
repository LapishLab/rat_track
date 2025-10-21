import os
import shutil
import sys

def main():
    if len(sys.argv) != 2:
        print("Usage: python move_wavs.py <start_path>")
        sys.exit(1)
    start_path = sys.argv[1]
    if not os.path.isdir(start_path):
        print(f"Invalid path: {start_path}")
        sys.exit(1)
    
    box_folders = find_folders(start_path, "box")
    
    if not box_folders:
        print("No folders starting with 'box' found.")
        sys.exit(1)

    for box_folder in box_folders:
        move_files_to_subfolder(box_folder, ".wav", "mic")
        move_files_to_subfolder(box_folder, ".pts", "cam")
        move_files_to_subfolder(box_folder, ".mp4", "cam")
        move_files_to_subfolder(box_folder, ".csv", "gpio")
    print("Done.")


def find_folders(start_path, name_start):
    matching_paths = []
    for root, dirs, _ in os.walk(start_path):
        for dir_name in dirs:
            if dir_name.startswith(name_start):
                matching_paths.append(os.path.join(root, dir_name))
    return matching_paths

def move_files_to_subfolder(parent, ext, subfolder):
    sub_path = os.path.join(parent, subfolder)
    os.makedirs(sub_path, exist_ok=True)
    for filename in os.listdir(parent):
        if filename.lower().endswith(ext):
                src = os.path.join(parent, filename)
                dst = os.path.join(sub_path, filename)
                shutil.move(src, dst)
                print(f"Moved: {src} → {dst}")

if __name__ == "__main__":
    main()