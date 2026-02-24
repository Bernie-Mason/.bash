#!/bin/bash

# Function to display help message
help() {
  echo "Usage: $0 [directory] [--depth n] [--pattern pattern] [--verbose]"
  echo "Options:"
  echo "  directory        The directory to count files in (default: current directory)"
  echo "  --depth n        The depth to count files (default: 1)"
  echo "  --pattern pattern The pattern to match files (default: *)"
  echo "  --verbose        Output additional information"
  exit 1
}

# Default values
DIRECTORY="."
DEPTH=1
PATTERN="*"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)
      DEPTH=$2
      shift
      ;;
    --pattern)
      PATTERN=$2
      shift
      ;;
    --verbose)
      VERBOSE=true
      ;;
    --help|-h)
      help
      ;;
    *)
      DIRECTORY=$1
      ;;
  esac
  shift
done

# Check if the directory exists
if [ ! -d "$DIRECTORY" ]; then
  echo "Error: Directory $DIRECTORY does not exist."
  exit 1
fi

# Count files
FILE_COUNT=$(find "$DIRECTORY" -maxdepth "$DEPTH" -type f -name "$PATTERN" | wc -l)

# Display the result
if [ "$VERBOSE" = true ]; then
  echo "Number of files in $DIRECTORY (depth: $DEPTH, pattern: $PATTERN): $FILE_COUNT"
else
  echo "$FILE_COUNT"
fi