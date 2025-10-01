#!/bin/bash
# Install Paru Aur Helper
# NOTE: If yay is already installed, paru will not be installed #

pkg="paru"
tmpdir="/tmp/paru"
LOG="$PARENT_DIR/Install-Logs/install-$(date +%d-%H%M%S)-paru.log"


## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "[ERROR] Failed to change directory to $PARENT_DIR" | tee -a "$LOG"; exit 1; }


# Source the global functions script
if ! source "$SCRIPT_DIR/base.sh"; then
  echo "[ERROR] Failed to source base.sh" 
  exit 1
fi


# Check for AUR helper and install if not found
ISAUR=$(check_aur_helper)

if [ -n "$ISAUR" ]; then
  printf "\n%s - ${SKY_BLUE}AUR helper${RESET} already installed, moving on.\n" "${OK}" | tee -a "$LOG"
else
  printf "\n%s - Installing ${SKY_BLUE}$pkg${RESET} from AUR\n" "${NOTE}" | tee -a "$LOG"
  # Check if directory exists and remove it
  if [ -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
  sudo pacman -S --needed --noconfirm base-devel
  git clone https://aur.archlinux.org/paru.git $tmpdir || { printf "%s - Failed to clone ${YELLOW}$pkg${RESET} from AUR\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
  cd $tmpdir
  makepkg -si --noconfirm 2>&1 | tee -a "$LOG" || { printf "%s - Failed to install ${YELLOW}$pkg${RESET} from AUR\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
  $pkg --gendb
fi

printf "${OK} Finished installing ${SKYBLUE}Yay${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}
