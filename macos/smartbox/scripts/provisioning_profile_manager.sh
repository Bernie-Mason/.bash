#!/bin/bash

# Apple Provisioning Profile Manager for Xcode 16
# Interactive script for managing provisioning profiles on macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directories for Xcode 16
PROFILES_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
BACKUP_DIR="$HOME/Provisioning Profiles Backup"

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo
    print_color $CYAN "================================================================="
    print_color $CYAN "        Apple Provisioning Profile Manager v3.0 (Xcode 16)"
    print_color $CYAN "================================================================="
    echo
}

ensure_backup_directory() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        print_color $GREEN "Created backup directory: $BACKUP_DIR"
    fi
}

check_profiles_directory() {
    if [ ! -d "$PROFILES_DIR" ]; then
        print_color $YELLOW "Warning: Xcode 16 provisioning profiles directory not found!"
        print_color $YELLOW "Expected location: $PROFILES_DIR"
        
        # Check for legacy location
        local legacy_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
        if [ -d "$legacy_dir" ]; then
            print_color $YELLOW "Found legacy profiles directory: $legacy_dir"
            read -p "Would you like to migrate profiles from the legacy location? (y/N): " migrate
            if [[ $migrate =~ ^[Yy]$ ]]; then
                migrate_legacy_profiles "$legacy_dir"
                return
            fi
        fi
        
        print_color $BLUE "Creating Xcode 16 profiles directory..."
        mkdir -p "$PROFILES_DIR"
        if [ $? -eq 0 ]; then
            print_color $GREEN "Created: $PROFILES_DIR"
        else
            print_color $RED "Error: Could not create profiles directory"
            exit 1
        fi
    fi
}

