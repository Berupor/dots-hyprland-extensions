import QtQuick

/** Screen overlay of the fixture: hidden until told, sized to the screen it was handed. */
Item {
    id: root

    required property var screen
    property bool shown: false
    width: root.screen.width
    height: root.screen.height
}
