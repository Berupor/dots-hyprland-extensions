//@ probe hello -x tests/fixtures/hello -g 100x40 -s 1500
/**
 * The service slot: one object while the widget is enabled, none after it is
 * switched off, one again after it is switched back on.
 */
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    readonly property var manifest: WidgetCatalog.widgets.find(w => w.widgetId === "hello") ?? null

    function services() {
        return loader.item?.services ?? -1;
    }

    property int enabled: -1
    property int disabled: -1

    function checks() {
        return [
            {
                "name": "the service is in its slot",
                "got": WidgetCatalog.forSlot("service").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "enabled, one service",
                "got": probe.enabled,
                "want": 1
            },
            {
                "name": "switched off, none",
                "got": probe.disabled,
                "want": 0
            },
            {
                "name": "switched on again, one",
                "got": probe.services(),
                "want": 1
            }
        ];
    }

    Timer { // A switched-off service is destroyed later in the event loop, not on the spot
        running: true
        interval: 300
        onTriggered: {
            probe.enabled = probe.services();
            WidgetsStore.setEnabled("hello", false);
        }
    }

    Timer {
        running: true
        interval: 700
        onTriggered: {
            probe.disabled = probe.services();
            WidgetsStore.setEnabled("hello", true);
        }
    }

    Loader {
        id: loader
        source: probe.manifest ? probe.manifest.resolve(probe.manifest.slotPath("barIndicator")) : ""
    }
}
