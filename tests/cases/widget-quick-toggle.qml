//@ probe hello -x tests/fixtures/hello -g 320x200 -s 1500
/**
 * A widget's quickToggle slot: the tile in the Android panel and its place in edit mode.
 */
import qs.modules.widgets
import qs.modules.ii.sidebarRight.quickToggles
import qs.modules.ii.sidebarRight.quickToggles.androidStyle
import QtQuick

Item {
    id: probe


    function checks() {
        const hello = helloTile;
        const built = hello.built;
        const before = hello.toggled;
        hello.mainAction();
        const flipped = hello.toggled;
        hello.editMode = true;
        const keptOnEdit = hello.built === built;
        hello.editMode = false;

        const gone = goneTile;
        const goneHidden = gone.visible;
        const goneEdit = goneEditTile;

        WidgetsStore.setEnabled("hello", false);
        const disabled = hello.visible;
        const disabledBuilt = hello.built;
        WidgetsStore.setEnabled("hello", true);
        const rebuilt = hello.built !== null && hello.built !== built;

        return [
            {
                "name": "a bare path is valid for quickToggle",
                "got": WidgetCatalog.slotProblems({ "slots": { "quickToggle": "Toggle.qml" } }),
                "want": []
            },
            {
                "name": "the widget reaches the slot",
                "got": WidgetCatalog.forSlot("quickToggle").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "a tile of an enabled widget shows",
                "got": hello.visible,
                "want": true
            },
            {
                "name": "it carries the model's name",
                "got": hello.name,
                "want": "Hello Toggle"
            },
            {
                "name": "and its icon",
                "got": hello.buttonIcon,
                "want": "waving_hand"
            },
            {
                "name": "the model starts off",
                "got": before,
                "want": false
            },
            {
                "name": "mainAction flips the model and the tile follows",
                "got": flipped,
                "want": true
            },
            {
                "name": "edit mode does not rebuild the model",
                "got": keptOnEdit,
                "want": true
            },
            {
                "name": "a widget that is gone is hidden outside edit mode",
                "got": goneHidden,
                "want": false
            },
            {
                "name": "and shown in edit mode, so the entry can be removed",
                "got": goneEdit.visible,
                "want": true
            },
            {
                "name": "a stale tile builds nothing",
                "got": goneEdit.built,
                "want": null
            },
            {
                "name": "a disabled widget's tile hides",
                "got": disabled,
                "want": false
            },
            {
                "name": "and drops its model",
                "got": disabledBuilt,
                "want": null
            },
            {
                "name": "enabling again builds a fresh model",
                "got": rebuilt,
                "want": true
            },
            {
                "name": "the panel offers the widget among the toggles",
                "got": panel.availableToggleTypes.includes("widget:hello"),
                "want": true
            },
            {
                "name": "the built-ins are still offered",
                "got": panel.availableToggleTypes.includes("network"),
                "want": true
            },
            {
                "name": "the chooser's catch-all gives a widget type the widget tile",
                "got": chosen.itemAt(0)?.name ?? "",
                "want": "Hello Toggle"
            },
            {
                "name": "and leaves a built-in type to its own delegate",
                "got": chosenBuiltin.itemAt(0)?.widgetId ?? "built-in",
                "want": "built-in"
            }
        ];
    }

    WidgetQuickToggle {
        id: helloTile
        buttonIndex: 0
        buttonData: ({ "type": "widget:hello", "size": 1 })
        expandedSize: false
        baseCellWidth: 56
        baseCellHeight: 56
        cellSpacing: 6
        cellSize: 1
    }

    WidgetQuickToggle {
        id: goneTile
        buttonIndex: 0
        buttonData: ({ "type": "widget:gone", "size": 1 })
        expandedSize: false
        baseCellWidth: 56
        baseCellHeight: 56
        cellSpacing: 6
        cellSize: 1
    }

    WidgetQuickToggle {
        id: goneEditTile
        buttonIndex: 0
        buttonData: ({ "type": "widget:gone", "size": 1 })
        editMode: true
        expandedSize: false
        baseCellWidth: 56
        baseCellHeight: 56
        cellSpacing: 6
        cellSize: 1
    }

    Repeater {
        id: chosen
        model: [{ "type": "widget:hello", "size": 1 }]
        delegate: AndroidToggleDelegateChooser {
            startingIndex: 0
            baseCellWidth: 56
            baseCellHeight: 56
            spacing: 6
        }
    }

    Repeater {
        id: chosenBuiltin
        model: [{ "type": "darkMode", "size": 1 }]
        delegate: AndroidToggleDelegateChooser {
            startingIndex: 0
            baseCellWidth: 56
            baseCellHeight: 56
            spacing: 6
        }
    }

    AndroidQuickPanel {
        id: panel
        width: 300
    }
}
