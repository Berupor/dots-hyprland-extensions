#!/usr/bin/env python3
"""Recolor Telegram Desktop's base palette with the generated Material colors.

Telegram watches the applied theme file and reloads it on every write, and
re-reads it on startup, so writing the file is enough. Apply it once by hand:
Settings > Chat settings > Chat background > Choose from file, pick the
generated palette, then press Keep changes within 16 seconds. Not the theme
editor's Import - that stores the theme under tdata and the file stops being
watched, as does saving it to the cloud.
"""

import argparse
import colorsys
import json
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
DEFAULT_COLORS = f"{STATE}/quickshell/user/generated/colors.json"
DEFAULT_OUT = f"{STATE}/quickshell/user/generated/telegram/matugen.tdesktop-palette"

# base palette -> accent of the tdesktop theme it was exported from
BASES = {
    True: (f"{HERE}/telegram-night-base.tdesktop-palette", "#5288c1"),
    False: (f"{HERE}/telegram-day-base.tdesktop-palette", "#40a7e3"),
}

HUE_THRESHOLD = 15       # tdesktop ColorizerFrom()
LIGHTNESS_MIN = 64
LIGHTNESS_MAX = 160
CONTRAST_ENOUGH = 64
PASTEL_SAT = 0.35        # accent saturation scale, 1 keeps the Material color
NEUTRAL_SAT = 140        # HSV saturation below this, near the base hue, is a gray
NEUTRAL_HUE_SPAN = 25

ENTRY = re.compile(r"^(\w+):\s*([^;]+);(.*)$")

# tdesktop kColorizeIgnoredKeys: peer, file and premium colors are fixed by design
IGNORED = set("""boxTextFgGood boxTextFgError callIconFg mediaviewFileRedCornerFg
mediaviewFileYellowCornerFg mediaviewFileGreenCornerFg mediaviewFileBlueCornerFg
settingsIconBg1 settingsIconBg2 settingsIconBg3 settingsIconBg4 settingsIconBg5
settingsIconBg6 settingsIconBg8 settingsIconBgArchive premiumButtonBg1
premiumButtonBg2 premiumButtonBg3 premiumIconBg1 premiumIconBg2""".split())
IGNORED |= {f"historyPeer{i}{s}" for i in range(1, 9)
            for s in ("NameFg", "NameFgSelected", "UserpicBg", "UserpicBg2")}
IGNORED |= {f"msgFile{i}{s}" for i in range(1, 5)
            for s in ("Bg", "BgDark", "BgOver", "BgSelected")}

# name -> (color to stay readable on, replacement when contrast is lost)
KEEP_CONTRAST = {
    "activeButtonFg": ("#2f6ea5", "#17212b"),
    "profileVerifiedCheckFg": ("#5288c1", "#17212b"),
    "overviewCheckFgActive": ("#5288c1", "#17212b"),
    "historyFileInIconFg": ("#3f96d0", "#182533"),
    "historyFileInIconFgSelected": ("#6ab4f4", "#2e70a5"),
    "historyFileInRadialFg": ("#3f96d0", "#182533"),
    "historyFileInRadialFgSelected": ("#6ab4f4", "#2e70a5"),
    "historyFileOutIconFg": ("#4c9ce2", "#2b5278"),
    "historyFileOutIconFgSelected": ("#58abf3", "#2e70a5"),
    "historyFileOutRadialFg": ("#4c9ce2", "#2b5278"),
    "historyFileOutRadialFgSelected": ("#58abf3", "#2e70a5"),
}


def parse_hex(value):
    v = value.lstrip("#")
    parts = [int(v[i:i + 2], 16) for i in range(0, len(v), 2)]
    return tuple(parts[:3]), (parts[3] if len(parts) > 3 else None)


def fmt_hex(rgb, alpha):
    out = "#" + "".join(f"{c:02x}" for c in rgb)
    return out + ("" if alpha is None else f"{alpha:02x}")


