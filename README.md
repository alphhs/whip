# whipclaude

Steer a running Claude Code turn **without interrupting it** — and hit it with a
lightsaber while you do.

Pressing Esc kills the whole turn and Claude restarts. This doesn't. A hook
injects your message between tool calls, so Claude changes course mid-task and
keeps everything it had already worked out.

## Install

```bash
./install.sh          # needs node 18+, jq, python3 (macOS)
whipclaude start      # then Cmd+Shift+W
```

Restart Claude Code afterwards so the hooks load.

## Use

**From any terminal** — no overlay needed:

```bash
whip -l                 # list live Claude Code sessions
whip "stop checking, ship it"
whip -t 2 "go faster"   # steer session #2 specifically
whip -b "don't run that"  # blocks its next tool call outright
```

Whips are addressed to one session, so several Claude instances never steal each
other's.

**Or Cmd+Shift+W** for the overlay: pick a target session from the chips at the
top, then `1`-`6` for a weapon, `R` to reload, Esc to leave.

| | |
|---|---|
| 1 Whip | Verlet rope, cracks on a real strike |
| 2 Lightsaber | melee — swing it through the target |
| 3 AK-47 | aims where you point, 30 rounds |
| 4 Flamethrower | hold to burn |
| 5 Avada Kedavra | fires when the incantation finishes |
| 6 Molotov | thrown on real ballistics |

Every hit sends that weapon's own message, so the weapon you pick changes what
Claude actually does.

## How it works

- `hooks/whip` runs on `PostToolUse`, reads `~/.claude/whip/s/<session_id>`, and
  returns it as `additionalContext` — Claude sees it between tool calls.
- `hooks/whip-block.sh` runs on `PreToolUse` and can `deny` a single tool call.
- The overlay is Electron + three.js. Weapons are 3D models aimed by mapping each
  model's own forward axis onto a world basis pointing at your cursor.

## Assets

None ship with this. Drop your own `.glb` files in `assets/` — see
`assets/README.md`. The Whip and Lightsaber are generated in code and need
nothing; every other weapon just renders without a model until you add one.

MIT, code only.
