#!/bin/bash
# Install and configure CachyOS Repository Pacman

LOG="Install-Logs/install-$(date +%d-%H%M%S)-cachyrepo.log"

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

curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o /tmp/cachyos-repo.tar.xz || { printf "%s - Failed to Download ${YELLOW}Repo Install Script${RESET}" "${ERROR}" | tee -a "$LOG"; exit 1; }
tar xvf /tmp/cachyos-repo.tar.xz
sudo /tmp/cachyos-repo/cachyos-repo.sh | tee -a "$LOG"
rm -r /tmp/cachyos-repo
rm -r /tmp/cachyos-repo.tar.xz

printf "${OK} Finished installing ${SKYBLUE}cachyos-repo${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}