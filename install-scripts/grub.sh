#!/bin/bash
# Install and Configure GRUB
LOG="Install-Logs/install-$(date +%d-%H%M%S)-grub.log"

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

printf "\n%.0s" {1..1}

grub_file="/etc/default/grub"

printf "${INFO} Installing ${GREEN}GRUB Theme${RESET}\n" | tee -a "$LOG"
sudo cp -an $PARENT_DIR/assets/grub/. /usr/share/grub/themes || { printf "%s - Failed to copy ${YELLOW}Themes${RESET} to /usr/share/grub/themes\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
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

# Activate OS PROBER
printf "${INFO} Activating ${ORANGE}OS Prober${RESET}\n" | tee -a "$LOG"
if grep -q '^[[:space:]]*GRUB_DISABLE_OS_PROBER=false' "$grub_file"; then
    printf "${INFO} OS Prober already activated. No changes needed.${RESET}\n" | tee -a $LOG
else
    sudo sed -i \
        -e 's/^[[:space:]]*#\?GRUB_DISABLE_OS_PROBER=\(true\|false\)/GRUB_DISABLE_OS_PROBER=false/' \
        "$grub_file" || { printf "%s - Failed to edit ${YELLOW}${grub_file}${RESET} to activate OS Prober\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

    if ! grep -q '^[[:space:]]*GRUB_DISABLE_OS_PROBER=false' "$grub_file"; then
        echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a "$grub_file" > /dev/null || { printf "%s - Failed to add GRUB_DISABLE_OS_PROBER=false to ${YELLOW}${grub_file}${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }
        printf "${INFO} Added 'GRUB_DISABLE_OS_PROBER=false' to ${YELLOW}${grub_file}${RESET}.\n" | tee -a "$LOG"
    else
        printf "${OK} Changed 'GRUB_DISABLE_OS_PROBER' to 'false' in ${YELLOW}${grub_file}${RESET}.\n" | tee -a "$LOG"
    fi
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg || { printf "%s - Failed to change ${YELLOW}grub config${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

printf "${OK} Finished configuring ${SKYBLUE}GRUB${RESET}\n" | tee -a "$LOG"
printf "\n%.0s" {1..1}
