#!/bin/bash
clear
figlet -f smslant "Cleanup"
echo
echo "Clearing pacman cache"
pacman_cache_space_used="$(du -sh /var/cache/pacman/pkg/)"
paccache -r
echo "Space saved: $pacman_cache_space_used"

echo "Clearing AUR cache"
aur_cache_space_used="$(du -sh ~/.cache/${AUR}/)"
$AUR -Scc
echo "Space saved: $aur_cache_space_used"

echo "Removing orphan packages"
$AUR -Qdtq | $AUR -Rns -

# echo "Clearing ~/.cache"
# home_cache_used="$(du -sh ~/.cache)"
# rm -rf ~/.cache/
# echo "Spaced saved: $home_cache_used"

echo "Clearing system logs"
sudo journalctl --vacuum-time=7d
