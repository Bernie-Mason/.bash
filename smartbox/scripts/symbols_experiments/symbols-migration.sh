#!/bin/bash

# Color variables
NC='\033[0m'              # Text Reset
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'

# Function to log messages
log() {
  echo -e "${Blue}[$(date +'%Y-%m-%d %H:%M:%S')] ${NC}$1"
}

# Function to check if a directory is an SVN directory
is_svn_directory() {
  if [ -d "$1/.svn" ]; then
    return 0
  else
    return 1
  fi
}

# Function to update SVN directory
update_svn_directory() {
  log "Checking if SVN directory needs updating..."
  svn status -u "$1" | grep -q '*'
  if [ $? -eq 0 ]; then
    read -p $'\e[32mSVN directory needs updating. Do you want to update it? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        log "Updating SVN directory..."
        svn update "$1"
        ;;
      *)
        log "Exiting script."
        exit 0
        ;;
    esac
  else
    log "SVN directory is up to date."
  fi
}

# Function to create SymbolLibraries directory and copy files
decompress_symbol_libraries() {
  if [ -d "SymbolLibraries" ]; then
    while true; do
      read -p "The directory SymbolLibraries exists. Type \"remove\" to remove it or \"continue\" to continue with the existing SymbolLibraries?" choice 
        
      if [ "$choice" == "remove" ]; then
        rm -rf "SymbolLibraries"
      elif [ "$choice" == "continue" ]; then
        return
      else 
        log "Invalid choice Please type either \"remove\" or \"continue\"."
      fi
    done
  fi
  log "Creating SymbolLibraries directory..."
  mkdir -p SymbolLibraries
  log "Copying directories from SVN directory to SymbolLibraries..."
  for dir in "$1"/*; do
    if [ -d "$dir" ] && [[ $(basename "$dir") != _* ]]; then
      cp -r "$dir" SymbolLibraries/
    fi
  done
  log "Unzipping files in SymbolLibraries..."
  find SymbolLibraries -name "*.zip" | xargs -P 5 -I fileName sh -c 'unzip -o -d "$(dirname "fileName")/$(basename -s .zip "fileName")" "fileName" > /dev/null'
  log "Removing remaining zip files..."
  find . -name "*.zip" -type f -delete
}

# Function to clone the symbols repository
clone_symbols_repo() {
  local clone_path="$1"
  log "The current directory is ${1}";
  read -p $'\e[32mIs a good location to clone the repository? (y/n): \e[0m' choice
  case "$choice" in
    y|Y|yes|Yes)
      ;;
    *)
      read -p $'\e[32mEnter the path to clone the repository: \e[0m' clone_path
      ;;
  esac

  if [ -d "$clone_path/symbols" ]; then
    read -p $'\e[32mDirectory named symbols already exists. Do you want to start over? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        log "Removing existing directory..."
        rm -rf "$clone_path/symbols"
        ;;
      *)
        log "Continuing with existing directory."
        return
        ;;
    esac
  fi

  log "Cloning symbols repository..."
  git clone ssh://git@bitbucket.thinksmartbox.com:7999/content/symbols.git "$clone_path/symbols"
}

# Function to check and clear the contents of the symbol repository
check_and_clear_repo() {
  if [ "$(ls -A)" != ".git" ]; then
    read -p $'\e[32mRepository contains files. Do you want to clear the contents? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        rm -rf ./*
        ;;
      *)
        log "Continuing with existing contents."
        ;;
    esac
  fi
}

checkout_working_branch() {
    if git show-ref --verify --quiet refs/heads/task/symbol-migration; then
    git checkout task/symbol-migration
  else
    git checkout -b task/symbol-migration
  fi
}

# Function to create .gitattributes file
create_gitattributes() {
  if [ ! -f .gitattributes ]; then
    log "Creating .gitattributes file..."
    echo "* -text" > .gitattributes
    git add .gitattributes
    git commit -m "Add .gitattributes to disable line ending normalization"
  fi
}

# Function to add gridresources submodule
add_gridresources_submodule() {
  if ! git submodule status | grep -q "gridresources"; then
    log "Adding gridresources submodule..."
    git submodule add ssh://git@bitbucket.thinksmartbox.com:7999/content/gridresources.git
    git commit -m "Add gridresources submodule"
  else
    log "gridresources submodule already exists."
    cat .gitmodules
    read -p $'\e[32mDo you want to recreate the submodule? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        git submodule deinit -f gridresources
        rm -rf .git/modules/gridresources
        git rm -f gridresources
        git submodule add ssh://git@bitbucket.thinksmartbox.com:7999/content/gridresources.git
        git commit -m "Recreate gridresources submodule"
        ;;
      *)
        log "Continuing with existing submodule."
        ;;
    esac
  fi
}

# Function to move SymbolLibraries to the repository
move_symbol_libraries() {
  log "Moving SymbolLibraries to the repository..."
  mv ../SymbolLibraries .
  git add SymbolLibraries
  git commit -m "Add SymbolLibraries"
}

# Function to copy tools to the repository
copy_tools() {
  read -p $'\e[32mEnter the path to the tools repository: \e[0m' tools_path
  if [ -d "$tools_path/.git" ] && [ -d "$tools_path/Symbols" ]; then
    log "Copying tools to the repository..."
    mkdir -p Tools
    cp -r "$tools_path/Symbols"/* Tools/
    git add Tools
    git commit -m "Add Tools"
  else
    log "Invalid tools repository path."
    exit 1
  fi
}

show_repository_stats() {
  echo -e "${Yellow}Repository statistics:${NC}"
  git_objects_data=$(git count-objects -v)
  echo -e "${Yellow}Object count:${NC} \n${git_objects_data}"
  git_objects_size=$(du -sh .git/objects)
  echo -e "${Yellow}Object total size:${NC} ${git_objects_size}"
  echo -e ""

  echo -e "${Yellow}Performing git gc...${NC}"
  git gc &> /dev/null
  git_objects_data=$(git count-objects -v)
  echo -e "${Yellow}Object count after git gc:${NC} \n${git_objects_data}"
  git_objects_size=$(du -sh .git/objects)
  echo -e "${Yellow}Object total size after git gc:${NC} ${git_objects_size}"
  echo -e ""

  symbol_library_size=$(du -sh "SymbolLibraries")
  echo -e "${Yellow}SymbolLibraries size:${NC} ${symbol_library_size}"
  tools_size=$(du -sh "Tools")
  echo -e "${Yellow}Tools size:${NC} ${tools_size}"
  grid_resources_size=$(du -sh "gridresources" )
  echo -e "${Yellow}Gridresources size:${NC} ${grid_resources_size}"

  echo -e "${Yellow}Calculating total size of whole repo...${NC}"
  total_size=$(du -sh */ | sort -hr)
  echo -e "${Yellow}Total size:${NC} ${total_size}xh
  "
  echo -e ""
}

