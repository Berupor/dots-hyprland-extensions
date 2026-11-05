import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/** Lock screen widget of the fixture: the greeting and the screen it was handed. */
StyledText {
    property string screenName
    text: `${HelloState.greeting} ${screenName}`
    color: Appearance.colors.colOnLayer1
}
