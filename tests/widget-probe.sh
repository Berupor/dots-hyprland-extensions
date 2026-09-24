#!/usr/bin/env bash
# Probe one widget slot in a throwaway shell instance: repo files straight from
# the worktree, own config dir, own options. The live shell is untouched, and
# the instance renders into an 8x8 window in a screen corner, so nothing is in
# the way and no clicks or keystrokes are synthesized.
#
#   tests/widget-probe.sh <widget> <slot> [flags]
#   tests/widget-probe.sh [<widget>] -f modules/widgets/foo/Bar.qml [flags]
#
#   -o key=value  widget option for this run (json value, else string)
#   -K key=value  ditto, but a top-level widgets.json key: error report settings
#                 and anything else that is not per-widget. The report target is
#                 blanked for every run, so probes never ship reports anywhere
#   -p prop=value ditto, set on the loaded item after load: hover states,
#                 model stubs, anything the slot exposes
#   -r prop.path  print that property after settling, dotted paths ok
#   -g WxH        item size, default 640x360
#   -s ms         settle time before probing, default 1200
#   -f file.qml   load a path relative to the ii dir, skipping the catalog. Name the
#                 widget too if its polling waits on the catalog switch
#   -b color      backdrop behind the item, default the shell background. Items that
#                 expect a host surface (popup bodies) come out washed out without it
#   -P px         pad the grab by that much, put the item on a Material You
#                 backdrop and render at 2x: for README shots, see widget-shots.sh
#   -H host       draw the host around the item in that mode: `bar` for a bar
#                 strip, `vbar` for the vertical one, `sidebar` for a panel,
#                 empty for a plain surface
#   -c colors.json  render with that palette instead of the one your wallpaper
#                 generated, so a shot looks the same on every machine
#   -D            start from the schema defaults instead of your stored options,
#                 for runs whose output should not depend on this machine
#   -x dir        install a widget dir into the temp config as an external widget,
#                 the way ~/.config/illogical-impulse/widgets/ holds one. Path is
#                 relative to the repo, repeatable, see tests/fixtures/. It goes in
#                 under its manifest id, shadowing a copy you have installed
#   -S name       symlink ~/.config/<name> into the temp config dir, for widgets
#                 whose real state lives outside illogical-impulse (accounts,
#                 tokens). Without it that state reads as empty, which is often
#                 the condition you want to probe
#   -k            keep the temp config dir and print it
#
# Grabbing needs a rendering window, and a hidden one does not render, hence
# the corner. Slots that only exist for some option value need that -o.
# harness.qml lives here but is copied into the ii dir for the run, since
# `import qs.*` resolves against the config root. Named per-PID so parallel
# probes don't share a file or a pkill pattern.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
II="$REPO/dots/.config/quickshell/ii"
HARNESS="$II/.probe-harness.$$.qml" # Copied in for the run, `import qs.*` needs it in the ii root
OUT="${QS_PROBE_OUT:-/tmp/widget-probe.png}"
OPTS='{}'
KEYS='{}'
PROPS='{}'
PROBE='[]'
FILE=""
KEEP=0
IW=640
IH=360
SETTLE=1200
BG=""
PAD=0
CHROME=""
COLORS=""
DEFAULTS=0
FAIL=0

