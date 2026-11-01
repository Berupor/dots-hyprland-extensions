import qs.modules.common
import qs.modules.common.widgets
import qs.modules.widgets
import QtQuick
import QtQuick.Layouts

/** Bar indicator of the fixture: both orientations, sibling type, own singleton, one option. */
Item {
    id: root

    property bool shown: true
    property bool vertical: false
    readonly property bool badge: WidgetCatalog.option("hello", "badge") ?? false
    readonly property string greeting: HelloState.greeting
    readonly property list<string> unlocks: HelloState.unlocks
    readonly property int services: HelloState.services
    readonly property real barThickness: root.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    implicitWidth: root.vertical ? root.barThickness : layout.implicitWidth
    implicitHeight: root.vertical ? layout.implicitHeight : root.barThickness

    GridLayout {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        columnSpacing: 4
        rowSpacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "waving_hand"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.vertical ? root.barThickness - 8 : -1
            elide: Text.ElideRight
            text: root.greeting
            font.pixelSize: root.vertical ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }

        HelloBadge {
            Layout.alignment: Qt.AlignHCenter
            visible: root.badge
        }
    }
}
