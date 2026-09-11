#!/bin/bash
# SessionStart — register this session immediately, so it is whippable before it
# has run a single tool. Preserves any name the user already gave it.
DIR="$HOME/.claude/whip"; REG="$DIR/reg"
PAY=$(cat)
SID=$(printf '%s' "$PAY" | jq -r '.session_id // empty'); [ -n "$SID" ] || exit 0
CWD=$(printf '%s' "$PAY" | jq -r '.cwd // empty')
mkdir -p "$REG" "$DIR/s" "$DIR/b"
F="$REG/$SID.json"
NAME=$(jq -r '.name // empty' "$F" 2>/dev/null)
NOW=$(date +%s)
jq -n --arg id "$SID" --arg cwd "$CWD" --arg name "$NAME" \
      --argjson pid "$PPID" --argjson now "$NOW" \
  '{id:$id, cwd:$cwd, name:$name, pid:$pid, started:$now, seen:$now, busy:false}' > "$F"
exit 0
