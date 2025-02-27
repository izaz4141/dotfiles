#!/bin/bash
dotfiles_dir=$(pwd)
execute_command() {
    while true; do
        "$@"
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            break
        else
            echo "Command failed with exit code $exit_code."
            choice=$(gum choose "Continue the script" "Retry the command" "Exit the script")
            case $choice in
                "Continue the script") break ;;
                "Retry the command") continue ;;
                "Exit the script") exit 1 ;;
            esac
        fi
    done
}

install_yay() {
    echo ":: Installing yay..."
    execute_command sudo pacman -Sy
    execute_command sudo pacman -S --needed --noconfirm base-devel git
    execute_command git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    execute_command makepkg -si --needed --noconfirm
}
install_packages() {
    echo ":: Installing packages"
    sleep 1
    execute_command sudo pacman -Sy
    execute_command sudo pacman -S --needed --noconfirm - < $dotfiles_dir/packages_main.txt
}

install_aur() {
    echo ":: Installing aur packages"
    sleep 1
    execute_command yay -Sy
    execute_command yay -S --needed --noconfirm - < $dotfiles_dir/packages_aur.txt
}

install_themes() {
    echo ":: Installing Themes (Icon, Mouse, and SDDM)"
    sleep 1
    execute_command mkdir $HOME/.icons/
    execute_command cp -an $dotfiles_dir/themes/.icons/. $HOME/.icons/
    execute_command sudo mkdir -p /usr/share/sddm/themes
    execute_command sudo cp -an $dotfiles_dir/themes/sddm/. /usr/share/sddm/themes
    execute_command sudo cp -an /etc/sddm.conf.d/sddm.conf /etc/sddm.conf.d/sddm.conf.bak
    execute_command sudo sed -i "s/Current=/\c Current=eucalyptus-drop" /etc/sddm.conf.d/sddm.conf
    execute_command gsettings set org.gnome.desktop.interface icon-theme "candy-icons-modified"
    execute_command gsettings set org.gnome.desktop.interface cursor-theme "Sweet-cursors"
    execute_command sudo cp -an $dotfiles_dir/themes/grub/. /usr/share/grub/themes
    execute_command sudo cp -an /etc/default/grub /etc/default/grub.bak
    execute_command sudo sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"/usr/share/grub/themes/Elegant-wave-float-right-dark/theme.txt\"|" /etc/default/grub
    execute_command sudo update-grub
}

install_dotfiles() {
    execute_command ln -s -f $HOME/dotfiles/.config/* $HOME/.config/
}

sudo pacman -Sy
sudo pacman -S --needed --noconfirm gum
mode=$(gum choose "Full Installation" "Main Installation" "AUR Installation" "Theme Installation")
case $mode in
    "Full Installation")
        install_yay
        install_packages
        install_aur
        install_themes
        install_dotfiles;;
    "Main Installation")
        install_packages ;;
    "AUR Installation")
        install_yay
        install_aur ;;
    "Theme Installation")
        install_themes
        install_dotfiles;;
esac
