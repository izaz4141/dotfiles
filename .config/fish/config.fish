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

export EDITOR=nvim
export VISUAL=nvim
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
cat ~/.cache/wallust/sequences


#######################################################
# GENERAL ALIAS'S
#######################################################
source "$HOME/.config/bashrc/10-aliases"

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

# Convert to audio
function convert_audio --description 'Convert to audio with metadata and cover art'
    argparse i/= o/= -- $argv
    or return

    set -l input $_flag_i
    set -l output $_flag_o
    set -l extracted_cover (mktemp -t cover.XXXXXXXXXX.jpg)

    # Extract cover art silently (ignore sequence warnings)
    ffmpeg -y -i "$input" -an -c:v copy -vframes 1 "$extracted_cover"

    # Check if cover art was actually extracted (file exists and is non-zero size)
    if test -s "$extracted_cover"
        # Convert with cover art
        ffmpeg -i "$input" -i "$extracted_cover" \
            -map 0:a -map 1:v \
            -c:a copy \
            -c:v copy \
            -disposition:v attached_pic \
            -map_metadata 0 \
            "$output"
        echo "Converted with cover art: $output"
    else
        # Convert without cover art
        ffmpeg -i "$input" \
            -c:a copy -b:a 256k \
            -map_metadata 0 \
            "$output"
        echo "Converted without cover art: $output"
    end

    # Cleanup temporary files
    rm -f "$extracted_cover"
end


fastfetch -c ~/.config/fastfetch/nadeko-chibi.jsonc

