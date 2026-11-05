pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.modules.widgets

/**
 * The lockWidget slot on one lock screen: granted widgets only, no input, boxed in at the top.
 */
FocusScope {
    id: root
    property string screenName: Screen.name
    readonly property real maxHeight: Math.min(160, 0.3 * (parent?.height ?? 0))

    anchors.top: parent?.top
    anchors.topMargin: 20
    anchors.horizontalCenter: parent?.horizontalCenter
    width: Math.min(360, column.implicitWidth)
    height: Math.min(root.maxHeight, column.implicitHeight)
    enabled: false
    clip: true

    // A widget's forceActiveFocus walks up through this scope even under enabled: false
    property Item focusBefore: null
    onFocusChanged: if (root.focus) Qt.callLater(root.giveFocusBack) // Not mid-way through the steal
    function giveFocusBack() {
        root.focus = false;
        root.focusBefore?.forceActiveFocus();
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            if (!root.focus)
                root.focusBefore = root.Window.activeFocusItem;
        }
    }

    Column {
        id: column
        width: root.width
        spacing: 8

        Repeater {
            model: WidgetCatalog.forSlot("lockWidget").filter(w => WidgetCatalog.lockWidgetsVerified.includes(w.widgetId))
            delegate: Loader {
                required property var modelData
                anchors.horizontalCenter: parent?.horizontalCenter
                visible: item?.shown ?? true
                Component.onCompleted: setSource(modelData.resolve(modelData.slotPath("lockWidget")), { "screenName": root.screenName })
                onStatusChanged: if (status === Loader.Error) ErrorReporter.report(modelData.widgetId, `${source} failed to load`)
            }
        }
    }
}
