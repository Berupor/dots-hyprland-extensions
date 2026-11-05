import qs.modules.common
import qs.modules.common.functions
import qs.modules.ii.sidebarRight.quickToggles.androidStyle
import QtQuick

/** Android panel tile of a widget's quickToggle slot. */
AndroidQuickToggleButton {
    id: root

    readonly property string widgetId: String(buttonData.type).replace(/^widget:/, "")
    readonly property var manifest: WidgetCatalog.forSlot("quickToggle").find(w => w.widgetId === root.widgetId) ?? null
    property QtObject built: null
    readonly property bool stale: root.built === null

    function rebuild() {
        root.built?.destroy();
        root.built = root.manifest ? WidgetCatalog.build(root.manifest, root.manifest.resolve(root.manifest.slotPath("quickToggle")), root) : null;
    }

    onManifestChanged: root.rebuild()
    Component.onCompleted: root.rebuild()

    visible: root.manifest !== null || root.editMode
    toggleModel: root.built
    name: root.built?.name ?? root.widgetId
    available: root.built?.available ?? true
    mainAction: root.built?.mainAction ?? (() => {})
    altAction: root.built?.altAction ?? null
    colText: root.stale ? ColorUtils.transparentize(Appearance.colors.colOnLayer2, 0.7) : ((toggled && !(altAction && expandedSize) && enabled) ? Appearance.colors.colOnPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer2, enabled ? 0 : 0.7))
}