WIDGET=""
SLOT=""
# Positional widget, then an optional slot: `-f` runs may name the widget alone
[ "${1:-}" ] && [ "${1#-}" = "${1:-}" ] && { WIDGET="$1"; shift; }
[ "${1:-}" ] && [ "${1#-}" = "${1:-}" ] && { SLOT="$1"; shift; }
SHARE=()
EXTERNAL=()
while getopts "o:K:p:r:g:s:f:S:b:x:P:H:c:Dk" flag; do
    case "$flag" in
        o) OPTS=$(jq -c --arg k "${OPTARG%%=*}" --arg v "${OPTARG#*=}" '.[$k] = (try ($v|fromjson) catch $v)' <<< "$OPTS") ;;
        K) KEYS=$(jq -c --arg k "${OPTARG%%=*}" --arg v "${OPTARG#*=}" '.[$k] = (try ($v|fromjson) catch $v)' <<< "$KEYS") ;;
        p) PROPS=$(jq -c --arg k "${OPTARG%%=*}" --arg v "${OPTARG#*=}" '.[$k] = (try ($v|fromjson) catch $v)' <<< "$PROPS") ;;
        r) PROBE=$(jq -c --arg p "$OPTARG" '. + [$p]' <<< "$PROBE") ;;
        g) IW=${OPTARG%x*}; IH=${OPTARG#*x} ;;
        s) SETTLE=$OPTARG ;;
        f) FILE=$OPTARG ;;
        S) SHARE+=("$OPTARG") ;;
        x) EXTERNAL+=("$OPTARG") ;;
        b) BG=$OPTARG ;;
        P) PAD=$OPTARG ;;
        H) CHROME=$OPTARG ;;
        c) COLORS=$OPTARG ;;
        D) DEFAULTS=1 ;;
        k) KEEP=1 ;;
    esac
done

[ -n "$FILE" ] && [ "${FILE#/}" = "$FILE" ] && FILE="$II/$FILE" # Absolute, harness wants file://
[ -z "$WIDGET$FILE" ] && { echo "usage: $0 <widget> <slot> | -f <file.qml>  [-o k=v] [-p k=v] [-r path] [-g WxH] [-s ms] [-k]"; exit 2; }

CFG=""
cleanup() {
    rm -f "$HARNESS"
    [ -z "$CFG" ] && return
    [ "$KEEP" = 1 ] && echo "kept: $CFG" || rm -rf "$CFG"
}
trap cleanup EXIT INT TERM

cp "$REPO/tests/harness.qml" "$HARNESS"

# Throwaway config dir seeded from the real one, so theme and colors match but
# nothing we write lands in the live config
CFG=$(mktemp -d /tmp/widget-probe.XXXXXX)
cp -r "$HOME/.config/illogical-impulse" "$CFG/"
jq -c --arg w "$WIDGET" --argjson o "$OPTS" --argjson k "$KEYS" --argjson d "$DEFAULTS" \
    '.errorReports = "never" | .errorReportsTarget = "" | . * $k | .enabled = [$w] | .options[$w] = ((if $d == 1 then {} else (.options[$w] // {}) end) * $o)' \
    "$HOME/.config/illogical-impulse/widgets.json" > "$CFG/illogical-impulse/widgets.json"
for name in ${SHARE[@]+"${SHARE[@]}"}; do
    ln -sfn "$HOME/.config/$name" "$CFG/$name"
