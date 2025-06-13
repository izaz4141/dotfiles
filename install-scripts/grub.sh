#!/bin/bash
# Install and Configure GRUB

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_grub.log"

# Source the global functions script
if ! source "$SCRIPT_DIR/base.sh"; then
  echo "${ERROR} Failed to source ${ORANGE}base.sh\n${RESET}" | tee -a "$LOG"
  exit 1
fi

printf "\n%.0s" {1..1}

grub_file="/etc/default/grub"

printf "${INFO} Installing ${GREEN}GRUB Theme${RESET}\n" | tee -a "$LOG"
sudo cp -an $dotfiles_dir/themes/grub/. /usr/share/grub/themes || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to /usr/share/grub/themes\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
sudo cp -an $grub_file "${grub_file}.bak" || { printf "%s - Failed to backup ${YELLOW}/etc/default/grub${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
sudo sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"/usr/share/grub/themes/Elegant-wave-float-right-dark/theme.txt\"|" $grub_file || { printf "%s - Failed to edit ${YELLOW}/etc/default/grub${RESET} to include Themes\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

printf "${INFO} Activating ${ORANGE}Sysrq${RESET}\n" | tee -a "$LOG"
# Check if parameter already exists (as a whole word)
if grep -q '^[[:space:]]*GRUB_CMDLINE_LINUX=".*\<sysrq_always_enabled=1\>' "$grub_file"; then
    printf "${INFO} Parameter 'sysrq_always_enabled=1' already exists. No changes needed.${RESET}\n" | tee -a $LOG
else
    sudo sed -i \
        -e '/^[[:space:]]*GRUB_CMDLINE_LINUX="/ {
            s/GRUB_CMDLINE_LINUX="\([^"]*\)"/GRUB_CMDLINE_LINUX="\1 sysrq_always_enabled=1"/
        }' "$grub_file" || { printf "%s - Failed to edit ${YELLOW}/etc/default/grub${RESET} to include Themes\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg || { printf "%s - Failed to change ${YELLOW}grub config${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

printf "\n%.0s" {1..2}
