#!/bin/bash

# --- Configuration ---
# Maximum combined length for artist and title (including separator and truncation indicator)
COMBINED_CHAR_LIMIT=21

# --- Global Variables ---
# These will store the final artist, title, and status to be outputted.
FINAL_ARTIST=""
FINAL_TITLE=""
FINAL_STATUS=""

# Flags to indicate if a playing or paused player has been found.
FOUND_PLAYING=false
FOUND_PAUSED=false

# --- Functions ---

# Function to safely get metadata from playerctl.
# Arguments:
#   $1: Player name (e.g., "spotify")
#   $2: Metadata format string (e.g., "{{markup_escape(artist)}}")
# Returns: The metadata string or an empty string if an error occurs.
get_metadata() {
    local player="$1"
    local format="$2"
    playerctl -p "$player" metadata --format "$format" 2>/dev/null || echo ""
}

# Function to truncate the title based on combined character limit.
# Arguments:
#   $1: Full artist string
#   $2: Full title string
#   $3: Combined character limit
# Returns: The truncated title string (echoed).
truncate_title() {
    local full_artist="$1"
    local full_title="$2"
    local char_limit="$3"
    local truncated_title=""

    # Calculate the potential length of the combined string "Artist | Title"
    # We add 3 for " | " (space, pipe, space)
    local potential_display_length=$(( ${#full_artist} + ${#full_title} + 3 ))

    # If the combined length exceeds the defined limit, truncation is needed.
    if [ "$potential_display_length" -gt "$char_limit" ]; then
        # Calculate available space for the title after accounting for artist,
        # the " | " separator, and ".." for truncation.
        # We subtract 1 for the '|' and another 2 for '..'
        local available_title_space=$(( char_limit - ${#full_artist} - 1 - 2 ))

        # If available space is zero or negative, it means the artist alone (or artist + " | ")
        # is already too long, or there's no meaningful space for the title.
        if [ "$available_title_space" -le 0 ]; then
            # If artist length + "|" is already greater than or equal to the combined limit,
            # then there's no space for the title, so set it to empty.
            if [ $(( ${#full_artist} + 1 )) -ge "$char_limit" ]; then
                truncated_title=""
            else
                # There's some space, but not enough for ".." and a character.
                # Truncate the title to fit exactly without ".."
                local truncated_length_no_dots=$(( char_limit - ${#full_artist} - 1 ))
                truncated_title="${full_title:0:$truncated_length_no_dots}"
            fi
        else
            # Truncate the title to fit the remaining space, and append ".."
            truncated_title="${full_title:0:$available_title_space}.."
        fi
    else
        # If the combined length is within the limit, use the full title.
        truncated_title="$full_title"
    fi
    echo "$truncated_title"
}

# --- Main Logic ---

# Get a list of all available playerctl players, suppressing errors.
PLAYERS=$(playerctl -l 2>/dev/null)

# Loop through each detected player.
for PLAYER in $PLAYERS; do
    # Get the status of the current player, suppressing errors.
    STATUS=$(playerctl -p "$PLAYER" status 2>/dev/null)

    # Check the status of the player.
    if [ "$STATUS" = "Playing" ]; then
        # If a playing player is found, it takes highest priority.
        # Get artist and title metadata.
        FULL_ARTIST_CANDIDATE=$(get_metadata "$PLAYER" '{{markup_escape(artist)}}')
        FULL_TITLE_CANDIDATE=$(get_metadata "$PLAYER" '{{markup_escape(title)}}')
        
        # Truncate the title if necessary.
        FINAL_TITLE=$(truncate_title "$FULL_ARTIST_CANDIDATE" "$FULL_TITLE_CANDIDATE" "$COMBINED_CHAR_LIMIT")
        
        FINAL_ARTIST="$FULL_ARTIST_CANDIDATE"
        FINAL_STATUS="PLAY"
        FOUND_PLAYING=true
        break # Found a playing player, no need to check further.
    elif [ "$STATUS" = "Paused" ] && [ "$FOUND_PLAYING" = false ]; then
        # If a paused player is found AND no playing player has been found yet,
        # capture its metadata. We only store the first paused one we encounter.
        
        FULL_ARTIST_CANDIDATE=$(get_metadata "$PLAYER" '{{markup_escape(artist)}}')
        FULL_TITLE_CANDIDATE=$(get_metadata "$PLAYER" '{{markup_escape(title)}}')
        
        # Truncate the title if necessary.
        FINAL_TITLE=$(truncate_title "$FULL_ARTIST_CANDIDATE" "$FULL_TITLE_CANDIDATE" "$COMBINED_CHAR_LIMIT")
        
        FINAL_ARTIST="$FULL_ARTIST_CANDIDATE"
        FINAL_STATUS="PAUSE"
        FOUND_PAUSED=true
        # Do NOT break here, as a 'Playing' player might still be found later in the loop
        # and should override a 'Paused' one.
    fi
done

# --- Output based on command-line argument ---
# If no media is playing or paused, ARTIST and TITLE will remain empty.
case "$1" in
    artist)
        echo "$FINAL_ARTIST"
        ;;
    title)
        echo "$FINAL_TITLE"
        ;;
    status)
        echo "$FINAL_STATUS"
        ;;
    separator)
        # Output a separator only if there's a title to display.
        if [[ -n "$FINAL_TITLE" ]]; then
            echo "|"
        else
            echo ""
        fi
        ;;
    *)
        # Default case for invalid arguments, or no argument.
        # You might want to add an error message or usage instructions here.
        echo "Usage: $0 [artist|title|status|separator]" >&2
        exit 1
        ;;
esac
