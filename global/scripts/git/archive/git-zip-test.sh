#!/bin/bash

# Function to display help message
help() {
  echo "Usage: $0 <directory>"
  echo "Options:"
  echo "  directory        The directory to create and initialize as a git repository"
  exit 1
}

record_sizes() {
  if [ ! -f "$1" ]; then
    echo "Run, Git Size, Git Objects Size, Archive Size, Git Objects File Count" > "$1"
  fi
  GIT_SIZE=$(du -sh .git | cut -f1)
  GIT_OBJECTS_SIZE=$(du -sh .git/objects | cut -f1)
  GIT_OBJECTS_FILE_COUNT=$(find .git/objects -type f | wc -l)
  if [ -f archive.tar.gz ]; then
    ARCHIVE_SIZE=$(du -sh archive.tar.gz | cut -f1) 
  else
    ARCHIVE_SIZE="N/A"
  fi
  echo "$2, $GIT_SIZE, $GIT_OBJECTS_SIZE, $ARCHIVE_SIZE, $GIT_OBJECTS_FILE_COUNT" | tee -a "$1"
}

# Check if directory is provided
if [ -z "$1" ]; then
  help
fi

DIRECTORY=$1
CURRENT_DIRECTORY=$(pwd)
OUTPUT_FILE="${CURRENT_DIRECTORY}/results.txt"
rm -f "$OUTPUT_FILE"
echo "Writing results to ${OUTPUT_FILE}"

# Create a new directory
mkdir -p "$DIRECTORY"
cd "$DIRECTORY" || exit

# Initialize it as a git repository
git init

# Initialize the output file
git commit -m "Initial commit" --allow-empty &> /dev/null
# Capture the sizes
record_sizes "$OUTPUT_FILE" "Empty repo"

# Add 100 files of 1K in size
for i in $(seq 1 100); do
  dd if=/dev/zero of=file_$i.txt bs=10K count=1 > /dev/null 2>&1
done

# Tar and gzip these files up into an archive
tar -czf archive.tar.gz ./*.txt

# Add and commit the archive as an "initial commit" for the repository
git add archive.tar.gz
git commit -m "Commit the initial archive" &> /dev/null
rm -rf *.txt
record_sizes "$OUTPUT_FILE" "Initial commit"
exit

for i in $(seq 10); do
  # Perform the following 100 times
  # Unzip the archive
  new_file_name="new_file_$(($i + 100)).txt"
  dd if=/dev/zero of=$new_file_name bs=1K count=1 > /dev/null 2>&1

  tar -xzf archive.tar.gz
  gunzip archive.tar.gz
  tar rf archive.tar ${new_file_name}
  gzip archive.tar
  rm -rf *.txt
  
  # Add and commit the new archive to the git repository with a name "committing one extra file"
  git add archive.tar.gz
  git commit -m "Committing one extra file" &> /dev/null
  
  # Capture the sizes
  record_sizes "$OUTPUT_FILE" "$i"
done

echo "Script completed successfully. Results saved to $OUTPUT_FILE."