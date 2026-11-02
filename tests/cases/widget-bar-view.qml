//@ probe hello -x tests/fixtures/hello -g 1200x40 -s 1500
/**
 * The barView slot: loaded while the widget is enabled, the built-in bar content
 * hidden only while the view says `active`.
 */
import qs.modules.ii.bar
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    function shown(bar) {
        return bar.children.filter(c => c.visible).length;
    }

    property bool inactive: true
    property int inactiveShown: -1
    property bool active: false
    property int activeShown: -1

    function checks() {
        return [
            {
                "name": "the view is found for the slot",
                "got": WidgetCatalog.viewFor("barView")?.widgetId ?? "",
                "want": "hello"
            },
            {
                "name": "inactive view leaves the built-in bar",
                "got": probe.inactive,
                "want": false
            },
            {
                "name": "an active view hides the three built-in sections",
                "got": probe.inactiveShown - probe.activeShown,
                "want": 2
            },
            {
                "name": "and is drawn itself",
                "got": probe.active,
                "want": true
            },
            {
                "name": "switched back off, the built-in bar returns",
                "got": probe.shown(bar),
                "want": probe.inactiveShown
            }
        ];
    }

    Timer {
        running: true
        interval: 300
        onTriggered: {
            probe.inactive = bar.widgetViewActive;
            probe.inactiveShown = probe.shown(bar);
            WidgetsStore.setOption("hello", "bar", true);
        }
    }

    Timer {
        running: true
        interval: 700
        onTriggered: {
            probe.active = bar.widgetViewActive;
            probe.activeShown = probe.shown(bar);
            WidgetsStore.setOption("hello", "bar", false);
        }
    }

    BarContent {
        id: bar
        anchors.fill: parent
    }
}