migrate_legacy_profiles() {
    local legacy_dir=$1
    
    print_color $BLUE "Migrating profiles from legacy location..."
    
    # Ensure the new directory exists
    mkdir -p "$PROFILES_DIR"
    
    local count=0
    for profile in "$legacy_dir"/*.mobileprovision; do
        if [ -f "$profile" ]; then
            # Extract UUID from profile to create proper filename
            local temp_plist="/tmp/migrate_$$.plist"
            security cms -D -i "$profile" > "$temp_plist" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                local uuid=$(/usr/libexec/PlistBuddy -c "Print :UUID" "$temp_plist" 2>/dev/null || echo "")
                rm -f "$temp_plist"
                
                if [ -n "$uuid" ]; then
                    local target_path="$PROFILES_DIR/$uuid.mobileprovision"
                    cp "$profile" "$target_path"
                    if [ $? -eq 0 ]; then
                        ((count++))
                    fi
                fi
            fi
        fi
    done
    
    print_color $GREEN "Migrated $count profiles to Xcode 16 location"
}

is_expired() {
    local expiration_date=$1
    local current_date=$(date +%s)
    
    # Handle different date formats that might come from the plist
    local exp_timestamp
    if [[ "$expiration_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        # Already in YYYY-MM-DD format
        exp_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$expiration_date" +%s 2>/dev/null || echo "0")
    else
        # Try the standard plist date format
        exp_timestamp=$(date -j -f "%a %b %d %H:%M:%S %Z %Y" "$expiration_date" +%s 2>/dev/null || echo "0")
    fi
    
    if [ $exp_timestamp -lt $current_date ]; then
        echo "TRUE"
    else
        echo "FALSE"
    fi
}

format_date() {
    local date_string=$1
    # Convert to readable format (YYYY-MM-DD)
    if [[ "$date_string" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        echo "$date_string"
    else
        date -j -f "%a %b %d %H:%M:%S %Z %Y" "$date_string" "+%Y-%m-%d" 2>/dev/null || echo "Invalid Date"
    fi
}

extract_profile_info() {
    local profile_path=$1
    local temp_plist="/tmp/profile_$$.plist"
    
    # Extract the profile data using security command
    security cms -D -i "$profile_path" > "$temp_plist" 2>/dev/null || return 1
    
    # Extract required fields using PlistBuddy
    local name=$(/usr/libexec/PlistBuddy -c "Print :Name" "$temp_plist" 2>/dev/null || echo "Unknown")
    local uuid=$(/usr/libexec/PlistBuddy -c "Print :UUID" "$temp_plist" 2>/dev/null || echo "Unknown")
    local expiration=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$temp_plist" 2>/dev/null || echo "Unknown")
    local team_name=$(/usr/libexec/PlistBuddy -c "Print :TeamName" "$temp_plist" 2>/dev/null || echo "Unknown")
    local app_id=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$temp_plist" 2>/dev/null || echo "Unknown")
    local team_id=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$temp_plist" 2>/dev/null || echo "Unknown")
    
    # Clean up temp file
    rm -f "$temp_plist"
    
    # Format expiration date for display
    local formatted_expiration=$(format_date "$expiration")
    local expired=$(is_expired "$expiration")
    
    # Return as tab-separated values
    echo -e "$name\t$uuid\t$formatted_expiration\t$expired\t$team_name\t$app_id\t$team_id\t$expiration"
}

backup_profile() {
    local profile_path=$1
    local reason=$2
    
    ensure_backup_directory
    
    local filename=$(basename "$profile_path")
    local timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_filename="${timestamp}_${reason}_${filename}"
    local backup_path="$BACKUP_DIR/$backup_filename"
    
    cp "$profile_path" "$backup_path"
    
    if [ $? -eq 0 ]; then
        print_color $GREEN "Profile backed up to: $backup_filename"
        return 0
    else
        print_color $RED "Error: Failed to backup profile"
        return 1
    fi
}

list_profiles() {
    print_color $BLUE "Scanning Xcode 16 provisioning profiles..."
    echo
    
    # Check if any profiles exist
    local profile_count=$(find "$PROFILES_DIR" -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ $profile_count -eq 0 ]; then
        print_color $YELLOW "No provisioning profiles found in $PROFILES_DIR"
        print_color $CYAN "Note: Xcode 16 stores profiles with UUID-based filenames"
        print_color $CYAN "Profiles are automatically managed by Xcode when you sign in with your Apple ID"
        return
    fi
    
    print_color $GREEN "Found $profile_count provisioning profile(s)"
    echo
    
    # First pass: collect all profiles and group by team ID
    declare -a team_profiles
    declare -a team_names
    local total_expired=0
    
    for profile in "$PROFILES_DIR"/*.mobileprovision; do
        if [ -f "$profile" ]; then
            local profile_info=$(extract_profile_info "$profile")
            
            if [ $? -eq 0 ] && [ -n "$profile_info" ]; then
                local team_id=$(echo "$profile_info" | cut -f7)
                local team_name=$(echo "$profile_info" | cut -f5)
                local expired=$(echo "$profile_info" | cut -f4)
                
                # Count expired profiles
                if [ "$expired" = "TRUE" ]; then
                    ((total_expired++))
                fi
                
                # Group profiles by team ID
                if [ -z "${team_profiles[$team_id]}" ]; then
                    team_profiles[$team_id]="$profile_info"
                    team_names[$team_id]="$team_name"
                else
                    team_profiles[$team_id]="${team_profiles[$team_id]}|$profile_info"
                fi
            fi
        fi
    done
    
    # Second pass: display tables for each team
    local global_counter=1
    
    for team_id in "${!team_profiles[@]}"; do
        local team_name="${team_names[$team_id]}"
        
        # Create temporary file for this team's table
        local temp_table="/tmp/profiles_table_${team_id}_$$.txt"
        
        print_color $CYAN "Team: $team_name (ID: $team_id)"
        echo
        
        # Table header
        printf "%-3s %-40s %-8s %-8s %-12s %-30s\n" \
            "No." "Profile Name" "Status" "UUID" "Expiration" "App ID" > "$temp_table"
        
        printf "%-3s %-40s %-8s %-8s %-12s %-30s\n" \
            "---" "----------------------------------------" \
            "--------" "--------" "------------" "------------------------------" >> "$temp_table"
        
        # Process profiles for this team
        local team_expired=0
        local team_valid=0
        
        IFS='|' read -ra PROFILES <<< "${team_profiles[$team_id]}"
        for profile_info in "${PROFILES[@]}"; do
            # Parse the tab-separated values
            local name=$(echo "$profile_info" | cut -f1)
            local uuid=$(echo "$profile_info" | cut -f2)
            local expiration=$(echo "$profile_info" | cut -f3)
            local expired=$(echo "$profile_info" | cut -f4)
            local app_id=$(echo "$profile_info" | cut -f6)
            
            # Count expired vs valid for this team
            if [ "$expired" = "TRUE" ]; then
                ((team_expired++))
            else
                ((team_valid++))
            fi
            
            # Truncate long strings for table display
            name=$(echo "$name" | cut -c1-38)
            uuid_short=$(echo "$uuid" | cut -c1-8)
            app_id=$(echo "$app_id" | cut -c1-28)
            
            # Determine status
            local status
            if [ "$expired" = "TRUE" ]; then
                status="EXPIRED"
            else
                status="Valid"
            fi
            
            # Add to table
            printf "%-3s %-40s %-8s %-8s %-12s %-30s\n" \
                "$global_counter" "$name" "$status" "$uuid_short" "$expiration" "$app_id" >> "$temp_table"
            
            ((global_counter++))
        done
        
        # Display the table with color coding
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if [ $line_num -le 2 ]; then
                # Header lines - show in cyan
                print_color $CYAN "$line"
            elif echo "$line" | grep -q "EXPIRED"; then
                # Expired profiles - show in red
                print_color $RED "$line"
            elif echo "$line" | grep -q "ERROR"; then
                # Error lines - show in red
                print_color $RED "$line"
            else
                # Valid profiles - show in normal color
                echo "$line"
            fi
        done < "$temp_table"
        
        # Team summary
        echo
        local team_total=$((team_expired + team_valid))
        print_color $GREEN "Team Summary: $team_total total ($team_valid valid, $team_expired expired)"
        echo
        echo "----------------------------------------"
        echo
        
        # Clean up temp file
        rm -f "$temp_table"
    done
    
    # Overall summary
    print_color $CYAN "Overall Summary:"
    print_color $RED "Total expired profiles: $total_expired"
    print_color $GREEN "Total valid profiles: $((profile_count - total_expired))"
    print_color $GREEN "Total profiles: $profile_count"
    print_color $PURPLE "Teams found: ${#team_profiles[@]}"
}

remove_expired_profiles() {
    print_color $BLUE "Scanning for expired profiles..."
    echo
    
    local expired_profiles=()
    local expired_count=0
    
    # First, identify all expired profiles
    for profile in "$PROFILES_DIR"/*.mobileprovision; do
        if [ -f "$profile" ]; then
            local profile_info=$(extract_profile_info "$profile")
            
            if [ $? -eq 0 ] && [ -n "$profile_info" ]; then
                local expired=$(echo "$profile_info" | cut -f4)
                local name=$(echo "$profile_info" | cut -f1)
                
                if [ "$expired" = "TRUE" ]; then
                    expired_profiles+=("$profile")
                    print_color $RED "Found expired: $name"
                    ((expired_count++))
                fi
            fi
        fi
    done
    
    if [ $expired_count -eq 0 ]; then
        print_color $GREEN "No expired profiles found!"
        return
    fi
    
    echo
    print_color $YELLOW "Found $expired_count expired profile(s)"
    print_color $CYAN "Note: Removing profiles from Xcode 16 location. Xcode will re-download them as needed."
    echo
    read -p "Do you want to remove all expired profiles? They will be backed up first. (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        local backup_count=0
        local remove_count=0
        
        for profile in "${expired_profiles[@]}"; do
            local profile_info=$(extract_profile_info "$profile")
            local name=$(echo "$profile_info" | cut -f1)
            
            print_color $YELLOW "Processing: $name"
            
            # Backup the profile first
            if backup_profile "$profile" "expired"; then
                ((backup_count++))
                # Remove the original
                rm "$profile"
                if [ $? -eq 0 ]; then
                    ((remove_count++))
                    print_color $GREEN "Removed: $name"
                else
                    print_color $RED "Error removing: $name"
                fi
            else
                print_color $RED "Skipping removal of: $name (backup failed)"
            fi
        done
        
        echo
        print_color $GREEN "Summary:"
        print_color $GREEN "- Backed up: $backup_count profiles"
        print_color $GREEN "- Removed: $remove_count profiles"
        print_color $CYAN "- Backup location: $BACKUP_DIR"
        print_color $CYAN "- Xcode will automatically re-download valid profiles as needed"
    else
        print_color $YELLOW "Operation cancelled"
    fi
}

install_profile() {
    print_color $CYAN "Install Provisioning Profile to Xcode 16"
    echo
    
    # Look for profiles in Downloads
    local downloads_dir="$HOME/Downloads"
    local recent_profiles=$(find "$downloads_dir" -name "*.mobileprovision" -mtime -7 2>/dev/null)
    
    local profile_path=""
    
    if [ -n "$recent_profiles" ]; then
        print_color $CYAN "Recently downloaded profiles found:"
        local counter=1
        declare -a profile_array
        
        while IFS= read -r profile; do
            profile_array[counter]="$profile"
            local profile_info=$(extract_profile_info "$profile")
            if [ $? -eq 0 ]; then
                local name=$(echo "$profile_info" | cut -f1)
                echo "$counter. $name ($(basename "$profile"))"
            else
                echo "$counter. $(basename "$profile") (Could not read)"
            fi
            ((counter++))
        done <<< "$recent_profiles"
        
        echo "0. Manually specify path"
        echo
        read -p "Select profile number to install: " selection
        
        if [ "$selection" -gt 0 ] && [ "$selection" -lt "$counter" ]; then
            profile_path="${profile_array[$selection]}"
        elif [ "$selection" -eq 0 ]; then
            read -p "Enter full path to the profile: " profile_path
        else
            print_color $RED "Invalid selection"
            return 1
        fi
    else
        read -p "Enter the full path to the profile: " profile_path
    fi
    
    if [ ! -f "$profile_path" ]; then
        print_color $RED "File not found: $profile_path"
        return 1
    fi
    
    # Get profile info
    local profile_info=$(extract_profile_info "$profile_path")
    if [ $? -ne 0 ]; then
        print_color $RED "Error: Could not read the profile"
        return 1
    fi
    
    local name=$(echo "$profile_info" | cut -f1)
    local uuid=$(echo "$profile_info" | cut -f2)
    local expiration=$(echo "$profile_info" | cut -f3)
    local app_id=$(echo "$profile_info" | cut -f6)
    
    print_color $GREEN "Profile information:"
    echo "Name: $name"
    echo "UUID: $uuid"
    echo "App ID: $app_id"
    echo "Expiration: $expiration"
    echo
    
    # Install with UUID-based filename (Xcode 16 format)
    local target_path="$PROFILES_DIR/$uuid.mobileprovision"
    
    if [ -f "$target_path" ]; then
        print_color $YELLOW "Profile with this UUID already exists."
        read -p "Replace existing profile? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            print_color $YELLOW "Installation cancelled"
            return
        fi
        
        # Backup existing profile
        backup_profile "$target_path" "replaced"
    fi
    
    # Copy profile to Xcode 16 location
    cp "$profile_path" "$target_path"
    
    if [ $? -eq 0 ]; then
        print_color $GREEN "Profile installed successfully to Xcode 16 location!"
        print_color $CYAN "File: $target_path"
    else
        print_color $RED "Error: Failed to install profile"
    fi
}

show_profile_details() {
    print_color $BLUE "Scanning profiles for detailed view..."
    echo
    
    # Check if any profiles exist
    local profile_count=$(find "$PROFILES_DIR" -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ $profile_count -eq 0 ]; then
        print_color $YELLOW "No provisioning profiles found"
        return
    fi
    
    # Create array to store profile paths
    declare -a profile_paths
    local counter=1
    
    print_color $GREEN "Available Profiles:"
    echo
    printf "%-3s %-50s %-8s %-10s\n" "No." "Profile Name" "Status" "UUID"
    printf "%-3s %-50s %-8s %-10s\n" "---" "--------------------------------------------------" "--------" "----------"
    
    # List all profiles with basic info
    for profile in "$PROFILES_DIR"/*.mobileprovision; do
        if [ -f "$profile" ]; then
            profile_paths[counter]="$profile"
            local profile_info=$(extract_profile_info "$profile")
            
            if [ $? -eq 0 ] && [ -n "$profile_info" ]; then
                local name=$(echo "$profile_info" | cut -f1)
                local uuid=$(echo "$profile_info" | cut -f2)
                local expired=$(echo "$profile_info" | cut -f4)
                
                # Truncate name and UUID for display
                name=$(echo "$name" | cut -c1-48)
                uuid_short=$(echo "$uuid" | cut -c1-8)
                
                # Determine status
                local status
                if [ "$expired" = "TRUE" ]; then
                    status="EXPIRED"
                    printf "\033[0;31m%-3s %-50s %-8s %-10s\033[0m\n" "$counter" "$name" "$status" "$uuid_short"
                else
                    status="Valid"
                    printf "%-3s %-50s %-8s %-10s\n" "$counter" "$name" "$status" "$uuid_short"
                fi
            else
                printf "\033[0;31m%-3s %-50s %-8s %-10s\033[0m\n" "$counter" "ERROR: Could not read profile" "ERROR" "---"
            fi
            ((counter++))
        fi
    done
    
    echo
    read -p "Enter profile number to view details (1-$((counter-1))): " selection
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -ge "$counter" ]; then
        print_color $RED "Invalid selection!"
        return
    fi
    
    local selected_profile="${profile_paths[$selection]}"
    
    print_color $CYAN "Detailed Profile Information:"
    echo "=============================================================="
    
    local temp_plist="/tmp/profile_detail_$$.plist"
    security cms -D -i "$selected_profile" > "$temp_plist" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "File: $(basename "$selected_profile")"
        echo "Location: $selected_profile"
        echo "Name: $(/usr/libexec/PlistBuddy -c "Print :Name" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "UUID: $(/usr/libexec/PlistBuddy -c "Print :UUID" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "Team Name: $(/usr/libexec/PlistBuddy -c "Print :TeamName" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "Team ID: $(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "App ID: $(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "Creation Date: $(/usr/libexec/PlistBuddy -c "Print :CreationDate" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "Expiration Date: $(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$temp_plist" 2>/dev/null || echo "Unknown")"
        echo "Platform: $(/usr/libexec/PlistBuddy -c "Print :Platform:0" "$temp_plist" 2>/dev/null || echo "Unknown")"
        
        # Check if expired
        local exp_date=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$temp_plist" 2>/dev/null || echo "Unknown")
        local expired=$(is_expired "$exp_date")
        if [ "$expired" = "TRUE" ]; then
            print_color $RED "Status: EXPIRED"
        else
            print_color $GREEN "Status: Valid"
        fi
        
        echo
        print_color $CYAN "Provisioned Devices:"
        echo "=============================================================="
        
        # FIXED: Get the number of provisioned devices
        local device_count=0
        # Check if ProvisionedDevices array exists
        if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$temp_plist" >/dev/null 2>&1; then
            # Get the actual count by trying to access array elements
            local i=0
            while /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices:$i" "$temp_plist" >/dev/null 2>&1; do
                ((device_count++))
                ((i++))
            done
        fi
        
        if [ "$device_count" -gt 0 ]; then
            print_color $GREEN "Total Devices: $device_count"
            echo
            
            printf "%-3s %-40s %-20s\n" "No." "Device UDID" "Device Type"
            printf "%-3s %-40s %-20s\n" "---" "----------------------------------------" "--------------------"
            
            # List all provisioned devices
            for ((i=0; i<device_count; i++)); do
                local device_udid=$(/usr/libexec/PlistBuddy -c "Print :ProvisionedDevices:$i" "$temp_plist" 2>/dev/null || echo "Unknown")
                
                # Determine device type based on UDID length and format
                local device_type="Unknown"
                if [[ ${#device_udid} -eq 40 ]]; then
                    device_type="iOS Device"
                elif [[ ${#device_udid} -eq 25 ]] && [[ "$device_udid" == *"-"* ]]; then
                    device_type="Apple Watch"
                elif [[ ${#device_udid} -eq 8 ]] && [[ "$device_udid" =~ ^[0-9A-F]+$ ]]; then
                    device_type="Simulator"
                fi
                
                # Truncate UDID for display
                local udid_display=$(echo "$device_udid" | cut -c1-38)
                
                printf "%-3s %-40s %-20s\n" "$((i+1))" "$udid_display" "$device_type"
            done
        else
            # Check if this is a distribution profile (no devices)
            local profile_type=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:get-task-allow" "$temp_plist" 2>/dev/null)
            local has_aps_env=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:aps-environment" "$temp_plist" 2>/dev/null)
            
            if [ "$profile_type" = "false" ] || [[ "$has_aps_env" == *"production"* ]]; then
                print_color $YELLOW "Distribution Profile - No specific devices (for App Store or Enterprise distribution)"
            else
                print_color $YELLOW "No devices provisioned or could not read device list"
            fi
        fi
        
        echo
        print_color $CYAN "Entitlements:"
        echo "=============================================================="
        
        # Show key entitlements
        local get_task_allow=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:get-task-allow" "$temp_plist" 2>/dev/null || echo "Not Set")
        local aps_environment=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:aps-environment" "$temp_plist" 2>/dev/null || echo "Not Set")
        local keychain_groups=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:keychain-access-groups" "$temp_plist" 2>/dev/null | grep -E "^\s*[0-9]+ =" | wc -l | tr -d ' ')
        
        echo "Debug/Development: $get_task_allow"
        echo "Push Notifications: $aps_environment"
        echo "Keychain Groups: $keychain_groups"
        
        # Determine profile type based on entitlements
        echo
        print_color $CYAN "Profile Type:"
        if [ "$get_task_allow" = "true" ]; then
            print_color $BLUE "Development Profile"
        elif [ "$device_count" -gt 0 ] && [ "$get_task_allow" = "false" ]; then
            print_color $PURPLE "Ad-Hoc Distribution Profile"
        elif [ "$device_count" -eq 0 ] && [ "$get_task_allow" = "false" ]; then
            print_color $GREEN "App Store Distribution Profile"
        else
            print_color $YELLOW "Unknown Profile Type"
        fi
        
        rm -f "$temp_plist"
    else
        print_color $RED "Error: Could not read profile details"
    fi
}

show_backup_directory() {
    ensure_backup_directory
    
    print_color $CYAN "Backup Directory Contents:"
    echo "Location: $BACKUP_DIR"
    echo
    
    local backup_files=$(ls -la "$BACKUP_DIR" 2>/dev/null | grep "\.mobileprovision$" || echo "")
    
    if [ -z "$backup_files" ]; then
        print_color $YELLOW "No backup files found"
    else
        echo "$backup_files"
        echo
        local count=$(echo "$backup_files" | wc -l | tr -d ' ')
        print_color $GREEN "Total backup files: $count"
    fi
}

restore_from_backup() {
    ensure_backup_directory
    
    print_color $CYAN "Restore Profile from Backup to Xcode 16"
    echo
    
    local backup_files=$(find "$BACKUP_DIR" -name "*.mobileprovision" 2>/dev/null)
    
    if [ -z "$backup_files" ]; then
        print_color $YELLOW "No backup files found in $BACKUP_DIR"
        return
    fi
    
    local counter=1
    declare -a backup_array
    
    print_color $GREEN "Available backup files:"
    while IFS= read -r backup_file; do
        backup_array[counter]="$backup_file"
        local filename=$(basename "$backup_file")
        local profile_info=$(extract_profile_info "$backup_file")
        if [ $? -eq 0 ]; then
            local name=$(echo "$profile_info" | cut -f1)
            echo "$counter. $name ($filename)"
        else
            echo "$counter. $filename (Could not read)"
        fi
        ((counter++))
    done <<< "$backup_files"
    
    echo
    read -p "Select backup file to restore (1-$((counter-1))): " selection
    
    if [ "$selection" -gt 0 ] && [ "$selection" -lt "$counter" ]; then
        local backup_file="${backup_array[$selection]}"
        local profile_info=$(extract_profile_info "$backup_file")
        
        if [ $? -eq 0 ]; then
            local name=$(echo "$profile_info" | cut -f1)
            local uuid=$(echo "$profile_info" | cut -f2)
            
            print_color $YELLOW "Restoring profile: $name"
            
            # Use UUID-based filename for Xcode 16
            local target_path="$PROFILES_DIR/$uuid.mobileprovision"
            
            if [ -f "$target_path" ]; then
                read -p "Profile already exists in Xcode 16 location. Replace it? (y/N): " confirm
                if [[ ! $confirm =~ ^[Yy]$ ]]; then
                    print_color $YELLOW "Restore cancelled"
                    return
                fi
                
                # Backup the existing profile
                backup_profile "$target_path" "before_restore"
            fi
            
            cp "$backup_file" "$target_path"
            
            if [ $? -eq 0 ]; then
                print_color $GREEN "Profile restored successfully to Xcode 16 location!"
                print_color $CYAN "Location: $target_path"
            else
                print_color $RED "Error: Failed to restore profile"
            fi
        else
            print_color $RED "Error: Could not read backup file"
        fi
    else
        print_color $RED "Invalid selection"
    fi
}

show_menu() {
    echo
    print_color $PURPLE "Choose an option:"
    echo "1. List all profiles"
    echo "2. Show profile details"
    echo "3. Remove all expired profiles"
    echo "4. Install/add new profile"
    echo "5. Show backup directory"
    echo "6. Restore profile from backup"
    echo "7. Refresh profiles directory"
    echo "8. Migrate from legacy location"
    echo "9. Exit"
    echo
}

# Main function
main() {
    print_header
    
    # Check prerequisites
    if ! command -v security &> /dev/null; then
        print_color $RED "Error: 'security' command not found. This script requires macOS."
        exit 1
    fi
    
    if ! command -v /usr/libexec/PlistBuddy &> /dev/null; then
        print_color $RED "Error: 'PlistBuddy' not found. This script requires macOS."
        exit 1
    fi
    
    check_profiles_directory
    ensure_backup_directory
    
    print_color $GREEN "Xcode 16 profiles directory: $PROFILES_DIR"
    print_color $GREEN "Backup directory: $BACKUP_DIR"
    
    # Main loop
    while true; do
        show_menu
        read -p "Enter your choice (1-9): " choice
        
        case $choice in
            1)
                list_profiles
                ;;
            2)
                show_profile_details
                ;;
            3)
                remove_expired_profiles
                ;;
            4)
                install_profile
                ;;
            5)
                show_backup_directory
                ;;
            6)
                restore_from_backup
                ;;
            7)
                print_color $BLUE "Refreshing Xcode 16 profiles directory..."
                check_profiles_directory
                print_color $GREEN "Directory refreshed!"
                ;;
            8)
                local legacy_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
                if [ -d "$legacy_dir" ]; then
                    migrate_legacy_profiles "$legacy_dir"
                else
                    print_color $YELLOW "No legacy profiles directory found at: $legacy_dir"
                fi
                ;;
            9)
                print_color $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_color $RED "Invalid choice. Please enter 1-9."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run the script
main "$@"