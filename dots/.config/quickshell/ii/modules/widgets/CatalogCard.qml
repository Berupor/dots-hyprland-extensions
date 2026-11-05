import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * List item of the widgets page: header with icon and subtitle, body behind a disclosure.
 */
Rectangle {
    id: root

    /// Place in a boxed list: outer corners round, inner ones nearly square
    enum Segment {
        Alone,
        First,
        Middle,
        Last
    }

    property string icon
    property string title
    property string subtitle
    property color iconColor: Appearance.colors.colSurfaceContainerHighest
    property color iconSymbolColor: Appearance.colors.colOnSurfaceVariant
    property real iconOpacity: 1
    property color titleColor: Appearance.colors.colOnLayer2
    property real titleOpacity: 1
    property color subtitleColor: Appearance.colors.colSubtext
    property bool subtitleOneLine: false
    property bool canExpand: true
    property bool expanded: false
    readonly property bool bodyShown: root.canExpand && root.expanded
    property int segment: CatalogCard.Segment.Alone
    readonly property real topRadius: segment === CatalogCard.Segment.Alone || segment === CatalogCard.Segment.First ? Appearance.rounding.large : Appearance.rounding.unsharpenmore
    readonly property real bottomRadius: segment === CatalogCard.Segment.Alone || segment === CatalogCard.Segment.Last ? Appearance.rounding.large : Appearance.rounding.unsharpenmore

    property alias headerTrailing: headerTrailingRow.data // After the chevron
    default property alias bodyData: bodyContent.data

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight
    topLeftRadius: root.topRadius
    topRightRadius: root.topRadius
    bottomLeftRadius: root.bottomRadius
    bottomRightRadius: root.bottomRadius
    color: Appearance.colors.colLayer3

    ColumnLayout {
        id: cardColumn
        width: parent.width
        spacing: 0

        Item { // Header
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + 10 * 2

            Rectangle {
                anchors.fill: parent
                topLeftRadius: root.topRadius
                topRightRadius: root.topRadius
                bottomLeftRadius: root.bodyShown ? 0 : root.bottomRadius
                bottomRightRadius: root.bodyShown ? 0 : root.bottomRadius
                color: Appearance.colors.colOnLayer2
                opacity: headerArea.containsMouse ? 0.06 : 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.canExpand
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }

            RowLayout {
                id: headerRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 14

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.icon
                    iconSize: Appearance.font.pixelSize.larger
                    padding: 7
                    opacity: root.iconOpacity
                    color: root.iconColor
                    colSymbol: root.iconSymbolColor

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Medium
                        color: root.titleColor
                        elide: Text.ElideRight
                        opacity: root.titleOpacity
                    }

                    StyledText {
                        id: subtitleText
                        Layout.fillWidth: true
                        visible: root.subtitle !== ""
                        text: root.subtitle
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.subtitleColor
                        wrapMode: root.subtitleOneLine ? Text.NoWrap : Text.WordWrap
                        elide: root.subtitleOneLine ? Text.ElideRight : Text.ElideNone

                        HoverHandler {
                            id: subtitleHover
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: subtitleHover.hovered && subtitleText.truncated
                            text: root.subtitle
                        }
                    }
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    opacity: root.canExpand ? 1 : 0
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                RowLayout {
                    id: headerTrailingRow
                    Layout.alignment: Qt.AlignVCenter
                    visible: children.length > 0
                    spacing: 14
                }
            }
        }

        Item { // Body
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.bodyShown ? bodyColumn.implicitHeight : 0
            visible: implicitHeight > 0

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            ColumnLayout {
                id: bodyColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 2

                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                ColumnLayout {
                    id: bodyContent
                    Layout.fillWidth: true
                    spacing: 2
                }

                Item {
                    implicitHeight: 8
                }
            }
        }
    }
}
