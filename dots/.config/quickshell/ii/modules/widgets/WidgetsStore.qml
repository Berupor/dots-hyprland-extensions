pragma Singleton
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Widget catalog state: enabled ids, per-widget options, sensitive slot grants.
 */
Singleton {
    id: root
    property var data: ({ "enabled": [], "options": {} })
    // Kept in sync with data.enabled, but reassigned only when the list actually
    // changes: readers bound to `data` re-evaluate on every option write
    property list<string> enabled: []

    function syncEnabled() {
        const next = data.enabled ?? []
        if (JSON.stringify(next) !== JSON.stringify(root.enabled))
            root.enabled = next
    }

    /// Drops the widget's grants either way, switching on is not consent
    function setEnabled(widgetId, on) {
        const enabled = (data.enabled ?? []).filter(x => x !== widgetId)
        if (on) enabled.push(widgetId)
        const grants = {}
        for (const slot in data.grants ?? {}) {
            grants[slot] = Object.assign({}, data.grants[slot])
            delete grants[slot][widgetId]
        }
        root.data = Object.assign({}, data, { "enabled": enabled, "grants": grants })
        syncEnabled()
        save()
    }

    function setOption(widgetId, key, value) {
        const options = Object.assign({}, data.options)
        options[widgetId] = Object.assign({}, options[widgetId], { [key]: value })
        root.data = Object.assign({}, data, { "options": options })
        save()
    }

    function setKey(key, value) {
        root.data = Object.assign({}, data, { [key]: value })
        save()
    }

    function save() {
        saveTimer.restart()
    }

    property string lastWritten: ""

    function writeFile() {
        root.lastWritten = JSON.stringify(root.data, null, 2)
        fileView.setText(root.lastWritten)
    }

    Timer {
        id: saveTimer
        interval: 400 // Coalesce frequent writers (text fields, spin boxes)
        onTriggered: root.writeFile()
    }

    FileView {
        id: fileView
        path: Qt.resolvedUrl(`${Directories.shellConfig}/widgets.json`)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const text = fileView.text()
            if (text === root.lastWritten) return // Own write echoing back, root.data may be newer
            try {
                root.data = JSON.parse(text)
                root.syncEnabled()
            } catch (e) {
                console.warn("[WidgetsStore] Bad json: " + e)
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) save()
        }
    }
}
