#!/bin/bash
# 
# pattern based git tag mover tool
#
# Finds a tag based on a provided regex and moves it to the current commit.
# If more than one match is found, the tool provides a list of options that may be selected.
#
# By default the script searches all tags (local and remote).
#
# Depends on:
# -> format-branches script. Required on path
# -> logging_utils script. Requires sourcing by setting the logging_utils_path environment variable

NC='\033[0m'              # Text Reset
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
UWhite='\033[4;37m'
Black='\033[0;30m'

source $logging_utils_path

function fetchForRemotes() {
    log-info "$1 selected as candidates, performing a git fetch to ensure tag list is up-to-date."
    git fetch --tags
}

function print_help() {
    echo -e "${UWhite}Move a tag to the current commit based on an identifier.${NC}"
    echo -e "First argument should be your string pattern for the tag in question. Supports grep operations."
    echo -e " "
    echo "\$gmvtag identifier [actions]"
    echo -e " "
    echo -e "actions:"
    echo -e "-h, --help        ${Yellow}show brief help${NC}"
    echo -e "-f, --force       ${Yellow}force move tag without confirmation${NC}"
    echo -e "-n, --dry-run     ${Yellow}show what would be done without actually moving the tag${NC}"
    echo -e "-b, --rainbow     ${Yellow}RAINBOW OUTPUT MODE${NC}"
    echo -e "-d, --debug       ${Yellow}enable debug output${NC}"
    die 0
}

PATTERN="$1"
test -z $PATTERN && print_help

FORCE=false
DRY_RUN=false
RAINBOW_OUTPUT=false
DEBUG=false

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            print_help
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--rainbow)
            RAINBOW_OUTPUT=true
            shift
            ;;
        *)
            shift
            continue
            ;;
    esac
done

$DEBUG && log-info "Debug output enabled"
log-info "Finding tags matching the pattern \"${PATTERN}\""

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log-error "git-move-tag FATAL: Not a git repository" true
fi

fetchForRemotes "Tags"

MATCHING_TAGS=$(git tag --list | grep -i $PATTERN)
TAGS=($MATCHING_TAGS)
MATCHCOUNT="${#TAGS[@]}"
$DEBUG && log-info "Match count: $MATCHCOUNT"

if [[ $MATCHCOUNT -eq 0 ]]; then
    log-error "${Red}No matching tags in the repository ${NC}\"$(basename `git rev-parse --show-toplevel`)\"${Red} for the pattern: ${NC}\"${PATTERN}\"${Red} Exiting...${NC}" true
fi

if (($MATCHCOUNT > 1)); then
    echo -e "${Green}More than one match. Select the one you want. E.g. type \"1\" to move the first item in the list:${NC}"

    for i in "${!TAGS[@]}"; do
        tag_name="${TAGS[$i]}"
        tag_commit=$(git rev-list -n 1 $tag_name 2>/dev/null)
        tag_commit_short=$(git rev-parse --short $tag_commit 2>/dev/null)
        tag_message=$(git tag -n1 $tag_name | sed "s/^$tag_name[[:space:]]*//" 2>/dev/null)
        
        if $RAINBOW_OUTPUT; then
            format-branches true "$tag_name ($tag_commit_short) $tag_message"
        else
            printf "${Yellow}%3d.${NC} %-30s ${Green}(%s)${NC} %s\n" $((i+1)) "$tag_name" "$tag_commit_short" "$tag_message"
        fi
    done

    echo ""
    re="^[0-9]+$"
    read -p "Enter number {1-$MATCHCOUNT}: " SELECTED_NUMBER
    log-info "Value read in: \"$SELECTED_NUMBER\""
    
    if ! [[ $SELECTED_NUMBER =~ $re ]]; then
        log-error "Not a valid option. Exiting..." true
    fi
    
    if (( $SELECTED_NUMBER < 1 || $SELECTED_NUMBER > $MATCHCOUNT )); then
        log-error "\"$SELECTED_NUMBER\" is out of bounds. exiting..." true
    fi

    SELECTED_TAG=${TAGS[$((--SELECTED_NUMBER))]}
    log-info "The selected tag is: \"$SELECTED_TAG\""
else
    SELECTED_TAG=${TAGS[0]}
    log-info "Found single matching tag: \"$SELECTED_TAG\""
fi

CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_COMMIT_SHORT=$(git rev-parse --short HEAD)

TAG_COMMIT=$(git rev-list -n 1 $SELECTED_TAG 2>/dev/null)
TAG_COMMIT_SHORT=$(git rev-parse --short $TAG_COMMIT 2>/dev/null)

log-info "Current commit: $CURRENT_COMMIT_SHORT"
log-info "Tag \"$SELECTED_TAG\" currently points to: $TAG_COMMIT_SHORT"

if [[ "$CURRENT_COMMIT" == "$TAG_COMMIT" ]]; then
    log-info "Tag \"$SELECTED_TAG\" is already at the current commit. Nothing to do."
    exit 0
fi

echo -e "${Yellow}Will move tag \"$SELECTED_TAG\" from $TAG_COMMIT_SHORT to $CURRENT_COMMIT_SHORT${NC}"

if $DRY_RUN; then
    log-info "Dry run mode - would execute:"
    echo "  git tag -d $SELECTED_TAG"
    echo "  git push origin :refs/tags/$SELECTED_TAG"
    echo "  git tag $SELECTED_TAG $CURRENT_COMMIT"
    echo "  git push origin $SELECTED_TAG"
    exit 0
fi

if ! $FORCE; then
    read -p "Are you sure you want to move this tag? (y/N): " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            log-info "Tag move cancelled."
            exit 0
            ;;
    esac
fi

title "Moving tag \"$SELECTED_TAG\" to current commit"
log-info "Removing local tag \"$SELECTED_TAG\"..."

if $DEBUG; then
    GIT_TRACE=1 git tag -d $SELECTED_TAG
else
    git tag -d $SELECTED_TAG
fi

if [[ $? != 0 ]]; then
    log-error "Failed to delete local tag \"$SELECTED_TAG\"" true
fi

log-info "Deleting remote tag..."
if $DEBUG; then
    GIT_TRACE=1 git push origin :refs/tags/$SELECTED_TAG
else
    git push origin :refs/tags/$SELECTED_TAG 2>/dev/null
fi

# Create new tag at current commit
log-info "Creating new tag at current commit..."
if $DEBUG; then
    GIT_TRACE=1 git tag $SELECTED_TAG $CURRENT_COMMIT
else
    git tag $SELECTED_TAG $CURRENT_COMMIT
fi

if [[ $? != 0 ]]; then
    log-error "Failed to create tag \"$SELECTED_TAG\" at current commit" true
fi

# Push new tag
log-info "Pushing new tag to remote..."
if $DEBUG; then
    GIT_TRACE=1 git push origin $SELECTED_TAG
else
    git push origin $SELECTED_TAG
fi

if [[ $? != 0 ]]; then
    log-error "Failed to push tag \"$SELECTED_TAG\" to remote" true
else
    log-success "Successfully moved tag \"$SELECTED_TAG\" to current commit $CURRENT_COMMIT_SHORT"
fi