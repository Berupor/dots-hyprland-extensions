//@ probe -g 520x120 -s 1500
/**
 * A search result marked `secret` draws a fixed mask, with no favicon for a link in it.
 */
import qs.modules.common
import qs.modules.common.models
import qs.modules.ii.overview
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: probe
    color: Appearance.colors.colLayer0

    function checks() {
        return [
            {
                "name": "the secret row shows the mask, not the text",
                "got": probe.showsMask(secretItem),
                "want": true
            },
            {
                "name": "the plain row shows its text",
                "got": probe.showsMask(plainItem),
                "want": false
            }
        ];
    }

    function showsMask(item) {
        const queue = [item];
        while (queue.length) {
            const node = queue.shift();
            if (node.text === "•".repeat(12))
                return true;
            queue.push(...node.children);
        }
        return false;
    }

    LauncherSearchResult {
        id: secret
        name: "https://example.com/?token=glpat-AbCdEfGhIjKlMnOpQrSt"
        rawValue: "1\thttps://example.com/?token=glpat-AbCdEfGhIjKlMnOpQrSt"
        type: "#1"
        secret: true
    }

    LauncherSearchResult {
        id: plain
        name: "ssh user@example.com"
        rawValue: "2\tssh user@example.com"
        type: "#2"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0
        SearchItem {
            id: secretItem
            Layout.fillWidth: true
            entry: secret
        }
        SearchItem {
            id: plainItem
            Layout.fillWidth: true
            entry: plain
        }
    }
}
