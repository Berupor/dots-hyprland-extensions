#!/usr/bin/env bash
# README shot of the settings app itself: the real window with its nav rail and
# titlebar, not a page torn out of it. Runs off a throwaway copy of the tree, so
# the catalog holds a few widgets instead of every one installed here, and off a
# throwaway config, so the palette is the same one the widget shots use.
#
#   tests/settings-shot.sh [-b] [out.png]
#
#   -b   open the Browse card, for the shot of the registry. Nothing here clicks,
#        so the card is opened by a patch to the copy
#
# Unlike widget-probe.sh this one does put a window on your screen for a few
# seconds: grabbing window chrome needs a window, and grim grabs from the screen.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BROWSE=0
[ "${1:-}" = "-b" ] && { BROWSE=1; shift; }
[ "$BROWSE" = 1 ] && NAME=widgets-registry || NAME=widgets-page
OUT="${1:-$REPO/.github/assets/$NAME.png}"
EXTERNAL="androidWebcam hello kdeconnect peripheralBattery statusphere vpn" # Installed widgets left in the catalog
# The Browse card lists what the registry knows and the catalog does not, so that shot
# leaves two of them uninstalled instead of depending on what this machine happens to have
[ "$BROWSE" = 1 ] && EXTERNAL="androidWebcam hello kdeconnect vpn"
ENABLED='["peripheralBattery","vpn"]'
PAGE=5                                       # Widgets, see the pages list in settings.qml
SCALE=1.5                                    # Bigger than 1 for a crisp png, small enough to fit the screen
W=1650
H=1050
[ "$BROWSE" = 1 ] && H=1290                  # The open card needs the room

command -v grim > /dev/null || { echo "no grim"; exit 2; }
command -v hyprctl > /dev/null || { echo "no hyprctl, this one needs the compositor"; exit 2; }

TMP=$(mktemp -d /tmp/settings-shot.XXXXXX)
trap 'rm -rf "$TMP"' EXIT INT TERM

cp -r "$REPO/dots/.config/quickshell/ii" "$TMP/ii"
sed -i "s/property int currentPage: 0/property int currentPage: $PAGE/" "$TMP/ii/settings.qml"
# The page loader starts on pages[0] and only follows currentPage when it changes
sed -i "s/source = root.pages\[0\].component/source = root.pages[$PAGE].component/" "$TMP/ii/settings.qml"
sed -i "s/QT_SCALE_FACTOR=1$/QT_SCALE_FACTOR=$SCALE/" "$TMP/ii/settings.qml"
[ "$BROWSE" = 1 ] && sed -i "s/^            expanded: root.catalogEmpty.*/            expanded: true/" \
    "$TMP/ii/modules/widgets/WidgetCatalogView.qml"

mkdir -p "$TMP/config" "$TMP/state/quickshell/user/generated"
cp -r "$HOME/.config/illogical-impulse" "$TMP/config/"
cp "$REPO/tests/shot-colors.json" "$TMP/state/quickshell/user/generated/colors.json"
jq -c --argjson e "$ENABLED" '.errorReports = "never" | .errorReportsTarget = "" | .enabled = $e' \
    "$HOME/.config/illogical-impulse/widgets.json" > "$TMP/config/illogical-impulse/widgets.json"
jq -c '.appearance.transparency.enable = false' "$HOME/.config/illogical-impulse/config.json" \
    > "$TMP/config/illogical-impulse/config.json"
for dir in "$TMP"/config/illogical-impulse/widgets/*/; do
    [ -d "$dir" ] || continue
    case " $EXTERNAL " in *" $(basename "$dir") "*) ;; *) rm -rf "${dir%/}" ;; esac
done

cat > "$TMP/run.sh" <<EOF
#!/usr/bin/env bash
export XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/state"
exec timeout 60 qs -p "$TMP/ii/settings.qml"
EOF
chmod +x "$TMP/run.sh"

# Fixed size and no rounding: grim takes it off the screen, so a rounded corner
# would come out as whatever is behind the window
RULES="float;size $W $H;move 40 40;noinitialfocus;noanim;noborder;noshadow;rounding 0;opaque"
hyprctl dispatch "hl.dsp.exec_cmd(\"[$RULES] $TMP/run.sh\")" > /dev/null

GEO=""
for _ in $(seq 40); do
    # By size too: a settings window you already have open answers to the title as well
    GEO=$(hyprctl clients -j | jq -r --argjson w "$W" --argjson h "$H" '.[] | select(.title == "illogical-impulse Settings" and .size[0] == $w and .size[1] == $h) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | head -1)
    [ -n "$GEO" ] && break
    sleep 0.5
done
[ -n "$GEO" ] || { echo "the settings window never showed up"; exit 1; }

sleep 2 # Cards animate in, and the theme lands a frame late
grim -g "$GEO" "$OUT" && echo "shot ok -> $OUT"
pkill -f "qs -p $TMP/ii/settings.qml"
