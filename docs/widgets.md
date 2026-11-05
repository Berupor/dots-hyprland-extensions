# Widget contract

A widget is a folder with `Manifest.qml` and the slot files it lists. The full
contract lives as the header comment in
[`WidgetManifest.qml`](../dots/.config/quickshell/ii/modules/widgets/WidgetManifest.qml);
this page is the public, browsable half of it, kept in sync with the slots and
option types below by `tests/verify-widget-docs.sh`. Start from
[`ii-widget-hello`](https://github.com/Berupor/ii-widget-hello) instead of an
empty folder.

Required properties are `widgetId` and `minShellVersion`; everything else on
`WidgetManifest` has a sane default. `dependencies` lists binaries checked with
`command -v` - missing ones grey out the card. `options` are read back with
`WidgetCatalog.option(widgetId, key)` or `optionValue(key)` from the manifest
itself, never restated as a literal default anywhere else. An option with a
`label` is drawn on the card by the catalog; one without is for `settingsPage`
to render, which lands inside the card so it wants `ContentSubsection`, not
`ContentSection`.

## Slots

| Slot               | Since | Required fields | Notes                                                                                                              |
| ------------------ | ----- | ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| `barIndicator`     | 1.0   | -               | Bar icon. Also drawn in the vertical bar if `orientations` lists it.                                               |
| `barGauge`         | 1.3   | -               | Resource-circle style: icon plus a number, next to CPU/RAM in the bar.                                             |
| `barUtilButton`    | 1.0   | -               | Bar utility button. Horizontal bar only - the vertical one has no utility group.                                   |
| `backgroundWidget` | 1.0   | -               | Desktop background layer, stays loaded while enabled - gate side effects on your own option.                       |
| `screenOverlay`    | 1.4   | -               | Click-through layer above windows, loaded once per screen and handed `screen`. Mapped only while an item's `shown` is true; size to `screen.width` x `screen.height`. |
| `unlockHook`       | 1.5   | -               | Runs once per password unlock of the lock screen: `unlocked(password)` gets the login password PAM accepted, then the object is destroyed, so hand the work to something that outlives it (a singleton of your own, `Quickshell.execDetached`). Skipped on fingerprint unlock, and until the user allows it on the card for this exact code; an update asks again. |
| `searchFilter`     | 1.7   | -               | Stays loaded, `filter(result)` sees each overview search result before it is drawn. Returning `false` drops it; setting `secret` masks its text and keeps Tab from pasting it into the search field. Clipboard entries carry `rawValue`. |
| `service`          | 1.8   | -               | Non-visual object, built once and kept while the widget is enabled, destroyed when it is switched off. The place for an `IpcHandler`, a `Timer` or a `Process` that runs without a drawn surface. |
| `catalogView`      | 1.0   | -               | Replaces the whole Widgets settings page.                                                                          |
| `settingsView`     | 1.0   | -               | Replaces the whole settings window, titlebar included.                                                             |
| `calendarView`     | 1.6   | -               | Replaces the Calendar tab of the right sidebar's bottom group, about 354x350.                                      |
| `translatorView`   | 1.12  | -               | Replaces the Translator tab of the left sidebar, which shows while the widget is enabled even with the built-in one off. |
| `barView`          | 1.9   | -               | Stays loaded and fills the horizontal bar; while its item's `active` is true it replaces the bar content, the bar background stays. False or no widget leaves the built-in bar. |
| `mediaView`        | 1.10  | -               | Replaces the player cards of the media popup, `mediaControlsWidth` wide; the popup takes the item's implicit height. Players come from `MprisController`. |
| `quickToggle`      | 1.11  | -               | A `QuickToggleModel` (`name`, `icon`, `toggled`, `statusText`, `mainAction`, `altAction`; `hasMenu` is ignored), drawn as a tile of the android-style quick toggles. The user places it in the grid's edit mode. |
| `notificationFilter` | 1.11 | -              | Stays loaded, `filter(n)` sees a frozen snapshot of each incoming notification (`appName`, `summary`, `body`, `urgency` low/normal/critical, `actions`, ...) before it is shown or stored. `false` drops it, `"silent"` keeps it in the list without a popup; a critical one is never dropped, only silenced. A throw keeps it. Synchronous, so stay fast. |
| `lockWidget`       | 1.11  | -               | Drawn at the top centre of each lock screen, built only while locked, clipped to 360x160, no input or focus, handed `screenName` and nothing else. Runs only after the user allows it on the card for this exact code; anyone at the screen sees it. |
| `regionAction`     | 1.0   | `name`          | Offered during region selection (ipc `region widget <name>`). Exposes `available` and `perform(path, x, y, w, h)`. |
| `sidebarLeftTab`   | 1.0   | `name`, `icon`  | Tab in the left sidebar.                                                                                           |
| `sidebarRightTab`  | 1.0   | `name`, `icon`  | Tab in the right sidebar.                                                                                          |

A slot entry is a bare path string, or an object carrying `path` plus the fields
above. Bar slots (`barIndicator`, `barGauge`, `barUtilButton`) also take
`orientations: ["horizontal", "vertical"]`, default `["horizontal"]` - a bar host
only draws a widget for the orientations it lists.

## Option types

- `switch` - boolean, drawn as `ConfigSwitch`.
- `spinBox` - numeric stepper, takes `min`/`max`/`step`.
- `textField` - free text, takes `placeholder`, committed to the store on a short debounce.

## Versions

`WidgetCatalog.shellVersion` is the contract's version, not the shell's or the
repo's: minor up when it grows (a slot, a manifest property, an option type),
major up when it breaks. A widget's `minShellVersion` has to match the same
major and be no newer than the shell's, or its card shows "Built for shell X,
this is Y" and it does not load. 1.0 is the baseline; 1.1 added `textField`;
1.2 added `orientations` for the vertical bar; 1.3 added `barGauge` and
`WidgetSlot.spacingBefore`; 1.4 added `screenOverlay`; 1.5 added `unlockHook`; 1.6 added `calendarView`; 1.7 added `searchFilter`; 1.8 added `service`; 1.9 added `barView`; 1.10 added `mediaView`; 1.11 added `quickToggle`, `notificationFilter`, `lockWidget` and `WidgetCatalog.showOsd`; 1.12 added `translatorView`.

Any slot file can call `WidgetCatalog.showOsd(widgetId, {icon, text, value})` to show
the shell's OSD pill: `icon` a Material symbol, `value` 0..1 draws the bar and is
optional. It replaces whatever OSD is up and uses the shell's timeout; a disabled
widget's call is dropped.

## External widgets

Installed at `~/.config/illogical-impulse/widgets/<id>/` (the folder name has to match `widgetId`), outside the shell
tree, by pasting a git url on the Widgets page. Same contract as a bundled
widget, two differences: its own singletons need a `qmldir` next to them
(`singleton Foo 1.0 Foo.qml`), and it cannot `import` its own directory as a
module.

Native code, root access, udev rules, anything that needs to run without a
session - out of scope. List the binary in `dependencies`, explain it in your
README, the user installs it themselves. The catalog never ships or enables
executables of its own.

## Before publishing

`tests/design-lint.sh <your-repo>` and `tests/qml-cases.sh -x <your-repo>` clean,
a `demo/` scene that doubles as your test and your README screenshot -
`ii-widget-hello` has the shape of both - and, if your `settingsPage` writes to
the store itself, an idempotent write: whatever your `onXChanged` handler hands
`setOption` has to match what the binding just read from `optionValue()`,
because that handler also fires on the binding's own initial assignment, not
just on user input. Prefer a real commit signal where the control has one
(`SpinBox.valueModified`, `TextField.editingFinished`) - it skips that spurious
write-back. Continuous input (typing, dragging) has no such signal, so the
idempotent on-changed write is the pattern there, not a shortcut around one.
