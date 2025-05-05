#!/bin/bash
# backport_helper.sh
# A script to assist with backporting branches to release branches.
# Author: Bernie
# Date: 2025-05-04

COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"
REMOTE="origin"  
MAINLINE_BRANCH="master"
ERROR=""
CURRENT_BRANCH=""
TICKET_ID=""

## set verbosity level depending on flag
if [[ $1 == "-v" ]]; then
    VERBOSE=true
else
    VERBOSE=false
fi

source $logging_utils_path

function set-ticket-id() {
    local branch_name=$1
    if [[ $branch_name =~ ([A-Z]{2,6}-[0-9]{1,8}) ]]; then
        TICKET_ID="${BASH_REMATCH[1]}"
        log-info "Detected ticket identifier: $TICKET_ID"
    else
        log-error "Failed to extract ticket identifier from branch name: $branch_name"
        exit 1
    fi
}

# Ensure we are in the grid repository
function ensure-in-grid-repo() {
    local is_quiet=false
    if [[ $1 == "quiet" ]]; then
        is_quiet=true
    fi

    $is_quiet || log-info "Checking if the current directory is a Git repository..."
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log-warn "You are not in a Git repository."
        if [[ -z "$GRID_REPO_DIR" ]]; then
            log-error "GRID_REPO_DIR environment variable is not set. Cannot navigate to the grid repository."
            exit 1
        fi
        read -p "Do you want to navigate to the grid repository at $GRID_REPO_DIR? (y/n): " choice
        if [[ "$choice" != "y" ]]; then
            log-error "Aborting script as we are not in the grid repository."
            exit 1
        fi
        cd "$GRID_REPO_DIR" || {
            log-error "Failed to navigate to $GRID_REPO_DIR."
            exit 1
        }
    fi

    $is_quiet || log-info "Checking if the repository remote contains 'apps/grid.git'..."
    if ! git remote -v | grep -q "apps/grid.git"; then
        log-error "The current repository is not the grid repository (missing 'apps/grid.git' in remotes)."
        exit 1
    fi

    # Store the GRID_DIR variable for later use
    GRID_DIR=$(git rev-parse --show-toplevel)
    $is_quiet || log-info "Grid repository detected at $GRID_DIR."
}

# Ensure the working directory is clean and extract ticket identifier
function pre-script-check() {
    log-info "Performing pre-menu checks..."

    ensure-in-grid-repo

    # Ensure the working directory is clean
    if [[ -n $(git status --porcelain) ]]; then
        log-error "Working directory is not clean. Please commit or stash your changes before proceeding."
        exit 1
    fi

    # Extract ticket identifier from the branch name
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    set-ticket-id "$current_branch" || exit 1

    # Confirm the branch to work with
    read -p "Do you want to work with the current branch ($current_branch, Ticket: $TICKET_ID)? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        if ! command -v gchu &> /dev/null; then
            die 0 "Please check out the branch you wish to backport and re-run the script."
        fi
        read -p "Enter the branch pattern to checkout: " branch_pattern
        gchu "$branch_pattern" ||  die 1 "Failed to checkout branch matching pattern $branch_pattern."
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        set-ticket-id "$current_branch" || exit 1
        log-info "Switched to branch: $current_branch"
    fi
    CURRENT_BRANCH=$current_branch
}

