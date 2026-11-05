//@ probe -g 620x200 -s 3500
/**
 * Error report settings: the built-in endpoint, and both outcomes of a test send.
 * The sink answers 200 to a POST, the discard port cannot be connected to.
 */
import qs.modules.widgets
import Quickshell.Io
import QtQuick

Item {
    id: probe
    property var seen: []
    property var snap: ({}) // Overriding the target rewrites the store, so keep the first state

    function checks() {
        return [
            {
                "name": "the endpoint is built in",
                "got": probe.snap.host ?? "",
                "want": "reports.ug3n.com"
            },
            {
                "name": "endpoint reaches the pipe environment",
                "got": probe.snap.argv?.indexOf("RT=https://reports.ug3n.com/report") ?? -1,
                "want": 3
            },
            {
                "name": "the pipe posts json to it",
                "got": probe.snap.argv?.[probe.snap.argv.length - 1]?.endsWith(`-d @- "$RT"`) ?? false,
                "want": true
            },
            {
                "name": "a delivered test send is seen",
                "got": probe.seen.indexOf(ErrorReporter.TestState.Sent) >= 0,
                "want": true
            },
            {
                "name": "an unreachable target fails the test send",
                "got": ErrorReporter.testState,
                "want": ErrorReporter.TestState.Failed
            }
        ];
    }

    ErrorReportsCard {
        id: section
        width: probe.width
        expanded: true
    }

    Process { // Somewhere for the successful send to land
        running: true
        command: ["python3", "-c", "import http.server as h\nclass S(h.BaseHTTPRequestHandler):\n    def do_POST(self):\n        self.rfile.read(int(self.headers.get('Content-Length', 0)))\n        self.send_response(200)\n        self.end_headers()\n    def log_message(self, *a): pass\nh.HTTPServer(('127.0.0.1', 9788), S).serve_forever()"]
    }

    Connections {
        target: ErrorReporter
        function onTestStateChanged() {
            probe.seen = probe.seen.concat([ErrorReporter.testState]);
        }
    }

    Timer { // Not onCompleted: the store loads its file asynchronously
        running: true
        interval: 800
        onTriggered: {
            WidgetsStore.setKey("errorReportsTarget", ""); // Reports are off here, nothing can send to it
            probe.snap = {
                "host": section.host,
                "argv": ErrorReporter.argv("test", "hello")
            };
            WidgetsStore.setKey("errorReportsTarget", "http://127.0.0.1:9788/report");
            ErrorReporter.test();
        }
    }

    Timer {
        running: true
        interval: 2200
        onTriggered: {
            WidgetsStore.setKey("errorReportsTarget", "http://127.0.0.1:9/hook");
            ErrorReporter.test();
        }
    }
}
