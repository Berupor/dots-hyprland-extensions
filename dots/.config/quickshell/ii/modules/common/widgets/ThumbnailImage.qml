import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (sourcePath.length == 0) return "";
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    property int _generation: 0
    // Set once the file is on disk, with a counter to bust Qt's cache: loading blind races the
    // generator, and of two widgets sharing a thumbnail the one that doesn't generate it stays stuck.
    source: ""

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onThumbnailPathChanged: {
        root._retries = 0;
        root.regenerate();
    }

    property int _retries: 0
    readonly property int maxRetries: 5

    readonly property int generatedExitCode: 2

    // A file that was already there loads by its bare path, so a recreated widget hits Qt's cache
    function show(alreadyThere: bool): void {
        if (alreadyThere) {
            root.source = root.thumbnailPath;
            return;
        }
        root._generation += 1;
        root.source = `${root.thumbnailPath}#${root._generation}`;
    }

    // Built here, not as a command binding: that binding may still hold the previous path when
    // this runs, which sends magick at the old destination and quietly generates nothing.
    function regenerate(): void {
        if (root.thumbnailPath.length === 0) {
            root.source = "";
            return;
        }
        if (!root.generateThumbnail) {
            root.show(false);
            return;
        }
        const maxSize = Images.thumbnailSizes[root.thumbnailSizeName];
        const dest = FileUtils.trimFileProtocol(root.thumbnailPath);
        thumbnailGeneration.running = false;
        // Via a temp file: whoever catches a half-written png caches the decode error
        thumbnailGeneration.command = ["bash", "-c",
            `[ -f '${dest}' ] || { mkdir -p "$(dirname '${dest}')" && magick '${root.sourcePath}' -resize ${maxSize}x${maxSize} png:'${dest}.$$' && mv -f '${dest}.$$' '${dest}' && exit ${root.generatedExitCode}; } || { rm -f '${dest}.$$'; exit 1; }`
        ];
        thumbnailGeneration.running = true;
    }

    Process {
        id: thumbnailGeneration
        onExited: (exitCode, exitStatus) => {
            if (exitStatus !== 0) // Killed by a path change, which started its own run
                return;
            if (exitCode === 0 || exitCode === root.generatedExitCode) {
                root.show(exitCode === 0);
            } else if (root._retries < root.maxRetries) { // Source may not be on disk yet
                root._retries += 1;
                retryTimer.restart();
            }
        }
    }
    Timer {
        id: retryTimer
        interval: 1000 * root._retries
        onTriggered: root.regenerate()
    }
}
