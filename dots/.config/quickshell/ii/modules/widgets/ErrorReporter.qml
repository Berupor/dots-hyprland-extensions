pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Widget failure reports, off unless turned on. widgets.json keys:
 * "errorReports": "always" sends, anything else (the default) sends nothing.
 * "errorReportsTarget": url taking a POST, hand-edited; empty means root.endpoint.
 */
Singleton {
    id: root

    enum TestState {
        Idle, Sending, Sent, Failed
    }

    readonly property string endpoint: "https://reports.ug3n.com/report"
    readonly property string target: {
        const override = WidgetsStore.data.errorReportsTarget ?? "";
        return override === "" ? root.endpoint : override;
    }
    readonly property bool sending: (WidgetsStore.data.errorReports ?? "never") === "always"

    property var reported: ({})

    function report(widgetId, message) {
        console.warn(`[ErrorReporter] ${widgetId}: ${message}`)
        if (!root.sending)
            return
        const key = `${widgetId}\n${message}`
        if (root.reported[key]) // Once per session, a broken widget retries forever
            return
        root.reported[key] = true
        root.send(widgetId, message)
    }

    // Logs may carry window titles and paths, hence the switch guarding all this
    function argv(widgetId, message) {
        const pipe = `jq -Rs '{widget: env.RW, report: .}' | curl -sf -X POST -H "Content-Type: application/json" -d @- "$RT"`
        return ["env", `RW=${widgetId}`, `RM=${message}`, `RT=${root.target}`, "bash", "-c", `{ echo "widget: $RW"; echo "$RM"; echo; qs log --pid ${Quickshell.processId} 2>/dev/null | tail -100; } | ${pipe}`]
    }

    function send(widgetId, message) {
        Quickshell.execDetached(root.argv(widgetId, message))
    }

    // Real reports are fire and forget, so a broken pipeline only shows up on a test run
    property int testState: ErrorReporter.TestState.Idle

    function test() {
        testProc.command = root.argv("test", "Test report from settings")
        root.testState = ErrorReporter.TestState.Sending
        testProc.running = true
    }

    Process {
        id: testProc
        onExited: exitCode => root.testState = (exitCode === 0 ? ErrorReporter.TestState.Sent : ErrorReporter.TestState.Failed)
    }
}
