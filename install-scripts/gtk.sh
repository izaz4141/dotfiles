#!/bin/bash
# Install GTK Themes
LOG="Install-Logs/install-$(date +%d-%H%M%S)-gtk.log"

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


if [ -d "$PARENT_DIR/assets/.icons" ]; then
printf "${INFO} Installing ${GREEN}Icon & Cursor Theme${RESET}\n" | tee -a "$LOG"
mkdir -p $HOME/.icons/ || { printf "%s - Failed to create icon dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
cp -an $PARENT_DIR/assets/.icons/. $HOME/.icons/ || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to icon dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
gsettings set org.gnome.desktop.interface icon-theme "candy-icons-modified" || { printf "%s - Failed to set ${YELLOW}Icon Themes${RESET} through gtk\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
gsettings set org.gnome.desktop.interface cursor-theme "Sweet-cursors" || { printf "%s - Failed to set ${YELLOW}Cutsor Themes${RESET} through gtk\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
fi

if [ -d "$PARENT_DIR/assets/.themes/Sweet-Dark-v40" ]; then
printf "${INFO} Installing ${GREEN}GTK & WM Theme${RESET}\n" | tee -a "$LOG"
mkdir -p $HOME/.themes
cp -an $PARENT_DIR/assets/.themes/Sweet-Dark-v40 $HOME/.themes/Sweet-Dark-v40 || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to themes dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
gsettings set org.gnome.desktop.interface gtk-theme Sweet-Dark-v40 || { printf "%s - Failed to set ${YELLOW}GTK Themes${RESET} through gtk\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
gsettings set org.gnome.desktop.wm.preferences theme Sweet-Dark-v40 || { printf "%s - Failed to set ${YELLOW}WM Themes${RESET} through gtk\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
fi

printf "${OK} Finished configuring ${SKYBLUE}GTK Themes${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}
