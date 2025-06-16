#!/bin/bash

clear

keep_sudo_alive() {
    while true; do
        sudo -v # Refreshes the sudo timestamp
        sleep 4m # Sleep for slightly less than your sudo timeout 
    done
}
# Start the keep-alive function in the background
keep_sudo_alive &
SUDO_PID=$! # Get the PID of the background process

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Create Directory for Install Logs
if [ ! -d Install-Logs ]; then
    mkdir Install-Logs
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR}   This script should ${WARNING}NOT${RESET} be executed as root!! Exiting......." | tee -a "$LOG"
    printf "\n%.0s" {1..2}
    exit 1
fi

if [ ! -d "$HOME/dotfiles" ]; then
    mkdir $HOME/dotfiles
    cp * $HOME/dotfiles/ || { printf "%s - Failed to copy ${YELLOW}dotfiles${RESET}\n" "${ERROR}"; exit 1; }
    echo "${OK}      dotfiles directory has been copied to HOME" | tee -a "$LOG"
fi


if sudo pacman -Sy --needed --noconfirm base-devel libnewt git; then
    echo "${OK}      base packages has been installed successfully." | tee -a "$LOG"
else
    echo "${ERROR}   base-packages not found nor cannot be installed."  | tee -a "$LOG"
    echo "${ACTION}  Please install base-devel libnewt git manually before running this script... Exiting" | tee -a "$LOG"
    exit 1
fi

clear

echo -e "\e[35m
   ___       __  ____ __
  / _ \___  / /_/ _(_) /__ ___
 / // / _ \/ __/ _/ / / -_|_-<
/____/\___/\__/_//_/_/\__/___/
================================
\e[0m"
printf "\n%.0s" {1..1}

# Welcome message using whiptail (for displaying information)
whiptail --title "Glicole Dotfiles Install Script" \
    --msgbox "Welcome to Glicole Arch-Hyprland Install Script!!!\n\n\
ATTENTION: Run a full system update and Reboot first !!! (Highly Recommended)\n\n\
NOTE: If you are installing on a VM, ensure to enable 3D acceleration else Hyprland may NOT start!" \
    15 80

    # Ask if the user wants to proceed
if ! whiptail --title "Proceed with Installation?" \
    --yesno "Would you like to proceed?" 7 50; then
    echo -e "\n"
    echo "${INFO}    You chose ${YELLOW}NOT${RESET} to proceed. ${YELLOW}Exiting...${RESET}" | tee -a "$LOG"
    echo -e "\n"
    exit 1
fi

echo "${OK}      ${MAGENTA}Okay!!${RESET} ${SKY_BLUE}lets continue with the installation...${RESET}" | tee -a "$LOG"

sleep 1
printf "\n%.0s" {1..1}


script_directory="install-scripts"

# Function to execute a script if it exists and make it executable
execute_script() {
    local script="$1"
    local script_path="$script_directory/$script"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if [ -x "$script_path" ]; then
            env "$script_path"
        else
            echo "Failed to make script '$script' executable."
        fi
    else
        echo "Script '$script' not found in '$script_directory'."
    fi
}

# Get all scripts
# mapfile -t scripts < <(find "$script_directory" -maxdepth 1 -type f -name "*.sh" ! -name "base.sh" -exec basename {} \; | sort)
# Create Whiptail checklist options
declare -a options=()
while IFS= read -r -d $'\0' script; do
    script_name=$(basename "$script")
    [[ "$script_name" == "base.sh" ]] && continue  # Skip base.sh
    
    # Extract second line and clean it (remove # and trim spaces)
    description=$(head -n 2 "$script" | tail -n 1 | sed 's/^# *//; s/ *$//')
    
    # Fallback if description is empty
    [[ -z "$description" ]] && description="No description available"
    
    options+=("$script_name" "$description" off)
done < <(find "$script_directory" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)


while true; do
    selected_options=$(whiptail --title "Select Scripts to Run" --checklist \
    "Choose options to install or configure\nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 85 20 \
    "${options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user pressed Cancel (exit status 1)
    if [ $? -ne 0 ]; then
        echo -e "\n"
        echo "${INFO}    You cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
        exit 0  # Exit the script if Cancel is pressed
    fi
    # If no option was selected, notify and restart the selection
    if [ -z "$selected_options" ]; then
        whiptail --title "Warning" --msgbox "No options were selected. Please select at least one option." 10 60
        continue  # Return to selection if no options selected
    fi
    # Strip the quotes and trim spaces if necessary (sanitize the input)
    selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')
    IFS=' ' read -ra selected_array <<< "$selected_options"
    # Prepare the confirmation message
    confirm_message="You have selected the following options:\n\n"
    for option in "${selected_array[@]}"; do
        confirm_message+=" - $option\n"
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

# Run selected scripts
for script in "${selected_array[@]}"; do
    echo "${INFO}    Running ${SKY_BLUE}${script}${RESET}" | tee -a "$LOG"
    execute_script "$script"
    script_exit_code=$?
    if [ "$script_exit_code" -eq 0 ]; then
        printf "${OK}      ${script} Execution Completed..!\n" | tee -a "$LOG"
    else
        printf "${ERROR}   ${script} Execution ${WARNING}Failed${RESET}..!\n" | tee -a "$LOG"
    fi
    printf "\n%.0s" {1..2}
done

# Kill the background keep-alive process when done
kill "$SUDO_PID"

if [ "$script_exit_code" -eq 0 ]; then
    printf "${OK}      Dotfiles Installation Completed..!" | tee -a "$LOG"
else
    printf "${ERROR}   Dotfiles Installation ${WARNING}Failed${RESET}..!" | tee -a "$LOG"
fi
printf "\n%.0s" {1..2}
