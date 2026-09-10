#!/usr/bin/env bash
# Cron entry point for the automated end-of-day boss-update draft.
#
# Runs a headless Claude Code session that follows ~/.claude/commands/eod-summary-auto.md:
# gather the day's git/GitHub/Claude activity, draft a boss update, and email it to me
# (david.precious@...) as a DRAFT to eyeball and forward. It never emails Leo directly.
#
# Scheduled on THIS box only (h-development-app-11) via the user crontab, NOT via the
# dotfiles cron-entry (that one is the all-boxes profile auto-updater). Weekdays 18:00.
#
# Scoped to --allowedTools "Bash Read" rather than --dangerously-skip-permissions: the
# routine only reads files and runs shell (git/gh/find/python/mail), so there's no reason
# to leave a blanket permission-bypass sitting in cron.
#
# Dry-run for a past day:  EOD_DATE=2026-07-15 ~/.claude/scripts/eod-summary-auto.sh

set -uo pipefail

export HOME="/home/davidp"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/bin"

# gh resolves the current repo from CWD; give it one (drains), per the /eod-summary note.
cd "$HOME/git/drains" 2>/dev/null || cd "$HOME"

LOG="$HOME/.claude/eod-auto.log"

{
  echo "===== eod-summary-auto run $(date -Iseconds) (EOD_DATE=${EOD_DATE:-today}) ====="
  claude -p "Follow the instructions in $HOME/.claude/commands/eod-summary-auto.md exactly. This is an unattended scheduled run: ask no questions, wait for no input — just gather, draft and email." \
    --allowedTools "Bash Read"
  echo "===== finished $(date -Iseconds) claude exit=$? ====="
  echo
} >> "$LOG" 2>&1
