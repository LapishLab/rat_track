#!/bin/bash
cd /research/lapishla/dlc/jobs/PV2CAP_pi/halfRes/

# Initialize an array to store failed files
failed_files=()

# Loop through common video extensions
for file in *.{mp4,mkv,avi,mov}; do
    # Ensure the file exists (handles cases where no files match the pattern)
    if [ -f "$file" ]; then
        echo -n "Checking: $file... "
        
        # Run ffprobe; send stderr to a temp variable to check for output
        # error_output=$(ffprobe -v error "$file" 2>&1)

        # error_output=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file")

        error_output=$(ffmpeg -v error -i "$file" -f null - 2>&1)

        
        if [ $? -ne 0 ] || [ -n "$error_output" ]; then
            echo "FAILED"
            failed_files+=("$file")
        else
            echo "OK"
        fi
    fi
done

# Print final report
echo -e "\n-----------------------------"
echo "Validation Complete"
echo "Total Failed: ${#failed_files[@]}"

if [ ${#failed_files[@]} -gt 0 ]; then
    echo "Failed Files List:"
    for failed in "${failed_files[@]}"; do
        echo " - $failed"
    done
fi
echo "-----------------------------"
