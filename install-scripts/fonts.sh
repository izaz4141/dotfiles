#!/bin/bash
# Add extra spices to pacman
LOG="Install-Logs/install-$(date +%d-%H%M%S)-fonts.log"

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

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"


font_options=(
  "DaddyTimeMono" "A monospaced font for programmers and other terminal groupies" off
  "DepartureMono" "A monospaced pixel font with a lo-fi, techy vibe" off
  "FiraCode" "Programming ligatures, extension of Fira Mono font, enlarged operators" on
  "IosevkaTermSlab" "A narrower variant with slab serifs focusing terminal uses: Arrows and geometric symbols will be narrow to follow typical terminal usage" on
  "JetBrainsMono" "JetBrains officially created font for developers" on
  "Monofur" "Dotted zeros, slightly exaggerated curvy characters, compact characters" off
  "Terminus" "Squarish characters that are slightly askew" off
)

while true; do
  selected_fonts=$(whiptail --title "Select Fonts to Install" --checklist \
  "Choose font to install \nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 85 20 \
  "${font_options[@]}" 3>&1 1>&2 2>&3)

  # Check if the user pressed Cancel (exit status 1)
  if [ $? -ne 0 ]; then
    echo -e "\n"
    echo "${INFO}    You cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
    exit 0  # Exit the script if Cancel is pressed
  fi
  # If no option was selected, notify and restart the selection
  if [ -z "$selected_fonts" ]; then
    whiptail --title "Warning" --msgbox "No options were selected. Please select at least one font or select cancel." 10 60
    continue  # Return to selection if no options selected
  fi
  # Strip the quotes and trim spaces if necessary (sanitize the input)
  selected_fonts=$(echo "$selected_fonts" | tr -d '"' | tr -s ' ')
  IFS=' ' read -ra selected_array <<< "$selected_fonts"
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

for font in "${selected_array[@]}"; do
  if [[ ! -d "assets/fonts/${font}" ]]; then
    echo "${INFO}    Installing ${SKY_BLUE}${font}${RESET}" | tee -a "$LOG"
    wget -c "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.tar.xz" -O "assets/fonts/${font}.tar.xz"
    mkdir -p "assets/fonts/${font}"
    tar -xf "assets/fonts/${font}.tar.xz" -C "assets/fonts/${font}"
    rm "assets/fonts/${font}.tar.xz"
  else
    echo "${INFO}    Skipped Installing ${SKY_BLUE}${font}${RESET}, Already exist" | tee -a "$LOG"
  fi
done

cp -an "assets/fonts/." "$FONT_DIR/" || { printf "%s - Failed to install ${YELLOW}FONT${RESET}\n" "${ERROR}" | tee -a "$LOG"; exit 1; }

for font in "${selected_array[@]}"; do
  if [[ ! -d "assets/fonts/${font}" ]]; then
    echo "${INFO}    Removing ${SKY_BLUE}${font}${RESET} from Repository" | tee -a "$LOG"
    rm -r "assets/fonts/${font}"
  fi
done

printf "${OK}      Succesfully Installed ${SKY_BLUE}FONTS${RESET}!" | tee -a "$LOG"
printf "\n%.0s" {1..1}