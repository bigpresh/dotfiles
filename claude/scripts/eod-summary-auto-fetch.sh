#!/usr/bin/env bash
# Gather everything /eod-summary-auto needs in one go and emit a single JSON document.
#
# Why a single script: each gh / git / find call would otherwise need its own
# permission prompt, and the routine runs unattended from cron where a prompt
# would just hang. One script = one (whitelisted) Bash call; fetches run in
# parallel for speed.
#
# Sources gathered (all for "today", local time):
#   - git commits I authored today across ~/git/drains and ~/git/puppet (all branches,
#     so worktree commits are included)
#   - GitHub PRs I authored / issues assigned to me, updated today
#   - my Claude Code conversations today: the prompts I typed, grouped by project/worktree,
#     mined from the session transcripts under ~/.claude/projects (NOT the raw tool output)
#
# Output shape (stdout, JSON):
#   {
#     today, user,
#     git_commits: { "drains": ["<hash> <subject>", ...], "puppet": [...] },
#     prs:    [ { number, title, state, url, repository, updatedAt }, ... ],
#     issues: [ { number, title, state, url, repository, updatedAt }, ... ],
#     claude_activity: [ { project, cwd, prompts: ["...", ...] }, ... ],
#     session_summaries: ["<path>", ...]   # summary.md files touched today (bonus context)
#   }

set -uo pipefail

# EOD_DATE lets you dry-run against a past day, e.g. EOD_DATE=2026-07-15 ...; defaults to today.
TODAY="${EOD_DATE:-$(date +%Y-%m-%d)}"
GIT_REPOS=("$HOME/git/drains" "$HOME/git/puppet")

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Sane defaults so the final assembly never trips on a missing/empty fetch.
echo '[]' > "$TMPDIR/prs.json"
echo '[]' > "$TMPDIR/issues.json"
echo '[]' > "$TMPDIR/claude_activity.json"
: > "$TMPDIR/sessions.txt"
echo "unknown" > "$TMPDIR/user.txt"

(
  gh api /user --jq .login 2>/dev/null > "$TMPDIR/user.txt" || echo "unknown" > "$TMPDIR/user.txt"
) &

(
  # My PRs updated today. Fetch the most-recently-updated and filter to today locally,
  # which avoids fragile date-qualifier syntax across gh versions.
  gh search prs --author=@me --sort updated --order desc --limit 40 \
    --json number,title,state,url,repository,updatedAt 2>/dev/null \
    | jq --arg t "$TODAY" '[ .[] | select((.updatedAt // "") | startswith($t)) ]' \
    > "$TMPDIR/prs.json" 2>/dev/null \
    || echo '[]' > "$TMPDIR/prs.json"
) &

(
  gh search issues --assignee=@me --sort updated --order desc --limit 40 \
    --json number,title,state,url,repository,updatedAt 2>/dev/null \
    | jq --arg t "$TODAY" '[ .[] | select((.updatedAt // "") | startswith($t)) ]' \
    > "$TMPDIR/issues.json" 2>/dev/null \
    || echo '[]' > "$TMPDIR/issues.json"
) &

(
  # Session summary.md files touched today — bonus context alongside the transcripts.
  find "$HOME/.claude/projects" -name "summary.md" -newermt "$TODAY 00:00" 2>/dev/null \
    > "$TMPDIR/sessions.txt" || true
) &

(
  # Mine today's typed prompts out of the Claude Code session transcripts.
  # Group by cwd (project / worktree). We deliberately keep only genuine human prompts
  # (strings or text blocks), skipping tool results, meta lines and slash-command noise.
  python3 - "$TODAY" > "$TMPDIR/claude_activity.json" 2>/dev/null <<'PY' || echo '[]' > "$TMPDIR/claude_activity.json"
import sys, os, json, glob
from datetime import datetime, timezone

today = sys.argv[1]
root = os.path.expanduser("~/.claude/projects")
MAX_PER_CWD = 30
TRUNC = 300

def local_date(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.astimezone().date().isoformat()
    except Exception:
        return None

def extract_prompt(obj):
    if obj.get("type") != "user" or obj.get("isMeta"):
        return None
    msg = obj.get("message") or {}
    content = msg.get("content")
    text = None
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "tool_result":
                    return None            # this "user" turn is tool output, not a prompt
                if block.get("type") == "text":
                    parts.append(block.get("text", ""))
        text = " ".join(p for p in parts if p)
    if not text:
        return None
    text = " ".join(text.split()).strip()
    if not text:
        return None
    # Drop harness/command noise that isn't something I typed.
    if text.startswith("<command-") or "local-command-stdout" in text or text.startswith("Caveat:"):
        return None
    return text[:TRUNC]

by_cwd = {}
now = datetime.now().astimezone()
for path in glob.glob(os.path.join(root, "*", "*.jsonl")):
    try:
        # Cheap pre-filter: skip transcripts last touched before the target day. We can't
        # use "== today" because a session spanning midnight (or still open now) keeps a
        # later mtime while still holding the target day's lines; per-line filtering below
        # does the exact date match.
        if datetime.fromtimestamp(os.path.getmtime(path)).astimezone().date().isoformat() < today:
            continue
    except OSError:
        continue
    try:
        with open(path, "r", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                ts = obj.get("timestamp")
                if not ts or local_date(ts) != today:
                    continue
                prompt = extract_prompt(obj)
                if not prompt:
                    continue
                cwd = obj.get("cwd") or "(unknown)"
                by_cwd.setdefault(cwd, []).append(prompt)
    except OSError:
        continue

out = []
for cwd, prompts in sorted(by_cwd.items()):
    out.append({
        "project": os.path.basename(cwd.rstrip("/")) or cwd,
        "cwd": cwd,
        "prompts": prompts[:MAX_PER_CWD],
        "prompt_count": len(prompts),
    })
print(json.dumps(out))
PY
) &

wait

# git commits authored today, per repo (all branches so worktree commits count).
GIT_JSON="{}"
for repo in "${GIT_REPOS[@]}"; do
  name=$(basename "$repo")
  if [[ -d "$repo/.git" ]]; then
    email=$(git -C "$repo" config user.email 2>/dev/null)
    arr=$(git -C "$repo" log --all --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" \
            --author="$email" --format='%h %s' 2>/dev/null \
          | jq -R -s 'split("\n") | map(select(length > 0))')
    [[ -z "$arr" ]] && arr='[]'
  else
    arr='[]'
  fi
  GIT_JSON=$(jq --arg n "$name" --argjson a "$arr" '. + {($n): $a}' <<<"$GIT_JSON")
done

jq -n \
  --arg today "$TODAY" \
  --rawfile user "$TMPDIR/user.txt" \
  --argjson git_commits "$GIT_JSON" \
  --slurpfile prs "$TMPDIR/prs.json" \
  --slurpfile issues "$TMPDIR/issues.json" \
  --slurpfile claude_activity "$TMPDIR/claude_activity.json" \
  --rawfile sessions "$TMPDIR/sessions.txt" \
  '{
    today: $today,
    user: ($user | rtrimstr("\n")),
    git_commits: $git_commits,
    prs: $prs[0],
    issues: $issues[0],
    claude_activity: $claude_activity[0],
    session_summaries: ($sessions | split("\n") | map(select(length > 0)))
  }'
