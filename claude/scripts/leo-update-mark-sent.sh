#!/usr/bin/env bash
# Record that today's update to Leo has been sent, which lifts the
# leo-update-gate.sh UserPromptSubmit block for the rest of the day.
# Run by /sod-summary once I confirm I've sent it.
date +%Y-%m-%d > "$HOME/.claude/leo-update-sent"
echo "Leo update marked as sent for $(date +%Y-%m-%d)."
