import QtQuick
import qs.modules.widgets

/**
 * The screenOverlay slot for one screen: every enabled widget's file, handed the
 * screen. `anyShown` is what the host maps its window on, so an overlay with
 * nothing to show costs no surface.
 */
Item {
    id: root
    required property var screen

    readonly property bool anyShown: {
        let any = false
        for (let i = 0; i < slot.count; i++)
            any = (slot.itemAt(i)?.item?.shown ?? false) || any
        return any
    }

    WidgetSlot {
        id: slot
        slot: "screenOverlay"
        initialProperties: ({ "screen": root.screen })
    }
}
