#!/bin/bash

SEQUENCE_FILE="$HOME/.cache/matugen/sequences"

if [ -f "$SEQUENCE_FILE" ]; then
    # Read the file and remove ALL newlines (so we send a single uninterrupted sequence)
    SEQUENCE=$(tr -d '\n' < "$SEQUENCE_FILE")

    # Get the current terminal to optionally skip it
    CURRENT_TTY=$(tty | sed 's#/dev/##')

    for pts in /dev/pts/*; do
        # Skip the terminal we're running in (optional, but avoids cluttering your prompt)
        [ "$pts" = "/dev/pts/$CURRENT_TTY" ] && continue

        # Only write if the PTY exists and is writable
        if [ -w "$pts" ]; then
            printf '%s' "$SEQUENCE" > "$pts" 2>/dev/null
        fi
    done
fi
