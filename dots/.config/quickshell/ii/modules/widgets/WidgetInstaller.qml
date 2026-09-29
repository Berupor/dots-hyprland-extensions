pragma Singleton
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Widgets installed with git into the user widget dir: clone to add, pull to
 * update, delete the directory to remove. One job at a time, `busy` while it runs.
 */
Singleton {
    id: root

    enum State {
        Idle, Working, Done, Failed
    }

    property int state: WidgetInstaller.State.Idle
    property string message: ""
    property string job: "" // Widget id being worked on, "" for an install
    readonly property bool busy: root.state === WidgetInstaller.State.Working

    /// A pull swapped files under a running shell, which keeps the ones it loaded.
    /// An install needs none of this: those files are new to the engine
    property bool needsReload: false

    /// Reloads the shell running the widgets, this process or another one. The
    /// settings window is a process of its own and holds its own copy of the
    /// manifests, so it is told too, or its cards keep the options of the old one
    function reloadShell() {
        root.needsReload = false;
        root.message = Translation.tr("Reloading the shell"); // Nothing else changes in this window
        for (const path of ["", "settings.qml"])
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(path), "ipc", "call", "widgets", "reload"]);
    }

    /// Directory to clone into: the repo name, ssh and https urls alike
    function idFor(url) {
        return String(url).trim().replace(/\/+$/, "").split(/[\/:]/).pop().replace(/\.git$/, "");
    }

    /// Directory name inside the widget dir, "" for anything we did not install.
    /// Names, never paths: the scripts below rebuild the path and refuse slashes
    function nameOf(widgetId) {
        const base = WidgetCatalog.externalDir === "" ? "" : `${WidgetCatalog.externalDir}/`;
        const dir = String(WidgetCatalog.widgets.find(w => w.widgetId === widgetId)?.dir ?? "").replace(/^file:\/\//, "");
        if (base === "" || !dir.startsWith(base))
            return "";
        const name = dir.slice(base.length);
        return root.sane(name) ? name : "";
    }

    function sane(name) {
        return name !== "" && !name.includes("/") && !name.startsWith(".");
    }

    /// Clones aside, names the directory after the widget id, then moves it in.
    /// `asId` is who to report progress to, empty for the url field
    function install(url, asId) {
        const job = asId ?? "";
        if (String(url).trim() === "") {
            root.fail(job, Translation.tr("Enter a repository url"));
            return;
        }
        root.run(job, ["env", `IU=${String(url).trim()}`, `IN=${root.idFor(url)}`, `IW=${WidgetCatalog.externalDir}`, `IS=${Directories.shellConfig}/.widget-install`, "bash", "-c", `
            set -e
            rm -rf -- "$IS" # Staging sits outside the widget dir: a half clone is not a widget
            mkdir -p "$IW"
            git clone --depth 1 -- "$IU" "$IS" 2>&1
            if [ ! -f "$IS/Manifest.qml" ]; then rm -rf -- "$IS"; echo "No Manifest.qml in $IN"; exit 1; fi
            id=$(sed -n 's/.*widgetId:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$IS/Manifest.qml" | head -1)
            [ -n "$id" ] || id="$IN" # No literal in the manifest, fall back to the repo name
            case "$id" in */*|.*|"") rm -rf -- "$IS"; echo "Bad widget id"; exit 1;; esac
            if [ -e "$IW/$id" ]; then rm -rf -- "$IS"; echo "Already installed: $id"; exit 1; fi
            mv -- "$IS" "$IW/$id"
            echo "Installed $id"`]);
    }

    function update(widgetId) {
        const name = root.nameOf(widgetId);
        if (!root.owns(widgetId, name))
            return;
        root.run(widgetId, ["env", `IN=${name}`, `IW=${WidgetCatalog.externalDir}`, "bash", "-c", `
            set -e
            case "$IN" in */*|.*|"") echo "Not a widget directory"; exit 1;; esac
            d="$IW/$IN"
            v() { sed -n 's/^[[:space:]]*version:[[:space:]]*"\\([^"]*\\)".*/\\1/p' "$d/Manifest.qml" | head -1; }
            was=$(git -C "$d" rev-parse HEAD)
            if [ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]; then
                echo "Files in $d were edited by hand and block the update. Discard the edits with: git -C $d checkout ."
                exit 1
            fi
            out=$(git -C "$d" pull --ff-only 2>&1) || { echo "$out" | grep -m1 -E '^(error|fatal)' || echo "$out" | tail -1; exit 1; }
            [ "$was" = "$(git -C "$d" rev-parse HEAD)" ] && { echo "$out" | tail -1; exit 0; }
            now=$(v) # The prefix asks for a reload, see needsReload
            echo "reload:Updated\${now:+ to $now}"`]);
    }

    /// Deletes a directory, so it goes by name and only where a Manifest.qml sits
    function remove(widgetId) {
        const name = root.nameOf(widgetId);
        if (!root.owns(widgetId, name))
            return;
        WidgetsStore.setEnabled(widgetId, false); // A gone widget left enabled would come back with a reinstall
        root.run(widgetId, ["env", `IN=${name}`, `IW=${WidgetCatalog.externalDir}`, "bash", "-c", `
            set -e
            case "$IN" in */*|.*|"") echo "Not a widget directory"; exit 1;; esac
            d="$IW/$IN"
            if [ ! -f "$d/Manifest.qml" ]; then echo "Not a widget directory"; exit 1; fi
            rm -rf -- "$d"
            echo Removed`]);
    }

    /// Only ever touch directories we installed ourselves
    function owns(widgetId, name) {
        if (name !== "")
            return true;
        root.fail(widgetId, Translation.tr("%1 is not installed here").arg(widgetId));
        return false;
    }

    function fail(widgetId, message) {
        root.job = widgetId;
        root.message = message; // Before the state, whoever watches it reads the message
        root.state = WidgetInstaller.State.Failed;
    }

    function run(widgetId, command) {
        if (root.busy)
            return;
        root.job = widgetId;
        root.state = WidgetInstaller.State.Working;
        root.message = "";
        proc.command = command;
        proc.running = true;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: output
        }
        stderr: StdioCollector {
            id: errors
        }
        onExited: exitCode => {
            // git talks in many lines and the last one says what happened
            const lines = `${output.text}\n${errors.text}`.trim().split("\n").filter(l => l.trim() !== "");
            const last = lines.pop() ?? (exitCode === 0 ? Translation.tr("Done") : Translation.tr("git failed"));
            root.needsReload = root.needsReload || last.startsWith("reload:");
            root.message = last.replace(/^reload:/, "");
            root.state = exitCode === 0 ? WidgetInstaller.State.Done : WidgetInstaller.State.Failed;
        }
    }
}
