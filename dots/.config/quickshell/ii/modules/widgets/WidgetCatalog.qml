pragma Singleton
import qs.modules.common
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
    readonly property string externalDir: `${Directories.shellConfig}/widgets`

    /// Version of the widget contract, not of the shell: minor up when it grows
    /// (a slot, a manifest property, an option type), major up when it breaks
    readonly property string shellVersion: "1.3"

    /// Known slots and the fields their entry needs beyond `path`. A bare-path
    /// entry is only valid when the list is empty
    readonly property var slotSchema: ({
        "barIndicator": [],
        "barGauge": [],
        "barUtilButton": [],
        "backgroundWidget": [],
        "catalogView": [],
        "settingsView": [],
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

    /// Widgets in a slot, optionally only the ones drawing for a bar orientation
    function forSlot(slot, orientation) {
        return widgets.filter(w => w.slots[slot] !== undefined && w.usable && isEnabled(w.widgetId)
            && (!orientation || w.slotOrientations(slot).includes(orientation)))
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

    // A view that won't load can't be switched off from itself
    function dropView(widgetId, url) {
        ErrorReporter.report(widgetId, `${url} failed to load`)
        root.brokenViews = root.brokenViews.concat([widgetId])
    }

    function option(widgetId, key) {
        return widgets.find(w => w.widgetId === widgetId)?.optionValue(key)
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
            if (!manifest) return
            if (found.some(w => w.widgetId === manifest.widgetId)) {
                ErrorReporter.report(name, `duplicate widget id ${manifest.widgetId}`)
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
        root.widgets = found
    }

    FolderListModel {
        id: folders
        folder: Qt.resolvedUrl(".")
        showDirs: true
        showFiles: false
        onStatusChanged: if (status === FolderListModel.Ready) root.scan()
    }

    /// Installed widgets, outside the shell tree so the installer's rsync can't wipe them
    FolderListModel {
        id: external
        folder: Qt.resolvedUrl(root.externalDir)
        showDirs: true
        showFiles: false
        onStatusChanged: if (status === FolderListModel.Ready) root.scan()
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
