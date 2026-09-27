import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A catalog widget. To add one:
 * 1. Create modules/widgets/<id>/ with Manifest.qml and slot files.
 *    Service singletons go flat into modules/widgets/ (dynamically loaded
 *    files resolve `import qs.modules.widgets`, but not subdir modules)
 * 2. Slot paths are relative to the widget dir; barIndicator files expose `shown`.
 *    barGauge is the same file in another place: next to the resource circles, for
 *    widgets drawn as one (ClippedFilledCircularProgress plus a number).
 *    Bar slots draw for the orientations they list: `{"path": ..., "orientations":
 *    ["horizontal", "vertical"]}`, either one alone is as good as both. The bare-path
 *    form means horizontal. A vertical host hands the file `vertical: true`, so one
 *    that lists it declares `property bool vertical` and sizes off the bar thickness
 * 3. Declare options with defaults, read them via WidgetCatalog.option(id, key), or
 *    optionValue(key) from the manifest itself. Never re-state a default elsewhere.
 *    An option with a `label` is drawn by the card, one without is for a settingsPage.
 *    Types: `switch`, `spinBox` (min/max/step), `textField` (placeholder)
 * 4. List required binaries in `dependencies`. A widget runs its own Process where it
 *    needs one; what cannot be QML is a dependency plus a README, never something the
 *    catalog installs
 * 5. `settingsPage` renders inside the widget's card on the Widgets page: group with
 *    ContentSubsection, ContentSection is the host's altitude
 * 6. `backgroundWidget` builds on AbstractBackgroundWidget and stays loaded, so gate it
 *    on its own option; `regionAction` exposes `available` and perform(path, x, y, w, h)
 * 7. `minShellVersion` is the contract you built against (WidgetCatalog.shellVersion).
 *    A widget asking for a newer one, or for another major, is shown but not loaded.
 *    Bump your own `version` on every release: the updater reports it
 * A widget can also be installed as ~/.config/illogical-impulse/widgets/<id>/, outside
 * the shell tree, and gets marked as such in the catalog. Same contract, two extras:
 * its own singletons need a `qmldir` next to them (`singleton Foo 1.0 Foo.qml`), and it
 * cannot import its own directory as a module. Working ones: tests/fixtures/hello here,
 * github.com/Berupor/ii-widget-hello to copy from.
 * View slots take over a host screen instead of adding to it: `catalogView` replaces the
 * Widgets page (built-in one: WidgetCatalogView), `settingsView` the whole settings
 * window, titlebar included. Disable the widget to get the built-in view back.
 * Build from the design system only: Appearance.* colors and fonts,
 * MaterialSymbol, widgets from modules/common/widgets/.
 */
QtObject {
    id: root
    required property string widgetId
    property string name
    property string description
    property string icon: "widgets"
    property string version: "1.0"
    property string author: ""
    property string minShellVersion: "1.0" // Widget contract this was built against
    property list<string> dependencies: []
    property var slots: ({})
    property var options: []
    property string settingsPage: ""
    property url dir // Set by WidgetCatalog
    property bool external: false // Ditto: installed by the user, not shipped with the shell

    property list<string> depsMissing: []
    property bool depsChecked: dependencies.length === 0
    /// Runs on this system. Widgets override it, hence the separate contract check
    property bool available: depsChecked && depsMissing.length === 0
    readonly property bool supported: WidgetCatalog.supports(root.minShellVersion)
    readonly property bool usable: root.available && root.supported

    function resolve(rel) {
        return `${dir}/${rel}`
    }

    /// File of a slot, both the bare-path form and the one carrying other fields
    function slotPath(slot) {
        const entry = root.slots[slot]
        return entry?.path ?? entry
    }

    /// Bar orientations a slot draws for. A bare path predates the field: horizontal
    function slotOrientations(slot) {
        return root.slots[slot]?.orientations ?? ["horizontal"]
    }

    // Reassigned only when this widget's own options change: a binding reading
    // WidgetsStore.data would re-run on every other widget's write, and one that
    // computes `slots` from options would make every slot host rebuild its content
    property var storedOptions: ({})

    function syncStoredOptions() {
        const next = WidgetsStore.data.options?.[root.widgetId] ?? {}
        if (JSON.stringify(next) !== JSON.stringify(root.storedOptions))
            root.storedOptions = next
    }

    /// Stored option value, or the schema default. The only place a default is read
    function optionValue(key) {
        const stored = root.storedOptions[key]
        return stored !== undefined ? stored : root.options.find(o => o.key === key)?.default
    }

    property Connections storeWatch: Connections {
        target: WidgetsStore
        function onDataChanged() {
            root.syncStoredOptions()
        }
    }

    Component.onCompleted: syncStoredOptions()

    property Process depsCheck: Process {
        running: root.dependencies.length > 0
        command: ["bash", "-c", "for c in " + root.dependencies.join(" ") + "; do command -v \"$c\" >/dev/null || echo \"$c\"; done"]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                root.depsMissing = collector.text.trim() ? collector.text.trim().split("\n") : []
                root.depsChecked = true
            }
        }
    }
}
