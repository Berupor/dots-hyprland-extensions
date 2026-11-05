pragma Singleton
import qs.modules.common
import qs.modules.common.functions
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Scans modules/widgets/<id>/Manifest.qml. See WidgetManifest for the contract.
 */
Singleton {
    id: root
    property list<QtObject> widgets: []
    property list<string> brokenViews: []
    // Keyed by "slot:orientation", so a write to one widget's options doesn't hand every
    // reader (sidebar tabs included) a new array and make them rebuild their content
    property var _slotCache: ({})
    readonly property string externalDir: `${Directories.shellConfig}/widgets`
    // Off in the Settings window (its pragma Env), so services don't run twice
    readonly property bool runsHosts: Quickshell.env("QS_WIDGET_HOSTS") !== "off"

    /// Version of the widget contract, not of the shell: minor up when it grows
    /// (a slot, a manifest property, an option type), major up when it breaks
    readonly property string shellVersion: "1.11"

    /// Known slots and the fields their entry needs beyond `path`. A bare-path
    /// entry is only valid when the list is empty
    readonly property var slotSchema: ({
        "barIndicator": [],
        "barGauge": [],
        "barUtilButton": [],
        "backgroundWidget": [],
        "screenOverlay": [],
        "unlockHook": [],
        "searchFilter": [],
        "service": [],
        "catalogView": [],
        "settingsView": [],
        "calendarView": [],
        "barView": [],
        "mediaView": [],
        "quickToggle": [],
        "regionAction": ["name"],
        "sidebarLeftTab": ["name", "icon"],
        "sidebarRightTab": ["name", "icon"]
    })

    /// Unknown slots and missing required fields, one message per problem
    function slotProblems(manifest) {
        const problems = []
        for (const slot in manifest.slots) {
            const required = root.slotSchema[slot]
            if (required === undefined) {
                problems.push(`unknown slot "${slot}"`)
                continue
            }
            const entry = manifest.slots[slot]
            if (required.length === 0) continue
            if (typeof entry !== "object") {
                problems.push(`slot "${slot}" needs {path, ${required.join(", ")}}, got a bare path`)
                continue
            }
            for (const field of required)
                if (entry[field] === undefined)
                    problems.push(`slot "${slot}" missing required field "${field}"`)
        }
        return problems
    }

    function isEnabled(widgetId) {
        return WidgetsStore.enabled.includes(widgetId)
    }

    /// Widgets in a slot, optionally only the ones drawing for a bar orientation. Stable
    /// across calls when the resulting list is the same, so an unrelated option write
    /// elsewhere doesn't hand every reader a fresh array and make it rebuild its content
    function forSlot(slot, orientation) {
        const list = widgets.filter(w => w.slots[slot] !== undefined && w.usable && isEnabled(w.widgetId)
            && (!orientation || w.slotOrientations(slot).includes(orientation)))
        const key = `${slot}:${orientation ?? ""}`
        const cached = root._slotCache[key]
        if (cached && cached.length === list.length && cached.every((w, i) => w === list[i]))
            return cached
        root._slotCache[key] = list
        return list
    }

    /// A widget runs on the contract it was built for: same major, not from the future
    function supports(minShellVersion) {
        return String(minShellVersion).split(".")[0] === root.shellVersion.split(".")[0]
            && root.compareVersions(minShellVersion, root.shellVersion) <= 0
    }

    /// Dotted numbers, so 1.10 beats 1.9. Returns -1, 0 or 1
    function compareVersions(a, b) {
        const pa = String(a).split(".")
        const pb = String(b).split(".")
        for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
            const d = (parseInt(pa[i]) || 0) - (parseInt(pb[i]) || 0)
            if (d !== 0) return d < 0 ? -1 : 1
        }
        return 0
    }

    /// Widget replacing a host view, null when the built-in one stands
    function viewFor(slot) {
        return root.forSlot(slot).filter(w => !root.brokenViews.includes(w.widgetId))[0] ?? null
    }

    /// Object of a widget's slot file, null when it won't build. Dies with `owner`
    function build(manifest, url, owner) {
        const component = Qt.createComponent(url)
        const object = component.createObject(owner ?? null)
        if (!object) ErrorReporter.report(manifest.widgetId, component.errorString())
        return object
    }

    /// One object per widget in a slot, the ones that fail dropped. For slots
    /// whose value carries a path among other fields
    function itemsFor(slot, owner) {
        return root.forSlot(slot)
            .map(w => root.build(w, w.resolve(w.slotPath(slot)), owner))
            .filter(o => o)
    }

    /// Object of the widget answering to a name in a slot, empty name for the first
    /// one. Null when nobody takes it, or the widget says it cannot right now
    function actionFor(slot, name, owner) {
        const manifest = root.forSlot(slot).find(w => name === "" || w.slots[slot].name === name)
        if (!manifest) return null
        const action = root.build(manifest, manifest.resolve(manifest.slotPath(slot)), owner)
        return action?.available ? action : null
    }

    /// Switched on while the manifest already had the slot, so an update can't add it silently
    function unlockHookAllowed(widgetId) {
        return (WidgetsStore.data.unlockHookAllowed ?? []).includes(widgetId)
    }

    /// sha256 of every file in a widget dir, so a script the hook runs counts too, symlinks
    /// by target; bytecode caches left out, they change without an update. "" on failure
    function codeHash(manifest, callback) {
        hashRunner.createObject(root, { "dir": FileUtils.trimFileProtocol(String(manifest.dir)), "done": callback })
    }

    Component {
        id: hashRunner
        Process {
            id: proc
            property string dir
            property var done
            running: true
            command: ["bash", "-c", "cd \"$1\" && find -L . -type f -not -path './.git/*' -not -path '*/__pycache__/*' -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1", "_", proc.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    proc.done(text.trim())
                    proc.destroy()
                }
            }
        }
    }

    /// Allows the unlockHook of a widget for the code with this hash, an empty hash revokes
    function setUnlockHookGrant(widgetId, hash) {
        const allowed = (WidgetsStore.data.unlockHookAllowed ?? []).filter(x => x !== widgetId)
        const hashes = Object.assign({}, WidgetsStore.data.unlockHookHashes)
        delete hashes[widgetId]
        if (hash !== "") {
            allowed.push(widgetId)
            hashes[widgetId] = hash
        }
        WidgetsStore.setKey("unlockHookAllowed", allowed)
        WidgetsStore.setKey("unlockHookHashes", hashes)
    }

    /// Hands the accepted login password to each unlockHook once, empty on fingerprint
    function runUnlockHooks(password) {
        if (!password) return
        for (const manifest of root.forSlot("unlockHook").filter(w => root.unlockHookAllowed(w.widgetId)))
            root.codeHash(manifest, hash => root.runUnlockHook(manifest, hash, password))
    }

    /// Only for the code that was allowed: anything else loses the grant
    function runUnlockHook(manifest, hash, password) {
        const id = manifest.widgetId
        if (!root.unlockHookAllowed(id)) return
        if (hash === "" || hash !== WidgetsStore.data.unlockHookHashes?.[id]) {
            console.warn(`[WidgetCatalog] unlock_hook_grant_dropped widget=${id}`)
            root.setUnlockHookGrant(id, "")
            return
        }
        let hook = null
        try {
            hook = root.build(manifest, manifest.resolve(manifest.slotPath("unlockHook")))
            hook?.unlocked(password)
        } catch (e) {
            // The message may carry the password, and reports leave the machine
            ErrorReporter.report(id, `unlockHook threw ${e.name} at line ${e.lineNumber}`)
        }
        hook?.destroy()
    }

    /// Results every searchFilter lets through, some of them marked `secret` on the way
    function filterSearchResults(results) {
        return results.filter(result => searchFilters.instances.every(host => {
            try {
                return host.filter?.filter(result) !== false
            } catch (e) {
                // The message may carry the result text, and reports leave the machine
                ErrorReporter.report(host.modelData.widgetId, `searchFilter threw ${e.name} at line ${e.lineNumber}`)
                return true
            }
        }))
    }

    Variants {
        id: searchFilters
        model: root.runsHosts ? root.forSlot("searchFilter") : []
        delegate: QtObject {
            id: host
            required property var modelData
            property QtObject filter: root.build(host.modelData, host.modelData.resolve(host.modelData.slotPath("searchFilter")), host)
        }
    }

    Variants {
        model: root.runsHosts ? root.forSlot("service") : []
        delegate: QtObject {
            id: serviceHost
            required property var modelData
            property QtObject service
            // Not a binding: whatever the service reads while it is built would rebuild it
            Component.onCompleted: serviceHost.service = root.build(serviceHost.modelData, serviceHost.modelData.resolve(serviceHost.modelData.slotPath("service")), serviceHost)
        }
    }

    // A view that won't load can't be switched off from itself
    function dropView(widgetId, url) {
        ErrorReporter.report(widgetId, `${url} failed to load`)
        root.brokenViews = root.brokenViews.concat([widgetId])
    }

    function option(widgetId, key) {
        return widgets.find(w => w.widgetId === widgetId)?.optionValue(key)
    }

    signal osdRequested(var spec)
    property var osd: ({})

    /// An OSD popup from an enabled widget: spec is {icon, text, value}, value 0-1 or absent
    function showOsd(widgetId, spec) {
        if (!root.isEnabled(widgetId) || !spec?.icon)
            return
        root.osd = { "widgetId": widgetId, "icon": String(spec.icon), "text": String(spec.text ?? ""), "value": spec.value ?? null }
        root.osdRequested(spec)
    }

    function scanWhenReady() {
        if (folders.status === FolderListModel.Ready && external.status === FolderListModel.Ready)
            root.scan()
    }

    function scan() {
        const found = []
        const add = (name, dir, external) => {
            const component = Qt.createComponent(`${dir}/Manifest.qml`)
            if (component.status === Component.Error) {
                ErrorReporter.report(name, component.errorString())
                return
            }
            const manifest = component.createObject(root, { "dir": dir, "external": external })
            if (!manifest) {
                ErrorReporter.report(name, component.errorString() || "Manifest.qml failed to build")
                return
            }
            // The installer names the folder by id, so a mismatch is a manifest lying about it
            if (external && manifest.widgetId !== name) {
                ErrorReporter.report(name, `folder ${name} holds widget id ${manifest.widgetId}`)
                manifest.destroy()
                return
            }
            if (found.some(w => w.widgetId === manifest.widgetId)) {
                ErrorReporter.report(name, `duplicate widget id ${manifest.widgetId}`)
                manifest.destroy()
                return
            }
            root.slotProblems(manifest).forEach(p => ErrorReporter.report(manifest.widgetId, p))
            found.push(manifest)
        }
        for (let i = 0; i < folders.count; i++)
            // Resolve against this file, not the scanned fileUrl: bundled widgets
            // import their own qs.modules.widgets.<id> module, which only the qs: scheme has
            add(folders.get(i, "fileName"), String(Qt.resolvedUrl(folders.get(i, "fileName"))), false)
        for (let i = 0; i < external.count; i++) {
            // A folder that does not exist yet makes the model list $HOME instead
            if (!String(external.get(i, "filePath")).startsWith(root.externalDir)) break
            add(external.get(i, "fileName"), String(external.get(i, "fileUrl")), true)
        }
        found.sort((a, b) => a.widgetId.localeCompare(b.widgetId))
        const superseded = root.widgets.slice()
        root.widgets = found
        root._slotCache = ({})
        superseded.forEach(w => w.destroy())
    }

    FolderListModel {
        id: folders
        folder: Qt.resolvedUrl(".")
        showDirs: true
        showFiles: false
        onStatusChanged: root.scanWhenReady()
    }

    /// Installed widgets, outside the shell tree so the installer's rsync can't wipe them
    FolderListModel {
        id: external
        folder: Qt.resolvedUrl(root.externalDir)
        showDirs: true
        showFiles: false
        onStatusChanged: root.scanWhenReady()
    }

    /// An updated widget runs the files the engine already loaded, a reload swaps them.
    /// Also reachable by hand: `qs -c ii ipc call widgets reload`
    IpcHandler {
        target: "widgets"

        function reload(): void {
            Quickshell.reload(true);
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.externalDir])
}