function ensure-up-to-date-with-mainline() {
    title "Ensuring the current branch is up-to-date with its remote and based on $REMOTE/$MAINLINE_BRANCH..."

    # Fetch the latest changes from the remote
    git fetch -q $REMOTE || die 1 "Failed to fetch from $REMOTE."

    # Check if the current branch is based on the tip of the mainline branch
    log-info "Checking if the current branch is up-to-date with $REMOTE/$MAINLINE_BRANCH..."
    local mainline_tip=$(git rev-parse $REMOTE/$MAINLINE_BRANCH)
    local branch_base=$(git merge-base @ $REMOTE/$MAINLINE_BRANCH)

    if [[ "$branch_base" != "$mainline_tip" ]]; then
        log-warn "The working branch $current_branch is not based on the tip of $REMOTE/$MAINLINE_BRANCH."
        read -p "Do you want to rebase $current_branch onto $REMOTE/$MAINLINE_BRANCH? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            git rebase -q $REMOTE/$MAINLINE_BRANCH || die 1 "Rebase onto $REMOTE/$MAINLINE_BRANCH failed. Resolve conflicts and try again."
        else
            log-warn "Skipping rebase onto $REMOTE/$MAINLINE_BRANCH."
        fi
    else
        log-info "The working branch $current_branch is based on the tip of $REMOTE/$MAINLINE_BRANCH."
    fi

    # Check the status of the current working branch
    log-info "Checking the status of the working branch $current_branch relative to its upstream..."
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)

    if [[ -z "$upstream" ]]; then
        log-warn "No upstream branch set for $current_branch."
        read -p "Do you want to you want to push your current branch? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            git push || die 1 "Failed to set upstream branch."
            upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
        else
            log-warn "Skipping upstream branch setup."
            return 0
        fi
    fi

    # Check if the working branch is behind or ahead of its upstream
    local local_commit=$(git rev-parse @)
    local remote_commit=$(git rev-parse "$upstream")
    local base_commit=$(git merge-base @ "$upstream")

    if [[ "$local_commit" == "$remote_commit" ]]; then
        log-info "The working branch $current_branch is up-to-date with $upstream."
    elif [[ "$local_commit" == "$base_commit" ]]; then
        log-warn "The working branch $current_branch is behind $upstream."
        read -p "Do you want to pull the latest changes from $upstream? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            git pull || die 1 "Failed to pull changes from $upstream."
        else
            log-warn "Skipping pull operation."
        fi
    elif [[ "$remote_commit" == "$base_commit" ]]; then
        log-warn "The working branch $current_branch is ahead of $upstream."
        read -p "Do you want to push your changes to $upstream? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            git push || die 1 "Failed to push changes to $upstream."
        else
            log-warn "Skipping push operation."
        fi
    else
        log-warn "The working branch $current_branch has diverged from $upstream."
        read -p "Do you want to rebase onto $upstream? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            git rebase "$upstream" || die 1 "Rebase failed. Resolve conflicts and try again."
        else
            log-warn "Skipping rebase operation."
        fi
    fi
}

