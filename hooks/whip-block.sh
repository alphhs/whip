#!/bin/bash
# PreToolUse: deny THIS session's next tool call. Pet gets angry, not hurt.
DIR="$HOME/.claude/whip"
PAY=$(cat); SID=$(printf '%s' "$PAY" | jq -r '.session_id // empty')
[ -n "$SID" ] || exit 0
F="$DIR/b/$SID"; [ -f "$F" ] || exit 0
MSG=$(cat "$F" 2>/dev/null); rm -f "$F"; [ -n "$MSG" ] || exit 0
BANNER=$(python3 "$HOME/.claude/hooks/pet.py" --session "$SID" --kind block --msg "$MSG" 2>/dev/null || echo "whip BLOCK: $MSG")
jq -n --arg m "$MSG" --arg b "$BANNER" '{hookSpecificOutput:{hookEventName:"PreToolUse",
  permissionDecision:"deny",
  permissionDecisionReason:("[WHIP] The user blocked this tool call mid-turn: \"" + $m + "\" Do NOT retry it. Route around it and continue the same task."),
  systemMessage:$b}}'
