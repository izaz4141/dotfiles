#!/bin/bash

# This script monitors playerctl metadata and outputs the
# currently "Playing" media's information to Waybar.
# If no media is playing, it outputs the "Paused" media information.
# If no media is playing or paused, it outputs a default "No media" state.

# Get metadata for all players.
# We're specifically interested in 'Playing' and 'Paused' statuses.
PLAYER_OUTPUT=$(playerctl -a metadata \
  --format '{"text": "{{markup_escape(artist)}} - {{markup_escape(title)}}", "tooltip": "{{playerName}}: {{markup_escape(title)}} ({{status}})", "alt": "{{status}}", "class": "{{status}}"}')

# Process the output using jq:
# 1. Slurp all lines into a single JSON array using 'jq -s'.
# 2. Filter for playing items and paused items separately.
# 3. If a playing item exists, output the first one.
# 4. Else if a paused item exists, output the first one.
# 5. Otherwise, output a default "No media" JSON object.
# The '-c' flag for jq ensures the output is a single, compact line with no indentation.
echo "$PLAYER_OUTPUT" | jq -s -c '
  . as $all_players | # Store the entire array of player outputs in a variable

  {
    # Filter for playing players from the stored array
    playing_players: ($all_players | map(select(.class == "Playing"))),
    # Filter for paused players from the stored array
    paused_players: ($all_players | map(select(.class == "Paused")))
  } | # Now we have an object with 'playing_players' and 'paused_players' arrays

  if .playing_players[0] then
    .playing_players[0]
  elif .paused_players[0] then
    .paused_players[0]
  else
    {"text": "No media", "tooltip": "No media playing", "alt": "Stopped", "class": "Stopped"}
  end
'
