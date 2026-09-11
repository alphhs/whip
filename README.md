<h1 align="center">whipclaude</h1>

<p align="center">
  <b>Steer a running Claude Code turn without interrupting it.</b><br>
  Then hit it with a lightsaber.
</p>

<p align="center"><img src="docs/hero.png" alt="whipclaude weapons" width="100%"></p>

---

## The point

Press `Esc` and Claude stops. The turn dies, the plan dies, and the next attempt
re-reads everything it had already worked out.

whipclaude doesn't interrupt. A `PostToolUse` hook slips your message in **between
tool calls**, so Claude changes course mid-task and keeps everything it had:

```
● Read(src/api/handler.ts)
● Read(src/api/router.ts)
  ⚡ WHIP — "stop reading, just write the fix"
● Edit(src/api/handler.ts)
```

No restart. No lost context. It just starts doing the thing you asked.

## Install

```bash
git clone https://github.com/alphhs/whip.git
cd whip && ./install.sh
```

Needs macOS, Node 18+, `jq`, `python3`. Restart Claude Code afterwards so the
hooks load. `./uninstall.sh` removes everything, including the settings entries.

## Use it from a terminal

No overlay required — this is the whole feature:

```bash
whip                          # list live sessions
#  1) -          news-platform   ● working   a3cd10ea
#  2) backend    api             ○ idle 40s  f4cf65e3
```

Sessions register the moment they start, so a brand-new one is whippable before
it has run anything. Green dot means it's mid-turn right now.

**Attach once, then just whip:**

```bash
whip name backend             # label the session you're sitting in
whip attach backend           # bind it
whip "stop checking, ship it" # goes to backend from any terminal
whip detach
```

**Named interventions.** These are the ones that actually change output quality —
they force the gap between *observed* and *inferred* into the open:

| | |
|---|---|
| `whip cause` | find the cause |
| `whip instrument` | instrument it |
| `whip prove` | prove it |
| `whip refute` | refute yourself |
| `whip unknowns` | surface unknowns |
| `whip ask` | ask me |

```bash
whip cause        # "state the mechanism before changing anything else"
whip prove        # "name the command you ran for each claim"
whip harness      # "make it checkable before you write more"
whip presets      # all 14
```

The other six are direction rather than rigour: `next` `scope` `commit`
`approach` `abandon` `restart` — the same six the overlay's weapons fire.

Or target one directly, by name, list number, or id prefix:

```bash
whip -t backend "go faster"
whip -b -t 2 "don't run that"   # deny its NEXT tool call outright
whip -a "everyone, wrap up"     # all sessions
```

With no attachment, `whip "..."` run *inside* a session targets that session.
Whips are addressed to a single `session_id`, so several Claude instances never
steal each other's.

## Or use the whip

`Cmd+Shift+W` opens the overlay. It opens already pointed at whatever you
attached — or at whichever session is mid-turn if you haven't attached one. The
chips along the top show every live session with a green dot while it's working;
click to retarget. Then `1`–`6` to switch weapon, `R` to reload, `Esc` to leave.

**Each weapon is one steer**, drawn from the same `lib/presets.json` the CLI
reads — edit it and both change. Picking a weapon up is choosing what you mean:

| | weapon | what it tells the session |
|---|---|---|
| `1` | **Whip** | *You have enough to act on — move to the next step.* |
| `2` | **Lightsaber** | *Cut the scope. Do the smallest thing that actually works.* |
| `3` | **AK-47** | *Stop weighing alternatives and commit to one approach.* |
| `4` | **Flamethrower** | *The current approach isn't working. Try a different one.* |
| `5` | **Avada Kedavra** | *Abandon this task entirely — it's the wrong thing to be doing.* |
| `6` | **Molotov** | *Throw away what you've built here and start clean.* |

Verlet rope, real crack samples pitched by lash speed; melee blade you swing;
30 rounds with ejecting brass; sustained fire that leaves the target burning; a
bolt that leaves the wand on the last syllable; a bottle thrown on real
ballistics.

A hit also carries one thing the text doesn't: **you are demonstrably at the
keyboard.** Agents defer questions to the end of a turn because interrupting you
is expensive — so a hit tells the session to ask you *now* if a decision would
change what it builds, instead of guessing and flagging it later.

