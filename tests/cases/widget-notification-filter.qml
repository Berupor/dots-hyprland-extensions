//@ probe hello -x tests/fixtures/hello -g 100x40 -s 1500
/**
 * The notificationFilter slot: drop, silent and keep verdicts, critical never dropped,
 * a throwing filter keeps the notification, a disabled one sees nothing.
 */
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    function note(appName, urgency) {
        return { "appName": appName, "urgency": urgency ?? "normal" };
    }

    function verdict(appName, urgency) {
        return WidgetCatalog.notificationVerdict(probe.note(appName, urgency));
    }

    function checks() {
        WidgetsStore.setEnabled("hello", false);
        const disabled = ["drop", "quiet", "firefox"].map(name => probe.verdict(name));
        WidgetsStore.setEnabled("hello", true);
        const snapshot = WidgetCatalog.notificationSnapshot({
            "appName": "app",
            "appIcon": "icon",
            "summary": "sum",
            "body": "text",
            "image": "img",
            "urgency": 2,
            "hints": { "transient": true },
            "expireTimeout": 5,
            "actions": [{ "identifier": "open", "text": "Open", "extra": 1 }]
        });
        return [
            {
                "name": "the filter is in its slot",
                "got": WidgetCatalog.forSlot("notificationFilter").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "disabled, everything is kept",
                "got": disabled,
                "want": ["keep", "keep", "keep"]
            },
            {
                "name": "enabled, drop, silent and keep",
                "got": ["drop", "quiet", "firefox"].map(name => probe.verdict(name)),
                "want": ["drop", "silent", "keep"]
            },
            {
                "name": "a critical notification is silenced, not dropped",
                "got": [probe.verdict("drop", "critical"), probe.verdict("quiet", "critical")],
                "want": ["silent", "silent"]
            },
            {
                "name": "drop beats silent beats keep, in any order",
                "got": [
                    WidgetCatalog.combineNotificationResults(["silent", false, undefined], "normal"),
                    WidgetCatalog.combineNotificationResults([false, "silent"], "normal"),
                    WidgetCatalog.combineNotificationResults([undefined, "silent", true, "other"], "low"),
                    WidgetCatalog.combineNotificationResults([undefined, "other", true], "low"),
                    WidgetCatalog.combineNotificationResults([false, "silent"], "critical"),
                    WidgetCatalog.combineNotificationResults([], "normal")
                ],
                "want": ["drop", "drop", "silent", "keep", "silent", "keep"]
            },
            {
                "name": "a throwing filter keeps the notification",
                "got": probe.verdict("throw"),
                "want": "keep"
            },
            {
                "name": "snapshot carries the plain fields",
                "got": snapshot,
                "want": {
                    "appName": "app",
                    "appIcon": "icon",
                    "summary": "sum",
                    "body": "text",
                    "image": "img",
                    "urgency": "critical",
                    "isTransient": true,
                    "expireTimeout": 5,
                    "actions": [{ "identifier": "open", "text": "Open" }]
                }
            },
            {
                "name": "snapshot is read-only",
                "got": Object.isFrozen(snapshot) && Object.isFrozen(snapshot.actions),
                "want": true
            },
            {
                "name": "urgency is normalised",
                "got": [0, 1, 2, "Low", "Normal", "Critical", "2", undefined].map(WidgetCatalog.notificationUrgency),
                "want": ["low", "normal", "critical", "low", "normal", "critical", "critical", "normal"]
            },
            {
                "name": "a missing urgency and fields give defaults",
                "got": WidgetCatalog.notificationSnapshot({}),
                "want": {
                    "appName": "",
                    "appIcon": "",
                    "summary": "",
                    "body": "",
                    "image": "",
                    "urgency": "normal",
                    "isTransient": false,
                    "expireTimeout": 0,
                    "actions": []
                }
            }
        ];
    }
}
