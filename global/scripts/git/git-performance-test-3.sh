#!/bin/bash

# This script measures the performance of various Git operations (clone, checkout, branch creation, add, commit, etc.)
# for a repository provided as an argument. It runs the operations multiple times with different Git configurations
# (default, manyfiles, fsmonitor, and both manyfiles and fsmonitor) and logs the results to a CSV file.
# The script captures the time taken for each operation and writes the results to both stdout and a CSV file.

help() {
  echo "Usage: $0 <repository-url-or-path> [--num-files n] [--file-size m]"
  echo "Options:"
  echo "  --num-files n    Number of files to generate for the add/commit tests (default: 1)"
  echo "  --file-size m    Size of each file in kilobytes (default: 0)"
  echo "If no repository URL or path is provided, a blank Git repository will be created for the tests."
  exit 1
}

if [ -z "$1" ] || [[ "$1" == "--help" || "$1" == "-h" ]]; then
  help
fi

# Function to measure the time taken for a command
measure_time() {
  local start_time=$(date +%s%N)
  "$@" > /dev/null 2>&1
  local status=$?
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))
  if [ $status -ne 0 ]; then
    echo "Error: Command {$@} failed with status $status"
    exit $status
  fi
  echo $duration
}

progress_bar() {
  local progress=$1
  local total=$2
  local width=50
  local percent=$((progress * 100 / total))
  local filled=$((progress * width / total))
  local empty=$((width - filled))
  local elapsed_time=$3
  local estimated_total_time=$((elapsed_time * total / progress))
  local remaining_time=$((estimated_total_time - elapsed_time))

  printf "\r["
  for ((i=0; i<filled; i++)); do
    printf "#"
  done
  for ((i=0; i<empty; i++)); do
    printf "-"
  done
  printf "] %d%% ETA: %ds" "$percent" "$remaining_time"
}

REPO_URL=$1
NUM_FILES=1
FILE_SIZE=0
ITERATIONS=1

# Parse additional arguments
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --num-files)
      NUM_FILES=$2
      shift
      ;;
    --file-size)
      FILE_SIZE=$2
      shift
      ;;
    --iterations|-i)
      ITERATIONS=$2
      shift
      ;;
    *)
      echo "Unknown option: $1"
      help
      ;;
  esac
  shift
done

# Generate files for the add/commit tests
SCRIPT_DIR=$(pwd)
echo "Script directory: $SCRIPT_DIR"
TEST_FILES_FOLDER_NAME="test_files_${NUM_FILES}_files_${FILE_SIZE}KB"
TEST_FILES_DIR="$SCRIPT_DIR/$TEST_FILES_FOLDER_NAME"
if [ ! -d "$TEST_FILES_DIR" ]; then
  mkdir -p "$TEST_FILES_DIR"
  echo "Creating a test directory with $NUM_FILES files of size ${FILE_SIZE}K each..."
  for i in $(seq 1 $NUM_FILES); do
    dd if=/dev/zero of=$TEST_FILES_DIR/file_$i.txt  bs=${FILE_SIZE}K  count=1 > /dev/null 2>&1
    elapsed_time=$(( $(date +%s) - start_time ))
    progress_bar $i $NUM_FILES $elapsed_time
  done
else
  echo "Test directory $TEST_FILES_DIR already exists. Skipping file generation."
fi


CSV_FILE="git_performance_results_${NUM_FILES}_files_${FILE_SIZE}KB.csv"
# Initialize CSV file
echo "Run,Config,Clone,Checkout New Branch,Checkout master Branch,Delete Branch,Add Files,Commit Files,Checkout master,Delete Branch Again,Status Before Add,Status After Add,Status After Commit" > $CSV_FILE

run_test() {
  local config_name=$1
  shift
  local git_configs=("$@")
  echo "<== Performing test with config: $config_name ==>"

  for i in {1..$ITERATIONS}; do
    echo "<= Iteration $i of $ITERATIONS =>"
    clone_dir="repo_clone_${config_name}_$i"
    clone=$(measure_time git clone "$REPO_URL" "$clone_dir")
    echo "=> Clone completed in $clone ms"
    
    cd "$clone_dir" || exit
    var index_version=$(git update-index --show-index-version)
    var core_fsmonitor=$(git config --get core.fsmonitor)
    var core_untrackedcache=$(git config --get core.untrackedcache)
    var manyfiles=$(git config --get feature.manyFiles)
    echo "Current config: {index_version: $index_version, core_fsmonitor: $core_fsmonitor, core_untrackedcache: $core_untrackedcache, manyfiles: $manyfiles}"
    for config in "${git_configs[@]}"; do
      echo "Setting git config {$config}"
      git config $config
    done

    if [[ "$config_name" == *"manyfiles"* ]]; then
      echo "Setting update-index version to 4"
      git update-index --index-version 4
    fi

    checkout_new_branch=$(measure_time git checkout -b test-branch)
    echo "=> Checkout new branch completed in $checkout_new_branch ms"
    
    checkout_master_branch=$(measure_time git checkout master)
    echo "=> Checkout master branch completed in $checkout_master_branch ms"
    
    delete_branch=$(measure_time git branch -D test-branch)
    echo "=> Delete branch completed in $delete_branch ms"
    
    measure_time git checkout -b test-branch
    mv "$TEST_FILES_DIR" .
    #mv /c/temp/git_perf_tests/metacm  .
    
    status_before_add=$(measure_time git status)
    echo "=> Status before add completed in $status_before_add ms"
    
    add_files=$(measure_time git add .)
    echo "=> Add files completed in $add_files ms"
    
    status_after_add=$(measure_time git status)
    echo "=> Status after add completed in $status_after_add ms"
    
    commit_files=$(measure_time git commit -m "Add $NUM_FILES test files")
    echo "=> Commit files completed in $commit_files ms"
    
    status_after_commit=$(measure_time git status)
    echo "=> Status after commit completed in $status_after_commit ms"

    mv "${TEST_FILES_FOLDER_NAME}" "$SCRIPT_DIR"
    #mv "metacm" /c/temp/git_perf_tests

    checkout_master=$(measure_time git checkout master)
    echo "=> Checkout master completed in $checkout_master ms"
    
    delete_branch_again=$(measure_time git branch -D test-branch)
    echo "=> Delete branch again completed in $delete_branch_again ms"
    

    # Clean up cloned repository
    cd ..
    rm -rf "$clone_dir"

    # Append results to CSV
    echo "$i,$config_name,$clone,$checkout_new_branch,$checkout_master_branch,$delete_branch,$add_files,$commit_files,$checkout_master,$delete_branch_again,$status_before_add,$status_after_add,$status_after_commit" >> $CSV_FILE
    echo ""
  done

  echo "<== Test with config $config_name completed ==>"
  echo ""
}

# Run tests with different configurations
run_test "default"

# Run test with manyfiles config
run_test "manyfiles" "feature.manyFiles true"

# Run test with fsmonitor config
run_test "fsmonitor_untrackedcache" "core.fsmonitor true" "core.untrackedcache true"

# Run test with both manyfiles and fsmonitor config
run_test "manyfiles_fsmonitor_untrackedcache" "feature.manyFiles true" "core.fsmonitor true" "core.untrackedcache true"

echo "Performance test completed. Results saved to $CSV_FILE."