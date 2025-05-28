#!/bin/bash
#                    __
#  _    _____ ___ __/ /  ___ _____
# | |/|/ / _ `/ // / _ \/ _ `/ __/
# |__,__/\_,_/\_, /_.__/\_,_/_/
#            /___/
#
# -----------------------------------------------------
# Quit all running waybar instances
# -----------------------------------------------------
killall waybar
pkill waybar
sleep 0.5

# Check if waybar-disabled file exists
if [ ! -f $HOME/.config/ml4w/settings/waybar-disabled ]; then
    waybar &
else
    echo ":: Waybar disabled"
fi
