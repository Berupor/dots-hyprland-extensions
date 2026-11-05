#!/usr/bin/env bash
# The Material You contract, checked on any tree of widget files: colors, fonts,
# radii and type sizes come from Appearance, never from a literal, or the palette
# generated off the wallpaper stops reaching the widget and its shapes drift from
# the shell's scale. Radii up to 3 pass: hairlines and thin bars have no token.
# Plus qmllint at syntax level. The rest of the contract is docs/widget-design.md.
#
#   tests/design-lint.sh <dir> [dir ...]
#
# Needs nothing but grep and, if it is around, Qt6's qmllint - so a widget repo
# can run it in CI where rendering is out of reach. See tests/widget-shots.sh for
# the part that does need a session.
set -u

[ "$#" -gt 0 ] || { echo "usage: $0 <dir> [dir ...]"; exit 2; }
FAIL=0

# The qmllint in PATH is Qt5's and dies with 255 and no output on this tree, so
# take the Qt6 one. Only syntax level counts: type warnings on the qs.* imports
# are noise it cannot resolve outside a quickshell config
QMLLINT=$(ls /usr/lib/qt6/bin/qmllint 2> /dev/null || command -v qmllint6 qmllint 2> /dev/null | head -1)
if [ -n "$QMLLINT" ]; then
    while IFS= read -r f; do
        out=$("$QMLLINT" "$f" 2>&1 | grep -E "^Error:|\[syntax")
        [ -n "$out" ] && { echo "qmllint: $f"; echo "$out"; FAIL=1; }
    done < <(find "$@" -name '*.qml' -not -path '*/unsynced/*')
else
    echo "no qmllint, syntax lint skipped"
fi

hex=$(grep -rnE --exclude-dir=unsynced 'color:.*"#[0-9a-fA-F]{3,8}"' "$@" | grep -v transparent)
fonts=$(grep -rn --exclude-dir=unsynced "font.family:" "$@" | grep -v "Appearance\.")
radii=$(grep -rnE --include='*.qml' --exclude-dir=unsynced '^\s*(radius|buttonRadius):\s*[0-9]+(\.[0-9]+)?\s*$' "$@" | grep -vE ':\s*[0-3](\.[0-9]+)?\s*$')
sizes=$(grep -rnE --include='*.qml' --exclude-dir=unsynced '^\s*(font\.pixelSize|iconSize):\s*[0-9]+(\.[0-9]+)?\s*$' "$@")
[ -n "$hex" ] && { echo "design lint, hardcoded colors:"; echo "$hex"; FAIL=1; }
[ -n "$fonts" ] && { echo "design lint, fonts outside Appearance:"; echo "$fonts"; FAIL=1; }
[ -n "$radii" ] && { echo "design lint, radii outside Appearance.rounding:"; echo "$radii"; FAIL=1; }
[ -n "$sizes" ] && { echo "design lint, type and icon sizes outside Appearance.font.pixelSize:"; echo "$sizes"; FAIL=1; }

[ "$FAIL" = 0 ] && echo "PASS design" || echo "FAIL design"
exit "$FAIL"
