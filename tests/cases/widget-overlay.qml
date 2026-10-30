//@ probe hello -x tests/fixtures/hello -g 320x120 -s 1500
/**
 * The screenOverlay slot: one item per widget, handed the screen, and the host's
 * window mapped only while one of them is shown.
 */
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    readonly property var fakeScreen: ({ "name": "DP-9", "width": 300, "height": 100 })
    readonly property var overlay: slot.children.find(c => c.item)?.item ?? null

    function checks() {
        const before = slot.anyShown;
        if (probe.overlay)
            probe.overlay.shown = true;
        const after = slot.anyShown;
        return [
            {
                "name": "the widget loads into the overlay",
                "got": !!probe.overlay,
                "want": true
            },
            {
                "name": "it is handed the screen",
                "got": probe.overlay?.screen?.name ?? "",
                "want": "DP-9"
            },
            {
                "name": "and sizes itself to it",
                "got": probe.overlay?.width ?? 0,
                "want": 300
            },
            {
                "name": "nothing shown, nothing to map",
                "got": before,
                "want": false
            },
            {
                "name": "a shown item maps the window",
                "got": after,
                "want": true
            }
        ];
    }

    WidgetOverlaySlot {
        id: slot
        anchors.fill: parent
        screen: probe.fakeScreen
    }
}
