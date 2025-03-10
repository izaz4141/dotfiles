function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting

end

# DATAPATH for MCNP cross-section data
export DATAPATH="/home/glicole/MCNP/MCNP_DATA"
export OPENMC_CROSS_SECTIONS="/home/glicole/Documents/OpenMC/endfb71/cross_sections.xml"
export OMP_NUM_THREADS=4

#######################################################
# Init Module
#######################################################
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/glicole/miniforge3/bin/conda
    eval /home/glicole/miniforge3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/glicole/miniforge3/etc/fish/conf.d/conda.fish"
        . "/home/glicole/miniforge3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/glicole/miniforge3/bin" $PATH
    end
end
# <<< conda initialize <<<
starship init fish | source
zoxide init fish | source
cat ~/.cache/wal/sequences


#######################################################
# GENERAL ALIAS'S
#######################################################
# To temporarily bypass an alias, we precede the command with a \
# EG: the ls command is aliased, but to use the normal ls command you would type \ls

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
# alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Editor
export EDITOR=nvim
export VISUAL=nvim
alias v='$EDITOR'
alias vim='$EDITOR'
alias vi='nvim'
alias svi='sudo vi'
alias vis='nvim "+set si"'

# alias to show the date
alias da='date "+%Y-%m-%d %A %T %Z"'

# Alias's to modified commands
alias cp='cp -i'
alias mv='mv -i'
# alias rm='trash -v'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias apt-get='sudo apt-get'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'


# Change directory aliases
alias home='z ~'
alias cd..='z ..'
alias ..='z ..'
alias ...='z ../..'
alias ....='z ../../..'
alias .....='z ../../../..'

# cd into the old directory
alias bd='z "$OLDPWD"'

# Remove a directory and all files
alias rmd='rm  --recursive --force --verbose '

# Alias's for multiple directory listing commands
alias la='ls -Alh'                # show hidden files
alias ls='ls -aFh --color=always' # add colors and file type extensions
alias lx='ls -lXBh'               # sort by extension
alias lk='ls -lSrh'               # sort by size
alias lc='ls -lcrh'               # sort by change time
alias lu='ls -lurh'               # sort by access time
alias lr='ls -lRh'                # recursive ls
alias lt='ls -ltrh'               # sort by date
alias lm='ls -alh |more'          # pipe through 'more'
alias lw='ls -xAh'                # wide listing format
alias ll='ls -Fls'                # long listing format
alias labc='ls -lap'              #alphabetical sort
alias lf="ls -l | egrep -v '^d'"  # files only
alias ldir="ls -l | egrep '^d'"   # directories only

# alias chmod commands
alias mx='chmod a+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder
alias f="find . | grep "

# Count all files (recursively) in the current folder
# alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# To see if a command is aliased, a file, or a built-in command
alias checkcommand="type -t"

# Show open ports
alias openports='netstat -nape --inet'

# Alias's for safe and forced reboots
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Show all logs in /var/log
# alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# SHA1
alias sha1='openssl sha1'

alias clickpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'

# KITTY - alias to be able to use kitty features when connecting to remote servers(e.g use tmux on remote server)

alias kssh="kitty +kitten ssh"


# -----------------------------------------------------
# SHORT ALIASES
# -----------------------------------------------------
alias c='clear'
alias nf='fastfetch'
alias pf='fastfetch'
alias ff='fastfetch'
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'
alias shutdown='systemctl poweroff'
alias ts='~/.config/ml4w/scripts/snapshot.sh'
alias matrix='cmatrix'
alias wifi='nmtui'
alias winclass="xprop | grep 'CLASS'"
alias dot="z ~/dotfiles"
alias cleanup='~/.config/ml4w/scripts/cleanup.sh'
alias zj='zellij'

# -----------------------------------------------------
# ML4W Apps
# -----------------------------------------------------
alias ml4w='com.ml4w.welcome'
alias ml4w-settings='com.ml4w.dotfilessettings'
alias ml4w-hyprland='com.ml4w.hyprland.settings'
alias ml4w-options='ml4w-hyprland-setup -m options'
alias ml4w-sidebar='ags -t sidebar'
alias ml4w-diagnosis='~/.config/hypr/scripts/diagnosis.sh'
alias ml4w-hyprland-diagnosis='~/.config/hypr/scripts/diagnosis.sh'
alias ml4w-qtile-diagnosis='~/.config/ml4w/qtile/scripts/diagnosis.sh'
alias ml4w-update='~/.config/ml4w/update.sh'

# -----------------------------------------------------
# Window Managers
# -----------------------------------------------------

alias Qtile='startx'
# Hyprland with Hyprland

# -----------------------------------------------------
# GIT
# -----------------------------------------------------
# alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gsp="git stash; git pull"
alias gcheck="git checkout"
alias gcredential="git config credential.helper store"

# -----------------------------------------------------
# SCRIPTS
# -----------------------------------------------------
alias ascii='~/.config/ml4w/scripts/figlet.sh'
alias onedrive_pull='~/.config/ml4w/scripts/onedrive.sh --pull'
alias onedrive_sync='~/.config/ml4w/scripts/onedrive.sh --sync'
alias package_main='yay -Qqen > ~/dotfiles/packages_main.txt'
alias package_aur='yay -Qqem > ~/dotfiles/packages_aur.txt'

# -----------------------------------------------------
# VIRTUAL MACHINE
# -----------------------------------------------------
# alias vm='~/private/launchvm.sh'
# alias lg='~/dotfiles/scripts/looking-glass.sh'

# -----------------------------------------------------
# EDIT NOTES
# -----------------------------------------------------
alias notes='$EDITOR ~/notes.txt'

# -----------------------------------------------------
# SYSTEM
# -----------------------------------------------------
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias setkb='setxkbmap de;echo "Keyboard set back to de."'

# -----------------------------------------------------
# SCREEN RESOLUTINS
# -----------------------------------------------------

# Qtile
alias res1='xrandr --output DisplayPort-0 --mode 2560x1440 --rate 120'
alias res2='xrandr --output DisplayPort-0 --mode 1920x1080 --rate 120'

export PATH="/usr/lib/ccache/bin/:$PATH"

# -----------------------------------------------------
# DEVELOPMENT
# -----------------------------------------------------
alias pamcan=pacman

#######################################################
# SPECIAL FUNCTIONS
#######################################################
# function fish_prompt
#   set_color cyan; echo (pwd)
#   set_color green; echo '> '
# end

function sudo
    set sudo_args_with_value (LANG=C command sudo --help | string match -gr '^\s*(-\w),\s*(--\w[\w-]*)=')
    set sudo_args

    while set -q argv[1]
        switch "$argv[1]"
            case '--'
                set -a sudo_args $argv[1]
                set -e argv[1]
                break
            case $sudo_args_with_value
                set -a sudo_args $argv[1]
                set -e argv[1]
            case '-*'
            case '*'
                break
        end
        set -a sudo_args $argv[1]
        set -e argv[1]
    end

    if functions -q -- $argv[1]
        set -- argv fish -C "$(functions --no-details -- $argv[1])" -c '$argv' -- $argv
    end

    command sudo $sudo_args $argv
end

# Automatically do an ls after each cd, z, or zoxide
function cd
	if [ -n $argv ]
		z $argv && ls
	else
		z ~ && ls
	end
end

function yy
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

fastfetch -c ~/.config/fastfetch/nadeko-chibi.jsonc

