//@ probe hello -x tests/fixtures/hello -g 560x760 -s 1500
/**
 * Catalog cards for an installed widget, a bundled one and one built for a shell
 * that isn't this one: only the installed one is marked, only the last one is barred.
 */
import qs.modules.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: probe

    readonly property var installed: WidgetCatalog.widgets.find(w => w.widgetId === "hello") ?? null

    // No widget ships in the tree any more, so the bundled one is a manifest right here
    WidgetManifest {
        id: bundled
        widgetId: "bundled"
        name: "Bundled"
        description: "Comes with the shell, so it is nobody's to remove"
    }

    WidgetManifest {
        id: future
        widgetId: "future"
        name: "Future"
        description: "Asks for a contract this shell does not have"
        minShellVersion: "9.0"
    }

    // external so the card opens without the store, see canExpand
    WidgetManifest {
        id: everyOption
        widgetId: "everyOption"
        name: "Every option"
        description: "One control per option type"
        external: true
        options: [
            {
                key: "sw",
                type: "switch",
                label: "Switch",
                icon: "toggle_on",
                default: true
            },
            {
                key: "num",
                type: "spinBox",
                label: "Number",
                icon: "timer",
                min: 0,
                max: 10,
                default: 3
            },
            {
                key: "text",
                type: "textField",
                label: "Text",
                icon: "edit",
                placeholder: "Empty",
                default: ""
            }
        ]
    }

    WidgetManifest {
        id: noOption
        widgetId: "noOption"
        name: "No options"
        description: "Nothing to draw, same card otherwise"
        external: true
    }

    /// Option rows of a card, whatever else its body holds
    function optionRows(card) {
        return card.bodyData.filter(o => o.modelData !== undefined).map(o => o.item.contentItem ?? o.item); // ConfigSwitch draws through contentItem
    }

    /// Where each row puts its label, in card coordinates: the rows line up only if these match
    function labelXs(card) {
        const find = (item, want) => {
            for (const kid of item.children ?? []) {
                if (kid.text === want)
                    return kid;
                const hit = find(kid, want);
                if (hit)
                    return hit;
            }
            return null;
        };
        return probe.optionRows(card).map((row, i) => {
            const label = find(row, card.drawnOptions[i].label);
            return label ? Math.round(label.mapToItem(card, 0, 0).x) : -1;
        });
    }

    /// And where each row's control ends, for the trailing column
    function controlRights(card) {
        return probe.optionRows(card).map(row => {
            const control = row.children[row.children.length - 1];
            return Math.round(control.mapToItem(card, 0, 0).x + control.width);
        });
    }

    /// A contract version relative to this shell's, so a bump does not rewrite the checks
    function contract(dMajor, dMinor) {
        const parts = WidgetCatalog.shellVersion.split(".").map(Number);
        return `${parts[0] + dMajor}.${parts[1] + dMinor}`;
    }

    function checks() {
        const writtenByExpanding = WidgetsStore.data.options?.everyOption ?? null;
        cards.itemAt(3).bodyData.find(o => o.modelData?.key === "sw").item.clicked();
        return [
            {
                "name": "expanding a card writes no option",
                "got": writtenByExpanding,
                "want": null
            },
            {
                "name": "a click on a switch does",
                "got": cards.itemAt(3).manifest.optionValue("sw"),
                "want": false
            },
            {
                "name": "the installed widget is marked external",
                "got": probe.installed?.external ?? null,
                "want": true
            },
            {
                "name": "a bundled widget is not",
                "got": bundled.external,
                "want": false
            },
            {
                // The probe runs on a throwaway XDG_CONFIG_HOME, so only the tail is stable
                "name": "the marker points at the widget dir",
                "got": (cards.itemAt(0)?.originText?.split("\n")[0] ?? "").replace(/^Installed in .*(\/illogical-impulse\/)/, "$1"),
                "want": "/illogical-impulse/widgets/hello"
            },
            {
                "name": "and carries author and version",
                "got": cards.itemAt(0)?.originText?.split("\n")[1] ?? "",
                "want": "tests · 1.0"
            },
            {
                "name": "cards render at full width",
                "got": (cards.itemAt(0)?.width ?? 0) === probe.width && (cards.itemAt(1)?.width ?? 0) === probe.width,
                "want": true
            },
            {
                // Update and remove live in the body, and a widget is usually off when removed
                "name": "an installed widget opens while switched off",
                "got": (cards.itemAt(0)?.widgetEnabled ?? true) === false && (cards.itemAt(0)?.bodyShown ?? false),
                "want": true
            },
            {
                "name": "a bundled one does not",
                "got": cards.itemAt(1)?.canExpand ?? true,
                "want": false
            },
            {
                "name": "dotted versions compare by number",
                "got": [["1.10", "1.9"], ["1.0", "1.0.0"], ["1.2", "2.0"]].map(p => WidgetCatalog.compareVersions(p[0], p[1])),
                "want": [1, 0, -1]
            },
            {
                "name": "the contract runs its own major, up to its own version",
                "got": ["1.0", probe.contract(0, 0), probe.contract(-1, 0), probe.contract(0, 1), probe.contract(1, 0)].map(v => WidgetCatalog.supports(v)),
                "want": [true, true, false, false, false]
            },
            {
                // Its deps are fine, the contract is not, and available is the author's to override
                "name": "a widget from another contract is not usable",
                "got": [future.available, future.supported, future.usable],
                "want": [true, false, false]
            },
            {
                "name": "and its card says which contract it wanted",
                "got": cards.itemAt(2)?.statusText ?? "",
                "want": `Built for shell 9.0, this is ${WidgetCatalog.shellVersion}`
            },
            {
                "name": "a widget that runs shows what it does instead",
                "got": cards.itemAt(0)?.statusText ?? "",
                "want": probe.installed?.description ?? ""
            },
            {
                // A type the card cannot draw loads nothing, so the body stays that much shorter
                "name": "every option type draws a control",
                "got": (cards.itemAt(3)?.implicitHeight ?? 0) - (cards.itemAt(4)?.implicitHeight ?? 0) > 100,
                "want": true
            },
            {
                "name": "every row hangs its label on one column",
                "got": [probe.labelXs(cards.itemAt(3)).length, probe.labelXs(cards.itemAt(3)).every((x, i, xs) => x > 0 && x === xs[0])],
                "want": [3, true]
            },
            {
                "name": "and its control on one right edge",
                "got": probe.controlRights(cards.itemAt(3)).every((x, i, xs) => x === xs[0]),
                "want": true
            }
        ];
    }

    Timer { // The probe enables what it probes, and removal is a thing you do to an off widget
        running: true
        interval: 300
        onTriggered: {
            WidgetsStore.setEnabled("hello", false);
            cards.itemAt(0).expanded = true;
            cards.itemAt(3).expanded = true;
            cards.itemAt(4).expanded = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Repeater {
            id: cards
            model: [probe.installed, bundled, future, everyOption, noOption].filter(m => m !== null)
            delegate: WidgetCard {
                required property var modelData
                manifest: modelData
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