done
widget_id() { # Manifest id of a widget dir, its folder name as the fallback
    local id
    id=$(sed -n 's/^[[:space:]]*widgetId:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/Manifest.qml" 2>/dev/null | head -1)
    echo "${id:-$(basename "$1")}"
}
for dir in ${EXTERNAL[@]+"${EXTERNAL[@]}"}; do
    [ "${dir#/}" = "$dir" ] && dir="$REPO/$dir"
    [ -d "$dir" ] || { echo "no such widget dir: $dir"; exit 2; }
    # By id, not by folder name: the seeded config carries the same widget installed,
    # and two manifests with one id leave the catalog on the installed copy
    id=$(widget_id "$dir")
    for seeded in "$CFG"/illogical-impulse/widgets/*/; do
        [ -d "$seeded" ] && [ "$(widget_id "$seeded")" = "$id" ] && rm -rf "${seeded%/}"
    done
    # Not cp: an installed widget is a clone, and git's read-only packs break it
    dest="$CFG/illogical-impulse/widgets/$id"
    mkdir -p "$dest"
    (cd "$dir" && tar --exclude=.git -cf - .) | (cd "$dest" && tar -xf -)
done

# Generated colors live in the state dir, not the config one, so they need their own move
STATE=""
if [ -n "$COLORS" ]; then
    [ "${COLORS#/}" = "$COLORS" ] && COLORS="$REPO/$COLORS"
    [ -f "$COLORS" ] || { echo "no such palette: $COLORS"; exit 2; }
    STATE="$CFG/state"
    mkdir -p "$STATE/quickshell/user/generated"
    cp "$COLORS" "$STATE/quickshell/user/generated/colors.json"
fi

SCALE=""
[ "$PAD" -gt 0 ] && SCALE="export QT_SCALE_FACTOR=2 # A shot is rendered at 2x, not upscaled after"

LOG="$CFG/probe.log"
rm -f "$OUT"
cat > "$CFG/run.sh" <<EOF
#!/usr/bin/env bash
export XDG_CONFIG_HOME="$CFG"
export XDG_CACHE_HOME="$CFG/cache" # A run that caches must not read the last one's, nor the user's
${STATE:+export XDG_STATE_HOME="$STATE"}
$SCALE
export QS_HARNESS_WIDGET="$WIDGET" QS_HARNESS_SLOT="$SLOT" QS_HARNESS_FILE="$FILE"
export QS_HARNESS_OUT="$OUT" QS_HARNESS_SETTLE="$SETTLE"
export QS_HARNESS_IW="$IW" QS_HARNESS_IH="$IH" QS_HARNESS_W=8 QS_HARNESS_H=8
export QS_HARNESS_PROPS='$PROPS' QS_HARNESS_PROBE='$PROBE' QS_HARNESS_BG="$BG" QS_HARNESS_PAD="$PAD" QS_HARNESS_CHROME="$CHROME"
exec timeout 40 qs -p "$HARNESS"
EOF
chmod +x "$CFG/run.sh"

echo "probe ${WIDGET:-$FILE}${SLOT:+/$SLOT}  options $(jq -c --arg w "$WIDGET" '.options[$w] // {}' "$CFG/illogical-impulse/widgets.json")${PROPS#\{\}}"

RULES="float;size 8 8;move 100%-8 100%-8;noanim;noborder;noshadow"
# noinitialfocus alone doesn't stop misc:focus_on_activate, hyprwm/Hyprland#12357
command -v hyprctl > /dev/null && hyprctl eval 'if not _G.__widget_probe_norule then hl.window_rule({match = {title = "^(qs-harness)$"}, no_initial_focus = true, focus_on_activate = false}); _G.__widget_probe_norule = true end' > /dev/null
if command -v hyprctl > /dev/null && hyprctl dispatch "hl.dsp.exec_cmd(\"[$RULES] $CFG/run.sh > $LOG 2>&1\")" > /dev/null; then
    : # Spawned out of the way, keeps focus and the current workspace as they are
else
    "$CFG/run.sh" > "$LOG" 2>&1 &
fi

for _ in $(seq 80); do
    grep -q "\[harness\] done" "$LOG" 2>/dev/null && break
    sleep 0.5
done
pkill -f "qs -p $HARNESS"

# Quickshell keeps a log directory per instance and never sweeps it, and a probe
# run leaves 4MB behind: a few hundred of them fill $XDG_RUNTIME_DIR
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
INSTANCE=$(sed -nE 's|.*Saving logs to "(.*)/log\.qslog".*|\1|p' "$LOG" 2>/dev/null | head -1)
case "$INSTANCE" in "$RUNTIME"/*) rm -rf "$INSTANCE";; esac # Ours only, it is an rm -rf
find "$RUNTIME" -maxdepth 2 -xtype l -delete 2>/dev/null

grep -E "\[harness\]|WARN|ERROR" "$LOG" 2>/dev/null |
    grep -vE "Saving logs|Shell ID|Launching config|translations/.*failed" |
    sed -E 's/\x1b\[[0-9;]*m//g; s/^ *(DEBUG|WARN|ERROR)[^:]*: *//; s/\[harness\] //'
grep -q "\[harness\] FAIL" "$LOG" 2>/dev/null && FAIL=1
[ -f "$OUT" ] && echo "png: $OUT" || FAIL=1
exit "$FAIL"
