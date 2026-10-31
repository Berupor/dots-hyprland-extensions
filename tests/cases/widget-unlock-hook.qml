//@ probe hello -x tests/fixtures/hello -g 100x40 -s 1500
/**
 * The unlockHook slot: the accepted password reaches each allowed hook once, a
 * fingerprint unlock hands nothing, and a widget enabled before it had the slot
 * gets nothing until switched on again.
 */
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    readonly property var manifest: WidgetCatalog.widgets.find(w => w.widgetId === "hello") ?? null

    function unlocks() {
        return Array.from(loader.item?.unlocks ?? ["no item"]);
    }

    function checks() {
        WidgetCatalog.runUnlockHooks("before-consent");
        const withoutConsent = probe.unlocks();
        WidgetsStore.setEnabled("hello", true, true);
        WidgetCatalog.runUnlockHooks("");
        const afterFingerprint = probe.unlocks();
        WidgetCatalog.runUnlockHooks("hunter2");
        const afterPassword = probe.unlocks();
        WidgetsStore.setEnabled("hello", false);
        WidgetsStore.setEnabled("hello", true);
        WidgetCatalog.runUnlockHooks("after-reenable-without-slot");
        return [
            {
                "name": "the hook is in its slot",
                "got": WidgetCatalog.forSlot("unlockHook").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "enabled without allowing the hook, no call",
                "got": withoutConsent,
                "want": []
            },
            {
                "name": "no password, no call",
                "got": afterFingerprint,
                "want": []
            },
            {
                "name": "the password reaches the allowed hook, once",
                "got": afterPassword,
                "want": ["hunter2"]
            },
            {
                "name": "switching off drops the permission",
                "got": probe.unlocks(),
                "want": ["hunter2"]
            }
        ];
    }

    Loader {
        id: loader
        source: probe.manifest ? probe.manifest.resolve(probe.manifest.slotPath("barIndicator")) : ""
    }
}
