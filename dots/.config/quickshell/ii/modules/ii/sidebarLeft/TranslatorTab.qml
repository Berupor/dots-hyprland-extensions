import QtQuick
import qs.modules.widgets

/** Translator tab: a translatorView widget, else the built-in one. */
Item {
    WidgetViewLoader {
        id: widgetView
        anchors.fill: parent
        slot: "translatorView"
    }

    Loader {
        anchors.fill: parent
        active: !widgetView.view
        sourceComponent: Translator {}
    }
}
