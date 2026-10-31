//@ probe hello -x tests/fixtures/hello -g 100x40 -s 1500
/**
 * The searchFilter slot: an enabled filter drops and masks results, a throwing one
 * keeps the result, a disabled one sees nothing.
 */
import qs.modules.common.models
import qs.modules.widgets
import QtQuick

Item {
    id: probe

    function results(names) {
        return names.map(name => resultComp.createObject(probe, { "name": name }));
    }

    function shown(results) {
        return WidgetCatalog.filterSearchResults(results).map(r => r.secret ? `${r.name}*` : r.name);
    }

    function checks() {
        WidgetsStore.setEnabled("hello", false);
        const disabled = probe.shown(probe.results(["drop", "secret key"]));
        WidgetsStore.setEnabled("hello", true);
        return [
            {
                "name": "the filter is in its slot",
                "got": WidgetCatalog.forSlot("searchFilter").map(w => w.widgetId),
                "want": ["hello"]
            },
            {
                "name": "disabled, results pass untouched",
                "got": disabled,
                "want": ["drop", "secret key"]
            },
            {
                "name": "enabled, dropped and masked",
                "got": probe.shown(probe.results(["firefox", "drop", "secret key"])),
                "want": ["firefox", "secret key*"]
            },
            {
                "name": "a throwing filter keeps the result",
                "got": probe.shown(probe.results(["throw"])),
                "want": ["throw"]
            }
        ];
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
