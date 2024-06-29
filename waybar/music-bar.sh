#!/usr/bin/bash

playerctl -a metadata --format '{"text": "{{title}}", "tooltip": "{{markup_escape(artist)}} - {{markup_escape(title)}}", "alt": "{{status}}", "class": "{{status}}"}' -F