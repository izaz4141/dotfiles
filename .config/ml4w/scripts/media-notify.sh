#!/bin/bash

# See README.md for usage instructions
volume_step=3
brightness_step=5
max_volume=100
notification_timeout=5000
download_album_art=true
show_album_art=true
show_music_in_volume_indicator=true

# Uses regex to get volume from pactl
function get_volume {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}
function get_mic_volume {
    pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

# Uses regex to get mute status from pactl
function get_mute {
    pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
}
function get_mic_mute {
    pactl get-source-mute @DEFAULT_SOURCE@ | grep -Po '(?<=Mute: )(yes|no)'
}

# Uses regex to get brightness from xbacklight
function get_brightness {
    CARD=`ls /sys/class/backlight | head -n 1`

	if [[ "$CARD" == *"intel_"* ]]; then
		BNESS=`xbacklight -get`
		LIGHT=${BNESS%.*}
	else
		BNESS=`brightnessctl g`
        BNMAX=`brightnessctl m`
		PERC=$(echo "scale=2; $BNESS / $BNMAX * 100" | bc)
		LIGHT=${PERC%.*}
	fi

	echo "$LIGHT"
}

# Returns a mute icon, a volume-low icon, or a volume-high icon, depending on the volume
get_volume_icon() {
    mute=$(get_mute)
    if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
        volume_icon=""
        volume_image=file://$HOME/dotfiles/assets/icons/volume-mute.png
    elif [ "$volume" -lt 30 ]; then
        volume_icon=""
        volume_image=file://$HOME/dotfiles/assets/icons/volume-low.png
    elif [ "$volume" -lt 60 ]; then
        volume_icon=""
        volume_image=file://$HOME/dotfiles/assets/icons/volume-mid.png
    else
        volume_icon=""
        volume_image=file://$HOME/dotfiles/assets/icons/volume-high.png
    fi
}
function get_mic_icon {
    mute=$(get_mic_mute)
    if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
        volume_icon="󰍭"
    else
        volume_icon="󰍬"
    fi
}

# Always returns the same icon - I couldn't get the brightness-low icon to work with fontawesome
function get_brightness_icon {
    if [ "$brightness" -lt 21 ] ; then
        brightness_image=file://$HOME/dotfiles/assets/icons/brightness-20.png
    elif [ "$brightness" -lt 41 ]; then
        brightness_image=file://$HOME/dotfiles/assets/icons/brightness-40.png
    elif [ "$brightness" -lt 61 ]; then
        brightness_image=file://$HOME/dotfiles/assets/icons/brightness-60.png
    elif [ "$brightness" -lt 81 ]; then
        brightness_image=file://$HOME/dotfiles/assets/icons/brightness-80.png
    else
        brightness_image=file://$HOME/dotfiles/assets/icons/brightness-100.png
    fi
}

function get_album_art {
    url=$(playerctl -f "{{mpris:artUrl}}" metadata)
    if [[ $url == "file://"* ]]; then
        album_art="${url/file:\/\//}"
    elif [[ $url == "http://"* ]] && [[ $download_album_art == "true" ]]; then
        # Identify filename from URL
        filename="$(echo $url | sed "s/.*\///")"

        # Download file to /tmp if it doesn't exist
        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    elif [[ $url == "https://"* ]] && [[ $download_album_art == "true" ]]; then
        # Identify filename from URL
        filename="$(echo $url | sed "s/.*\///")"

        # Download file to /tmp if it doesn't exist
        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    else
        album_art="file:///home/glicole/dotfiles/eww/assets/music.png"
    fi
}

# Displays a volume notification
function show_volume_notif {
    volume=$(get_volume)
    if [[ $show_music_in_volume_indicator == "true" && \
        $show_album_art == "true" ]] && \
        ! playerctl status 2>&1 | grep -q "No players found"; then
        current_song=$(playerctl -f "{{title}} - {{artist}}" metadata)
        echo $current_song
        get_album_art
        notify-send -r 1 -t $notification_timeout -h int:value:$volume -i "$album_art" "$volume_icon     $volume%" "$current_song"
    else
        get_volume_icon
        notify-send -r 1 -t $notification_timeout -h int:value:$volume -i "$volume_image" "$volume%"
    fi
}
function show_mic_notif {
    volume=$(get_mic_volume)
    get_mic_icon
    notify-send -r 3 -t $notification_timeout -h int:value:$volume -i "file:///home/glicole/dotfiles/eww/assets/volume.png" "$volume_icon     $volume%"

}

# Displays a music notification
function show_music_notif {
    song_title=$(playerctl -f "{{title}}" metadata)
    song_artist=$(playerctl -f "{{artist}}" metadata)
    song_album=$(playerctl -f "{{album}}" metadata)

    if [[ $show_album_art == "true" ]]; then
        get_album_art
    fi

    notify-send -r 4 -t $notification_timeout -i "$album_art" "$song_title" "$song_artist - $song_album"
}

# Displays a brightness notification
function show_brightness_notif {
    brightness=$(get_brightness)
    get_brightness_icon
    notify-send -r 2 -t $notification_timeout -h int:value:$brightness -i "$brightness_image" "$brightness%"
}

# Main function - Takes user input, "volume_up", "volume_down", "brightness_up", or "brightness_down"
case $1 in
    volume_up)
    # Unmutes and increases volume, then displays the notification
    volume=$(get_volume)
    pactl set-sink-mute @DEFAULT_SINK@ 0
    if [ $(( "$volume" + "$volume_step" )) -gt $max_volume ]; then
        pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
    else
        pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
    fi
