#!/bin/bash
# backport_helper.sh
# A script to assist with backporting branches to release branches.
# Author: Bernie
# Date: 2025-05-04
#
# Dependencies:
# - scripts
# - gchu
# - git-base-update

COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"
YES_NO=("y" "n")
REMOTE="origin"  
MAINLINE_BRANCH="master"
ERROR=""
CURRENT_BRANCH=""
TICKET_ID=""
SCRIPT_DIR=$(dirname "$(realpath "$0")")
HELPER_SCRIPTS="$SCRIPT_DIR/backport_helper_tools"
REPO_CHECKER_SCRIPT="$HELPER_SCRIPTS/repo_path_checker.sh"
REPO_PATH_CACHE="$HELPER_SCRIPTS/repo_paths.txt"
declare -A HEAD_VERSIONS
declare -A MAINLINE_VERSIONS
declare -A RELEASE_VERSIONS

declare -A PROPS_TO_REPO_MAP=(
    ["EyeGaze"]="libs/eyegaze.git"
    ["GridPhone"]="libs/gridphone.git"
    ["Shared"]="libs/shared.git"
    ["Speech"]="apps/speech.git"
    ["Eriskay"]="libs/eriskaylib.git"
    ["SpeechEngine"]="apps/grid.git"
    ["LakeLib"]="apps/smartboxlink.git"
)
## set verbosity level depending on flag
if [[ $1 == "-v" ]]; then
    VERBOSE=true
else
    VERBOSE=false
fi

source $logging_utils_path


function log-info-verbose() {
    if $VERBOSE; then
        log-info "$1"
    fi
}

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
        choice=$(read-user-input "Do you want to navigate to the grid repository at $GRID_REPO_DIR? (y/n)" YES_NO)
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
    title "Performing pre-menu checks..."

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
    # read -p "Do you want to work with the current branch ($current_branch, Ticket: $TICKET_ID)? (y/n): " choice
    # if [[ "$choice" != "y" ]]; then
    #     if ! command -v gchu &> /dev/null; then
    #         die 0 "Please check out the branch you wish to backport and re-run the script."
    #     fi
    #     read -p "Enter the branch pattern to checkout: " branch_pattern
    #     gchu "$branch_pattern" ||  die 1 "Failed to checkout branch matching pattern $branch_pattern."
    #     current_branch=$(git rev-parse --abbrev-ref HEAD)
    #     set-ticket-id "$current_branch" || exit 1
    #     log-info "Switched to branch: $current_branch"
    # fi
    CURRENT_BRANCH=$current_branch
}

