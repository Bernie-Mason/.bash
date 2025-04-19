#!/bin/bash

NC='\033[0m'              # Text Reset
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
COMPRESSED_DIR="SymbolLibrariesDecompressed"
SVN_DIR="SymbolLibraries"
start_time=$(date +%s)
ROOT_PATH="/c/dev"
SVN_PATH="$ROOT_PATH/$SVN_DIR"
REPO_PATH="$ROOT_PATH/symbols"
COMPRESSED_PATH="$ROOT_PATH/$COMPRESSED_DIR"
TOOLS_PATH="$ROOT_PATH/tools"
LOG_FILE="${ROOT_PATH}/symbol_migration.log"
TICKET_ID="MD-151"
# VERBOSE=false

# if [[ $1 == "--verbose"]]; then
#   VERBOSE=true
# fi

# Function to log messages
log() {
  echo -e "${Blue}[$(date +'%Y-%m-%d %H:%M:%S')] ${NC}$1" | tee -a $LOG_FILE
}

title() {
  log "${Yellow}[-- $1 --]${NC}" | tee -a $LOG_FILE
}

is_svn_directory() {
  if [ -d "${SVN_PATH}/.svn" ]; then
    return 0
  else
    return 1
  fi
}

update_svn_directory() {
  title "Checking if SVN directory needs updating"
  svn status -u "$SVN_PATH" | grep -q '*'
  if [ $? -eq 0 ]; then
    read -p $'\e[32mSVN directory needs updating. Do you want to update it? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        log "Updating SVN directory..."
        svn update "$SVN_PATH"
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

decompress_symbol_libraries() {
  title "Decompressing symbol libraries"
  if [ -d "$COMPRESSED_PATH" ]; then
    while true; do
      read -p "The directory $COMPRESSED_PATH exists. Type \"remove\" to remove it or \"continue\" to continue with the existing $COMPRESSED_PATH? " choice 
        
      if [ "$choice" == "remove" ]; then
        rm -rf "$COMPRESSED_PATH"
        break
      elif [ "$choice" == "continue" ]; then
        return
      else 
        log "Invalid choice Please type either \"remove\" or \"continue\"."
      fi
    done
  fi
  mkdir -p $COMPRESSED_PATH
  log "Copying all files from $SVN_PATH to $COMPRESSED_PATH..."
  for node in "$SVN_PATH"/*; do
    log "Copying $node to $COMPRESSED_PATH..."
    cp -r "$node" $COMPRESSED_PATH/
  done

  log "Unzipping files from ${SVN_PATH} to $COMPRESSED_PATH..."
  echo "Log file for unzipping files" > /c/dev/ziplog.txt
  # if [ "$VERBOSE" = true ]; then
    find "$SVN_PATH" -name "*.zip" -print0 | while IFS= read -r -d '' zip_file; do
      local substituted=$(sed "s_${SVN_DIR}_${COMPRESSED_DIR}_g" <<< "${zip_file}")
      target_dir="$(dirname "${substituted}")/$(basename -s ".zip" "${substituted}")"
      echo "${target_dir}" 
      unzip -o -d "$target_dir" "$zip_file" 2>> /c/dev/ziplog.txt
      if [ $? -ne 0 ]; then
        echo "Error unzipping ${zip_file} to ${target_dir}" >> /c/dev/ziplog.txt
      fi
    done
  # else
  #   find $COMPRESSED_DIR -name "*.zip" | xargs -P 5 -I fileName sh -c 'unzip -o -d "$(dirname "fileName")/$(basename -s .zip "fileName")" "fileName" >> /c/dev/ziplog.txt'
  # fi
  tidy_decompressed_files
}

tidy_decompressed_files() {
  title "Tidying files ahead of migration"

  log "Removing zip files..."
  find $COMPRESSED_PATH -name "*.zip" -type f -delete
  log "Removing old Grid 2 symbol directories maksym and maksig..."
  rm -rf $COMPRESSED_PATH/maksym
  rm -rf $COMPRESSED_PATH/maksig
  log "Removing empty category extractor directory..."
  rm -rf "$COMPRESSED_PATH/_Category Extractor"
  log "Removing symbol swap directory..."
  rm -rf "$COMPRESSED_PATH/_Symbol Swap"
  log "Removing symbols libraries overview.pptx..."
  rm "$COMPRESSED_PATH/Symbol libraries overview.pptx"
  log "Removing .svn directory..."
  rm -rf "$COMPRESSED_PATH/.svn"
}

init_symbols_repo() {
  title "Initializing symbols repository"
  log "Target repo path is ${REPO_PATH}";
  read -p $'\e[32mIs a good location to init the repository? (y/n): \e[0m' choice
  case "$choice" in
    y|Y|yes|Yes)
      ;;
    *)
      read -p $'\e[32mEnter the path to init the repository: \e[0m' ROOT_PATH
      ;;
  esac

  if [ -d "$REPO_PATH" ]; then
    read -p $'\e[32mDirectory named symbols already exists. Do you want to start over? (y/n): \e[0m' choice
    case "$choice" in
      y|Y|yes|Yes)
        log "Removing existing directory..."
        rm -rf "$REPO_PATH"
        ;;
      *)
        log "Continuing with existing directory."
        return
        ;;
    esac
  fi

  mkdir -p "$REPO_PATH"
  cd "$REPO_PATH" || exit
  git init
}

git_set_symbols_remote() {
  title "Setting symbols remote"
  cd "$REPO_PATH" || exit
  git remote add "origin" ssh://git@bitbucket.thinksmartbox.com:7999/content/symbols.git 
}

check_and_clear_repo() {
  cd "$REPO_PATH" || exit
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
  title "Checking out working branch"
  cd "$REPO_PATH" || exit
  if git show-ref --verify --quiet refs/heads/task/symbol-migration; then
    git checkout task/${TICKET_ID}-symbol-migration
  else
    git checkout -b task/${TICKET_ID}-symbol-migration
  fi
}

create_gitattributes() {
  title "Creating .gitattributes file"
  cd "$REPO_PATH" || exit
  echo "* -text" > .gitattributes
  git add .gitattributes
  git commit -m "Add .gitattributes to disable line ending normalization $TICKET_ID"
}

add_gridresources_submodule() {
  title "Adding gridresources submodule"
  cd "$REPO_PATH" || exit
  if ! git submodule status | grep -q "gridresources"; then
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
  cd "$REPO_PATH" || exit
  title "Copying $COMPRESSED_PATH to the repository..."
  target_dir="$REPO_PATH/libraries/"
  if [ ! -d "$target_dir" ]; then
    cp -rf $COMPRESSED_PATH $target_dir
  else
    cp -rf "$COMPRESSED_PATH/"* "$target_dir"
  fi
}

git_commit_symbol_libraries() {
  cd "$REPO_PATH" || exit
  title "Committing symbol libraries..."
  log "Adding $SVN_DIR to the repository..."
  git add -v $SVN_DIR >> $LOG_FILE
  log "Committing changes..."
  git commit -m "Add uncompressed symbol libraries from SVN $TICKET_ID" >> $LOG_FILE
}

update_tools() {
  title "Updating tools..."
  if [ -d "$TOOLS_PATH/.git" ] && [ -d "$TOOLS_PATH/Symbols" ]; then
    cd "$TOOLS_PATH" || exit
    local working_directory_is_clean=$(git status --porcelain)
    if [ -n "$working_directory_is_clean" ]; then
      log "Working directory is not clean. Stashing changes..."
      git stash
    fi
    git checkout master
    git pull
    if [ -n "$working_directory_is_clean" ]; then
      log "Applying stashed changes..."
      git stash pop
    fi
  else
    log "Invalid tools repository path."
    exit 1
  fi
}

# Function to copy tools to the repository
copy_tools() {
  title "Copying tools to the repository..."
  cd "$REPO_PATH" || exit
  if [ -d "$TOOLS_PATH/.git" ] && [ -d "$TOOLS_PATH/Symbols" ]; then
    log "Copying tools to the repository..."
    mkdir -p Tools
    cp -r "$TOOLS_PATH/Symbols"/* "${REPO_PATH}/Tools/"
    #cp -r "$TOOLS_PATH/PictureIndexEditor" "${REPO_PATH}/Tools/"
    log "Adding Tools to the repository..."
    git add -v Tools  >> $LOG_FILE
    log "Committing Tools..."
    git commit -m "Add symbol tools from tools repo $TICKET_ID"  >> $LOG_FILE
  else
    log "Invalid tools repository path."
    exit 1
  fi
}

final_migration_steps() {
  title "Final migration steps..."
  log "Removing corrupted file 27617.png that does not exist in master folder."
  rm "$REPO_PATH\\$SVN_PATH\arasaa\Source\Pictogramas_Color_ID\27617.png"

  
}

show_repository_stats() {
  title "Showing repository statistics..."
  cd "$REPO_PATH" || exit
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

  symbol_library_size=$(du -sh "$COMPRESSED_PATH")
  echo -e "${Yellow}$COMPRESSED_DIR size:${NC} ${symbol_library_size}"
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
  cd "$REPO_PATH" || exit
  log "Cleaning up..."
  if [ -d "$COMPRESSED_DIR" ]; then
    read -p $'\e[32mDo you want to remove the $COMPRESSED_DIR) directory? (y/n): \e[0m' choice
    if [ "$choice" == "y" ]; then
      rm -rf $COMPRESSED_DIR
    fi
  fi
}


if ! is_svn_directory "$SVN_PATH"; then
  echo "No directory provided or not an SVN directory."
  
  read -p "Would you like to checkout a new SVN symbols directory to $SVN_PATH? (y/n): " choice
  case "$choice" in
    y|Y|yes|Yes)
      mkdir $SVN_PATH
      svn checkout "https://svn.sensorysoftware.com/svn/repos2/_Trunk/Resources/Symbol libraries" $SVN_PATH
      ;;
    *)
      echo "Exiting script."
      exit 0
      ;;
  esac
fi

cd /c/dev || exit

log "Starting symbol migration script..."
log "Select an operation mode:"
log "fm => Run a full migration"
log "up => Update symbol libraries from SVN"
log "rs => Show reposistory statistics"
read -p "Enter your selection: " choice

case "$choice" in
  fm)
    log "Running full migration..."
    update_svn_directory
    decompress_symbol_libraries 
    init_symbols_repo
    git_set_symbols_remote
    checkout_working_branch
    check_and_clear_repo
    create_gitattributes
    #add_gridresources_submodule
    copy_tools
    move_symbol_libraries
    git_commit_symbol_libraries
    show_repository_stats

    cd ${CURRENT_DIRECTORY} || exit
    cleanup

    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    log "Script completed in $elapsed_time seconds."
    ;;
  up)
    log "Updating symbol libraries from SVN..."
    update_svn_directory
    decompress_symbol_libraries
    #checkout_working_branch
    move_symbol_libraries
    #git_commit_symbol_libraries
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
    log "Invalid selection. Exiting."
    exit 1
    ;;
esac