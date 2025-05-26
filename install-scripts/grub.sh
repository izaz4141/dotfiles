#!/bin/bash
# Install and Configure GRUB

grubs=(
  grub
  grub-btrfs
  snapper-support
)

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
LOG="Install-Logs/install-$(date +%d-%H%M%S)_grub.log"

# Install GRUB
printf "${NOTE} Installing grub and dependencies........\n"
  for package in "${grubs[@]}"; do
  install_package "$package" "$LOG"
  done

printf "\n%.0s" {1..1}

printf "${INFO} Installing ${GREEN}GRUB Theme${RESET}\n"
sudo cp -an $dotfiles_dir/themes/grub/. /usr/share/grub/themes || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to /usr/share/grub/themes\n" "${ERROR}"; exit 1; }
sudo cp -an /etc/default/grub /etc/default/grub.bak || { printf "%s - Failed to backup ${YELLOW}/etc/default/grub${RESET}\n" "${ERROR}"; exit 1; }
sudo sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"/usr/share/grub/themes/Elegant-wave-float-right-dark/theme.txt\"|" /etc/default/grub || { printf "%s - Failed to edit ${YELLOW}/etc/default/grub${RESET} to include Themes\n" "${ERROR}"; exit 1; }
sudo grub-mkconfig -o /boot/grub/grub.cfg || { printf "%s - Failed to change ${YELLOW}grub config${RESET}\n" "${ERROR}"; exit 1; }
printf "\n%.0s" {1..2}
