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

# Show progress function pinned at top
show_progress() {
  local pid=$1
  local pkg=$2
  local spin_chars=( '◐' '◓' '◑' '◒' )
  local i=0

  tput civis   # hide cursor

  # initial top-line (do not change the foreground cursor)
  tput sc
  tput cup 0 0
  tput el
  printf "%s Installing %s %s" "${NOTE:-[..]}" "$pkg" "${spin_chars[i]}"
  tput rc

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % ${#spin_chars[@]} ))

    tput sc        # save foreground cursor pos
    tput cup 0 0   # move to top line
    tput el        # clear to end of line
    printf "%s Installing %s %s" "${NOTE:-[..]}" "$pkg" "${spin_chars[i]}"
    tput rc        # restore foreground cursor pos

    sleep 0.18
  done

  # final: overwrite top line and move to next line (so subsequent prints appear below)
  tput cup 0 0
  tput el
  printf "%s Installing %s ... Done!\n" "${NOTE:-[..]}" "$pkg"

  tput cnorm     # show cursor again
}

# Function to install packages with either AUR helper or pacman (interactive + tee)
install_package() {
  local pkg=$1
  local LOG=$2

  # Pick installer
  local installer
  if [ -n "$ISAUR" ]; then
    installer="$ISAUR"
  else
    installer="sudo pacman"
  fi

  # Check if package is already installed
  if $installer -Q "$pkg" &>/dev/null ; then
    echo -e "${INFO} ${MAGENTA}${pkg}${RESET} is already installed. Skipping..."
  else
    # Clear screen and reserve top line for spinner
    clear
    tput cup 0 0
    echo ""   # newline -> output (installer) will start on line 1
    # split installer into words (so "sudo pacman" works)
    read -r -a installer_parts <<< "$installer"
    # decide which process name to watch (handle "sudo pacman")
    local watch_cmd
    if [ "${installer_parts[0]}" = "sudo" ] && [ -n "${installer_parts[1]:-}" ]; then
      watch_cmd="${installer_parts[1]}"
    else
      watch_cmd="${installer_parts[0]}"
    fi

    # watcher: wait for either the installer process or pacman to appear, then run spinner on that pid
    (
      local INSPID=""
      while true; do
        if pgrep -x "$watch_cmd" >/dev/null 2>&1; then
          INSPID=$(pgrep -n -x "$watch_cmd")
          break
        elif pgrep -x pacman >/dev/null 2>&1; then
          INSPID=$(pgrep -n -x pacman)
          break
        fi
        sleep 0.05
      done

      if [ -n "$INSPID" ]; then
        show_progress "$INSPID" "$pkg"
      fi
    ) & WATCHER_PID=$!

    # Run installer in the foreground (interactive) and tee output to log
    # Note: installer_parts expands to e.g. ("sudo" "pacman") or ("yay")
    stdbuf -oL "${installer_parts[@]}" -S --noconfirm "$pkg" 2>&1 | tee -a "$LOG"

    # wait for watcher to finish (it will finish after the watched PID dies)
    wait "$WATCHER_PID" 2>/dev/null || true

    # Double check if package is installed
    if $installer -Q "$pkg" &>/dev/null ; then
      echo -e "${OK} Package ${YELLOW}${pkg}${RESET} has been successfully installed!"
    else
      echo -e "\n${ERROR} ${YELLOW}${pkg}${RESET} failed to install :( , please check ${LOG}. You may need to install manually!"
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
  
  # Clear screen and reserve top line for spinner
  clear
  tput cup 0 0
  echo ""   # newline -> output (installer) will start on line 1
  # split installer into words (so "sudo pacman" works)
  read -r -a installer_parts <<< "$installer"
  # decide which process name to watch (handle "sudo pacman")
  local watch_cmd
  if [ "${installer_parts[0]}" = "sudo" ] && [ -n "${installer_parts[1]:-}" ]; then
    watch_cmd="${installer_parts[1]}"
  else
    watch_cmd="${installer_parts[0]}"
  fi

  # watcher: wait for either the installer process or pacman to appear, then run spinner on that pid
  (
    local INSPID=""
    while true; do
      if pgrep -x "$watch_cmd" >/dev/null 2>&1; then
        INSPID=$(pgrep -n -x "$watch_cmd")
        break
      elif pgrep -x pacman >/dev/null 2>&1; then
        INSPID=$(pgrep -n -x pacman)
        break
      fi
      sleep 0.05
    done

    if [ -n "$INSPID" ]; then
      show_progress "$INSPID" "$pkg"
    fi
  ) & WATCHER_PID=$!

  # Run installer in the foreground (interactive) and tee output to log
  # Note: installer_parts expands to e.g. ("sudo" "pacman") or ("yay")
  stdbuf -oL "${installer_parts[@]}" -S --noconfirm "$pkg" 2>&1 | tee -a "$LOG"

  # wait for watcher to finish (it will finish after the watched PID dies)
  wait "$WATCHER_PID" 2>/dev/null || true

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
