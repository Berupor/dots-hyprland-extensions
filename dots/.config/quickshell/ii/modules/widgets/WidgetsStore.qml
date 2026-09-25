pragma Singleton
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Widget catalog state: enabled ids and per-widget options.
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

    function setEnabled(widgetId, on) {
        const enabled = (data.enabled ?? []).filter(x => x !== widgetId)
        if (on) enabled.push(widgetId)
        root.data = Object.assign({}, data, { "enabled": enabled })
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

    function writeFile() {
        fileView.setText(JSON.stringify(root.data, null, 2))
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
            try {
                root.data = JSON.parse(fileView.text())
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
