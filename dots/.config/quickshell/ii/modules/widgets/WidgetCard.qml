import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.widgets

/**
 * One catalog widget: switch list item, options behind a disclosure.
 */
CatalogCard {
    id: root
    required property var manifest
    readonly property bool widgetEnabled: WidgetCatalog.isEnabled(manifest.widgetId)
    readonly property var drawnOptions: manifest.options.filter(o => o.label) // The rest are values for a settingsPage
    readonly property bool hasBody: root.drawnOptions.length > 0 || manifest.settingsPage !== "" || root.placements.length > 0 || manifest.external
    readonly property string jobMessage: WidgetInstaller.job === root.manifest.widgetId ? WidgetInstaller.message : ""
    property bool confirmingRemove: false

    readonly property var slotNames: ({
        "barUtilButton": Translation.tr("Bar button"),
        "barIndicator": Translation.tr("Bar indicator"),
        "sidebarLeftTab": Translation.tr("Left sidebar"),
        "sidebarRightTab": Translation.tr("Right sidebar"),
        "backgroundWidget": Translation.tr("Wallpaper"),
        "screenOverlay": Translation.tr("Over windows"),
        "regionAction": Translation.tr("Region selector"),
        "catalogView": Translation.tr("This page"),
        "settingsView": Translation.tr("Settings window")
    })
    readonly property var placements: Object.keys(root.manifest.slots).map(s => root.slotNames[s] ?? s)

    /// Subtitle: why it cannot run, or what it does
    readonly property string statusText: {
        if (!root.manifest.supported)
            return Translation.tr("Built for shell %1, this is %2").arg(root.manifest.minShellVersion).arg(WidgetCatalog.shellVersion);
        if (root.manifest.depsMissing.length > 0)
            return Translation.tr("Needs %1").arg(root.manifest.depsMissing.join(", "));
        if (!root.manifest.available)
            return Translation.tr("Not available on this system");
        return root.manifest.description;
    }

    /// Where an installed widget sits, so it is clear what to update or delete by hand
    readonly property string originText: {
        const path = FileUtils.trimFileProtocol(String(root.manifest.dir)).replace(FileUtils.trimFileProtocol(Directories.home), "~");
        const by = [root.manifest.author, root.manifest.version].filter(s => s !== "").join(" · ");
        return Translation.tr("Installed in %1").arg(path) + (by === "" ? "" : `\n${by}`);
    }

    icon: root.manifest.icon
    title: root.manifest.name
    subtitle: root.statusText
    iconOpacity: root.manifest.usable ? 1 : 0.4
    iconColor: root.widgetEnabled ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
    iconSymbolColor: root.widgetEnabled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
    titleOpacity: root.manifest.usable ? 1 : 0.6
    subtitleColor: root.manifest.usable ? Appearance.colors.colSubtext : Appearance.colors.colError
    // An installed widget opens while off too, that is where update and remove live
    canExpand: root.hasBody && (root.widgetEnabled || root.manifest.external)

    component PlacementChip: Rectangle {
        property string label
        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 26
        radius: Appearance.rounding.full
        color: "transparent"
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    headerLeading: MaterialSymbol {
        visible: root.manifest.external
        text: "folder_open"
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnSurfaceVariant

        HoverHandler {
            id: originHover
        }

        StyledToolTip {
            extraVisibleCondition: false
            alternativeVisibleCondition: originHover.hovered
            text: root.originText
        }
    }

    headerTrailing: StyledSwitch {
        enabled: root.manifest.usable
        checked: root.widgetEnabled
        onClicked: {
            WidgetsStore.setEnabled(root.manifest.widgetId, checked);
            root.expanded = checked; // Just switched on, so show what's inside
        }
    }

    RowLayout {
        visible: root.placements.length > 0
        Layout.bottomMargin: 6
        spacing: 6

        Repeater {
            model: root.placements
            delegate: PlacementChip {
                required property string modelData
                label: modelData
            }
        }
    }

    Repeater {
        model: root.bodyShown ? root.drawnOptions : []
        delegate: Loader {
            id: optLoader
            required property var modelData
            readonly property Component control: {
                switch (modelData.type) {
                case "switch": return switchOption;
                case "spinBox": return spinOption;
                case "textField": return textOption;
                }
                return null;
            }
            Layout.fillWidth: true
            // Margins of the row itself land on the Loader, and ConfigSwitch pads its own
            Layout.leftMargin: modelData.type === "switch" ? 0 : 8
            Layout.rightMargin: Layout.leftMargin
            sourceComponent: control
            Component.onCompleted: if (!control) ErrorReporter.report(root.manifest.widgetId, `Unknown option type "${modelData.type}" for "${modelData.key}"`)

            Component {
                id: switchOption
                ConfigSwitch {
                    buttonIcon: optLoader.modelData.icon ?? ""
                    text: optLoader.modelData.label
                    checked: root.manifest.optionValue(optLoader.modelData.key) ?? false
                    onCheckedChanged: WidgetsStore.setOption(root.manifest.widgetId, optLoader.modelData.key, checked)
                }
            }
            Component {
                id: spinOption
                ConfigSpinBox {
                    icon: optLoader.modelData.icon ?? ""
                    text: optLoader.modelData.label
                    value: root.manifest.optionValue(optLoader.modelData.key) ?? 0
                    from: optLoader.modelData.min ?? 0
                    to: optLoader.modelData.max ?? 100
                    stepSize: optLoader.modelData.step ?? 1
                    onValueChanged: WidgetsStore.setOption(root.manifest.widgetId, optLoader.modelData.key, value)
                }
            }
            Component {
                id: textOption
                RowLayout { // Same shape as ConfigSpinBox, so the rows line up
                    spacing: 10

                    RowLayout {
                        spacing: 10

                        OptionalMaterialSymbol {
                            icon: optLoader.modelData.icon ?? ""
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: optLoader.modelData.label
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                        }
                    }

                    ToolbarTextField { // A filled field, as tall as a spin box
                        id: textField
                        Layout.fillHeight: false
                        topPadding: 8 // As tall as a spin box
                        bottomPadding: 8
                        colBackground: Appearance.colors.colLayer2
                        color: Appearance.colors.colOnLayer2
                        placeholderText: optLoader.modelData.placeholder ?? ""
                        text: root.manifest.optionValue(optLoader.modelData.key) ?? ""
                        onTextChanged: WidgetsStore.setOption(root.manifest.widgetId, optLoader.modelData.key, textField.text.trim())
                    }
                }
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        active: root.bodyShown && root.manifest.settingsPage !== ""
        source: active ? root.manifest.resolve(root.manifest.settingsPage) : ""
    }

    RowLayout { // Installed widgets are ours to update and delete
        visible: root.manifest.external
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        StyledText { // Fills even while empty, so the buttons stay right
            Layout.fillWidth: true
            text: root.jobMessage
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: WidgetInstaller.state === WidgetInstaller.State.Failed ? Appearance.colors.colError : Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        RippleButtonWithIcon { // Only on the card that pulled, one reload covers them all
            visible: WidgetInstaller.needsReload && root.jobMessage !== ""
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colSecondaryContainer // The move to make now, so not flat like the rest
            materialIcon: "restart_alt"
            mainText: Translation.tr("Reload")
            onClicked: WidgetInstaller.reloadShell()

            StyledToolTip {
                text: Translation.tr("Restarts the shell and this window, so open panels close")
            }
        }

        RippleButtonWithIcon {
            buttonRadius: Appearance.rounding.small
            enabled: !WidgetInstaller.busy
            materialIcon: "sync"
            mainText: Translation.tr("Update")
            onClicked: {
                root.confirmingRemove = false;
                WidgetInstaller.update(root.manifest.widgetId);
            }

            StyledToolTip {
                text: Translation.tr("git pull in the widget directory")
            }
        }

        RippleButtonWithIcon {
            buttonRadius: Appearance.rounding.small
            enabled: !WidgetInstaller.busy
            materialIcon: root.confirmingRemove ? "delete_forever" : "delete"
            mainText: root.confirmingRemove ? Translation.tr("Sure?") : Translation.tr("Remove")
            onClicked: {
                if (root.confirmingRemove)
                    WidgetInstaller.remove(root.manifest.widgetId);
                root.confirmingRemove = !root.confirmingRemove;
                forgetConfirm.restart();
            }

            Timer {
                id: forgetConfirm
                interval: 4000 // A stray click should not leave a live delete button
                onTriggered: root.confirmingRemove = false
            }
        }
    }
}
