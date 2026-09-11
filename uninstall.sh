#!/bin/bash
# Removes everything install.sh added. Leaves your cloned copy alone.
set -euo pipefail
SETTINGS="${HOME}/.claude/settings.json"
"${HOME}/.local/bin/whipclaude" stop 2>/dev/null || true
rm -f "${HOME}/.local/bin/whip" "${HOME}/.local/bin/whipclaude"
rm -f "${HOME}/.claude/hooks/whip" "${HOME}/.claude/hooks/whip-block.sh" "${HOME}/.claude/hooks/whip-register.sh" "${HOME}/.claude/hooks/whip-verify.sh"
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak-whipclaude-uninstall"
  python3 - "$SETTINGS" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text() or "{}")
for ev in ("PostToolUse", "PreToolUse", "SessionStart"):
    if ev in d.get("hooks", {}):
        d["hooks"][ev] = [e for e in d["hooks"][ev]
                          if not any("whip" in x["command"] for x in e.get("hooks", []))]
        if not d["hooks"][ev]: del d["hooks"][ev]
if d.get("hooks") == {}: del d["hooks"]
p.write_text(json.dumps(d, indent=2))
PY
fi
rm -rf "${HOME}/.claude/whip"
echo "uninstalled. your clone is untouched; rm -rf it to finish."
