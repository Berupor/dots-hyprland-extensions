//@ probe hello -x tests/fixtures/hello -x tests/fixtures/hostile -g 400x300 -s 4000
/**
 * The lockWidget slot: only widgets allowed for their current code draw, boxed in at the
 * top with no input, and one that grabs focus, outgrows its box or throws can't reach the
 * password field or the widgets next to it.
 */
import qs
import qs.modules.widgets
import QtQuick

Item {
    id: probe
    width: 400
    height: 300

    readonly property var hello: WidgetCatalog.widgets.find(w => w.widgetId === "hello") ?? null
    readonly property var hostile: WidgetCatalog.widgets.find(w => w.widgetId === "hostile") ?? null
    property var hashes: ({})
    property var log: ({})
    property int step: 0

    function loaders() {
        return area.children[0].children.filter(c => c.modelData !== undefined);
    }

    function loaderOf(id) {
        return probe.loaders().find(l => l.modelData.widgetId === id) ?? null;
    }

    function relock() {
        GlobalStates.screenLocked = false;
        GlobalStates.screenLocked = true;
    }

    readonly property var steps: [
        () => {
            field.forceActiveFocus(); // Not on completion: the item is not in the window yet
            WidgetsStore.setEnabled("hostile", true);
            WidgetCatalog.codeHash(probe.hello, h => probe.hashes.hello = h);
            WidgetCatalog.codeHash(probe.hostile, h => probe.hashes.hostile = h);
            probe.relock();
        },
        () => {
            probe.log.ungranted = probe.loaders().length;
            WidgetCatalog.setGrant("lockWidget", "hello", probe.hashes.hello);
            probe.relock();
        },
        () => {
            const item = probe.loaderOf("hello")?.item;
            probe.log.granted = [probe.loaders().length, item?.screenName ?? null];
            WidgetCatalog.setGrant("lockWidget", "hostile", probe.hashes.hostile);
            probe.relock();
        },
        () => {
            probe.log.hostile = {
                "count": probe.loaders().length,
                "helloReady": probe.loaderOf("hello")?.status === Loader.Ready,
                "hostileActiveFocus": probe.loaderOf("hostile")?.item?.activeFocus ?? null,
                "fieldActiveFocus": field.activeFocus,
                "focusItem": probe.Window.activeFocusItem === field,
                "width": area.width,
                "bottom": area.y + area.height
            };
            WidgetCatalog.setGrant("lockWidget", "hello", "hash-of-the-old-code"); // As if an update swapped the code
            probe.relock();
        },
        () => {
            probe.log.changed = [probe.loaders().map(l => l.modelData.widgetId), WidgetCatalog.grantFor("lockWidget", "hello")];
        }
    ]

    function checks() {
        return [
            {
                "name": "a bare path is a valid lockWidget entry",
                "got": WidgetCatalog.slotProblems(probe.hello),
                "want": []
            },
            {
                "name": "enabled is not granted: nothing on the lock screen",
                "got": probe.log.ungranted,
                "want": 0
            },
            {
                "name": "granted for its code, it draws and gets the screen name",
                "got": probe.log.granted,
                "want": [1, area.screenName]
            },
            {
                "name": "the screen name is a real one",
                "got": area.screenName !== "",
                "want": true
            },
            {
                "name": "the area takes no input",
                "got": area.enabled,
                "want": false
            },
            {
                "name": "a widget grabbing focus leaves it on the password field",
                "got": [probe.log.hostile?.hostileActiveFocus, probe.log.hostile?.fieldActiveFocus, probe.log.hostile?.focusItem],
                "want": [false, true, true]
            },
            {
                "name": "a widget throwing next to it leaves the other loaded",
                "got": [probe.log.hostile?.count, probe.log.hostile?.helloReady],
                "want": [2, true]
            },
            {
                "name": "a 5000 px widget is capped at 360 and clipped",
                "got": [probe.log.hostile?.width, area.clip],
                "want": [360, true]
            },
            {
                "name": "a 5000 px tall widget stays clear of the password row",
                "got": (probe.log.hostile?.bottom ?? 1e9) <= passwordRow.y,
                "want": true
            },
            {
                "name": "a changed widget draws nothing and loses the grant",
                "got": probe.log.changed,
                "want": [["hostile"], ""]
            }
        ];
    }

    Timer {
        running: true
        repeat: true
        interval: 300
        onTriggered: {
            if (probe.hello && probe.hostile && probe.step < probe.steps.length)
                probe.steps[probe.step++]();
        }
    }

    // Stand-in for the lock surface: a password row at the bottom, the area on top
    Item {
        id: passwordRow
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 200
        height: 40

        TextInput {
            id: field
            anchors.fill: parent
        }
    }

    WidgetLockArea {
        id: area
    }
}
