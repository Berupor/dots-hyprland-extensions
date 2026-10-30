import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.widgets

/**
 * A click-through layer above every window on each screen, for the screenOverlay
 * slot. Mapped only while a widget in it is shown.
 */
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            visible: content.anyShown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.namespace: "quickshell:widgetOverlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WidgetOverlaySlot {
                id: content
                anchors.fill: parent
                screen: window.modelData
            }
        }
    }
}
