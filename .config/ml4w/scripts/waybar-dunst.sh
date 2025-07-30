#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
# Exit if any unset variables are used.
# The pipefail option prevents errors in a pipeline from being masked.
set -euo pipefail

# This script checks the paused state of Dunst and outputs JSON for Waybar.

# Get the current paused state of Dunst.
# 'true' if Dunst is paused (DND), 'false' otherwise.
# Use 'tr -d "\n"' to remove any newline characters from the output,
# ensuring the variable contains only "true" or "false".
PAUSED=$(dunstctl is-paused | tr -d '\n')

# Initialize variables for JSON output
TOOLTIP_TEXT=""
CLASS_STATE=""
TEXT_CONTENT="" # Keep empty for Waybar to handle icons

# Determine the state based on Dunst's paused status
if [[ "$PAUSED" == "true" ]]; then
    # Dunst is paused, indicating Do Not Disturb (DND) mode.
    CLASS_STATE="dnd-none"
    # Use '\\n' for newlines in JSON strings that Waybar will interpret as actual newlines.
    TOOLTIP_TEXT="Left Click: Clear All Notification\\nRight Click: Disable Do Not Disturb (DND)"
elif [[ "$PAUSED" == "false" ]]; then
    # Dunst is not paused.
    CLASS_STATE="notification"
    TOOLTIP_TEXT="Left Click: Clear All Notification\\nRight Click: Enable Do Not Disturb (DND)"
else
    # Handle unexpected output from dunstctl (e.g., if dunstctl isn't running or returns garbage)
    CLASS_STATE="dnd-none" # Fallback icon
    TOOLTIP_TEXT="Error: Dunst state unknown.\\nLeft Click: Clear All Notification\\nRight Click: Toggle DND"
    # You can uncomment the line below for debugging to see what dunstctl returned
    # echo "ERROR: Unexpected dunstctl output: '${PAUSED}'" >&2
fi

# Output the JSON string for Waybar using printf for more controlled and reliable output.
# This avoids potential issues with heredocs and ensures proper quoting.
printf '{"text": "%s", "tooltip": "%s", "alt": "%s", "class": "%s"}\n' \
    "${TEXT_CONTENT}" \
    "${TOOLTIP_TEXT}" \
    "${CLASS_STATE}" \
    "${CLASS_STATE}"
