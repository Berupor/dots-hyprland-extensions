#!/usr/bin/env python3
"""Push generated Material colors into a Vivaldi user theme.

Edits Preferences when the browser is not running - that is the normal
path, and the ~/.local/bin/vivaldi wrapper calls this script right before
launching, so a wallpaper change lands on the next browser start.

Live-patching a running Vivaldi over the DevTools protocol still works, but
needs --remote-debugging-port open permanently, and any local process can
then drive the browser: cookies, sessions, actions past 2FA. Not worth it
for a colour scheme, so the flag is deliberately absent.
"""

import argparse
import base64
import json
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import urllib.request

# Vivaldi theme slot <- Material role
ROLES = {
    "colorBg": "surface_container_lowest",
    "colorFg": "on_surface",
    "colorAccentBg": "primary_container",
    "colorHighlightBg": "primary",
}

STATE = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
DEFAULT_COLORS = f"{STATE}/quickshell/user/generated/colors.json"
DEFAULT_PROFILE = f"{CONFIG}/vivaldi/Default"


def log(msg):
    print(f"[apply_vivaldi] {msg}", file=sys.stderr)


# --- minimal websocket client (stdlib only) ---------------------------------

class WS:
    def __init__(self, url, timeout=5):
        _, rest = url.split("://", 1)
        hostport, _, path = rest.partition("/")
        host, _, port = hostport.partition(":")
        self.sock = socket.create_connection((host, int(port or 80)), timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall(
            f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n".encode()
        )
        self.buf = b""
        while b"\r\n\r\n" not in self.buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise OSError("handshake closed")
            self.buf += chunk
        head, self.buf = self.buf.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise OSError(f"handshake failed: {head.splitlines()[0]!r}")

    def _recv(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise OSError("closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def send(self, text):
        data = text.encode()
        n = len(data)
        header = b"\x81"
        if n < 126:
            header += struct.pack("!B", 0x80 | n)
        elif n < 1 << 16:
            header += struct.pack("!BH", 0x80 | 126, n)
        else:
            header += struct.pack("!BQ", 0x80 | 127, n)
        mask = os.urandom(4)
        self.sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def recv(self):
        while True:
            b0, b1 = self._recv(2)
            opcode, n = b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack("!H", self._recv(2))[0]
            elif n == 127:
                n = struct.unpack("!Q", self._recv(8))[0]
            payload = self._recv(n)
            if opcode == 0x9:  # ping
                self.sock.sendall(b"\x8a\x80" + os.urandom(4))
                continue
            if opcode == 0x8:
                raise OSError("closed by peer")
            if opcode in (0x1, 0x2):
                return payload.decode()

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# --- theme building ---------------------------------------------------------

def build_patch(colors):
    missing = [r for r in ROLES.values() if r not in colors]
    if missing:
        raise SystemExit(f"colors.json lacks roles: {', '.join(missing)}")
    return {slot: colors[role] for slot, role in ROLES.items()}


def apply_patch(theme, patch):
    theme.update(patch)
    # keep the start-page fallback in sync only when it is a color, not an image
    if str(theme.get("defaultBackground", "")).startswith("#"):
        theme["defaultBackground"] = patch["colorBg"]
    return theme


def pick(themes, theme_id, name):
    for t in themes:
        if theme_id and t.get("id") == theme_id:
            return t
    for t in themes:
        if t.get("name") == name:
            return t
    return None


# --- delivery: running browser ----------------------------------------------

# prefs.set takes no callback and returns nothing; calls are delivered in order.
# themes.current must land before the schedule is switched off, or Vivaldi falls
# back to the pref default (Vivaldi1, light) at that moment.
JS = """(async () => {
  const P = vivaldi.prefs;
  const r = await P.get('vivaldi.themes.user');
  const themes = ((r && typeof r === 'object' && 'value' in r) ? r.value : r) || [];
  const patch = %(patch)s, id = %(id)s, name = %(name)s;
  const t = themes.find(x => x.id === id) || themes.find(x => x.name === name);
  if (!t) return 'no-theme';
  Object.assign(t, patch);
  if (String(t.defaultBackground || '').startsWith('#')) t.defaultBackground = patch.colorBg;
  P.set({path: 'vivaldi.themes.user', value: themes});
  P.set({path: 'vivaldi.themes.current', value: t.id});
  for (const v of ['off', 0]) {
    try { P.set({path: 'vivaldi.theme.schedule.enabled', value: v}); break; } catch (e) {}
  }
  return 'ok:' + t.id;
})()"""


def ui_targets(port):
    url = f"http://127.0.0.1:{port}/json/list"
    with urllib.request.urlopen(url, timeout=3) as r:
        targets = json.load(r)
    return [t for t in targets if t.get("url", "").endswith("window.html") and t.get("webSocketDebuggerUrl")]


def push_live(port, patch, theme_id, name):
    targets = ui_targets(port)
    if not targets:
        raise OSError("no Vivaldi UI target on the debug port")
    ws = WS(targets[0]["webSocketDebuggerUrl"])
    try:
        expr = JS % {
            "patch": json.dumps(patch),
            "id": json.dumps(theme_id or ""),
            "name": json.dumps(name),
        }
        ws.send(json.dumps({
            "id": 1,
            "method": "Runtime.evaluate",
            "params": {"expression": expr, "awaitPromise": True, "returnByValue": True},
        }))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == 1:
                break
    finally:
        ws.close()
    if "error" in msg:
        raise OSError(msg["error"].get("message", "evaluate failed"))
    res = msg["result"]
    if res.get("exceptionDetails"):
        raise OSError(json.dumps(res["exceptionDetails"].get("exception", {}).get("description", "?")))
    return res["result"].get("value")


# --- delivery: offline profile ----------------------------------------------

def push_file(profile, patch, theme_id, name):
    path = os.path.join(profile, "Preferences")
    with open(path, encoding="utf-8") as f:
        prefs = json.load(f)
    v = prefs.setdefault("vivaldi", {})
    themes = v.setdefault("themes", {}).setdefault("user", [])
    theme = pick(themes, theme_id, name)
    if theme is None:
        return "no-theme"
    apply_patch(theme, patch)
    v["themes"]["current"] = theme["id"]
    v.setdefault("theme", {}).setdefault("schedule", {})["enabled"] = 0

    backup = path + ".pre-matugen"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    fd, tmp = tempfile.mkstemp(dir=profile, prefix=".Preferences.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(prefs, f, separators=(",", ":"))
    os.replace(tmp, path)
    return "ok:" + theme["id"]


def vivaldi_running():
    return subprocess.run(["pgrep", "-x", "vivaldi-bin"], capture_output=True).returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--colors", default=DEFAULT_COLORS)
    ap.add_argument("--profile", default=DEFAULT_PROFILE)
    ap.add_argument("--name", default="Mine", help="theme name to patch")
    ap.add_argument("--id", default="", help="theme id, wins over --name")
    ap.add_argument("--port", type=int, default=9222)
    args = ap.parse_args()

    if not os.path.isdir(args.profile):
        return 0
    with open(args.colors, encoding="utf-8") as f:
        patch = build_patch(json.load(f))

    if vivaldi_running():
        try:
            result = push_live(args.port, patch, args.id, args.name)
        except (OSError, ValueError) as e:
            log(f"live push unavailable ({e}); colors will be applied by the "
                f"~/.local/bin/vivaldi wrapper on the next browser start")
            return 0
    else:
        result = push_file(args.profile, patch, args.id, args.name)

    if result == "no-theme":
        log(f"theme {args.id or args.name!r} not found, nothing to patch")
    return 0


if __name__ == "__main__":
    sys.exit(main())