#     show_volume_notif
    ;;

    volume_down)
    # Decrease volume and displays the notification
    volume=$(get_volume)
    if [ $(( "$volume" - "$volume_step" )) -lt "0" ]; then
        pactl set-sink-mute @DEFAULT_SINK@ 1
    else
        pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
    fi
#     show_volume_notif
    ;;

    volume_mute)
    # Toggles mute and displays the notification
    pactl set-sink-mute @DEFAULT_SINK@ toggle
#     show_volume_notif
    ;;

    mic_up)
    # Unmutes and increases microphone volume, then displays the notification
    volume=$(get_mic_volume)
    pactl set-source-mute @DEFAULT_SOURCE@ 0
    if [ $(( "$volume" + "$volume_step" )) -gt $max_volume ]; then
        pactl set-source-volume @DEFAULT_SOURCE@ $max_volume%
    else
        pactl set-source-volume @DEFAULT_SOURCE@ +$volume_step%
    fi
#     show_mic_notif
    ;;

    mic_down)
    # Decrease microphone volume and displays the notification
    volume=$(get_mic_volume)
    if [ $(( "$volume" - "$volume_step" )) -lt "0" ]; then
        pactl set-source-mute @DEFAULT_SOURCE@ 1
    else
        pactl set-source-volume @DEFAULT_SOURCE@ -$volume_step%
    fi
#     show_mic_notif
    ;;

    mic_mute)
    # Toggles mute and displays the notification
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
#     show_mic_notif
    ;;

    brightness_up)
    # Increases brightness and displays the notification
    # brightnessctl -q s +$brightness_step%
    qs ipc call brightness incrementDefault $brightness_step
#     show_brightness_notif
    ;;

    brightness_down)
    # Decreases brightness and displays the notification
    # brightnessctl -q s $brightness_step%-
    qs ipc call brightness decrementDefault $brightness_step
#     show_brightness_notif
    ;;

    next_track)
    # Skips to the next song and displays the notification
    playerctl next
    sleep 0.5 && show_music_notif
    ;;

    prev_track)
    # Skips to the previous song and displays the notification
    playerctl previous
    sleep 0.5 && show_music_notif
    ;;

    play_pause)
    playerctl play-pause
    show_music_notif
    # Pauses/resumes playback and displays the notification
    ;;
esac