def to_hsv(rgb):
    """Qt getHsv(): hue is -1 for grays, saturation and value are 0-255."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    return (-1 if s == 0 else round(h * 360) % 360, round(s * 255), round(v * 255))


def from_hsv(hsv):
    h, s, v = hsv
    rgb = colorsys.hsv_to_rgb(max(h, 0) % 360 / 360, s / 255, v / 255)
    return tuple(round(c * 255) for c in rgb)


def lightness(rgb):
    """HSL lightness, 0-255, the same measure QColor::lightness() reports."""
    return (max(rgb) + min(rgb)) / 2


def to_hls(rgb):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    return h * 360, l * 255, s


def from_hls(h, l, s):
    rgb = colorsys.hls_to_rgb(h % 360 / 360, min(max(l, 0), 255) / 255, min(max(s, 0), 1))
    return tuple(round(c * 255) for c in rgb)


class Colorizer:
    """tdesktop's accent shift: hue-rotate the blues, leave every other hue alone."""

    def __init__(self, base_accent, accent):
        h, l, s = to_hls(accent)
        self.was = to_hsv(base_accent)
        self.now = to_hsv(from_hls(h, min(max(l, LIGHTNESS_MIN), LIGHTNESS_MAX), s))

    def shift(self, hsv):
        h, s, v = hsv
        wh, ws, wv = self.was
        nh, ns, nv = self.now
        if abs(h - wh) >= HUE_THRESHOLD:
            return None
        if s > ws and ns > ws:
            s2 = (ns * (255 - ws) + (s - ws) * (255 - ns)) // (255 - ws)
        elif s != ws and ws != 0:
            s2 = s * ns // ws
        else:
            s2 = ns
        if v > wv:
            v2 = (nv * (255 - wv) + (v - wv) * (255 - nv)) // (255 - wv)
        elif v < wv:
            v2 = v * nv // wv
        else:
            v2 = nv
        return ((h + nh - wh + 360) % 360, s2, v2)

    def apply(self, name, rgb):
        hsv = to_hsv(rgb)
        shifted = self.shift(hsv)
        pair = KEEP_CONTRAST.get(name)
        if pair is None:
            return from_hsv(shifted) if shifted else rgb
        check, replace = (to_hsv(parse_hex(c)[0]) for c in pair)
        hsv_lightness = lambda c: c[2] - c[2] * c[1] // 511
        checked = self.shift(check) or check
        if abs(hsv_lightness(shifted or hsv) - hsv_lightness(checked)) >= CONTRAST_ENOUGH:
            return from_hsv(shifted) if shifted else rgb
        return from_hsv(self.shift(replace) or replace)


class Neutrals:
    """Move the base grays onto the Material surface..on_surface line.

    Lightness and the tint (offset from the gray of that lightness) interpolate
    separately - HLS saturation degenerates to 1 near white and would push the
    mid grays of a light scheme far off hue.
    """

    def __init__(self, base_accent, base_bg, base_fg, dark, light):
        split = lambda c: (lightness(c), [v - lightness(c) for v in c])
        self.base_hue = to_hsv(base_accent)[0]
        self.src = (lightness(base_bg), lightness(base_fg))
        self.dst = (split(dark), split(light))

    def is_neutral(self, hsv):
        h, s, _ = hsv
        return s < NEUTRAL_SAT and (h < 0 or abs(h - self.base_hue) <= NEUTRAL_HUE_SPAN)

    def remap(self, rgb):
        (l0, tint0), (l1, tint1) = self.dst
        t = (lightness(rgb) - self.src[0]) / (self.src[1] - self.src[0])
        l = l0 + (l1 - l0) * t
        return tuple(round(min(max(l + a + (b - a) * t, 0), 255))
                     for a, b in zip(tint0, tint1))


def generate(base_text, base_accent, colors):
    lines = [(ENTRY.match(line), line) for line in base_text.splitlines()]
    literal = {m.group(1): m.group(2) for m, _ in lines if m and m.group(2)[0] == "#"}
    base_accent = parse_hex(base_accent)[0]
    # tdesktop fills its accent areas with light text, so take the darker role
    accent = min((parse_hex(colors[r])[0] for r in ("primary", "primary_container")),
                 key=lambda c: to_hls(c)[1])
    h, l, s = to_hls(accent)
    colorizer = Colorizer(base_accent, from_hls(h, l, s * PASTEL_SAT))
    neutrals = Neutrals(
        base_accent,
        parse_hex(literal["windowBg"])[0],
        parse_hex(literal["windowFg"])[0],
        parse_hex(colors["surface"])[0],
        parse_hex(colors["on_surface"])[0])

    out = ["// generated from the wallpaper by apply_telegram.py, edits are lost"]
    for match, line in lines:
        if not match or match.group(2)[0] != "#":
            out.append(line)
            continue
        name, value, tail = match.groups()
        rgb, alpha = parse_hex(value)
        if name in IGNORED:
            new = rgb
        elif neutrals.is_neutral(to_hsv(rgb)):
            new = neutrals.remap(rgb)
        else:
            new = colorizer.apply(name, rgb)
        out.append(f"{name}: {fmt_hex(new, alpha)};{tail}")
    return "\n".join(out) + "\n"


def write(path, text):
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".palette.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--colors", default=DEFAULT_COLORS)
    ap.add_argument("--base", help="override the auto-picked day/night base palette")
    ap.add_argument("--accent", help="accent of --base, needed only with --base")
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()

    with open(args.colors, encoding="utf-8") as f:
        colors = json.load(f)
    needed = ("primary", "primary_container", "surface", "on_surface")
    missing = [r for r in needed if r not in colors]
    if missing:
        print(f"[apply_telegram] colors.json lacks {', '.join(missing)}", file=sys.stderr)
        return 1

    dark = to_hls(parse_hex(colors["surface"])[0])[1] < to_hls(parse_hex(colors["on_surface"])[0])[1]
    base_path, base_accent = BASES[dark]
    base_path = args.base or base_path
    base_accent = args.accent or base_accent
    with open(base_path, encoding="utf-8") as f:
        base = f.read()
    write(args.out, generate(base, base_accent, colors))
    return 0


if __name__ == "__main__":
    sys.exit(main())
