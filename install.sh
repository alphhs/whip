#!/bin/bash
# whipclaude installer — hooks, CLI, and the overlay app.
set -euo pipefail
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="$(basename "$APP_DIR")"
BIN_DIR="${HOME}/.local/bin"
HOOK_DIR="${HOME}/.claude/hooks"
SETTINGS="${HOME}/.claude/settings.json"

command -v jq   >/dev/null || { echo "need jq (brew install jq)"; exit 1; }
command -v node >/dev/null || { echo "need node 18+"; exit 1; }
python3 -c 'import sys; sys.exit(0)' || { echo "need python3"; exit 1; }

echo "==> installing deps"
( cd "$APP_DIR" && npm install --no-audit --no-fund )

echo "==> hooks -> $HOOK_DIR"
mkdir -p "$HOOK_DIR"
install -m 755 "$APP_DIR/hooks/whip"           "$HOOK_DIR/whip"
install -m 755 "$APP_DIR/hooks/whip-block.sh"  "$HOOK_DIR/whip-block.sh"
install -m 755 "$APP_DIR/hooks/whip-register.sh" "$HOOK_DIR/whip-register.sh"
install -m 755 "$APP_DIR/hooks/whip-verify.sh"   "$HOOK_DIR/whip-verify.sh"

echo "==> cli -> $BIN_DIR"
mkdir -p "$BIN_DIR" "$HOME/.claude/whip"
install -m 644 "$APP_DIR/lib/presets.json" "$HOME/.claude/whip/presets.json"
install -m 644 "$APP_DIR/lib/report.py"     "$HOME/.claude/whip/report.py"
install -m 755 "$APP_DIR/bin/whip" "$BIN_DIR/whip"
sed -e "s|__APP_DIR__|$APP_DIR|g" -e "s|__APP_NAME__|$APP_NAME|g" \
    "$APP_DIR/bin/whipclaude" > "$BIN_DIR/whipclaude"
chmod 755 "$BIN_DIR/whipclaude"

echo "==> registering hooks in $SETTINGS"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-whipclaude"
python3 - "$SETTINGS" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text() or "{}")
h = d.setdefault("hooks", {})
def add(event, cmd):
    lst = h.setdefault(event, [])
    if any(cmd in x["command"] for e in lst for x in e.get("hooks", [])):
        return False
    lst.append({"matcher": "*", "hooks": [{"type": "command", "command": cmd, "timeout": 5}]})
    return True
a = add("PostToolUse",  "~/.claude/hooks/whip")
b = add("PreToolUse",   "~/.claude/hooks/whip-block.sh")
c = add("SessionStart", "~/.claude/hooks/whip-register.sh")
# the verifier only runs on edits, and only if you set one
lst = h.setdefault("PostToolUse", [])
if not any("whip-verify" in x["command"] for e in lst for x in e.get("hooks", [])):
    lst.append({"matcher": "Write|Edit", "hooks": [{"type": "command",
                "command": "~/.claude/hooks/whip-verify.sh", "timeout": 130}]})
p.write_text(json.dumps(d, indent=2))
print(f"   PostToolUse:  {'added' if a else 'already present'}")
print(f"   PreToolUse:   {'added' if b else 'already present'}")
print(f"   SessionStart: {'added' if c else 'already present'}")
PY

case ":$PATH:" in *":$BIN_DIR:"*) ;; *)
  echo "   NOTE: $BIN_DIR is not on your PATH — add it to use 'whip'";; esac

cat <<'DONE'

installed.

  whip                  list live Claude Code sessions
  whip attach 1         bind one — later whips go there by default
  whip "go faster"      steer it mid-turn, without interrupting it
  whipclaude start      launch the overlay, then Cmd+Shift+W

Drop your own models in assets/ — see assets/README.md. It runs without them.
Restart Claude Code (or open /hooks once) so the new hooks load.
DONE
