import QtQuick

/** Service of the fixture: counts how many of it are alive. */
QtObject {
    Component.onCompleted: HelloState.services += 1
    Component.onDestruction: HelloState.services -= 1
}
