import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.widgets

/**
 * Built-in view of the Widgets settings page. Replaceable via the catalogView slot.
 */
ContentPage {
    id: root
    readonly property int count: WidgetCatalog.widgets.length
    readonly property bool catalogEmpty: root.count === 0
    property CatalogCard openCard: root.catalogEmpty ? browseCard : null // The one thing to do here, so it opens itself

    forceWidth: true

    component PanelButton: RippleButtonWithIcon {
        required property CatalogCard card
        buttonRadius: Appearance.rounding.full
        implicitHeight: 40
        horizontalPadding: 14
        colBackground: Appearance.colors.colLayer3
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        toggled: root.openCard === card
        onClicked: {
            root.openCard = toggled ? null : card;
            card.expanded = true;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PanelButton {
                card: browseCard
                materialIcon: "travel_explore"
                mainText: Translation.tr("Browse")
            }

            PanelButton {
                card: installCard
                materialIcon: "download"
                mainText: Translation.tr("Install from url")
            }

            Item {
                Layout.fillWidth: true
            }

            PanelButton {
                card: reportsCard
                implicitWidth: implicitHeight
                horizontalPadding: 10
                materialIcon: "bug_report"
                mainText: ""

                StyledToolTip {
                    text: Translation.tr("Error reports") + " · " + reportsCard.subtitle
                }
            }
        }

        Item { // Nothing to list yet, so the open Browse card is the whole page
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.bottomMargin: 12
            visible: root.catalogEmpty
            implicitHeight: 200

            PagePlaceholder {
                icon: "widgets"
                title: Translation.tr("No widgets yet")
                description: Translation.tr("Every widget is a git repository of its own.\nInstall one below and it lands here.")
                shape: MaterialShape.Shape.Cookie9Sided
                descriptionHorizontalAlignment: Text.AlignHCenter
            }
        }

        // The chevron closes a card the same way its button does
        BrowseCard {
            id: browseCard
            visible: root.openCard === browseCard
            expanded: root.catalogEmpty
            onExpandedChanged: if (!expanded && root.openCard === browseCard) root.openCard = null
        }

        InstallCard {
            id: installCard
            visible: root.openCard === installCard
            onExpandedChanged: if (!expanded && root.openCard === installCard) root.openCard = null
        }

        ErrorReportsCard {
            id: reportsCard
            visible: root.openCard === reportsCard
            onExpandedChanged: if (!expanded && root.openCard === reportsCard) root.openCard = null
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: WidgetCatalog.widgets
                delegate: WidgetCard {
                    required property var modelData
                    required property int index
                    manifest: modelData
                    segment: root.count === 1 ? CatalogCard.Segment.Alone : index === 0 ? CatalogCard.Segment.First : index === root.count - 1 ? CatalogCard.Segment.Last : CatalogCard.Segment.Middle
                }
            }
        }
    }
}
