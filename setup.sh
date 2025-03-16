#!/bin/bash

# Define the base directory
BASE_DIR="$HOME/.bash"
CONFIG_DIR="$BASE_DIR/global/conf"
HOME_DIR="$HOME"

# Function to prompt for user input
prompt() {
  local prompt_text="$1"
  local default_value="$2"
  read -p "$prompt_text [$default_value]: " input
  echo "${input:-$default_value}"
}

# Function to generate .bash_profile
generate_bash_profile() {
  local bash_profile_path="$HOME_DIR/.bash_profile"
  if [ -f "$bash_profile_path" ]; then
    read -p "$bash_profile_path already exists. Do you want to overwrite it? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
      return
    fi
  fi
  cp "$CONFIG_DIR/.bash_profile.sample" "$bash_profile_path"
  echo ".bash_profile generated at $bash_profile_path"
}

# Function to generate .bashrc
generate_bashrc() {
  local bashrc_path="$HOME_DIR/.bashrc"
  if [ -f "$bashrc_path" ]; then
    read -p "$bashrc_path already exists. Do you want to overwrite it? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
      return
    fi
  fi

  echo "# .bashrc" > "$bashrc_path"
  echo "source $HOME_DIR/.bash_profile" >> "$bashrc_path"

  local environment=$(prompt "Enter environment (home/smartbox)" "home")
  local platform=$(prompt "Enter platform (windows/linux/ios)" "windows")

  local paths_to_add=(
    "$BASE_DIR/global/sourceable"
    "$BASE_DIR/global/$environment/sourceable"
    "$BASE_DIR/$platform/$environment/sourceable"
    "$BASE_DIR/$platform/sourceable"
  )
  
  echo "" >> "$bashrc_path"
  echo "function source_all_bash_files() {" >> "$bashrc_path"
  for path in "${paths_to_add[@]}"; do
    if [ -d "$path" ]; then
      echo "  local SOURCEABLE_DIRECTORY=$path" >> "$bashrc_path"
      echo "  for i in \$(find \$SOURCEABLE_DIRECTORY -type f); do" >> "$bashrc_path"
      echo "    source \$i" >> "$bashrc_path"
      echo "  done;" >> "$bashrc_path"
    fi
  done
  echo "}" >> "$bashrc_path"
  echo "" >> "$bashrc_path"
  echo "source_all_bash_files" >> "$bashrc_path"

  echo ".bashrc generated at $bashrc_path"
}

# Function to generate .gitconfig
generate_gitconfig() {
  local gitconfig_path="$HOME_DIR/.gitconfig"
  if [ -f "$gitconfig_path" ]; then
    read -p "$gitconfig_path already exists. Do you want to overwrite it? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
      return
    fi
  fi

  local name=$(prompt "Enter your name" "Your Name")
  local email=$(prompt "Enter your email" "your.email@example.com")
  local whitespace=$(prompt "Enter whitespace handling (e.g., cr-at-eol)" "cr-at-eol")

  echo "[user]" > "$gitconfig_path"
  echo "  name = $name" >> "$gitconfig_path"
  echo "  email = $email" >> "$gitconfig_path"
  echo "[core]" >> "$gitconfig_path"
  echo "  autocrlf = false" >> "$gitconfig_path"
  echo "  editor = vim" >> "$gitconfig_path"
  echo "  whitespace = $whitespace" >> "$gitconfig_path"

  echo ".gitconfig generated at $gitconfig_path"
}

# Function to convert Unix path to Windows path
convert_to_windows_path() {
  local unix_path="$1"
  local windows_path=$(echo "$unix_path" | sed 's|^/|C:/|' | sed 's|/|\\|g')
  echo "$windows_path"
}

# Function to update PATH
update_path() {
  local environment=$(prompt "Enter environment (home/smartbox)" "home")
  local platform=$(prompt "Enter platform (windows/linux/ios)" "linux")

  local paths_to_add=(
    "$BASE_DIR/global/scripts"
    "$BASE_DIR/global/$environment/scripts"
    "$BASE_DIR/$platform/$environment/scripts"
    "$BASE_DIR/$platform/scripts"
  )

  # Find all subdirectories and add them to paths_to_add
  for path in "${paths_to_add[@]}"; do
    if [ -d "$path" ]; then
      while IFS= read -r -d '' subdir; do
        paths_to_add+=("$subdir")
      done < <(find "$path" -type d -print0)
    fi
  done

  local path_file="$HOME_DIR/.bash_profile"

  for path in "${paths_to_add[@]}"; do
    if ! grep -q "$path" "$path_file"; then
      echo "export PATH=\"$path:\$PATH\"" >> "$path_file"
    fi
  done

  if [[ "$platform" == "windows" ]]; then
    echo "The following paths have been added to .bash_profile:"
    for path in "${paths_to_add[@]}"; do
      windows_path=$(convert_to_windows_path "$path")
      echo "$windows_path"
    done
    echo "Please add these paths to the system environmental variables via the GUI."
  else
    local path_file="$HOME_DIR/.bashrc"
    for path in "${paths_to_add[@]}"; do
      if ! grep -q "$path" "$path_file"; then
        echo "export PATH=\"$path:\$PATH\"" >> "$path_file"
      fi
    done
  fi

  echo "PATH updated in $path_file"
}

# Function to remove old PATH entries
remove_old_paths() {
  local path_file="$HOME_DIR/.bashrc"
  if [[ "$platform" == "windows" ]]; then
    path_file="$HOME_DIR/.bash_profile"
  fi

  if [ -f "$path_file" ]; then
    grep -o 'export PATH="[^"]*' "$path_file" | grep "$BASE_DIR" | while read -r old_path; do
      read -p "Do you want to remove $old_path from PATH? (y/n): " choice
      if [[ "$choice" == "y" ]]; then
        sed -i.bak "/$old_path/d" "$path_file"
      fi
    done
  fi
}

echo "bash environment setup script"
echo "This script will generate .bash_profile, .bashrc, and .gitconfig files in your home directory."
echo "It will also update the PATH in .bash_profile or .bashrc."

# Main script
read -p "Do you want to generate config files? (y/n): " generate_config_files
if [[ "$generate_config_files" == "y" ]]; then
  generate_bash_profile
  generate_bashrc
  generate_gitconfig
fi

read -p "Do you want to update the PATH? (y/n): " update_path_choice
if [[ "$update_path_choice" == "y" ]]; then
  remove_old_paths
  update_path
fi

echo "Setup complete."