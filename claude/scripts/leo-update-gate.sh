#!/usr/bin/env bash
# UserPromptSubmit hook: on weekdays, refuse prompts until today's update for Leo has
# been sent. The update is drafted by /sod-summary, which writes the marker once I
# confirm I've actually sent it.
#
# Why a hard block rather than a polite nudge: the polite SessionStart nudge got
# ignored, and evening "I'll send it once I've finished this bit" turned into not
# sending it at all. The block makes the morning routine the path of least resistance.
#
# Escape hatches:
#   - a prompt starting with /sod-summary is allowed, and so is the rest of that
#     session (its session_id is recorded), so I can answer the skill's questions
#   - a prompt starting with "URGENT:" is allowed, once; the next prompt is gated again
#   - LEO_GATE_SKIP=1 in the environment (headless claude -p runs, e.g. cron)

set -u

[ "${LEO_GATE_SKIP:-}" = "1" ] && exit 0

# Weekends: nothing to report to anyone.
[ "$(date +%u)" -ge 6 ] && exit 0

TODAY=$(date +%Y-%m-%d)
MARKER="$HOME/.claude/leo-update-sent"
[ "$(cat "$MARKER" 2>/dev/null)" = "$TODAY" ] && exit 0

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // empty')

# Sessions that have started /sod-summary today, one session_id per line.
ALLOWED="$HOME/.claude/sod-sessions-$TODAY"

# Leading whitespace shouldn't defeat the escape hatches.
trimmed="${prompt#"${prompt%%[![:space:]]*}"}"

case "$trimmed" in
    /sod-summary*)
        [ -n "$session" ] && echo "$session" >> "$ALLOWED"
        # Tidy up previous days' allow-lists.
        find "$HOME/.claude" -maxdepth 1 -name 'sod-sessions-*' ! -name "sod-sessions-$TODAY" -delete 2>/dev/null
        exit 0
        ;;
    URGENT:*)
        exit 0
        ;;
esac

if [ -n "$session" ] && grep -qxF "$session" "$ALLOWED" 2>/dev/null; then
    exit 0
fi

LAST=$(cat "$MARKER" 2>/dev/null || echo never)
REASON="Oi, wankpuffin. No update sent to Leo today (last sent: ${LAST}). Run /sod-summary first: plan the day, send Leo the update, THEN get stuck in. Genuinely on fire? Prefix the prompt with URGENT: (works for that one prompt only)."

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
