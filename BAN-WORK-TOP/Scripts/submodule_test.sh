#!/bin/sh

# Create a temporary directory for testing
TEST_DIR=$(powershell -Command "[System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()")
mkdir -p "$TEST_DIR"
echo "Temporary directory created at $TEST_DIR"

# Create sample directories and files
mkdir -p "$TEST_DIR/parentRepo"
mkdir -p "$TEST_DIR/parentRepo/subdir1"
mkdir -p "$TEST_DIR/parentRepo/subdir2"
mkdir -p "$TEST_DIR/parentRepo/subdir3"
mkdir -p "$TEST_DIR/parentRepo/subdir1/nested1"
mkdir -p "$TEST_DIR/parentRepo/subdir2/nested2"
mkdir -p "$TEST_DIR/parentRepo/subdir3/nested3"

echo "Sample file 1" > "$TEST_DIR/parentRepo/subdir1/file1.txt"
echo "Sample file 2" > "$TEST_DIR/parentRepo/subdir2/file2.txt"
echo "Sample file 3" > "$TEST_DIR/parentRepo/subdir3/file3.txt"
echo "Nested file 1" > "$TEST_DIR/parentRepo/subdir1/nested1/nested_file1.txt"
echo "Nested file 2" > "$TEST_DIR/parentRepo/subdir2/nested2/nested_file2.txt"
echo "Nested file 3" > "$TEST_DIR/parentRepo/subdir3/nested3/nested_file3.txt"

# Run the git_submodule_populate script
./git_submodule_populate "$TEST_DIR/parentRepo"

# Verify the correctness of the script
echo "Verifying the correctness of the script..."

# Check if subdirectories are initialized as Git repositories
for subdir in subdir1 subdir2 subdir3; do
    if [ -d "$TEST_DIR/parentRepo/$subdir/.git" ]; then
        echo "$subdir is a Git repository."
    else
        echo "Error: $subdir is not a Git repository."
        exit 1
    fi
done

# Check if nested subdirectories are not initialized as Git repositories
for subdir in subdir1/nested1 subdir2/nested2 subdir3/nested3; do
    if [ -d "$TEST_DIR/parentRepo/$subdir/.git" ]; then
        echo "Error: $subdir should not be a Git repository."
        exit 1
    else
        echo "$subdir is correctly not a Git repository."
    fi
done

# Check if the Symbols directory is created and initialized as a Git repository
if [ -d "$TEST_DIR/parentRepo/Symbols/.git" ]; then
    echo "Symbols directory is a Git repository."
else
    echo "Error: Symbols directory is not a Git repository."
    exit 1
fi

# Check if submodules are added to the Symbols repository
cd "$TEST_DIR/parentRepo/Symbols" || exit
for subdir in subdir1 subdir2 subdir3; do
    if git submodule status | grep -q "$subdir"; then
        echo "$subdir is added as a submodule."
    else
        echo "Error: $subdir is not added as a submodule."
        exit 1
    fi
done

echo "All checks passed. Script is correct."

# Clean up the test directory
#rm -rf "$TEST_DIR"
echo "Test directory cleaned up."