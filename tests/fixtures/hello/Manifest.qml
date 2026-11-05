import qs.modules.widgets
import qs.services

/** Fixture widget, installed the way an external one is. See tests/fixtures/README.md. */
WidgetManifest {
    widgetId: "hello"
    name: Translation.tr("Hello")
    description: Translation.tr("Test fixture for widgets outside the shell tree")
    icon: "waving_hand"
    version: "1.0"
    author: "tests"
    minShellVersion: "1.0"
    slots: ({
        "barIndicator": { "path": "HelloIndicator.qml", "orientations": ["horizontal", "vertical"] },
        "sidebarLeftTab": { "path": "HelloTab.qml", "icon": "waving_hand", "name": Translation.tr("Hello") },
        "regionAction": { "path": "HelloAction.qml", "name": "hello" },
        "screenOverlay": "HelloOverlay.qml",
        "unlockHook": "HelloUnlock.qml",
        "searchFilter": "HelloFilter.qml",
        "service": "HelloService.qml",
        "barView": "HelloBar.qml",
        "quickToggle": "Toggle.qml",
        "lockWidget": "LockWidget.qml",
        "notificationFilter": "NotificationFilter.qml"
    })
    options: [
        {
            "key": "badge",
            "type": "switch",
            "icon": "counter_1",
            "label": Translation.tr("Show the badge"),
            "default": true
        },
        {
            "key": "bar",
            "type": "switch",
            "icon": "toolbar",
            "label": Translation.tr("Take over the bar"),
            "default": false
        }
    ]
}
