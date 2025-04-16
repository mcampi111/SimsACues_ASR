#!/bin/bash
#SBATCH --job-name=copy_and_delete
#SBATCH --output=copy_and_delete_%j.out
#SBATCH --error=copy_and_delete_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1

# Source and destination paths
SOURCE_DIR="/pasteur/appa/homes/mcampi/ASR_ANSD/Neurogram_Sim/SELECT_Neurograms_ANSD_WithNoise"
DEST_DIR="/pasteur/helix/scratch/mcampi/SELECT_Neurograms_ANSD_WithNoise"

# Create a log file
LOG_FILE="copy_and_delete_log.txt"
echo "Starting copy and delete operation at $(date)" > $LOG_FILE

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist" | tee -a $LOG_FILE
    exit 1
fi

# Check if destination directory already exists
if [ -d "$DEST_DIR" ]; then
    echo "Warning: Destination directory already exists. Will overwrite files." | tee -a $LOG_FILE
else
    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$DEST_DIR")"
fi

# Copy files with rsync to show progress and ensure complete transfer
echo "Starting file copy at $(date)" | tee -a $LOG_FILE
rsync -av --progress "$SOURCE_DIR" "$(dirname "$DEST_DIR")"
RSYNC_EXIT_CODE=$?

# Check if rsync completed successfully
if [ $RSYNC_EXIT_CODE -ne 0 ]; then
    echo "Error: rsync failed with exit code $RSYNC_EXIT_CODE" | tee -a $LOG_FILE
    echo "Files were not deleted due to copy failure" | tee -a $LOG_FILE
    exit $RSYNC_EXIT_CODE
fi

# Verify copy was successful by comparing directory sizes
SOURCE_SIZE=$(du -s "$SOURCE_DIR" | awk '{print $1}')
DEST_SIZE=$(du -s "$DEST_DIR" | awk '{print $1}')

echo "Source directory size: $SOURCE_SIZE KB" | tee -a $LOG_FILE
echo "Destination directory size: $DEST_SIZE KB" | tee -a $LOG_FILE

if [ "$SOURCE_SIZE" -ne "$DEST_SIZE" ]; then
    echo "Error: Directory sizes don't match! Copy may be incomplete." | tee -a $LOG_FILE
    echo "Source: $SOURCE_SIZE KB, Destination: $DEST_SIZE KB" | tee -a $LOG_FILE
    echo "Files were not deleted due to size mismatch" | tee -a $LOG_FILE
    exit 1
fi

# Compare file counts
SOURCE_FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l)
DEST_FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l)

echo "Source file count: $SOURCE_FILE_COUNT" | tee -a $LOG_FILE
echo "Destination file count: $DEST_FILE_COUNT" | tee -a $LOG_FILE

if [ "$SOURCE_FILE_COUNT" -ne "$DEST_FILE_COUNT" ]; then
    echo "Error: File counts don't match! Copy may be incomplete." | tee -a $LOG_FILE
    echo "Source: $SOURCE_FILE_COUNT files, Destination: $DEST_FILE_COUNT files" | tee -a $LOG_FILE
    echo "Files were not deleted due to file count mismatch" | tee -a $LOG_FILE
    exit 1
fi

# If we've reached here, copy was successful, so delete the source
echo "Copy verified successfully. Deleting source directory..." | tee -a $LOG_FILE
rm -rf "$SOURCE_DIR"
RM_EXIT_CODE=$?

if [ $RM_EXIT_CODE -ne 0 ]; then
    echo "Warning: Could not delete source directory, exit code: $RM_EXIT_CODE" | tee -a $LOG_FILE
    exit $RM_EXIT_CODE
else
    echo "Source directory successfully deleted at $(date)" | tee -a $LOG_FILE
    echo "Operation completed successfully" | tee -a $LOG_FILE
fi
