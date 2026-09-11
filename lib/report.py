#!/usr/bin/env python3
"""Did whipping actually change anything?

Every delivered whip is already in the session transcript as a
hook_additional_context attachment with a timestamp, so this reads back over
history — no logging required, and it works on sessions that predate it.

For each whip it compares the N tool calls before against the N after. That is
a real measurement of behaviour, not a vibe, and it is perfectly capable of
reporting that nothing changed.
"""
import json, sys, re, pathlib
from collections import Counter

LOOK = 6                       # tool calls either side
READY = {"Read","Grep","Glob","WebFetch","WebSearch","NotebookRead","ToolSearch"}
DOY   = {"Edit","Write","NotebookEdit","Bash"}

def load(path):
    events = []
    for line in open(path):
        try: d = json.loads(line)
        except: continue
        ts = d.get("timestamp")
        if not ts: continue
        a = d.get("attachment") or {}
        if a.get("type") == "hook_additional_context":
            txt = json.dumps(a)
            if "[WHIP]" in txt:
                m = re.search(r'"([^"]*?\[WHIP\][^"]*)"', txt)
                events.append(("whip", ts, (m.group(1) if m else "")[:400]))
            continue
        if d.get("type") == "assistant":
            c = (d.get("message") or {}).get("content")
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        events.append(("tool", ts, b.get("name")))
    return events

def kind(label):
    for pat, k in (("Move on","next"),("Cut the scope","scope"),("commit","commit"),
                   ("not working","approach"),("Abandon","abandon"),("Throw away","restart"),
                   ("MECHANISM","cause"),("capture the actual","instrument"),
                   ("OBSERVED","prove"),("disprove","refute"),("assuming","unknowns")):
        if pat.lower() in label.lower(): return k
    return "typed" if "sent this mid-turn" in label else "game"

def main(path):
    ev = load(path)
    whips = [(i,e) for i,e in enumerate(ev) if e[0]=="whip"]
    if not whips:
        print("  no whips in this transcript"); return
    agg = {}
    for i,(_,ts,label) in whips:
        before = [e[2] for e in ev[max(0,i-LOOK*3):i] if e[0]=="tool"][-LOOK:]
        after  = [e[2] for e in ev[i+1:i+1+LOOK*3] if e[0]=="tool"][:LOOK]
        if len(before) < 3 or len(after) < 3: continue
        rb = sum(1 for t in before if t in READY)/len(before)
        ra = sum(1 for t in after  if t in READY)/len(after)
        k = kind(label)
        agg.setdefault(k, []).append((rb, ra, len(after)))
    if not agg:
        print("  not enough tool calls around any whip to compare"); return
    print(f"  {len(whips)} whips delivered · comparing {LOOK} tool calls either side\n")
    print(f"  {'steer':12} {'n':>3}  {'reading before':>15} {'after':>8}   effect")
    for k, rows in sorted(agg.items(), key=lambda kv: -len(kv[1])):
        n = len(rows)
        b = sum(r[0] for r in rows)/n
        a = sum(r[1] for r in rows)/n
        d = a - b
        eff = ("less reading" if d < -0.08 else
               "more reading" if d >  0.08 else "no measurable change")
        print(f"  {k:12} {n:3}  {b*100:13.0f}% {a*100:7.0f}%   {eff} ({d*100:+.0f} pts)")
    print("\n  'reading' = Read/Grep/Glob/WebFetch/WebSearch as a share of tool calls.")
    print("  A steer that says 'stop re-reading' should push this DOWN. If it does")
    print("  not, the whip did nothing measurable — which is a real answer.")

if __name__ == "__main__":
    main(sys.argv[1])
