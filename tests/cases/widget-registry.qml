//@ probe hello -x tests/fixtures/hello -g 560x120 -s 8000
/**
 * The registry against a local index.json served over file://, so the case needs
 * no network: parsing, what the page lists, the cache and its fallback.
 */
import qs.modules.common
import qs.modules.widgets
import Quickshell.Io
import QtQuick

Item {
    id: probe

    readonly property string indexPath: `${Directories.shellConfig}/registry/index.json`
    property var seen: ({}) // The singleton is overwritten each step, so snapshot as they land
    property int step: 0

    /// hello is installed by the probe, futureThing asks for a contract we do not
    /// have, and the last one has no id to install as
    function indexJson(extra) {
        const widgets = [
            {
                "id": "hello",
                "name": "Hello",
                "url": "https://example.invalid/hello",
                "minShellVersion": "1.0"
            },
            {
                "id": "coffeeTimer",
                "name": "Coffee timer",
                "description": "Tells you when the brew is done",
                "icon": "coffee",
                "author": "t",
                "url": "https://example.invalid/coffee",
                "minShellVersion": "1.0",
                "dependencies": ["upower"],
                "tags": ["hardware"]
            },
            {
                "id": "futureThing",
                "name": "Future",
                "url": "https://example.invalid/future",
                "minShellVersion": "1.99"
            },
            {
                "name": "No id at all",
                "url": "https://example.invalid/nameless"
            }
        ];
        if (extra)
            widgets.push({
                "id": "extra",
                "name": "Extra",
                "url": "https://example.invalid/extra",
                "minShellVersion": "1.0"
            });
        return JSON.stringify({
            "formatVersion": 1,
            "widgets": widgets
        });
    }

    function checks() {
        return [
            {
                "name": "an entry without the fields to install by is dropped",
                "got": probe.seen.entries ?? 0,
                "want": 3
            },
            {
                "name": "defaults fill in for what an entry leaves out",
                "got": [probe.seen.icon ?? "", probe.seen.deps ?? null],
                "want": ["widgets", []]
            },
            {
                "name": "installed and future entries stay out of the list",
                "got": [probe.seen.listed ?? [], probe.seen.unsupported ?? 0],
                "want": [["coffeeTimer"], 1]
            },
            {
                "name": "a fresh cache answers instead of the source",
                "got": probe.seen.cached ?? 0,
                "want": 3
            },
            {
                "name": "refresh goes back to the source",
                "got": probe.seen.refreshed ?? 0,
                "want": 4
            },
            {
                "name": "a fetch that fails falls back to the cache and says so",
                "got": [probe.seen.offline ?? 0, probe.seen.offlineStale ?? false],
                "want": [4, true]
            },
            {
                "name": "what is not an index parses to nothing",
                "got": [WidgetRegistry.parse("not json"), WidgetRegistry.parse('{"widgets":"soon"}'), WidgetRegistry.parse('{"widgets":[]}')],
                "want": [null, null, []]
            },
            {
                "name": "an install from the list reports to its own row, not to the url field",
                "got": [probe.seen.job ?? "", probe.seen.jobMessage ?? ""],
                "want": ["coffeeTimer", "Enter a repository url"]
            }
        ];
    }

    // Env, not a heredoc: the json carries quotes and goes through no shell parsing
    Process {
        id: writeIndex
        property bool extra: false
        property bool thenForce: false
        command: ["env", `RB=${probe.indexJson(extra)}`, `RP=${probe.indexPath}`, "bash", "-c", `
            mkdir -p "$(dirname "$RP")"
            printf '%s' "$RB" > "$RP"`]
        onExited: {
            WidgetRegistry.url = `file://${probe.indexPath}`;
            WidgetRegistry.load(thenForce);
        }
    }

    Connections {
        target: WidgetRegistry
        function onStateChanged() {
            if (WidgetRegistry.busy)
                return;
            const snap = {};
            switch (probe.step) {
            case 0:
                snap.entries = WidgetRegistry.entries.length;
                snap.icon = WidgetRegistry.entries.find(e => e.id === "futureThing")?.icon ?? "";
                snap.deps = WidgetRegistry.entries.find(e => e.id === "futureThing")?.dependencies ?? null;
                snap.listed = WidgetRegistry.listed.map(e => e.id);
                snap.unsupported = WidgetRegistry.unsupported;
                break;
            case 1:
                snap.cached = WidgetRegistry.entries.length;
                break;
            case 2:
                snap.refreshed = WidgetRegistry.entries.length;
                break;
            case 3:
                snap.offline = WidgetRegistry.entries.length;
                snap.offlineStale = WidgetRegistry.stale;
                // The url field is the empty job, a listed widget is its own
                WidgetInstaller.install("", "coffeeTimer");
                snap.job = WidgetInstaller.job;
                snap.jobMessage = WidgetInstaller.message;
                break;
            }
            probe.seen = Object.assign({}, probe.seen, snap);
            probe.step++;
            advance.restart();
        }
    }

    Timer {
        id: advance
        interval: 200
        onTriggered: {
            switch (probe.step) {
            case 1: // Source grows, but the cache written a moment ago is still good
                writeIndex.extra = true;
                writeIndex.thenForce = false;
                writeIndex.running = true;
                break;
            case 2:
                WidgetRegistry.load(true);
                break;
            case 3: // Nothing to fetch from, so the cache has to answer
                WidgetRegistry.url = `file://${probe.indexPath}.gone`;
                WidgetRegistry.load(true);
                break;
            }
        }
    }

    Component.onCompleted: writeIndex.running = true
}
