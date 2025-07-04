#!/bin/bash
# Install dotfiles configuration to .config

CONFIG_DIR=".config"
TARGET_DIR="$HOME/.config"
LOG="Install-Logs/install-$(date +%d-%H%M%S)-dots.log"

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "[ERROR] Failed to change directory to $PARENT_DIR" | tee -a "$LOG"; exit 1; }


# Source the global functions script
if ! source "$SCRIPT_DIR/base.sh"; then
  echo "[ERROR] Failed to source base.sh\n" | tee -a "$LOG"
  exit 1
fi


ln -sf $PARENT_DIR/assets/wallpaper $HOME/wallpaper

# Check if source .config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    echo "${ERROR} $CONFIG_DIR directory not found in current directory\n" | tee -a "$LOG"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Process each item in the source .config directory
for item in "$CONFIG_DIR"/*; do
    # Handle case where directory is empty
    [ -e "$item" ] || continue

    item_name=$(basename "$item")
    target="$TARGET_DIR/$item_name"

    # Check if item exists in target
    if [ -e "$target" ]; then
        if [ -L "$target" ]; then
            echo "${INFO} Skipping ${SKYBLUE}$item_name: already a symlink${RESET}" | tee -a "$LOG"
            continue
        else
            # Backup existing file/directory
            echo "${INFO} Creating backup for ${SKYBLUE}$item_name${RESET}\n" | tee -a "$LOG"
            mv -f "$target" "$target.bak" || { printf "%s - Failed to backup ${YELLOW}$item${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
        fi
    fi

    # Create symbolic link
    ln -sfv "$(pwd)/$item" "$target" || { printf "%s - Failed to link ${YELLOW}$item${RESET}" "${ERROR}" | tee -a "$LOG"; exit 1; }
done

# Check if ~/.bashrc exists, create a backup, and copy the new configuration
if [ -f "$HOME/.bashrc" ]; then
mv -b "$HOME/.bashrc" "$HOME/.bashrc.bak" || true
fi

# Copying the preconfigured zsh themes and profile
ln -sf $PARENT_DIR/.bashrc $HOME/.bashrc

printf "${OK} Finished configuring ${SKYBLUE}dotfiles${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}