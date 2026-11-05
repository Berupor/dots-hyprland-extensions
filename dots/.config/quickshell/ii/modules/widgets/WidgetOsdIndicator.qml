import qs.modules.widgets
import qs.modules.ii.onScreenDisplay
import QtQuick

/**
 * The OSD of WidgetCatalog.showOsd.
 */
OsdValueIndicator {
    readonly property bool valueShown: WidgetCatalog.osd.value !== null && WidgetCatalog.osd.value !== undefined

    icon: WidgetCatalog.osd.icon ?? ""
    name: WidgetCatalog.osd.text ?? ""
    value: valueShown ? Number(WidgetCatalog.osd.value) : 0
    showValue: valueShown
}
