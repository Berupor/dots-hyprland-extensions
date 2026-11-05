pragma Singleton
import qs.modules.common
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * The registry: one index.json listing widgets to install by url. Fetched on demand,
 * cached on disk, and the cache stands in when the fetch does not land.
 */
Singleton {
    id: root

    enum State {
        Idle, Loading, Ready, Failed
    }

    property string url: "https://raw.githubusercontent.com/Berupor/ii-widgets/main/index.json"
    readonly property string homepage: "https://github.com/Berupor/ii-widgets" // Where an author adds their own
    readonly property string cacheFile: FileUtils.trimFileProtocol(`${Directories.cache}/widgets/index.json`)
    property int ttl: 6 * 3600 // Seconds a cached index is good for

    property int state: WidgetRegistry.State.Idle
    property string message: ""
    property bool stale: false // Cache stood in, so the list may be behind
    property var entries: []
    readonly property bool busy: root.state === WidgetRegistry.State.Loading

    readonly property var installedIds: WidgetCatalog.widgets.map(w => w.widgetId)

    /// Listed: not installed, and runnable on this contract
    readonly property var listed: root.entries.filter(e => !root.installedIds.includes(e.id) && WidgetCatalog.supports(e.minShellVersion))
    /// Hidden for asking another contract. Counted, so the page can say so
    readonly property int unsupported: root.entries.filter(e => !root.installedIds.includes(e.id) && !WidgetCatalog.supports(e.minShellVersion)).length

    /// Fetches unless the cache is still fresh, `force` for the refresh button
    function load(force) {
        if (root.busy)
            return;
        root.state = WidgetRegistry.State.Loading;
        root.message = "";
        proc.command = ["env", `RU=${root.url}`, `RC=${root.cacheFile}`, `RT=${root.ttl}`, `RF=${force ? 1 : ""}`, "bash", "-c", `
            [ -n "$RC" ] || exit 1 # No cache path, no writing ".new" into whatever the cwd is
            mkdir -p "$(dirname "$RC")"
            valid() { jq -e '.widgets | arrays' "$1" >/dev/null 2>&1; }
            if [ -z "$RF" ] && [ -f "$RC" ] && [ $(( $(date +%s) - $(stat -c %Y "$RC") )) -lt "$RT" ] && valid "$RC"; then
                exec cat "$RC"
            fi
            # Only an index replaces the cache; otherwise an old list beats an empty page
            if ! curl -fsS --max-time 15 -o "$RC.new" "$RU"; then
                rm -f -- "$RC.new"
            elif valid "$RC.new"; then
                mv -- "$RC.new" "$RC"
            else
                echo "The registry answered with something that is not an index" >&2
                rm -f -- "$RC.new"
            fi
            [ -f "$RC" ] && valid "$RC" || exit 1
            cat "$RC"`];
        proc.running = true;
    }

    /// Entries the page can act on: an id to install as, a name to show, a url to clone
    function parse(text) {
        let index;
        try {
            index = JSON.parse(text);
        } catch (e) {
            return null;
        }
        if (!Array.isArray(index?.widgets))
            return null;
        return index.widgets.filter(e => e?.id && e?.name && e?.url).map(e => ({
                    "id": String(e.id),
                    "name": String(e.name),
                    "description": String(e.description ?? ""),
                    "icon": String(e.icon || "widgets"),
                    "author": String(e.author ?? ""),
                    "url": String(e.url),
                    "minShellVersion": String(e.minShellVersion || "1.0"),
                    "dependencies": Array.isArray(e.dependencies) ? e.dependencies.map(String) : [],
                    "tags": Array.isArray(e.tags) ? e.tags.map(String) : []
                }));
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: output
        }
        stderr: StdioCollector {
            id: errors
        }
        onExited: exitCode => {
            const parsed = exitCode === 0 ? root.parse(output.text) : null;
            if (!parsed) {
                root.message = errors.text.trim().split("\n").pop() || Translation.tr("The registry could not be read");
                root.state = WidgetRegistry.State.Failed;
                return;
            }
            // Exit 0 with something on stderr means curl failed and the cache answered
            root.stale = errors.text.trim() !== "";
            root.entries = parsed;
            root.message = "";
            root.state = WidgetRegistry.State.Ready;
        }
    }
}
