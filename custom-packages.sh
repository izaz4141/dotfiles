#!/bin/bash

PACKAGESGROUP="kate vscodium-bin btop ncdu yazi fzf fish foot bat zoxide multitail bash-completion tree trash-cli musikcube spotube snapper gimp freedownloadmanager photoqt-bin gimp libreoffice-fresh zotero-bin ttf-ms-win11-auto man-db brave-bin downgrade bc"

echo y | LANG=C yay --noprovides --answerdiff None --answerclean None --mflags "--noconfirm" $PACKAGESGROUP
