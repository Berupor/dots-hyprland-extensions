import QtQuick
import qs.modules.widgets

/** Translator tab: a translatorView widget, else the built-in one. */
Item {
    onActiveFocusChanged: if (activeFocus) (widgetView.item ?? builtin.item)?.forceActiveFocus()

    WidgetViewLoader {
        id: widgetView
        anchors.fill: parent
        slot: "translatorView"
    }

    Loader {
        id: builtin
        anchors.fill: parent
        active: !widgetView.view
        sourceComponent: Translator {}
    }
}
