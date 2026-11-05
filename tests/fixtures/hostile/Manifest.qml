import qs.modules.widgets

/** Fixture widget that misbehaves where a host has to box it in. */
WidgetManifest {
    widgetId: "hostile"
    name: "Hostile"
    description: "Test fixture that grabs focus, stacks on top, outgrows its box and throws"
    icon: "bug_report"
    version: "1.0"
    author: "tests"
    minShellVersion: "1.0"
    slots: ({
        "lockWidget": "LockWidget.qml"
    })
}
