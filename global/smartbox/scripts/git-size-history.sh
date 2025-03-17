#!/bin/bash

set -e

# Save the path of the current repository.
REPO=$(pwd)

# Generate a list of all commits on the current branch. We use
# --first-parent so we only analyze merge commits, and not individual commits
# in pull request branches.
COMMITS=$(git log --pretty=format:%H --reverse --first-parent)

# Create a temporary directory to run our analysis in.
cd /c/temp
rm -rf working-clone
git init working-clone
cd working-clone

git remote add origin $REPO

# Disable automatic garbage collection. By default, this process runs in the
# background and can lead to errors when analyzing the repository. As well,
# we want to control this ourselves so we can analyze the best-case repository
# size.
git config gc.auto 0

# Keep track of how far back in history we want to fetch objects. This ensures
# that each commit is placed in the tree, and is not isolated from each other.
DEPTH=1

for COMMIT in $COMMITS; do
  # Fetch the next commit.
  git fetch --quiet --depth $DEPTH origin $COMMIT
  # Make sure we have a branch pointing to the commit so it doesn't get
  # garbage collected.
  git reset --hard --quiet $COMMIT

  # Run garbage collection so we are analyzing a best-case scenario.
  git gc --quiet

  # Save the commit ID as the first column.
  echo -n $COMMIT, >> ../repository-size.csv

  # Save the date of the commit as the second column.
  git show -s --pretty=format:\"%as\", $COMMIT >> ../repository-size.csv

  # Save the size of the git directory as kilobytes.
  du -sk .git | cut -f1 >> ../repository-size.csv

  # Show the last line we just saved.
  tail -n 1 ../repository-size.csv

  # Increase the depth for the next commit to fetch.
  ((DEPTH=$DEPTH+1))
done