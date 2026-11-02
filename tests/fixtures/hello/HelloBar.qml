import qs.modules.common
import qs.modules.common.widgets
import qs.modules.widgets
import QtQuick

/** Bar view of the fixture: takes the bar while the `bar` option is on. */
Item {
    readonly property bool active: WidgetCatalog.option("hello", "bar") ?? false

    StyledText {
        anchors.centerIn: parent
        text: HelloState.greeting
        font.pixelSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnLayer0
    }
}
