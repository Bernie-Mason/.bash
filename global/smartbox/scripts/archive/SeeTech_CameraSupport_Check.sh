#!/bin/bash

# Define the log file
LOG_FILE="$(pwd)/SeeTech_CameraSupport_Check.log"

# Function to log messages to the log file and echo to the console
log() {
  local message="$1"
  echo "$message" | tee -a "$LOG_FILE"
}

log "[--- INFO: Checking for SeeTech Camera Support... --]"
SEETECH_PATH="C:\\Program Files\\SeeTech\\SeeTech.exe"
if [ -f "$SEETECH_PATH" ]; then
  log "INFO: $SEETECH_PATH exists."
else
  log "INFO: $SEETECH_PATH does not exist."
fi

log "\n[--- INFO: Checking for SeeTech Camera configuration... --]"
USER_DIR="C:\\Users\\Public\\Documents\\Smartbox\\Grid 3\\Users"

CAMERA_CONFIGURATION_FOUND=false
for user_dir in "$USER_DIR"/*; do
  if [ -d "$user_dir" ]; then
    user_settings_path="$user_dir\\UserSettings\\UserSettings.xml"
    if [ -f "$user_settings_path" ]; then
      selected_camera=$(grep -oP '(?<=<SelectedCamera>).*?(?=</SelectedCamera>)' "$user_settings_path")
      if [ "$selected_camera" == "SeeTech" ]; then
        log "INFO: $user_settings_path has SeeTech selected."
        CAMERA_CONFIGURATION_FOUND=true
      fi
    else
      log "Warning: $user_settings_path does not exist."
    fi
  fi
done

if [ "$CAMERA_CONFIGURATION_FOUND" = false ]; then
  log "INFO: No SeeTech Camera configuration found."
fi

LOG_FILE_PATH="C:\\Users\\Public\\Documents\\Sensory Software\\Diagnostic Logs\\ssUpdate.log"

log "\n[--- INFO: Searching log file for specific strings... --]"
if grep -q "camera selected, but 64-bit SeeTech software was not found." "$LOG_FILE_PATH"; then
  log "INFO: Found 'camera selected, but 64-bit SeeTech software was not found.' in log file."
else
  log "INFO: 'camera selected, but 64-bit SeeTech software was not found.' not found in log file."
fi

if grep -q "Grid 3 Users folder is located at" "$LOG_FILE_PATH"; then
  log "INFO: Found 'Grid 3 Users folder is located at' in log file."
else
  log "INFO: 'Grid 3 Users folder is located at' not found in log file."
fi