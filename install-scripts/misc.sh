#!/bin/bash
# Add extra spices to pacman
LOG="Install-Logs/install-$(date +%d-%H%M%S)-misc.log"

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

misc_options=(
  "pbignore" "Setup systemd-logind to ignore power button" on
)

while true; do
  selected_option=$(whiptail --title "Select action to do" --checklist \
  "Choose font to install \nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 85 20 \
  "${misc_options[@]}" 3>&1 1>&2 2>&3)

  # Check if the user pressed Cancel (exit status 1)
  if [ $? -ne 0 ]; then
    echo -e "\n"
    echo "${INFO}    You cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
    exit 0  # Exit the script if Cancel is pressed
  fi
  # If no option was selected, notify and restart the selection
  if [ -z "$selected_option" ]; then
    whiptail --title "Warning" --msgbox "No options were selected. Please select at least one option or select cancel." 10 60
    continue  # Return to selection if no options selected
  fi
  # Strip the quotes and trim spaces if necessary (sanitize the input)
  selected_option=$(echo "$selected_option" | tr -d '"' | tr -s ' ')
  IFS=' ' read -ra selected_array <<< "$selected_option"
  # Prepare the confirmation message
  confirm_message="You have selected the following options:\n\n"
  for font in "${selected_array[@]}"; do
    confirm_message+=" - $font\n"
  done
  confirm_message+="\nAre you happy with these choices?"

  # Confirmation prompt
  if ! whiptail --title "Confirm Your Choices" --yesno "$(printf "%s" "$confirm_message")" 25 80; then
    echo -e "\n"
    echo "${SKY_BLUE}You're not happy${RESET}. ${YELLOW}Returning to options...${RESET}" | tee -a "$LOG"
    continue
  fi

  echo "${OK}      You confirmed your choices. Proceeding with ${SKY_BLUE}Dotfiles Installation...${RESET}" | tee -a "$LOG"
  break
done

for option in "${selected_array[@]}"; do
    case "$option" in
        "pbignore")
            echo "${INFO} Setting up systemd-logind to ignore power button..." | tee -a "$LOG"

            # Check if logind.conf exists
            if [ ! -f /etc/systemd/logind.conf ]; then
                echo "${YELLOW}[ERROR] /etc/systemd/logind.conf not found. Skipping power button setup.${RESET}" | tee -a "$LOG"
                continue
            fi

            # Backup original file
            sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak
            echo "${INFO} Backed up original logind.conf to /etc/systemd/logind.conf.bak" | tee -a "$LOG"

            # Check if HandlePowerKey is already set to ignore
            if grep -q "^HandlePowerKey=ignore" /etc/systemd/logind.conf; then
                echo "${INFO} HandlePowerKey is already set to ignore. No changes needed." | tee -a "$LOG"
            else
                # Use sed to modify the file:
                # 1. Replace any existing (commented or uncommented) HandlePowerKey line
                sudo sed -i 's/^#\?HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf

                # 2. If the line still doesn't exist, add it under the [Login] section
                if ! grep -q "^HandlePowerKey=" /etc/systemd/logind.conf; then
                    sudo sed -i '/^\[Login\]/a HandlePowerKey=ignore' /etc/systemd/logind.conf
                fi

                echo "${OK} Set HandlePowerKey=ignore in /etc/systemd/logind.conf" | tee -a "$LOG"
            fi

            # Restart systemd-logind to apply changes
            echo "${INFO} Restarting systemd-logind service..." | tee -a "$LOG"
            sudo systemctl restart systemd-logind.service
            if [ $? -eq 0 ]; then
                echo "${OK} systemd-logind restarted successfully." | tee -a "$LOG"
            else
                echo "${YELLOW}[ERROR] Failed to restart systemd-logind. Please check manually.${RESET}" | tee -a "$LOG"
            fi
            ;;
        *)
            echo "${YELLOW}Unknown option: $option. Skipping.${RESET}" | tee -a "$LOG"
            ;;
    esac
done

done

printf "${OK}      Succesfully Done ${SKY_BLUE}Misc Setup${RESET}!" | tee -a "$LOG"
printf "\n%.0s" {1..1}
