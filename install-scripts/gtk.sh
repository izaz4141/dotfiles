#!/bin/bash
# Install GTK Themes

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$SCRIPT_DIR/base.sh"; then
  echo "Failed to source base.sh"
  exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_icons.log"


printf "${INFO} Installing ${GREEN}Icon Theme${RESET}\n"
mkdir $HOME/.icons/ || { printf "%s - Failed to create icon dir\n" "${ERROR}"; exit 1; }
cp -an $dotfiles_dir/themes/.icons/. $HOME/.icons/ || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to icon dir\n" "${ERROR}"; exit 1; }
gsettings set org.gnome.desktop.interface icon-theme "candy-icons-modified" || { printf "%s - Failed to set ${YELLOW}Icon Themes${RESET} through gtk\n" "${ERROR}"; exit 1; }
gsettings set org.gnome.desktop.interface cursor-theme "Sweet-cursors" || { printf "%s - Failed to set ${YELLOW}Cutsor Themes${RESET} through gtk\n" "${ERROR}"; exit 1; }
printf "\n%.0s" {1..2}
