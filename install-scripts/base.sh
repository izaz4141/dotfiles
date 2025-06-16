#!/bin/bash

set -e

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

check_aur_helper() {
    if command -v yay &> /dev/null; then
        echo "yay"
    elif command -v paru &> /dev/null; then
        echo "paru"
    else
        echo ""
    fi
}
ISAUR=$(check_aur_helper)

# Show progress function
show_progress() {
    local pid=$1
    local pkg=$2
    local spin_chars=("●○○○○○○○○○" "○●○○○○○○○○" "○○●○○○○○○○" "○○○●○○○○○○" "○○○○●○○○○" \
                      "○○○○○●○○○○" "○○○○○○●○○○" "○○○○○○○●○○" "○○○○○○○○●○" "○○○○○○○○○●")
    local i=0

    tput civis
    printf "\r${NOTE} Installing ${YELLOW}%s${RESET} ..." "${pkg}"

    while ps -p $pid &> /dev/null; do
        printf "\r${NOTE} Installing ${YELLOW}%s${RESET} %s" "${pkg}" "${spin_chars[i]}"
        i=$(( (i + 1) % 10 ))
        sleep 0.3
    done

    printf "\r${NOTE} Installing ${YELLOW}%s${RESET} ... Done!%-20s \n" "${pkg}" ""
    tput cnorm
}



# Function to install packages with pacman
install_package_pacman() {
  local pkg=$1
  local LOG=$2

  # Check if package is already installed
  if pacman -Q "$1" &>/dev/null ; then
    echo -e "${INFO} ${MAGENTA}${pkg}${RESET} is already installed. Skipping..."
  else
    # Run pacman and redirect all output to a log file
    (
      stdbuf -oL sudo pacman -S --noconfirm "${pkg}" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "${pkg}"

    # Double check if package is installed
    if pacman -Q "${pkg}" &>/dev/null ; then
      echo -e "${OK} Package ${YELLOW}${pkg}${RESET} has been successfully installed!"
    else
      echo -e "\n${ERROR} ${YELLOW}${pkg}${RESET} failed to install. Please check the $LOG. You may need to install manually."
    fi
  fi
}

# Function to install packages with either aur helper or pacman
install_package() {
  local pkg=$1
  local LOG=$2

  if [ -n $ISAUR ]; then
    local installer=$ISAUR
  else
    local installer="sudo pacman"
  fi

  if $installer -Q "$1" &>> /dev/null ; then
    echo -e "${INFO} ${MAGENTA}${pkg}${RESET} is already installed. Skipping..."
  else
    (
      stdbuf -oL $installer -S --noconfirm "${pkg}" 2>&1
    ) >> "$LOG" 2>&1 &
    PID=$!
    show_progress $PID "${pkg}"

    # Double check if package is installed
    if $installer -Q "${pkg}" &>> /dev/null ; then
      echo -e "${OK} Package ${YELLOW}${pkg}${RESET} has been successfully installed!"
    else
      # Something is missing, exiting to review log
      echo -e "\n${ERROR} ${YELLOW}${pkg}${RESET} failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
    fi
  fi
}

# Function to just install packages with either yay or paru without checking if installed
install_package_f() {
  local pkg=$1
  local LOG=$2

  if [ -n $ISAUR ]; then
    local installer=$ISAUR
  else
    local installer="sudo pacman"
  fi
  
  (
    stdbuf -oL $installer -S --noconfirm "${pkg}" 2>&1
  ) >> "$LOG" 2>&1 &
  PID=$!
  show_progress $PID "${pkg}"

  # Double check if package is installed
  if $installer -Q "${pkg}" &>> /dev/null ; then
    echo -e "${OK} Package ${YELLOW}${pkg}${RESET} has been successfully installed!"
  else
    # Something is missing, exiting to review log
    echo -e "\n${ERROR} ${YELLOW}${pkg}${RESET} failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
  fi
}


# Function for removing packages
uninstall_package() {
  local pkg="$1"

  # Checking if package is installed
  if pacman -Qi "$pkg" &>/dev/null; then
    echo -e "${NOTE} removing $pkg ..."
    sudo pacman -Rsn --noconfirm "$pkg" 2>&1 | tee -a "$LOG" | grep -v "error: target not found"

    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo -e "\e[1A\e[K${OK} $pkg removed."
    else
      echo -e "\e[1A\e[K${ERROR} $pkg Removal failed. No actions required."
      return 1
    fi
  else
    echo -e "${INFO} Package $pkg not installed, skipping."
  fi
  return 0
}
