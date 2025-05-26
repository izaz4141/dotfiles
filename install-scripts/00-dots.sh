#!/bin/bash
# Install dotfiles configuration to .config

ln -s -f $HOME/dotfiles/wallpaper $HOME/wallpaper
ln -s -f $HOME/dotfiles/.config/* $HOME/.config/
