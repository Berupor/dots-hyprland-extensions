//@ probe hello -x tests/fixtures/hello -g 100x40 -s 4000
/**
 * The unlockHook slot: the accepted password reaches each hook allowed for its current
 * code once, a fingerprint unlock hands nothing, switching on is not consent, and a hook
 * whose code changed after the grant gets nothing and loses it. Code is any file in the
 * widget dir, a script the hook hands the password to included.
 */
import qs.modules.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell.Io

Item {
    id: probe

    readonly property var manifest: WidgetCatalog.widgets.find(w => w.widgetId === "hello") ?? null
    readonly property var card: cardLoader.item
    property var log: ({})
    property int step: 0

    function unlocks() {
        return Array.from(loader.item?.unlocks ?? ["no item"]);
    }

    function allowed() {
        return WidgetCatalog.unlockHookAllowed("hello");
    }

    /// Hooks run once the hash is back, so each step reads what the one before it caused
    readonly property var steps: [
        () => {
            WidgetsStore.setEnabled("hello", true);
            probe.log.afterEnable = [probe.card.unlockHookBlocked, probe.card.statusText, probe.allowed()];
            WidgetCatalog.runUnlockHooks("before-consent");
        },
        () => {
            probe.log.withoutConsent = probe.unlocks();
            probe.card.setUnlockHookGrant(true);
            probe.log.afterGrant = [probe.card.unlockHookGranted, WidgetsStore.data.unlockHookHashes?.hello === probe.card.hookHash];
            WidgetCatalog.runUnlockHooks("");
        },
        () => {
            probe.log.afterFingerprint = probe.unlocks();
            WidgetCatalog.runUnlockHooks("hunter2");
        },
        () => {
            probe.log.afterPassword = probe.unlocks();
            WidgetsStore.setKey("unlockHookHashes", { "hello": "hash-of-the-old-code" }); // As if an update swapped the code
            probe.log.staleInCard = [probe.card.unlockHookGranted, probe.card.unlockHookBlocked];
            WidgetCatalog.runUnlockHooks("stale-code");
        },
        () => {
            probe.log.afterStale = [probe.unlocks(), probe.allowed(), WidgetsStore.data.unlockHookHashes?.hello ?? null];
            probe.card.setUnlockHookGrant(true);
            WidgetCatalog.runUnlockHooks("regranted");
        },
        () => {
            probe.log.afterRegrant = probe.unlocks();
            WidgetsStore.setEnabled("hello", false);
            WidgetsStore.setEnabled("hello", true);
            WidgetCatalog.runUnlockHooks("after-reenable");
        },
        () => {
            probe.log.afterReenable = [probe.unlocks(), probe.allowed()];
            probe.addFile("helper.py");
        },
        () => WidgetCatalog.codeHash(probe.manifest, hash => probe.log.withScript = hash),
        () => probe.addFile("__pycache__/helper.cpython-313.pyc"),
        () => WidgetCatalog.codeHash(probe.manifest, hash => probe.log.withBytecode = hash)
    ]

    /// Into the probe's copy of the fixture, not the repo
    function addFile(name) {
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1/$2")" && echo changed > "$1/$2"', "_", FileUtils.trimFileProtocol(String(probe.manifest.dir)), name];
        writer.running = true;
    }

    Process {
        id: writer
    }

    function checks() {
        return [
            {
                "name": "the hook's code hash is a sha256",
                "got": /^[0-9a-f]{64}$/.test(probe.card?.hookHash ?? ""),
                "want": true
            },
            {
                "name": "the hook is in its slot",
                "got": WidgetCatalog.forSlot("unlockHook").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "switching on is not consent: asked for, nothing allowed",
                "got": probe.log.afterEnable,
                "want": [true, "Wants your login password: allow it inside", false]
            },
            {
                "name": "enabled without allowing the hook, no call",
                "got": probe.log.withoutConsent,
                "want": []
            },
            {
                "name": "the grant in the card is allowed and tied to the code",
                "got": probe.log.afterGrant,
                "want": [true, true]
            },
            {
                "name": "no password, no call",
                "got": probe.log.afterFingerprint,
                "want": []
            },
            {
                "name": "the password reaches the hook allowed for its code, once",
                "got": probe.log.afterPassword,
                "want": ["hunter2"]
            },
            {
                "name": "a card shows a changed hook as not granted",
                "got": probe.log.staleInCard,
                "want": [false, true]
            },
            {
                "name": "a changed hook gets no password and loses the grant",
                "got": probe.log.afterStale,
                "want": [["hunter2"], false, null]
            },
            {
                "name": "allowing it again delivers to the current code",
                "got": probe.log.afterRegrant,
                "want": ["hunter2", "regranted"]
            },
            {
                "name": "switching off and on drops the permission",
                "got": probe.log.afterReenable,
                "want": [["hunter2", "regranted"], false]
            },
            {
                "name": "a script added next to the hook changes the code hash",
                "got": /^[0-9a-f]{64}$/.test(probe.log.withScript ?? "") && probe.log.withScript !== probe.card?.hookHash,
                "want": true
            },
            {
                "name": "a bytecode cache does not",
                "got": probe.log.withBytecode === probe.log.withScript,
                "want": true
            }
        ];
    }

    Timer {
        running: true
        repeat: true
        interval: 200
        onTriggered: {
            if (probe.card?.hookHash && probe.step < probe.steps.length)
                probe.steps[probe.step++]();
        }
    }

    Loader { // The catalog scans after the scene is up
        id: cardLoader
        active: probe.manifest !== null
        sourceComponent: WidgetCard {
            visible: false
            manifest: probe.manifest
        }
    }

    Loader {
        id: loader
        source: probe.manifest ? probe.manifest.resolve(probe.manifest.slotPath("barIndicator")) : ""
    }
}
