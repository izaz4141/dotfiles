#!/bin/bash

files=$(find "$HOME" -type f -print)

selected=$(rofi -dmenu -i -markup -replace -p "Keybinds" -config ~/.config/rofi/config-recursive.rasi <<<"$files")

if [ -z $selected ]; then
    echo "Canceled"
else
    xdg-open $selected &
fi