#!/bin/bash

# This script monitors playerctl metadata and outputs the
# currently "Playing" media's information to Waybar.
# If no media is playing, it outputs a default "Stopped" state.

# Get metadata for all players.
PLAYER_OUTPUT=$(playerctl -a metadata \
  --format '{"text": "{{markup_escape(artist)}}  {{markup_escape(title)}}", "tooltip": "{{playerName}} : {{markup_escape(title)}}", "alt": "{{status}}", "class": "{{status}}"}')

# Process the output:
# 1. Slurp all lines into a single JSON array using 'jq -s'.
# 2. Filter this array to select only objects where 'class' is "Playing".
# 3. If a playing item exists (.[0]), output it.
# 4. Otherwise, output a default "No media" JSON object.
# The '-c' flag for jq ensures the output is a single, compact line with no indentation.
echo "$PLAYER_OUTPUT" | jq -s -c '
  map(select(.class == "Playing")) |
  if .[0] then
    .[0]
  else
    {"text": "No media", "tooltip": "No media playing", "alt": "Stopped", "class": "Stopped"}
  end
'
