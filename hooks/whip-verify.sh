#!/bin/bash
# PostToolUse on Write|Edit — the gen/verify loop, closed.
#
# Karpathy's formula: write a verifier, bound the retries, put it on a trigger,
# slide autonomy up as the verifier proves out. This is the trigger and the
# bound. Whatever command you set is the verifier.
#
# Silence on success is deliberate: a verifier that talks when it passes is
# noise, and noise is what gets ignored.
DIR="$HOME/.claude/whip"; CFG="$DIR/verify.json"; ST="$DIR/verify-state"
[ -f "$CFG" ] || exit 0
PAY=$(cat)
SID=$(printf '%s' "$PAY" | jq -r '.session_id // empty'); [ -n "$SID" ] || exit 0
CWD=$(printf '%s' "$PAY" | jq -r '.cwd // empty');        [ -n "$CWD" ] || exit 0
mkdir -p "$ST"

# nearest configured ancestor of cwd wins
CMD=""; ROOT=""; d="$CWD"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  c=$(jq -r --arg d "$d" '.[$d].cmd // empty' "$CFG" 2>/dev/null)
  if [ -n "$c" ]; then CMD="$c"; ROOT="$d"; break; fi
  d=$(dirname "$d")
done
[ -n "$CMD" ] || exit 0
MAX=$(jq -r --arg d "$ROOT" '.[$d].max // 3' "$CFG")
EVERY=$(jq -r --arg d "$ROOT" '.[$d].debounce // 20' "$CFG")

S="$ST/$SID.json"; NOW=$(date +%s)
LAST=$(jq -r '.last // 0' "$S" 2>/dev/null || echo 0)
FAILS=$(jq -r '.fails // 0' "$S" 2>/dev/null || echo 0)
SILENCED=$(jq -r '.silenced // false' "$S" 2>/dev/null || echo false)
[ $((NOW - LAST)) -lt "$EVERY" ] && exit 0        # debounce: edits come in bursts

OUT=$(cd "$ROOT" && timeout 120 bash -lc "$CMD" 2>&1); RC=$?

if [ "$RC" -eq 0 ]; then
  jq -n --argjson now "$NOW" '{last:$now, fails:0, silenced:false}' > "$S"
  exit 0                                          # passing verifier says nothing
fi

FAILS=$((FAILS + 1))
if [ "$FAILS" -gt "$MAX" ]; then
  if [ "$SILENCED" != "true" ]; then
    jq -n --argjson now "$NOW" --argjson f "$FAILS" '{last:$now, fails:$f, silenced:true}' > "$S"
    jq -n --arg c "[VERIFY] \"$CMD\" has now failed $FAILS times in a row. Stopping automatic feedback so this does not loop. Do not keep trying variations — the retry budget is spent. Tell the user what is failing and what you would need from them." \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
  else
    jq -n --argjson now "$NOW" --argjson f "$FAILS" '{last:$now, fails:$f, silenced:true}' > "$S"
  fi
  exit 0
fi

jq -n --argjson now "$NOW" --argjson f "$FAILS" '{last:$now, fails:$f, silenced:false}' > "$S"
TAIL=$(printf '%s' "$OUT" | tail -c 2500)
jq -n --arg cmd "$CMD" --arg out "$TAIL" --argjson f "$FAILS" --argjson m "$MAX" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",
    additionalContext:("[VERIFY] Your verifier failed after that edit (attempt " + ($f|tostring) + " of " + ($m|tostring) + ").\n$ " + $cmd + "\n\n" + $out + "\n\nThis is real output from a real run, not a guess. Fix the cause before continuing; if you cannot, say so rather than editing around it.")}}'