cleanup() {
  log "Cleaning up..."
  if [ -d "SymbolLibraries" ]; then
    read -p $'\e[32mDo you want to remove the SymbolLibraries directory? (y/n): \e[0m' choice
    if [ "$choice" == "y" ]; then
      rm -rf SymbolLibraries
    fi
  fi
}

# Main script
start_time=$(date +%s)

if [ $# -ne 1 ]; then
  echo "Usage: $0 <SVNSymbolLibraryDirectory>"
  exit 1
fi

SVNSymbolLibraryDirectory="$1"

if ! is_svn_directory "$SVNSymbolLibraryDirectory"; then
  echo "Error: $SVNSymbolLibraryDirectory is not a valid SVN directory."
  exit 1
fi

log "Starting symbol migration script..."
log "Select an operation mode:"
log "fm => Run a full migration"
log "up => Update symbol libraries from SVN"
log "rs => Show reposistory statistics"
read -p "Enter your selection: " choice

case "$choice" in
  fm)
    log "Running full migration..."
    update_svn_directory "$SVNSymbolLibraryDirectory"
    decompress_symbol_libraries "$SVNSymbolLibraryDirectory"
    CURRENT_DIRECTORY=$(pwd)
    cd "${CURRENT_DIRECTORY}/symbols" || exit
    clone_symbols_repo
    checkout_working_branch
    check_and_clear_repo
    create_gitattributes
    add_gridresources_submodule
    move_symbol_libraries
    copy_tools
    show_repository_stats

    cd ${CURRENT_DIRECTORY} || exit
    cleanup

    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    log "Script completed in $elapsed_time seconds."
    ;;
  up)
    log "Updating symbol libraries from SVN..."
    update_svn_directory "$SVNSymbolLibraryDirectory"
    decompress_symbol_libraries "$SVNSymbolLibraryDirectory"
    CURRENT_DIRECTORY=$(pwd)
    cd "${CURRENT_DIRECTORY}/symbols" || exit
    move_symbol_libraries
    show_repository_stats    

    cd ${CURRENT_DIRECTORY} || exit
    cleanup
    exit 0
    ;;
  rs)
    log "Showing repository statistics..."
    CURRENT_DIRECTORY=$(pwd)
    if [ ! -d ".git" ]; then
      log "Error: Not a git repository. Please run the script in the symbols git repository."
      exit 1
    fi
    show_repository_stats
    exit 0
    ;;
  *)
    log "Invalid selection. Please try again."
    exit 1
    ;;
esac