#!/bin/bash
clear
figlet -f smslant "Cleanup"
echo
echo "Clearing pacman cache"
pacman_cache_space_used="$(sudo du -sh /var/cache/pacman/pkg/)"
sudo paccache -r
echo "Space saved: $pacman_cache_space_used"

echo "Clearing AUR cache"
aur_cache_space_used="$(sudo du -sh ~/.cache/${AUR}/)"
$AUR -Scc
echo "Space saved: $aur_cache_space_used"

echo "Removing orphan packages"
sudo pacman -Qdtq | sudo pacman -Rns -

# echo "Clearing ~/.cache"
# home_cache_used="$(du -sh ~/.cache)"
# rm -rf ~/.cache/
# echo "Spaced saved: $home_cache_used"

echo "Clearing system logs"
sudo journalctl --vacuum-time=7d