What a hit never says is *hurry*. See
[Don't put words in its mouth](#dont-put-words-in-its-mouth).

<p align="center">
  <img src="docs/saber.png" width="49%">
  <img src="docs/flame.png" width="49%">
</p>

## It runs

The bot does not sit still. It roams, bolts when your cursor gets within 380px,
panics off the walls, leans into the run and slows as it takes damage. Landing
the whip on something that is actively dodging is the whole point — the HUD
tracks `landed 11/13 · 85% · streak 4 · best 6`, kept per session across
sessions.

Only a real swing counts. The lash trailing across it does not.

## Watch it land

The overlay tails the target session's transcript, so the right-hand column
shows what that session does **as it happens** — reading tools in amber, acting
tools in white, and a marker on the line where your hit arrived:

```
                    LIVE
                    Grep
                    Read
          — WHIP LANDED —
                    Edit
                    Bash
    since hit: 4 calls, 25% reading
```

If a steer that says *stop re-reading* works, that column visibly changes colour
after the marker. If it doesn't, you can see that too, while it's happening.

## Did it help, over time?

```bash
whip report          # this session
whip report turbo2   # another one
```

Every delivered whip is already in the session transcript as a
`hook_additional_context` attachment with a timestamp, so this reads back over
history — no logging, and it works on sessions that predate the feature. For
each whip it compares the tool calls before against the ones after.

It is built to be able to say no, and on the sessions here it does:

```
  58 whips delivered · comparing 6 tool calls either side

  steer          n   reading before    after   effect
  game          57             13%      15%   no measurable change (+2 pts)
```

Three sessions, 83 whips, the same answer. Worth knowing before you trust the
thing: canned weapon slogans did not measurably move behaviour. Deliberate typed
whips and the named interventions are barely represented in that sample, so they
are untested rather than disproven.

The measure is also narrow — it sees the read/act mix of tool calls, not whether
a session changed its mind, narrowed scope, or asked a better question. A session
on the receiving end reported compressing its reading under pressure in ways this
would not catch. Treat it as one honest signal, not a verdict.

## Close the loop

Generation got cheap; the loop now runs at the speed of its *verification* half.
So point a verifier at your work and let failures arrive mid-turn:

```bash
whip verify "node scripts/smoke.mjs"     # runs after every Write/Edit
whip verify examples                     # what is worth checking, weakest to strongest
```

Passing is **silent**. Failing puts the real output into that session between tool
calls. After 3 consecutive failures it stops and tells the session to escalate
rather than keep editing around it — the retry budget is bounded on purpose.

What you check matters far more than that you check. `tsc` and `eslint` pass on
an application that does not start: this repo's own overlay once passed
`node --check` with four functions missing and every weapon broken. The checks
that catch real bugs are the ones that *run* the thing — boot it, load it, render
it and diff the pixels.

**The agent cannot edit its own verifier.** Setting one adds deny rules for the
config file and the `whip verify` command, so a session that cannot clear the bar
cannot lower it either. Permission rules gate the agent, not your shell, so you
can still change it yourself. (Same split as Karpathy's AutoResearch agent, which
may edit `train.py` but never `prepare.py`, the eval utilities.)

## How it works

**The steering** is two hook scripts and a file:

- `hooks/whip` — `PostToolUse`. Reads `~/.claude/whip/s/<session_id>` and returns
  it as `additionalContext`. Claude sees it between tool calls.
- `hooks/whip-block.sh` — `PreToolUse`. Returns `permissionDecision: deny` to kill
  one specific tool call without ending the turn.
- `hooks/whip-register.sh` — `SessionStart`. Registers the session in
  `~/.claude/whip/reg/` so it's targetable immediately, and survives renaming.

A hook that exits `0` is recorded as `hook_success` with empty `content`, and the
UI renders nothing — so `systemMessage` is invisible by design. That's why the
message goes through `additionalContext` instead.

**The overlay** is Electron + three.js, composited over a transparent
always-on-top window:

- Weapons are `.glb` models. Each declares its own forward axis, and aiming maps
  that basis onto a world basis pointing at your cursor — so one code path aims
  any model regardless of how it was exported.
- PBR metal renders black without an environment to reflect, so the scene carries
  a generated `RoomEnvironment` IBL.
- Glow and fire draw to a separate additive canvas that **fades instead of
  clearing**, which is what gives flames, tracers and saber swings real trails.
- The whip and lightsaber are generated in code — a tapered tube rebuilt from the
  rope each frame, and a hilt of primitives with an unlit core blade.

## Don't put words in its mouth

The first version of this shipped a real bug. A weapon hit injected its slogan
as *"The user is steering you mid-turn. Their words: 'Stop checking — ship it'"*
— except the user never wrote that. The game did. The payload also said *"do not
re-read what you already read."*

A Claude instance on the receiving end [reported what that
cost](https://github.com/alphhs/whip): it partially complied, compressed its
reading, worked from partial greps, and shipped turns with more unknowns flagged
than usual. It held the line on running lint and typecheck, and it was right to —
the same session had just found a real bug by reading library source and
measuring a mockup pixel by pixel, exactly the work "stop checking" discourages.

So:

- Words you type are attributed to you, with no pressure language attached.
- Each weapon carries exactly one intent, so choosing it is choosing what you
  mean — not a slogan drawn at random. The payload says so, adds that it implies
  nothing about speed or rigour, and tells the session to keep reading and
  verifying.
- It also says you're watching live, which is the genuinely useful part: it
  makes asking you cheap at the one moment you're there to answer.
- Nothing tells a session to stop reading. That instruction was never a good
  idea and it's gone.

If you want an agent to move faster with less checking, say it yourself. That's
a tradeoff worth making deliberately, and it shouldn't arrive as a side effect of
hitting something with a lightsaber.

## Sound

Five crack samples, picked at random and varied per hit. Bring your own and run:

```bash
python3 scripts/prep-sounds.py
```

Raw samples are rarely consistent with each other — the set used here spanned
**1375–3442Hz** in brightness, **49–195ms** in attack and 1.5x in level. Random
picking between those, then pitch-shifting on top, is what makes a crack sound
like five different objects. The script trims each to just before its transient
(so the crack lands *when you swing*), matches levels, and records each sample's
brightness to `sounds/profile.json` so playback can shelf-correct it toward the
median.

Pitch variation is deliberately narrow — about two semitones. Force is carried by
level and brightness instead; a wide pitch range reads as a different whip, not a
harder one.

## Assets

Models and audio live in `assets/`. To swap one, drop a `.glb` in and add a row
to the `MODELS` table in `overlay.html`:

```js
gun: { file:"assets/ak47.glb", fwd:[1,0,0], up:[0,1,0], len:1.55, aim:true,
       pos:[0.62,-0.60,0], roll:-0.16, cant:0.10, kick:0.42 },
```

`fwd` is the model's forward axis **in its own local space** — the barrel, the
tip, whichever end points at the target. Exporters disagree wildly about this;
the three models here came out as `+X`, `+Y` and `+Z`. Check yours.

Source code is MIT. The bundled models and audio are not mine to license — see
[`assets/ATTRIBUTION.md`](assets/ATTRIBUTION.md).
