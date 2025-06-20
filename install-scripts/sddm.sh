#!/bin/bash
# Install and configure SDDM Login Manager

# login managers to attempt to disable
LOG="Install-Logs/install-$(date +%d-%H%M%S)-sddm.log"
login=(
  lightdm
  gdm3
  gdm
  lxdm
  lxdm-gtk3
)

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



# Check if other login managers installed and disabling its service before enabling sddm
for login_manager in "${login[@]}"; do
  if pacman -Qs "$login_manager" > /dev/null 2>&1; then
    sudo systemctl disable "$login_manager.service" >> "$LOG" 2>&1
    echo "$login_manager disabled." >> "$LOG" 2>&1
  fi
done

# Double check with systemctl
for manager in "${login[@]}"; do
  if systemctl is-active --quiet "$manager" > /dev/null 2>&1; then
    echo "$manager is active, disabling it..." >> "$LOG" 2>&1
    sudo systemctl disable "$manager" --now >> "$LOG" 2>&1
  fi
done

printf "\n%.0s" {1..1}

printf "${INFO} Installing ${SKY_BLUE}Additional SDDM Theme${RESET}\n" | tee -a "$LOG"
sudo mkdir -p /usr/share/sddm/themes || { printf "%s - Failed to create sddm themes dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
sudo cp -an $PARENT_DIR/assets/sddm/. /usr/share/sddm/themes || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to sddm themes dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
sudo mkdir -p /etc/sddm.conf.d || { printf "%s - Failed to create sddm config dir\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

if [ -f "/etc/sddm.conf.d/sddm.conf" ]; then
  sudo cp -an /etc/sddm.conf.d/sddm.conf /etc/sddm.conf.d/sddm.conf.bak || { printf "%s - Failed to backup ${YELLOW}sddm config${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
else
  sudo cp -an /usr/lib/sddm/sddm.conf.d/default.conf /etc/sddm.conf.d/sddm.conf || { printf "%s - Failed to copy ${YELLOW}default sddm config${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
fi

sudo sed -i "s|.*Current=.*|Current=eucalyptus-drop|" /etc/sddm.conf.d/sddm.conf  || { printf "%s - Failed to edit ${YELLOW}sddm config${RESET} to include Themes\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
sudo ln -sf /etc/sddm.conf.d/sddm.conf /etc/sddm.conf || { printf "%s - Failed to link ${YELLOW}sddm config${RESET}for support\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

printf "\n%.0s" {1..1} | tee -a "$LOG"

printf "${INFO} Activating sddm service........\n" | tee -a "$LOG"
sudo systemctl enable --now sddm

wayland_sessions_dir=/usr/share/wayland-sessions
[ ! -d "$wayland_sessions_dir" ] && { printf "$CAT - $wayland_sessions_dir not found, creating...\n"; sudo mkdir "$wayland_sessions_dir" 2>&1 | tee -a "$LOG"; }

printf "${OK} Finished configuring ${SKYBLUE}SDDM${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}
