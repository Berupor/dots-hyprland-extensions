import QtQuick
import qs.modules.widgets

/** Calendar tab: a calendarView widget, else the built-in grid. */
Item {
    WidgetViewLoader {
        id: widgetView
        anchors.fill: parent
        slot: "calendarView"
    }

    Loader {
        anchors.fill: parent
        active: !widgetView.view
        sourceComponent: CalendarWidget {}
    }
}
