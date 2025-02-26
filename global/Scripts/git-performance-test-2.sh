#!/bin/bash
# This script measures the performance of various Git operations (clone, checkout, branch creation, add, commit, etc.)
# for a repository provided as an argument. It runs the operations multiple times with different Git configurations
# (default, manyfiles, fsmonitor, and both manyfiles and fsmonitor) and logs the results to a CSV file.
# The script captures the time taken for each operation and writes the results to both stdout and a CSV file.

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

# Check if repository URL or path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <repository-url-or-path> [--fetch] [--pull]"
  exit 1
fi

REPO_URL=$1
CSV_FILE="git_performance_results.csv"
INCLUDE_FETCH=false
INCLUDE_PULL=false

echo "<=== Git Performance Test ===>"
echo "Repository URL: $REPO_URL"
echo "Include Fetch: $INCLUDE_FETCH"
echo "Include Pull: $INCLUDE_PULL"
echo "Results will be saved to $CSV_FILE"
echo "============================="
echo ""

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
      echo "Usage: $0 <repository-url-or-path> [--fetch] [--pull]"
      exit 1
      ;;
  esac
  shift
done

# Initialize CSV file
echo "Run,Config,Clone,Checkout New Branch,Checkout master Branch,Delete Branch,Add Files,Commit Files,Checkout master,Delete Branch Again,Fetch,Pull,Status Before Add,Status After Add,Status After Commit" > $CSV_FILE

run_test() {
  local config_name=$1
  shift
  local git_configs=("$@")
  echo "<== Performing test with config: $config_name ==>"

  for i in {1..1}; do
    clone_dir="repo_clone_${config_name}_$i"
    clone=$(measure_time git clone "$REPO_URL" "$clone_dir")
    echo "=> Clone completed in $clone ms"
    
    cd "$clone_dir" || exit

    for config in "${git_configs[@]}"; do
      git config $config
    done

    if [[ "$config_name" == *"manyfiles"* ]]; then
      git update-index --index-version 4
    fi

    checkout_new_branch=$(measure_time git checkout -b test-branch)
    echo "=> Checkout new branch completed in $checkout_new_branch ms"
    
    checkout_master_branch=$(measure_time git checkout master)
    echo "=> Checkout master branch completed in $checkout_master_branch ms"
    
    delete_branch=$(measure_time git branch -D test-branch)
    echo "=> Delete branch completed in $delete_branch ms"
    
    measure_time git checkout -b test-branch
    mv /c/temp/git_perf_tests/metacm  .
    
    status_before_add=$(measure_time git status)
    echo "=> Status before add completed in $status_before_add ms"
    
    add_files=$(measure_time git add metacm/*)
    echo "=> Add files completed in $add_files ms"
    
    status_after_add=$(measure_time git status)
    echo "=> Status after add completed in $status_after_add ms"
    
    commit_files=$(measure_time git commit -m "Add 1000 test files")
    echo "=> Commit files completed in $commit_files ms"
    
    status_after_commit=$(measure_time git status)
    echo "=> Status after commit completed in $status_after_commit ms"

    mv "metacm" /c/temp/git_perf_tests
    
    checkout_master=$(measure_time git checkout master)
    echo "=> Checkout master completed in $checkout_master ms"
    
    delete_branch_again=$(measure_time git branch -D test-branch)
    echo "=> Delete branch again completed in $delete_branch_again ms"
    
    if [ "$INCLUDE_FETCH" = true ]; then
      fetch=$(measure_time git fetch)
      echo "=> Fetch completed in $fetch ms"
    else
      fetch=""
    fi
    
    if [ "$INCLUDE_PULL" = true ]; then
      pull=$(measure_time git pull)
      echo "=> Pull completed in $pull ms"
    else
      pull=""
    fi
    
    # Append results to CSV
    echo "$i,$config_name,$clone,$checkout_new_branch,$checkout_master_branch,$delete_branch,$add_files,$commit_files,$checkout_master,$delete_branch_again,$fetch,$pull,$status_before_add,$status_after_add,$status_after_commit" >> $CSV_FILE

    # Clean up cloned repository
    cd ..
    rm -rf "$clone_dir"
  done

  echo "<== Test with config $config_name completed ==>"
  echo ""
}

# Run tests with different configurations
run_test "default"

# Run test with manyfiles config
run_test "manyfiles" "feature.manyFiles true"

# Run test with fsmonitor config
run_test "fsmonitor" "core.fsmonitor true"

# Run test with both manyfiles and fsmonitor config
run_test "manyfiles_fsmonitor" "feature.manyFiles true" "core.fsmonitor true"

echo "Performance test completed. Results saved to $CSV_FILE."