//@ probe hello -x tests/fixtures/hello -g 100x40 -s 2000
/**
 * WidgetCatalog.showOsd through the bridge into a stub OSD, and the indicator without a value.
 */
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    QtObject {
        id: stub
        property var indicators: [{ "id": "volume", "sourceUrl": "v.qml" }]
        property string currentIndicator: "volume"
        property string protectionMessage: "protected"
        property int triggered: 0
        function triggerOsd() {
            stub.triggered++;
        }
    }

    WidgetOsdBridge { osd: stub }

    WidgetOsdIndicator {
        id: indicator
    }

    property var shown: ({})
    property var ignored: ({})
    property var twice: ({})
    property var withValue: ({})
    property var withoutValue: ({})

    function snapshot() {
        return {
            "osd": WidgetCatalog.osd,
            "current": stub.currentIndicator,
            "triggered": stub.triggered,
            "protection": stub.protectionMessage,
            "widgetEntries": stub.indicators.filter(i => i.id === "widget").length
        };
    }

    function run() {
        const spec = { "icon": "bolt", "text": "Charge", "value": 0.4 };
        WidgetCatalog.showOsd("hello", spec);
        probe.shown = probe.snapshot();
        probe.withValue = { "shown": indicator.valueShown, "showValue": indicator.showValue };

        WidgetCatalog.showOsd("hello", { "text": "no icon" });
        const noIcon = probe.snapshot();
        WidgetsStore.setEnabled("hello", false);
        WidgetCatalog.showOsd("hello", { "icon": "close", "text": "off" });
        const off = probe.snapshot();
        WidgetsStore.setEnabled("hello", true);
        probe.ignored = { "noIcon": noIcon, "off": off };

        stub.triggered = 0;
        WidgetCatalog.showOsd("hello", { "icon": "a", "text": "first", "value": 0.1 });
        WidgetCatalog.showOsd("hello", { "icon": "b", "text": "second" });
        probe.twice = probe.snapshot();
        probe.withoutValue = { "shown": indicator.valueShown, "showValue": indicator.showValue };
    }

    function checks() {
        return [
            {
                "name": "a call sets the osd to its spec",
                "got": probe.shown.osd,
                "want": { "widgetId": "hello", "icon": "bolt", "text": "Charge", "value": 0.4 }
            },
            {
                "name": "the stub shows the widget indicator",
                "got": probe.shown.current,
                "want": "widget"
            },
            {
                "name": "triggered once",
                "got": probe.shown.triggered,
                "want": 1
            },
            {
                "name": "protection message cleared",
                "got": probe.shown.protection,
                "want": ""
            },
            {
                "name": "one widget entry in indicators",
                "got": probe.shown.widgetEntries,
                "want": 1
            },
            {
                "name": "the volume entry stays",
                "got": stub.indicators[0].id,
                "want": "volume"
            },
            {
                "name": "no icon, nothing happens",
                "got": [probe.ignored.noIcon.triggered, probe.ignored.noIcon.osd.icon],
                "want": [1, "bolt"]
            },
            {
                "name": "disabled widget, nothing happens",
                "got": [probe.ignored.off.triggered, probe.ignored.off.osd.icon],
                "want": [1, "bolt"]
            },
            {
                "name": "two calls, the last wins",
                "got": [probe.twice.osd.text, probe.twice.osd.value],
                "want": ["second", null]
            },
            {
                "name": "two calls, two triggers",
                "got": probe.twice.triggered,
                "want": 2
            },
            {
                "name": "with a value the bar and the number are shown",
                "got": probe.withValue,
                "want": { "shown": true, "showValue": true }
            },
            {
                "name": "without a value the bar and the number are hidden",
                "got": probe.withoutValue,
                "want": { "shown": false, "showValue": false }
            }
        ];
    }

    Timer {
        running: true
        interval: 500
        onTriggered: probe.run()
    }
}
