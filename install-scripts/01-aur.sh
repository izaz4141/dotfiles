#!/bin/bash
# Install packages from AUR
## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

PACKAGE_FILE="assets/packages/aur.txt"
LOG="Install-Logs/install-$(date +%d-%H%M%S)_packages.log"

# Source the global functions script
if ! source "$SCRIPT_DIR/base.sh"; then
  echo "${ERROR} Failed to source ${ORANGE}base.sh\n${RESET}" | tee -a "$LOG"
  exit 1
fi

while IFS= read -r PACKAGE; do
    [[ -z "$PACKAGE" ]] && continue  # Skip empty lines
    install_package "$PACKAGE" "$LOG"
done < "$PACKAGE_FILE"
