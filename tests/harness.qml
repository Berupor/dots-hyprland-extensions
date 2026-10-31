//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

/**
 * Dev harness: render one widget slot from this tree in isolation, probe its
 * state, save a PNG, exit. Driven by env, see tests/widget-probe.sh.
 */
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar
import qs.modules.ii.background.widgets
import qs.modules.ii.overview
import qs.modules.widgets
import qs.services
import QtQuick
import Quickshell

ShellRoot {
    id: root
    property string widgetId: Quickshell.env("QS_HARNESS_WIDGET") ?? ""
    property string slot: Quickshell.env("QS_HARNESS_SLOT") ?? ""
    property string file: Quickshell.env("QS_HARNESS_FILE") ?? ""
    property string out: Quickshell.env("QS_HARNESS_OUT") ?? "/tmp/harness.png"
    property var props: JSON.parse(Quickshell.env("QS_HARNESS_PROPS") ?? "{}")
    property var probe: JSON.parse(Quickshell.env("QS_HARNESS_PROBE") ?? "[]")
    property int settle: parseInt(Quickshell.env("QS_HARNESS_SETTLE") ?? "1200")
    property int itemW: parseInt(Quickshell.env("QS_HARNESS_IW") ?? "0")
    property int itemH: parseInt(Quickshell.env("QS_HARNESS_IH") ?? "0")
    property string bg: Quickshell.env("QS_HARNESS_BG") ?? ""
    property int pad: parseInt(Quickshell.env("QS_HARNESS_PAD") ?? "0") // Shot mode, see widget-shots.sh
    property string chrome: Quickshell.env("QS_HARNESS_CHROME") ?? "" // Host to draw around the item

    readonly property var manifest: WidgetCatalog.widgets.find(w => w.widgetId === root.widgetId) ?? null
    readonly property string source: {
        // file:// so sibling types resolve without importing the widget's own module,
        // which is what manifest.resolve() ends up handing the hosts too
        if (root.file) return root.file.startsWith("/") ? `file://${root.file}` : Qt.resolvedUrl(root.file);
        if (!root.manifest) return "";
        const entry = root.manifest.slots[root.slot];
        if (!entry) return "";
        return root.manifest.resolve(entry.path ?? entry);
    }

    // Lazy singleton: without this the run renders in Appearance's grey fallback
    Component.onCompleted: MaterialThemeLoader.reapplyTheme()

    onSourceChanged: if (source) {
        console.log(`[harness] source ${source}`)
        loader.setSource(source, root.props) // Not a source binding: required properties must exist at creation
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: if (!root.source) {
            console.log(`[harness] FAIL no slot: widget=${root.widgetId} slot=${root.slot} file=${root.file}`)
            console.log(`[harness] catalog ${WidgetCatalog.widgets.map(w => w.widgetId).join(",")}`)
            if (root.manifest) console.log(`[harness] slots ${Object.keys(root.manifest.slots).join(",")}`)
            console.log("[harness] done")
        }
    }

    FloatingWindow {
        id: win
        title: "qs-harness"
        implicitWidth: parseInt(Quickshell.env("QS_HARNESS_W") ?? "640")
        implicitHeight: parseInt(Quickshell.env("QS_HARNESS_H") ?? "360")
        color: Appearance.colors.colLayer0

        // Opaque, so items that count on a host surface don't grab as washed-out alpha
        Rectangle {
            id: stage
            implicitWidth: host.width + root.pad * 2
            implicitHeight: host.height + root.pad * 2
            radius: root.pad > 0 ? Appearance.rounding.verylarge : 0
            color: root.bg !== "" ? root.bg : Appearance.colors.colLayer0

            Rectangle { // Flat colLayer0 reads as dead in a README, so shots get depth
                anchors.fill: parent
                radius: parent.radius
                visible: root.pad > 0 && root.bg === ""
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Appearance.colors.colPrimaryContainer
                    }
                    GradientStop {
                        position: 1
                        color: Appearance.colors.colSecondaryContainer
                    }
                }
            }

            // A slot out of its host reads as a slab of nothing, so a shot puts it
            // back into one: the bar strip, the vertical bar, the sidebar panel,
            // or a plain surface
            Rectangle {
                id: host
                visible: root.pad > 0
                x: root.pad
                y: root.pad
                width: Math.max(loader.width + host.hPad * 2, root.chrome === "vbar" ? Appearance.sizes.baseVerticalBarWidth : 0)
                height: Math.max(loader.height + host.vPad * 2, root.chrome === "bar" ? Appearance.sizes.baseBarHeight : 0)
                radius: host.isBar ? Appearance.rounding.small : Appearance.rounding.large
                color: Appearance.colors.colLayer0Base
                border.width: root.chrome === "sidebar" ? 1 : 0
                border.color: Appearance.colors.colLayer0Border

                readonly property bool isBar: root.chrome === "bar" || root.chrome === "vbar"
                // Hosts give their content air; without it a shot reads as cramped
                readonly property int hPad: root.chrome === "bar" ? 24 : host.isBar ? 0 : 14
                readonly property int vPad: root.chrome === "vbar" ? 24 : host.isBar ? 0 : 14
            }

            Loader {
                id: loader
                x: host.x + (host.width - loader.width) / 2
                y: host.y + (host.height - loader.height) / 2
                width: root.itemW > 0 ? root.itemW : (item?.implicitWidth > 0 ? item.implicitWidth : win.width)
                height: root.itemH > 0 ? root.itemH : (item?.implicitHeight > 0 ? item.implicitHeight : win.height)

                onLoaded: {
                    for (const key in root.props)
                        item[key] = root.props[key];
                    grabTimer.start()
                }
                onStatusChanged: if (status === Loader.Error) {
                    console.log(`[harness] FAIL load ${root.source}`)
                    console.log("[harness] done")
                }
            }
        }

        Timer {
            id: grabTimer
            interval: root.settle
            onTriggered: {
                const checks = loader.item?.checks; // A function, so it reads the settled state
                for (const check of (typeof checks === "function" ? checks() : checks ?? [])) {
                    const tol = check.tol ?? 0.5;
                    const near = typeof check.got === "number" && typeof check.want === "number" && Math.abs(check.got - check.want) <= tol;
                    const ok = near || JSON.stringify(check.got) === JSON.stringify(check.want);
                    console.log(`[harness] ${ok ? "check" : "FAIL check"} ${check.name}: got ${JSON.stringify(check.got)} want ${JSON.stringify(check.want)}`);
                }
                for (const path of root.probe) {
                    let value = loader.item;
                    for (const part of path.split("."))
                        value = value?.[part];
                    console.log(`[harness] probe ${path} = ${JSON.stringify(value)}`)
                }
                console.log(`[harness] size ${loader.width}x${loader.height}`)
                // Shots render at QT_SCALE_FACTOR=2, so the grab is already crisp
                stage.grabToImage(res => {
                    console.log(`[harness] png ${res.saveToFile(root.out) ? "ok" : "FAIL"} ${root.out}`)
                    console.log("[harness] done")
                })
            }
        }
    }
}