function detect-version-to-backport() {
    title "Detecting the version to backport..."
    local tag=$(git describe --tags --abbrev=0)
    log-info "Latest tag detected: $tag"
    if [[ $tag =~ Grid_([0-9]+\.[0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
        local major_minor=${BASH_REMATCH[1]}
        local patch=${BASH_REMATCH[2]}
        log-info "Latest detected version of Major.Minor.Patch: $major_minor.$patch"
        read -p "Do you want to use the patch version of $patch? (y/n): " choice
        if [[ "$choice" != "y" ]]; then
            read -p "Enter the new patch version (e.g. 94): " new_patch
            if [[ ! $new_patch =~ ^[0-9]+$ ]]; then
                log-error "Invalid patch version. Exiting."
                return 1
            fi
            patch=$new_patch
        fi
        eval "$1=$major_minor.$patch"
        eval "$2=$patch"
    else
        log-error "Failed to detect a valid version tag."
        return 1
    fi
}

function check-release-branch-exists() {
    local release_branch=$1
    title "Checking if release branch ${release_branch} exists on $REMOTE..."
    if git ls-remote --heads $REMOTE "${release_branch}" | grep -q "${release_branch}"; then
        log-info "Release branch ${release_branch} exists."
        return 0
    else
        log-error "Release branch ${release_branch} does not exist."
        return 1
    fi
}

function create-backport-branch() {
    local release_branch=$1
    local patch_version=$2
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local new_branch="${current_branch}-${patch_version}"

    log-info "Checking if new branch ${new_branch} already exists..."
    if git branch --list "$new_branch" | grep -q "$new_branch"; then
        log-error "Branch ${new_branch} already exists. Exiting."
        return 1
    fi

    log-info "Creating a new branch ${new_branch}..."
    git branch "$new_branch" || die 1 "Failed to create branch ${new_branch}."

    local branch_base_commit=$(git merge-base @ $REMOTE/$MAINLINE_BRANCH)
    log-info "Rebasing ${new_branch} onto $release_branch skipping commits from the merge base $branch_base_commit..."
    git rebase -i --onto "$release_branch" $branch_base_commit "$new_branch" || die 1 "Interactive rebase failed. Resolve conflicts and try again."

    read -p "Do you want to push the new branch ${new_branch} to $REMOTE? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        log-warn "Skipping push operation."
        return 0
    fi
    git push -u $REMOTE "$new_branch" || log-error "Failed to push new branch ${new_branch}."
}

# Parse the dependency versions from a given props file
function parse-dependency-versions() {
    local git_ref=$1
    local props_file=$2
    declare -n versions_ref=$3  # Use a name reference for the output array

    log-info "Parsing dependency versions from $props_file at ref $git_ref..."

    # Get the contents of the file at the specified Git ref
    local file_contents
    file_contents=$(git show "$git_ref:$props_file" 2>/dev/null) || {
        log-error "Failed to retrieve $props_file at ref $git_ref."
        return 1
    }

    # Parse the dependency versions from the file contents
    while read -r line; do
        local repo_name=$(echo "$line" | grep -oP '<\K\w+(?=Version)')
        local version=$(echo "$line" | grep -oP '\[.*?\]' | tr -d '[]')
        if [[ -n "$repo_name" && -n "$version" ]]; then
            versions_ref["$repo_name"]="$version"
            VERBOSE && log-info "Found dependency: $repo_name with version $version"
        fi
    done < <(echo "$file_contents" | grep -oP '<\w+Version>\[.*?\]</\w+Version>')

    log-success "Parsed dependency versions from $props_file at ref $git_ref."
}

# Compare dependency versions between current and mainline
function compare-dependency-versions() {
    declare -n current=$1  # Reference to the current branch's versions
    declare -n mainline=$2  # Reference to the mainline branch's versions
    declare -n changed=$3  # Reference to the output array for changed dependencies

    log-info "Comparing dependency versions..."
    for repo_name in "${!current[@]}"; do
        local current_version=${current["$repo_name"]}
        local mainline_version=${mainline["$repo_name"]}
        if [[ "$current_version" != "$mainline_version" ]]; then
            log-warn "Version mismatch for $repo_name: current=$current_version, $MAINLINE_BRANCH=$mainline_version"
            changed["$repo_name"]="$current_version"
        fi
    done

    if [[ ${#changed[@]} -eq 0 ]]; then
        log-info "No dependency version changes detected."
        return 1
    fi

    log-success "Dependency version changes detected."
    return 0
}

# Handle changed dependencies and allow the user to create branches
function handle-changed-dependencies() {
    declare -n changed_dependencies=$1
    declare -n mainline_versions=$2

    log-info "Listing changed dependencies..."
    PS3="Select a dependency to create a branch for (or type 'q' to quit): "
    select repo_name in "${!changed_dependencies[@]}"; do
        if [[ -z "$repo_name" ]]; then
            log-warn "Invalid selection. Please try again."
            continue
        fi

        # Navigate to the repository
        local repo_path="C:/dev/$repo_name"
        if [[ ! -d "$repo_path" ]]; then
            log-error "Repository $repo_name not found at $repo_path."
            break
        fi
        cd "$repo_path" || {
            log-error "Failed to navigate to $repo_path."
            break
        }

        # Detect the current branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        log-info "Current branch: $current_branch"
        read -p "Do you want to use this branch for backporting? (y/n): " use_current_branch
        if [[ "$use_current_branch" != "y" ]]; then
            if ! command -v gchu &> /dev/null; then
                log-info "Please check out the branch you wish to backport and re-run the script."
                break
            fi
            read -p "Enter the branch pattern to checkout: " branch_pattern
            gchu "$branch_pattern" || {
                log-error "Failed to checkout branch matching pattern $branch_pattern."
                break
            }
            current_branch=$(git rev-parse --abbrev-ref HEAD)
        fi

        # Ensure the branch is up-to-date with $REMOTE/$MAINLINE_BRANCH
        ensure-up-to-date-with-mainline

        # Check for release branches
        local release_branch="release/${mainline_versions["$repo_name"]}"
        if git ls-remote --heads $REMOTE "$release_branch" | grep -q "$release_branch"; then
            log-info "Release branch $release_branch exists."
        else
            log-warn "Release branch $release_branch does not exist."
            log-info "Looking for tags matching version ${mainline_versions["$repo_name"]}..."
            local tags=$(git tag -l "*${mainline_versions["$repo_name"]}*")
            if [[ -z "$tags" ]]; then
                log-error "No tags found matching version ${mainline_versions["$repo_name"]}."
                break
            fi
            log-info "Found tags: $tags"
            read -p "Do you want to create a release branch $release_branch? (y/n): " create_release_branch
            if [[ "$create_release_branch" == "y" ]]; then
                git checkout -b "$release_branch" "${tags[0]}" || {
                    log-error "Failed to create release branch $release_branch."
                    break
                }
                git push $REMOTE "$release_branch"
            else
                log-info "Skipping release branch creation."
                break
            fi
        fi

        # Create a new branch for backporting
        local new_branch="${current_branch}-backport-${mainline_versions["$repo_name"]}"
        log-info "Creating a new branch $new_branch..."
        git checkout -b "$new_branch" "$release_branch"
        git rebase -i "$release_branch" || log-error "Interactive rebase failed. Resolve conflicts and try again."
        break
    done
}

# Main inspect_dependencies function
function inspect-dependencies() {

    log-info "Inspecting dependencies for changes..."
    grid_dir=$(git rev-parse --show-toplevel)
    local props_file="Source/Directory.Build.props"

    # Parse current branch's dependency versions
    declare -A current_versions
    local current_head=$(git rev-parse HEAD)
    parse-dependency-versions $current_head "$props_file" current_versions || die 1 "Failed to parse dependency versions for $current_branch."

    declare -A mainline_versions
    local mainline_head=$(git rev-parse $REMOTE/$MAINLINE_BRANCH)
    parse-dependency-versions $mainline_head "$props_file" mainline_versions || die 1 "Failed to parse dependency versions for $REMOTE/$MAINLINE_BRANCH."

    # Compare versions and handle changes
    declare -A changed_dependencies
    compare-dependency-versions current_versions mainline_versions changed_dependencies

    handle-changed-dependencies changed_dependencies mainline_versions
}

function display-menu() {
    local branch=$(git rev-parse --abbrev-ref HEAD)
    echo -e "==========================="
    echo -e "${COLOR_BLUE}Backport Helper Menu. Branch -> ${branch}:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1. Backport current branch${COLOR_RESET}"
    echo -e "${COLOR_GREEN}2. Inspect dependencies for changes${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}h. Show help${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}q. Quit${COLOR_RESET}"
    echo -e "==========================="
}

function show-help() {
    echo -e "${COLOR_BLUE}Backport Helper script:${COLOR_RESET}"
    echo -e "This script assists with backporting branches to release branches."
    echo -e "It provides options to check the current branch, inspect dependencies, and create backport branches."
    echo -e ""
    echo -e "Usage:"
    echo -e "1. Backport current branch: Create a new branch for backporting the current branch."
    echo -e "2. Inspect dependencies for changes: Check for dependency version changes."
    echo -e "h. Show help: Display this help message."
    echo -e "q. Quit: Exit the script."
}

pre-script-check || die 1 "Pre-script checks failed."
clear 

# Main script
while true; do
    # clear
    last_error=$(get-last-error)
    # if [[ ! -n "$last_error" ]]; then
    #     # clear
    # fi
    display-menu
    read -p "Select an option: " choice
    case $choice in
        1)
            ensure-up-to-date-with-mainline || {
                log-warn "Failed to ensure the branch is up-to-date."
                continue
            }

            version_out="" patch_out=""
            detect-version-to-backport version_out patch_out || {
                log-warn "Failed to detect version to backport."
                continue
            }

            release_branch="release/${version_out}"
            if check-release-branch-exists "$release_branch"; then
                create-backport-branch "$release_branch" "$patch_out"
            fi
            ;;
        2)
        
            ensure-in-grid-repo "quiet"
            ensure-up-to-date-with-mainline || {
                log-warn "Failed to ensure the branch is up-to-date."
                continue
            }
            inspect-dependencies
            ;;
        h|H)
            show-help
            ;;
        q|Q)
            log-info "Exiting Backport Helper."
            exit 0
            ;;
        *)
            log-warn "Invalid choice. Please try again."
            ;;
    esac
done