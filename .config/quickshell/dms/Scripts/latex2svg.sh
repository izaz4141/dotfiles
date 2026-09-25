#!/usr/bin/env bash

CHECK_MODE=0
INPUT=""
OUTPUT=""
DISPLAY=0
COLOR=""
TEXTSIZE=12
PADDING=4

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_MODE=1 ;;
        --input) INPUT="$2"; shift ;;
        --output) OUTPUT="$2"; shift ;;
        --display) DISPLAY="$2"; shift ;;
        --color) COLOR="$2"; shift ;;
        --textsize) TEXTSIZE="${2:-12}"; shift ;;
        --padding) PADDING="${2:-4}"; shift ;;
    esac
    shift
done

bool() {
    if [[ "$1" == "1" ]]; then printf 'true'; else printf 'false'; fi
}

if [[ "$CHECK_MODE" == "1" ]]; then
    if command -v latex >/dev/null 2>&1; then has_latex=1; else has_latex=0; fi
    if command -v dvisvgm >/dev/null 2>&1; then has_dvisvgm=1; else has_dvisvgm=0; fi
    if command -v kpsewhich >/dev/null 2>&1; then has_kpsewhich=1; else has_kpsewhich=0; fi

    has_packages=0
    if [[ "$has_latex" == "1" && "$has_dvisvgm" == "1" && "$has_kpsewhich" == "1" ]]; then
        if kpsewhich standalone.cls >/dev/null 2>&1 && kpsewhich amsmath.sty >/dev/null 2>&1 && kpsewhich xcolor.sty >/dev/null 2>&1; then
            has_packages=1
        fi
    fi

    renderer=0
    if [[ "$has_latex" == "1" && "$has_dvisvgm" == "1" && "$has_packages" == "1" ]]; then
        renderer=1
    fi
    printf '{"renderer":%s,"latex":%s,"dvisvgm":%s,"packages":%s,"source":"latex-dvisvgm"}\n' \
        "$(bool "$renderer")" "$(bool "$has_latex")" "$(bool "$has_dvisvgm")" "$(bool "$has_packages")"
    if [[ "$renderer" == "1" ]]; then exit 0; fi
    exit 1
fi

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
    echo 'latex2svg: --input and --output are required' >&2
    exit 1
fi

color_hex="${COLOR#\#}"
color_hex="${color_hex^^}"

scale=$(awk -v ts="$TEXTSIZE" 'BEGIN { printf "%.4f", ts / 12 }')

workdir=$(mktemp -d "${TMPDIR:-/tmp}/latex2svg.XXXXXX") || exit 1
trap 'rm -rf "$workdir"' EXIT
cd "$workdir" || exit 1

{
    printf '\\documentclass[border=%dpt]{standalone}\n' "$PADDING"
    printf '\\usepackage{amsmath}\n'
    printf '\\usepackage{xcolor}\n'
    printf '\\begin{document}\n'
    printf '\\color[HTML]{%s}\n' "$color_hex"
    if [[ "$DISPLAY" == "1" ]]; then
        printf '$\\displaystyle %s$\n' "$INPUT"
    else
        printf '$%s$\n' "$INPUT"
    fi
    printf '\\end{document}\n'
} > eq.tex

latex -interaction=nonstopmode -halt-on-error eq.tex >/dev/null 2>&1
latex_status=$?
if [[ "$latex_status" != "0" ]]; then
    if [[ -f eq.log ]]; then
        grep -n '^!' eq.log | head -n 5 >&2
    fi
    echo "latex2svg: latex failed with exit code $latex_status" >&2
    exit 2
fi

dvisvgm --no-fonts --exact --scale="$scale" --output="$OUTPUT" eq.dvi
dvisvgm_status=$?
if [[ "$dvisvgm_status" != "0" ]]; then
    echo "latex2svg: dvisvgm failed with exit code $dvisvgm_status" >&2
    exit 3
fi

exit 0