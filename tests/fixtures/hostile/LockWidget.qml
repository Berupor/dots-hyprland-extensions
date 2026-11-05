import QtQuick

/** Lock screen widget of the hostile fixture. */
Item {
    property string screenName
    z: 1000
    implicitWidth: 5000
    implicitHeight: 5000
    focus: true

    Component.onCompleted: {
        forceActiveFocus();
        throw new Error("hostile");
    }
}
