pragma Singleton
import QtQuick

/** Singleton of an external widget: only resolves because qmldir declares it. */
QtObject {
    readonly property string greeting: "Hello"
    property list<string> unlocks: []
}
