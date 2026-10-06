#!/usr/bin/env bash
# README shots of a widget: the same isolated instance widget-probe.sh renders
# in, only padded and put on a Material You backdrop. No live shell, no mouse,
# and neither your palette nor your stored options in the frame, so the pictures
# don't change from machine to machine.
#
#   tests/widget-shots.sh [-x dir] [-w widget] [-d outdir] [-P px] ["<slot> [flags]" ...]
#
#   -x dir     widget directory to install into the run, the way an external
#              widget sits in ~/.config/illogical-impulse/widgets/. It shadows the
#              copy you have installed, so slot shots come from the dir you edit
#   -w widget  widget id, default: read from <dir>/Manifest.qml
#   -d outdir  where the pngs land, default <dir>/docs, else /tmp/widget-shots
#   -P px      padding around the item, default 28
#   -c file    palette to render with, default tests/shot-colors.json so shots
#              look the same everywhere. `-c none` takes your wallpaper's colors
#
# A shot is one part of the widget in one state, written as probe arguments: a
# slot, or `-f File.qml` for something with no slot of its own (a settings page),
# plus any widget-probe flag - `-g WxH` for the size, `-o key=value` for the state
# you want in the picture. `-n name` names the file, so the same slot can be shot
# twice. With no shots given they come from <dir>/shots.txt, `#` comments ignored:
#
#   barIndicator -n quiet -o incognito=true -g 150x44
#   barIndicator -n vertical -p vertical=true -H vbar -g 46x120
#   sidebarLeftTab -g 420x560
#   -f ExtraSettings.qml -g 460x520
#
# So a widget repo carrying shots.txt regenerates its README images with one
# command, and gets the same images on any machine.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
XDIR=""
WIDGET=""
OUTDIR=""
PAD=28
COLORS="tests/shot-colors.json"

while getopts "x:w:d:P:c:" flag; do
    case "$flag" in
        x) XDIR=$OPTARG ;;
        w) WIDGET=$OPTARG ;;
        d) OUTDIR=$OPTARG ;;
        P) PAD=$OPTARG ;;
        c) COLORS=$OPTARG ;;
    esac
done
shift $((OPTIND - 1))

if [ -n "$XDIR" ]; then
    [ "${XDIR#/}" = "$XDIR" ] && XDIR="$REPO/$XDIR"
    [ -f "$XDIR/Manifest.qml" ] || { echo "no Manifest.qml in $XDIR"; exit 2; }
    [ -z "$WIDGET" ] && WIDGET=$(sed -n 's/^[[:space:]]*widgetId:[[:space:]]*"\([^"]*\)".*/\1/p' "$XDIR/Manifest.qml" | head -1)
fi
[ -n "$WIDGET" ] || { echo "usage: $0 [-x dir] [-w widget] [-d outdir] [\"<slot> [flags]\" ...]"; exit 2; }

SHOTS=("$@")
if [ "${#SHOTS[@]}" = 0 ]; then
    LIST="${XDIR:+$XDIR/}shots.txt"
    [ -f "$LIST" ] || { echo "no shots given and no $LIST"; exit 2; }
    while IFS= read -r line; do
        line="${line%%#*}"
        [ -n "${line// }" ] && SHOTS+=("$line")
    done < "$LIST"
fi

[ -z "$OUTDIR" ] && OUTDIR="${XDIR:+$XDIR/docs}"
[ -z "$OUTDIR" ] && OUTDIR="/tmp/widget-shots"
# The instance renders with a cwd of its own, so a relative -d would save nowhere
[ "${OUTDIR#/}" = "$OUTDIR" ] && OUTDIR="$PWD/$OUTDIR"
mkdir -p "$OUTDIR"
[ "$COLORS" = none ] && COLORS=""

FAIL=0
MADE=()
for shot in "${SHOTS[@]}"; do
    # shellcheck disable=SC2206
    args=($shot)
    slot=""
    if [ "${args[0]#-}" = "${args[0]}" ]; then # A slot, and the probe wants it right after the widget
        slot="${args[0]}"
        args=("${args[@]:1}")
    fi
    name="${slot:-shot}"
    keep=()
    for i in "${!args[@]}"; do
        case "${args[$i]}" in
            -f) # A file of an external widget is named relative to its own directory
                file="${args[$((i + 1))]}"
                [ -n "$XDIR" ] && [ "${file#/}" = "$file" ] && args[$((i + 1))]="$XDIR/$file"
                name=$(basename "$file" .qml) ;;
            -n) name="${args[$((i + 1))]}"; continue ;; # Ours, the probe knows no -n
        esac
        [ "$i" -gt 0 ] && [ "${args[$((i - 1))]}" = "-n" ] && continue
        keep+=("${args[$i]}")
    done
    args=(${keep[@]+"${keep[@]}"})
    # A slot means a host: the bar strip or the sidebar panel, unless the line says
    case " $shot " in
        *" -H "*) ;;
        *) case "$slot" in
               bar*) args+=(-H bar) ;;
               sidebar*) args+=(-H sidebar) ;;
           esac ;;
    esac
    out="$OUTDIR/$name.png"
    # shellcheck disable=SC2086
    if QS_PROBE_OUT="$out" "$REPO/tests/widget-probe.sh" "$WIDGET" ${slot:+"$slot"} -D -P "$PAD" ${XDIR:+-x "$XDIR"} ${COLORS:+-c "$COLORS"} "${args[@]}" > /dev/null 2>&1; then
        echo "shot ok   $name -> $out"
        MADE+=("$name")
    else
        echo "shot FAIL $name (run widget-probe.sh with the same flags to see why)"
        FAIL=1
    fi
done

[ "${#MADE[@]}" = 0 ] && exit "$FAIL"
echo
echo "Markdown for the README:"
for name in "${MADE[@]}"; do
    echo "![$name]($(basename "$OUTDIR")/$name.png)"
done
exit "$FAIL"
