# Widget design

A widget should read as a piece of ii, not as a separate app inside its window.
`tests/design-lint.sh` only catches hex colors and fonts outside `Appearance`; a
widget can pass it and still look foreign next to the shell. This page is the
part the lint can't check.

## Start from the host

Every slot has an upstream surface it replaces or sits next to: the media popup
for `mediaView`, the sidebar for `sidebarLeftTab`, the bar for the bar slots.
Find it (`rg -l <slot> dots/.config/quickshell/ii/modules/`), open it and its
neighbours, and take their tokens before laying anything out: radius, padding,
title font, button sizes, color roles. A deviation is a decision with a reason,
not a default. For `mediaView` the reference is
`modules/ii/mediaControls/PlayerControl.qml`.

Reuse before drawing: `StyledText`, `MaterialSymbol`, `RippleButton`,
`StyledSlider`, `ConfigSwitch`, `ConfigSelectionArray` and the rest of
`modules/common/widgets/`. New visual vocabulary (`MaterialShape` cookies,
chips, expressive fonts) only where upstream already uses it in a similar place.

## Shape and type

Radii come from the host. ii popups and panels derive theirs from the screen,
`Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1`;
nested corners step down the `Appearance.rounding` scale (2/6/8/12/17/23/30,
`full`). Surfaces take the host's role and its shadow
(`StyledRectangularShadow`, `elevationMargin`), with no border unless the host
has one.

ii typography is restrained. In popup cards a title is
`Appearance.font.pixelSize.large` in the default family, secondary text
`small`/`smaller` in `colSubtext`; `family.title`, `family.expressive`, `huge`
and `hugeass` belong to page headers and big numbers. Icon buttons in popup
cards are 24-44 px with `iconSize` from `Appearance.font.pixelSize`. These sizes
are taken from the popup cards; a sidebar tab or a settings page takes its own
host's.

## Color

Every background goes with the text of the same role: `colLayerN` with
`colOnLayerN`, `colPrimary` with `colOnPrimary`, `colSecondaryContainer` with
`colOnSecondaryContainer`, and so on. `colLayer0..4` are surfaces by elevation;
an element above a card takes the next layer, not a drop shadow. Hover and
pressed states are the ready `colXHover`/`colXActive`, through `RippleButton` or
`StateLayer` rather than a `MouseArea` with a hand-picked color.

A card tinted from an image or a color (`AdaptedMaterialScheme`, the way
`PlayerControl.qml` tints from the cover) takes every color on it from that
scheme: background, text, icons, slider. `Appearance.colors` on a tinted
background is a mixed pair, and a hand-made `ColorUtils.mix` for contrast is the
usual sign of one. Check light mode: tinted layers lose contrast there first.

Motion uses the `Appearance.animation` curves (`elementMove`,
`elementMoveFast`, `clickBounce`), not a hand-written easing.

## Content

Text you don't control (a title from a service, a path, an error) gets
`elide: Text.ElideRight` or `wrapMode` plus `Layout.fillWidth` or
`maximumWidth`. Raw stderr of a tool is never shown as is: map known failures
(dns, refused, timeout, auth) to a short phrase and cut the rest.

Design from the empty case, it is what most users see first. A header over an
empty list reads as a bug: hide it, or show where the data comes from. An empty
state is an icon, a line on what is missing and a line on what to do, in
`colSubtext`, not `colErrorContainer`. A missing dependency removes the section
rather than leaving it empty. Collapsed blocks set `implicitHeight` to 0 so they
leave no gap in a `ColumnLayout`.

Inside one container position either with anchors or with `Layout`, not both.

## Checking it

Look at pictures, not the diff. `tests/widget-probe.sh <widget> <slot> -g WxH`
renders a slot in an isolated instance; `tests/widget-shots.sh` renders your
`shots.txt` with a fixed palette (`-c` takes another one, e.g. a light palette
from `matugen`). Shoot a tight width and a comfortable one, the empty input,
light and dark, and a shot of the host surface in the same palette next to
yours: if your widget looks bigger, denser or "from another app" than its
neighbours, that is the bug.

[`ii-widget-player`](https://github.com/Berupor/ii-widget-player) is a popup
built this way against its upstream host, `PlayerControl.qml`.
[`ii-widget-vpn`](https://github.com/Berupor/ii-widget-vpn) (`VpnMenu.qml`, a
bar popup of rows and chips) and
[`ii-widget-peripheral-battery`](https://github.com/Berupor/ii-widget-peripheral-battery)
(`PeripheralBatteryTab.qml`, a sidebar tab of cards, with empty and single
scenes in `demo/`) follow the color and size rules.
