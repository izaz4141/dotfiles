#!/usr/bin/env bash

SERVICE="hypridle"
if [[ "$1" == "status" ]]; then
    if pgrep -x "$SERVICE" >/dev/null ;then
        echo 'active'
    else
        echo 'notactive'
    fi
fi

if [[ "$1" == "toggle" ]]; then
    if pgrep -x "$SERVICE" >/dev/null ;then
        killall hypridle
        notify-send 'Hypridle Disabled'
    else
        hypridle &
        notify-send 'Hypridle Enabled'
    fi
fi
