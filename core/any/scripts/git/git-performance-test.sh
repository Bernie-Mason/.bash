#!/bin/bash

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

# Check if repository path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <repository-path> [--fetch] [--pull]"
  exit 1
fi

REPO_PATH=$1
CSV_FILE="git_performance_results.csv"
INCLUDE_FETCH=false
INCLUDE_PULL=false

# Parse additional arguments
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch)
      INCLUDE_FETCH=true
      ;;
    --pull)
      INCLUDE_PULL=true
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 <repository-path> [--fetch] [--pull]"
      exit 1
      ;;
  esac
  shift
done

# Check if the provided path is a valid Git repository
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Error: $REPO_PATH is not a valid Git repository."
  exit 1
fi

cd "${REPO_PATH}"

# Initialize CSV file
echo "Run,Checkout New Branch,Checkout master Branch,Delete Branch,Add Files,Commit Files,Checkout master,Delete Branch Again,Fetch,Pull,Status Before Add,Status After Add,Status After Commit" | tee $CSV_FILE

# Run the operations 10 times each
for i in {1..10}; do
  # Checkout a new branch
  checkout_new_branch=$(measure_time git checkout -b test-branch)
  
  # Checkout the master branch
  checkout_master_branch=$(measure_time git checkout master)
  
  # Delete the test branch
  delete_branch=$(measure_time git branch -D test-branch)
  
  # Create a new branch and add a large number of files
  measure_time git checkout -b test-branch
  mv /c/temp/git_perf_tests/metacm  "${REPO_PATH}"
  # mkdir -p test-files
  # for j in {1..1000}; do
  #   echo "This is test file $j" > test-files/file$j.txt
  # done
  
  # Measure git status before adding files
  status_before_add=$(measure_time git status)
  
  # Add files
  add_files=$(measure_time git add metacm/*)
  
  # Measure git status after adding files
  status_after_add=$(measure_time git status)
  
  # Commit files
  commit_files=$(measure_time git commit -m "Add 1000 test files")
  
  # Measure git status after committing files
  status_after_commit=$(measure_time git status)

  # Clean up
  mv "${REPO_PATH}/metacm" /c/temp/git_perf_tests
  
  # Checkout the master branch
  checkout_master=$(measure_time git checkout master)
  
  # Delete the test branch
  delete_branch_again=$(measure_time git branch -D test-branch)
  
  # Fetch (if included)
  if [ "$INCLUDE_FETCH" = true ]; then
    fetch=$(measure_time git fetch)
  else
    fetch=""
  fi
  
  # Pull (if included)
  if [ "$INCLUDE_PULL" = true ]; then
    pull=$(measure_time git pull)
  else
    pull=""
  fi
  
  # Append results to CSV
  echo "$i,$checkout_new_branch,$checkout_main_branch,$delete_branch,$add_files,$commit_files,$checkout_master,$delete_branch_again,$fetch,$pull,$status_before_add,$status_after_add,$status_after_commit" | tee -a $CSV_FILE
done

echo "Performance test completed. Results saved to $CSV_FILE."