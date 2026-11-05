import qs.modules.widgets
import QtQuick
import Quickshell

/**
 * Shows WidgetCatalog.showOsd requests in the built-in OSD.
 */
Scope {
    id: root
    required property var osd

    Component.onCompleted: root.osd.indicators = root.osd.indicators.concat([{
        id: "widget",
        sourceUrl: Qt.resolvedUrl("WidgetOsdIndicator.qml")
    }])

    Connections {
        target: WidgetCatalog
        function onOsdRequested() {
            root.osd.protectionMessage = "";
            root.osd.currentIndicator = "widget";
            root.osd.triggerOsd();
        }
    }
}
