#!/bin/bash
#
# Repo path checker script
#

COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"
SUPPRESS_ERRORS=false
SUPPRESS_INFO=false
SCRIPT_DIR=$(dirname "$(realpath "$0")")
OUTPUT="$SCRIPT_DIR/repo_paths.txt"

source $logging_utils_path

declare -A PROPS_TO_REPO_MAP=(
    ["EyeGaze"]="libs/eyegaze.git"
    ["GridPhone"]="libs/gridphone.git"
    ["Shared"]="libs/shared.git"
    ["Speech"]="apps/speech.git"
    ["Eriskay"]="libs/eriskaylib.git"
    ["SpeechEngine"]="apps/speech.git" #  TODO: check if this is correct
    ["LakeLib"]="apps/smartboxlink.git"
)

REPO_TO_CHECK=$1

while test $# -gt 0; do
    case "$1" in
        -s|--suppress-errors)
            SUPPRESS_ERRORS=true;
            shift
            ;;  
        -i|--suppress-info)
            SUPPRESS_INFO=true;
            shift
            ;;
        *)
            shift
            continue
            ;;
    esac
done

function validate-repo-path() {
    local repo_path=$1
    local repo_name=$2
     if [[ ! -d "$repo_path" ]]; then
        $SUPPRESS_ERRORS || log-error  "Repository $repo_name not found at $repo_path."
        return 1
    elif [[ ! -d "$repo_path/.git" ]]; then
        $SUPPRESS_ERRORS || log-error "No .git directory found in $repo_path. Please check the path."
        return 1
    else
        cd $repo_path
        if ! git remote -v | grep -q "${PROPS_TO_REPO_MAP[$repo_name]}"; then
            $SUPPRESS_ERRORS || log-error "The current repository is not the correct repository (missing the fragment '${PROPS_TO_REPO_MAP[$repo_name]}' in remotes)."
            return 1
        fi
        cd $OLDPWD
    fi
    return 0
}

function get-valid-repo-path() {
    local repo_name=$1
    $SUPPRESS_INFO || log-info "Checking for $repo_name with value ${PROPS_TO_REPO_MAP[$repo_name]}" 

    if [[ -n "${REPO_PATHS[$repo_name]}" ]]; then
        validate-repo-path "${REPO_PATHS[$repo_name]}" "$repo_name"
        if [[ $? -ne 0 ]]; then
            $SUPPRESS_ERRORS || log-error "$repo_name exists in ${REPO_PATHS[$repo_name]} but is invalid. Removing from $OUTPUT."
            sed -i "/$repo_name=/d" $OUTPUT
        else
            $SUPPRESS_INFO || log-info "$repo_name exists in $OUTPUT and is valid."
            return 0 
        fi
    fi

    read -p "Enter path to the $repo_name repository: " repo_path
    echo "Validating $repo_name at $repo_path..."
    validate-repo-path "$repo_path" "$repo_name" || { 
        $SUPPRESS_ERRORS || log-error "Validation failed for $repo_name at $repo_path. Exiting."
        exit 1
    }
    $SUPPRESS_INFO || log-info "Validation passed for $repo_name at $repo_path."
    
    echo "$repo_name=$repo_path" >> $OUTPUT
}

declare -A REPO_PATHS

if [[ -f $OUTPUT ]]; then
    # If the file exists, read the paths from it
    # and populate the REPO_PATHS array with the key
    # as the repo name and the value as the path
    while IFS='=' read -r key value; do
        REPO_PATHS["$key"]="$value"
    done < "$OUTPUT"
fi

if [[ ! -z "$REPO_TO_CHECK" ]]; then
    if [[ ! ${PROPS_TO_REPO_MAP[$REPO_TO_CHECK]} ]]; then
        log-error "Error: Invalid repository name '$REPO_TO_CHECK'."
        ## Display valid repository names
        ## and exit with error code 1
        log-info "Valid repository names (case sensitive) are:"
        for repo_name in "${!PROPS_TO_REPO_MAP[@]}"; do
            log-info " -> $repo_name"
        done
        exit 1
    fi

    get-valid-repo-path "$REPO_TO_CHECK"
else
    for repo_name in "${!PROPS_TO_REPO_MAP[@]}"; do
        get-valid-repo-path "$repo_name"
    done
fi