function detect-version-to-backport() {
    title "Detecting the version to backport..."
    local tag=$(git describe --tags --abbrev=0)
    log-info "Latest tag detected: $tag"
    if [[ $tag =~ Grid_([0-9]+\.[0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
        local major_minor=${BASH_REMATCH[1]}
        local patch=${BASH_REMATCH[2]}
        log-info "Latest detected version of Major.Minor.Patch: $major_minor.$patch"

        choice=$(read-user-input "Do you want to use the patch version of $patch? (y/n)" YES_NO)
        # read -p "Do you want to use the patch version of $patch? (y/n): " choice
        if [[ "$choice" != "y" ]]; then
            new_patch=$(read-user-input "Enter the new patch version (e.g. 94)")

            # read -p "Enter the new patch version (e.g. 94): " new_patch
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
    git rebase -i --onto "$release_branch" $branch_base_commit "$new_branch" || handle-rebase-conflicts
    choice=$(read-user-input "Do you want to push the new branch ${new_branch} to $REMOTE? (y/n)" YES_NO)

    # read -p "Do you want to push the new branch ${new_branch} to $REMOTE? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        log-warn "Skipping push operation."
        return 0
    fi
    git push -u $REMOTE "$new_branch" || log-error "Failed to push new branch ${new_branch}."
}

# Parse the dependency versions from a given props file
function parse-versions-from-props() {
    local git_ref=$1
    local props_file="Source/Directory.Build.props"
    declare -n versions_ref=$2  # Use a name reference for the output array

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
            $VERBOSE && log-info "Found dependency: $repo_name with version $version"
        fi
    done < <(echo "$file_contents" | grep -oP '<\w+Version>\[.*?\]</\w+Version>')

    log-success "Parsed dependency versions from $props_file at ref $git_ref."
}

# Handle changed dependencies and allow the user to create branches
function handle-changed-dependencies() {
    declare -n changed_dependencies=$1

    log-info "Listing changed dependencies..."
    PS3="Select a dependency to create a branch for (or type 'q' to quit): "
    select repo_name in "${!changed_dependencies[@]}"; do
        if [[ -z "$repo_name" ]]; then
            log-warn "Invalid selection. Please try again."
            continue
        fi

        $REPO_CHECKER_SCRIPT $repo_name --suppress-info
        # get repo path from repo_paths.txt
        declare -A repo_paths

        if [[ -f $REPO_PATH_CACHE ]]; then
            while IFS='=' read -r key value; do
                repo_paths["$key"]="$value"
            done < "$REPO_PATH_CACHE"
        else
            # error and continue
            log-error "Could not find $REPO_PATH_CACHE data file. Skipping $repo_name..."
            continue
        fi

        local repo_path=repo_paths["$repo_name"]
        log-info "Using repo path of $repo_path"

        # Navigate to the repository
        # local repo_path="C:/dev/$repo_name"
        # if [[ ! -d "$repo_path" ]]; then
        #     log-error "Repository $repo_name not found at $repo_path."
        #     break
        # fi
        cd "$repo_path" || {
            log-error "Failed to navigate to $repo_path."
            break
        }

        # Detect the current branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        log-info "Current branch: $current_branch"
        use_current_branch=$(read-user-input "Do you want to use this branch for backporting? (y/n)" YES_NO)

        # read -p "Do you want to use this branch for backporting? (y/n): " use_current_branch
        if [[ "$use_current_branch" != "y" ]]; then
            if ! command -v gchu &> /dev/null; then
                log-info "Please check out the branch you wish to backport and re-run the script."
                break
            fi
            branch_pattern=$(read-user-input "Enter the branch pattern to checkout: $release_branch?")
            # read -p "Enter the branch pattern to checkout: " branch_pattern
            gchu "$branch_pattern" || {
                log-error "Failed to checkout branch matching pattern $branch_pattern."
                break
            }
            current_branch=$(git rev-parse --abbrev-ref HEAD)
        fi

        # Ensure the branch is up-to-date with $REMOTE/$MAINLINE_BRANCH
        git-base-update -upstream || {
            log-warn "Failed to ensure the branch is up-to-date with $REMOTE/$MAINLINE_BRANCH."
            break
        }

        # Check for release branches
        local release_branch="release/${MAINLINE_VERSIONS["$repo_name"]}"
        if git ls-remote --heads $REMOTE "$release_branch" | grep -q "$release_branch"; then
            log-info "Release branch $release_branch exists."
        else
            log-warn "Release branch $release_branch does not exist."
            log-info "Looking for tags matching version ${MAINLINE_VERSIONS["$repo_name"]}..."
            local tags=$(git tag -l "*${MAINLINE_VERSIONS["$repo_name"]}*")
            if [[ -z "$tags" ]]; then
                log-error "No tags found matching version ${MAINLINE_VERSIONS["$repo_name"]}."
                break
            fi
            log-info "Found tags: $tags"
            create_release_branch=$(read-user-input "Do you want to create a release branch $release_branch? (y/n)" YES_NO)

            # read -p "Do you want to create a release branch $release_branch? (y/n): " create_release_branch
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

function get-modified-dependencies() {
    declare -n versions_ref1=$1
    declare -n versions_ref2=$2
    declare -n modified=$3

    # Compare dependencies
    for repo_name in "${!versions_ref1[@]}"; do
        # Instead of checking that the version strings are not equal we should compare the version numbers
        # A versio could be a single number, e.g. 1, or a version with multiple parts, e.g. 1.2.3. The first number
        # will have priority followed by the second and so on. The numbers should be compared as integers.

        if [[ "${versions_ref1[$repo_name]}" != "${versions_ref2[$repo_name]}" ]]; then
            modified["$repo_name"]="${versions_ref1[$repo_name]}"
            $VERBOSE && log-info "Dependency modified: $repo_name ($1: ${versions_ref1[$repo_name]} -> $2: ${versions_ref2[$repo_name]})"
        fi
    done
}

function compare-modified-dependencies() {
    local release_branch=$1
    local mainline_branch=$2
    declare -n requires_release_branch=$3
    local props_file="Source/Directory.Build.props"

    declare -A modified_dependencies
    declare -A release_dependencies
    
    local current_head=$(git rev-parse HEAD)
    local mainline_head=$(git rev-parse "$REMOTE/$MAINLINE_BRANCH")
    local release_head=$(git rev-parse "$REMOTE/$release_branch")
    parse-versions-from-props "$current_head" HEAD_VERSIONS
    parse-versions-from-props "$mainline_head" MAINLINE_VERSIONS
    parse-versions-from-props "$release_head" RELEASE_VERSIONS

    # Compare current branch dependency versions to mainline branch
    get-modified-dependencies HEAD_VERSIONS MAINLINE_VERSIONS modified_dependencies

    # Compare mainline branch dependency versions to release branch
    get-modified-dependencies RELEASE_VERSIONS MAINLINE_VERSIONS release_dependencies

    for repo_name in "${!release_dependencies[@]}"; do
        if [[ -n "${modified_dependencies[$repo_name]}" ]]; then
            requires_release_branch["$repo_name"]="${modified_dependencies[$repo_name]}"
        fi
    done
}

# Handle rebase conflicts
function handle-rebase-conflicts() {
    log-warn "Rebase failed due to conflicts."
    while true; do
        echo -e "${COLOR_YELLOW}Options:${COLOR_RESET}"
        echo "1. Open merge tool"
        echo "2. Add resolved code and continue rebase"
        echo "3. Abort rebase and exit"
        echo "4. Continue rebase"
        read -p "Select an option: " choice
        case $choice in
            1)
                git mergetool || log-error "Failed to open merge tool."
                ;;
            2)
                git add -A || log-error "Failed to add resolved code."
                git rebase --continue || log-error "Failed to continue rebase."
                ;;
            3)
                git rebase --abort || log-error "Failed to abort rebase."
                exit 1
                ;;
            4)
                git rebase --continue || log-error "Failed to continue rebase."
                ;;
            *)
                log-warn "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Perform a backport
function perform-backport() {
    title "Performing backport for branch $CURRENT_BRANCH..." "reset-count"
    title "Ensuring the current branch is up-to-date with its remote and based on $REMOTE/$MAINLINE_BRANCH..."
    git-base-update -upstream || {
        log-warn "Failed to ensure the branch is up-to-date."  
        return 1
    }

    local version_out="" patch_out=""
    detect-version-to-backport version_out patch_out || {
        log-warn "Failed to detect version to backport."
        return 1
    }

    release_branch="release/${version_out}"
    if check-release-branch-exists "$release_branch"; then
        create-backport-branch "$release_branch" "$patch_out"
    else
        log-error "Release branch $release_branch does not exist. Exiting."
        return 1
    fi

    declare -A modified
    compare-modified-dependencies "$release_branch" "$REMOTE/$MAINLINE_BRANCH" modified

    for repo_name in "${!modified[@]}"; do
        log-info "Dependency $repo_name may require a release branch."
        log-info "Versions: HEAD: ${HEAD_VERSIONS[$repo_name]}, Mainline: ${MAINLINE_VERSIONS[$repo_name]}, Release: ${RELEASE_VERSIONS[$repo_name]}"
    done

     if [[ ${#modified[@]} -eq 0 ]]; then
        log-info "No dependencies that require release branches found."
        return 0
    fi

    # handle-changed-dependencies modified

    # Handle release branch creation and backporting
    # (Implementation omitted for brevity)
    # for repo_name in "${!release_dependencies[@]}"; do
    #     if [[ -n "${modified[$repo_name]}" ]]; then
    #         log-info "Dependency $repo_name requires a release branch."
    #         # Handle release branch creation and backporting
    #         # (Implementation omitted for brevity)
    #     fi
    # done
}

function inspect-dependencies() {
    title "Inspecting dependencies for changes..." "reset-count"

    choice=$(read-user-input "Do you want to get up-to-date with the mainline? (y/n)" YES_NO)
    # read -p "Do you want to get up-to-date with the mainline (y/n)? " choice
    if [[ "$choice" == "y" ]]; then
        git-base-update -upstream || {
            log-warn "Failed to ensure the branch is up-to-date."  
            return 1
        }
    fi

    local version_out="" patch_out=""
    detect-version-to-backport version_out patch_out || {
        log-warn "Failed to detect version to backport."
        return 1
    }

    release_branch="release/${version_out}"
    check-release-branch-exists "$release_branch"

    declare -A modified
    compare-modified-dependencies "$release_branch" "$REMOTE/$MAINLINE_BRANCH" modified

    for repo_name in "${!modified[@]}"; do
        log-info "Dependency $repo_name may require a release branch."
        log-info "Versions: HEAD: ${HEAD_VERSIONS[$repo_name]}, Mainline: ${MAINLINE_VERSIONS[$repo_name]}, Release: ${RELEASE_VERSIONS[$repo_name]}"
    done

     if [[ ${#modified[@]} -eq 0 ]]; then
        log-info "No dependencies that require release branches found."
        return 0
    fi
}

function display-menu() {
    local branch=$(git rev-parse --abbrev-ref HEAD)
    echo -e "==========================="
    echo -e "${COLOR_BLUE}Backport Helper Menu. Branch -> ${branch}:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1. Backport current branch${COLOR_RESET}"
    echo -e "${COLOR_GREEN}2. Inspect dependencies for changes${COLOR_RESET}"
    echo -e "${COLOR_GREEN}3. Perform individual actions${COLOR_RESET}"
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

function show-sub-menu() {
    echo -e "${COLOR_YELLOW}Sub-menu options:${COLOR_RESET}"
    echo -e "c. Check for necessary repos"
    echo -e "v. Toggle verbose mode (current: $VERBOSE)"
    echo -e "b. return to main menu"
    echo -e "q. Quit"

    read -p "Select an option: " choice
    case $choice in
        c|C)
            log-info "${COLOR_YELLOW}Checking for necessary repositories...${COLOR_RESET}"
            if [[ ! -f "$REPO_CHECKER_SCRIPT" ]]; then
                log-error "$REPO_CHECKER_SCRIPT not found. Please check the path."
                return 1
            fi

            $REPO_CHECKER_SCRIPT
            ;;
        v|V)
            if $VERBOSE; then
                VERBOSE=false
                log-info "Verbose mode disabled."
            else
                VERBOSE=true
                log-info "Verbose mode enabled."
            fi
            ;;
        b|B)
            return 0
            ;;
        q|Q)
            log-info "Exiting Backport Helper."
            exit 0
            ;;
        *)
            log-warn "Invalid choice. Please try again."
            ;;
    esac
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
            perform-backport || continue
            ;;
        2)
            inspect-dependencies || continue
        
            # ensure-in-grid-repo "quiet"
            # ensure-up-to-date-with-mainline || {
            #     log-warn "Failed to ensure the branch is up-to-date."
            #     continue
            # }
            # inspect-dependencies
            ;;
        3) 
            show-sub-menu
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